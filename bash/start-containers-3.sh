#!/bin/bash
#start-containers-3.sh
#This script fires up the docker containers for stanton
#Make sure you run this command first
#echo "export DOCKER_HOST=10.0.0.24:3375"
source ./inc-parse-servers.sh

if [ -n "$DOCKER_HOST" ]; then
    exec 3< <(docker-compose -f /opt/stanton/devops/infrastructures.yml up -d)
    sed '/Creating topologies$/q' <&3
    echo -e "${RED}Connecting to topologies log${NC}"
    sleep 2
    until docker logs topologies 2>&1 | grep 'Finished\ submitting\ topology:\ report-render'
    do
        LINE=`docker logs topologies 2>&1 | tail -1`
        if [[ ${LINE} != ${LASTLINE} ]]; then
            echo "${LINE}"
            LASTLINE=${LINE}
        fi
        sleep 1
    done
    echo -e "${RED}Ready to run next command${NC}"
    echo -e "${GREEN}docker-compose -f /opt/stanton/devops/applications.yml up -d${NC}"
    echo -e "or script ${GREEN}./start-containers-4.sh${NC}"
else
    echo "DOCKER_HOST environment variable not set.  Please run 'export DOCKER_HOST=10.0.0.24:3375'"
fi

