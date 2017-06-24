#!/usr/bin/env bash
IMAGE="joostvdg-github-io-image"
NAME="joostvdg-github-io-instance"

RUNNING=`docker ps | grep -c $NAME`
if [ $RUNNING -gt 0 ]
then
   echo "Stopping $NAME"
   docker stop $NAME
fi

EXISTING=`docker ps -a | grep -c $NAME`
if [ $EXISTING -gt 0 ]
then
   echo "Removing $NAME"
  docker rm $NAME
fi

echo "Create new instance $NAME based on $IMAGE"
docker run --name $NAME -d $IMAGE

echo "Tail the logs of the new instance"
docker logs $NAME

IP=$(docker inspect --format '{{.NetworkSettings.Networks.bridge.IPAddress}}' $NAME)
echo "IP address of the container: $IP"
echo "http://${IP}/docs/"
