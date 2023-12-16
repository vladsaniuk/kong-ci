#!/bin/sh
set -x
printenv
echo "${WORKSPACE}"
ls -l
ls -l /var
ls -l /var/jenkins_home
ls -l /var/jenkins_home/workspace
ls -l /var/jenkins_home/workspace/Kong_CI_main
ls -l /var/jenkins_home/workspace/Kong_CI_main/opt
ls -l /var/jenkins_home/workspace/Kong_CI_main/opt/plugins/
ls -l "${WORKSPACE}"
# ls -l /tmp/
# for plugin in /tmp/*
# for plugin in /var/jenkins_home/workspace/Kong_CI_main/opt/plugins/*
for plugin in "${WORKSPACE}"/opt/plugins/*
do
    # if [ "$plugin" = "/tmp/*" ]
    if [ "$plugin" = "${WORKSPACE}/opt/plugins/*" ]
    then
        echo "No folders in /tmp, probably plugins folder wasn't mounted"
        exit 1
    fi
    luacheck "$plugin"
done