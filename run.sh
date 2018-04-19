#!/bin/bash

ENGINE_PORT=9001

if [ "$1" != "stop" ]; then
  docker network create vcf-net
  docker run -d --network vcf-net --name zookeeper zookeeper
  docker run -d --network vcf-net --name redis redis
  docker run -d --network vcf-net --name kafka \
                --env ZOOKEEPER_IP=zookeeper ches/kafka
  docker run -d --network vcf-net --name function-engine \
                --env IC_REDIS_INCLUDED=True \
                --env IC_REDIS_HOST=redis \
                --env IC_QUEUE_HOSTS=kafka:9092 \
                -p ${ENGINE_PORT}:8080 \
                sosoftware/function-engine:latest


  for ID in {3..5}; do
    mkdir -p "/tmp/apps/vcf$ID"
    docker run -d --network vcf-net \
                  --name "vcfjs$ID" \
                  --env MLL_ID="vcfjs$ID" \
                  --env KAFKA_TOPIC="vcfjs$ID" \
                  --env KAFKA_HOST=kafka:9092 \
                  -v "/tmp/apps/vcf$ID:/opt" \
                  --restart on-failure:20 \
                  sosoftware/vcfjs:latest
    until docker exec "vcfjs$ID" bash -c "cd ../function-engine-setup && yarn && yarn run setup:next"; do sleep 1; done
  done
  echo "foo" > "/tmp/apps/vcf3/A"
  echo "foo" > "/tmp/apps/vcf4/A"
  echo "bar" > "/tmp/apps/vcf4/B"

  for ID in {1..2}; do
    docker run -d --network vcf-net --name "hello$ID" -p 8080 registry.sosoftware.pl/tfe/hello-rest
    docker run -d --network vcf-net \
                  --name "vcfjs$ID" \
                  --env MLL_ID="vcfjs$ID" \
                  --env KAFKA_TOPIC="vcfjs$ID" \
                  --env KAFKA_HOST=kafka:9092 \
                  --env REST_HELLO_URL="http://hello$ID/repository" \
                  --restart on-failure:20 \
                  sosoftware/vcfjs:latest
    until docker exec "vcfjs$ID" bash -c "cd ../function-engine-setup && yarn && yarn run setup:next"; do sleep 1; done
    # PORT=$(docker inspect --format='{{(index (index .NetworkSettings.Ports "8080/tcp") 0).HostPort}}' "hello$ID")
    # curl -X PUT localhost:$PORT/repositories/A 
  done
  
  docker exec redis bash -c 'redis-cli SADD http-A vcfjs1 && \
                             redis-cli SADD http-B vcfjs1 vcfjs2 && \
                             redis-cli SADD http-C vcfjs1 && \
                             redis-cli SADD file-A vcfjs3 vcfjs4 && \
                             redis-cli SADD file-B vcfjs4 && \
                             redis-cli SET vcfjs1 http && \
                             redis-cli SET vcfjs2 http && \
                             redis-cli SET vcfjs3 file && \
                             redis-cli SET vcfjs4 file && \
                             redis-cli SET vcfjs5 file'

  echo
  # shellcheck disable=SC1117
  echo -e "\e[32mRUNNING!\e[0m"
else
  docker rm -f vcfjs1 vcfjs2 vcfjs3 vcfjs4 vcfjs5 function-engine kafka zookeeper
  docker network rm vcf-net
  echo
  # shellcheck disable=SC1117
  echo -e "\e[31mDONE!\e[0m"
fi
