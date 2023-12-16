#!/usr/bin/env bash
CREATED_TAG=$(docker images arminc/clair-db --format "{{.CreatedSince}}" | cut -d ' ' -f 2)
if [[ $CREATED_TAG = "seconds" || $CREATED_TAG = "minutes" || $CREATED_TAG = "hours" ]]
then
    echo "clair-db container created less than 1 day ago, no need for clean-up"
else
    echo "clair-db container created more than 1 day ago - clean-up required"
    docker rmi arminc/clair-db:latest
fi