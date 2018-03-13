#!/bin/bash

ENGINE_PORT=9001

if [ "$1" != "stop" ]; then
  docker network create kafka-net
  docker run -d --name zookeeper --network kafka-net zookeeper
  docker run -d --name kafka --network kafka-net --env ZOOKEEPER_IP=zookeeper ches/kafka
  docker run -d --name function-engine --env IC_QUEUE_HOSTS=kafka:9092 --network kafka-net -p ${ENGINE_PORT}:8080 sosoftware/function-engine:latest
  docker run -d --name vcfjs --network kafka-net --restart on-failure:20 sosoftware/vcfjs:latest
  until docker exec -it vcfjs bash -c "cd ../function-engine-setup && yarn && yarn run setup:next"; do
    sleep 1
  done
  echo
  echo -e "\e[32mRUNNING!\e[0m"
else
  docker rm -f vcfjs function-engine kafka zookeeper
  docker network rm kafka-net
  echo
  echo -e "\e[31mDONE!\e[0m"
fi
