#!/bin/bash
#start-containers-1.sh
#This script fires up the docker containers for HPAD
#Make sure you run this command first
#echo "export DOCKER_HOST=10.111.4.24:3375"
source ./inc-parse-servers.sh

if [ -n "$DOCKER_HOST" ]; then
    exec 3< <(docker-compose -f /opt/hpad/appdefender/infrastructures.yml up -d db_migrations)
    sed '/Creating db_migrations$/q' <&3 
    echo -e "${RED}Connecting to db_migrations${NC}"
    sleep 2
    until docker logs db_migrations 2>&1 | grep 'INFO\ \[main\]\ -\ migrating'
    do
        LINE=`docker logs db_migrations 2>&1 | tail -1`
        if [[ ${LINE} != ${LASTLINE} ]]; then
            echo "${LINE}"
            LASTLINE=${LINE}
        fi
        sleep 1
    done
    echo -e "${RED}Ready to run next command${NC}"
    echo -e "${GREEN}docker-compose -f /opt/hpad/appdefender/applications.yml up -d ui_customer${NC}"
    echo -e "or script ${GREEN}./start-containers-2.sh${NC}"
else
    echo "DOCKER_HOST environment variable not set.  Please run 'export DOCKER_HOST=10.111.4.24:3375'"
fi
