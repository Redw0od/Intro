#!/bin/bash
#launch-scripts.sh
source ./inc-parse-servers.sh
PRIORITY=0
COUNTER=0
if [ -n "$DOCKER_HOST" ]
then
    echo "DOCKER_HOST set to ${DOCKER_HOST}. Run command 'export DOCKER_HOST=' before starting this script"
    exit
fi
echo "CONTROLLER = ${CONTROLLER}"
for SERVER in "${SERVERS[@]}"
do
    if [ $CONTROLLER == $SERVER ]
	then
        PRIORITY=1
    fi
    if [ $PRIORITY -eq 1 ]
        then
        echo -e "${RED}Launching Swarm Scripts on ${SERVER}${NC}"
        ssh root@${SERVER} "/opt/stanton/hostShellScripts/${NAMES[$COUNTER]}.sh"
    fi
	COUNTER=$((COUNTER + 1 ))
done
PRIORITY=0
COUNTER=0
for SERVER in "${SERVERS[@]}"
do
    if [ $CONTROLLER == $SERVER ] 
        then 
        PRIORITY=1
    fi
    if [ $PRIORITY -eq 0 ]
	then
        echo -e "${RED}Launching Swarm Scripts on ${SERVER}${NC}"
	ssh root@${SERVER} "/opt/stanton/hostShellScripts/${NAMES[$COUNTER]}.sh"
    fi
	COUNTER=$((COUNTER + 1 ))
done
