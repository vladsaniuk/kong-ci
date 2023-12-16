#!/bin/sh
for plugin in "${WORKSPACE}"/opt/plugins/*
do
    if [ "$plugin" = "${WORKSPACE}/opt/plugins/*" ]
    then
        echo "No folders in /tmp, probably plugins folder wasn't mounted"
        exit 1
    fi
    luacheck "$plugin" --ignore kong self --max-line-length 130
done