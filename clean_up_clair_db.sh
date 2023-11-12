#!/usr/bin/env bash
CREATED_TAG=$(echo $(docker images | grep clair-db) | cut -d ' ' -f 5)
if [[ $CREATED_TAG -eq "seconds" || $CREATED_TAG -eq "minutes" || $CREATED_TAG -eq "hours" ]]
then
    echo "clair-db container created less than 1 day ago, no need for clean-up"
else
    echo "clair-db container created more than 1 day ago - clean-up required"
    docker rmi arminc/clair-db:latest
fi