#!/bin/sh

for plugin in /tmp/*
do
    if [ "$plugin" = "/tmp/*" ]
    then
        echo "No folders in /tmp, probably plugins folder wasn't mounted"
        exit 1
    fi
    luacheck "$plugin"
done