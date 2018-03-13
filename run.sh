#!/bin/bash

ENGINE_PORT=9001

if [ "$1" != "stop" ]; then
  docker network create vcf-net
  docker run -d --network vcf-net --name zookeeper zookeeper
  docker run -d --network vcf-net --name kafka --env ZOOKEEPER_IP=zookeeper ches/kafka
  docker run -d --network vcf-net --name function-engine --env IC_QUEUE_HOSTS=kafka:9092 -p ${ENGINE_PORT}:8080 sosoftware/function-engine:latest
  docker run -d --network vcf-net --name vcfjs --env KAFKA_HOST=kafka:9092 --restart on-failure:20 sosoftware/vcfjs:latest
  until docker exec vcfjs bash -c "cd ../function-engine-setup && yarn && yarn run setup:next"; do
    sleep 1
  done
  echo
  echo -e "\e[32mRUNNING!\e[0m"
else
  docker rm -f vcfjs function-engine kafka zookeeper
  docker network rm vcf-net
  echo
  echo -e "\e[31mDONE!\e[0m"
fi
