#!/bin/bash
#start-containers-4.sh
#This script fires up the docker containers for HPAD
#Make sure you run this command first
#echo "export DOCKER_HOST=10.111.4.24:3375"
source ./inc-parse-servers.sh

if [ -n "$DOCKER_HOST" ]; then
    exec 3< <(docker-compose -f /opt/hpad/appdefender/applications.yml up -d)
    sed '/haproxy$/q' <&3 
    echo -e "${RED}Connecting to haproxy log${NC}"
    sleep 2
    until docker logs haproxy 2>&1 | grep '(runner)\ watching\ 4'
    do
        LINE=`docker logs haproxy 2>&1 | tail -1`
        if [[ ${LINE} != ${LASTLINE} ]]; then
            echo "${LINE}"
            LASTLINE=${LINE}
        fi
        sleep 1
    done
    echo -e "${RED}Script Complete${NC}"
else
    echo "DOCKER_HOST environment variable not set.  Please run 'export DOCKER_HOST=10.111.4.24:3375'"
fi




