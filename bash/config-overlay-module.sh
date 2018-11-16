#!/bin/bash
#config-overlay.sh
RED="\033[0;31m"
NC="\033[0m"
source ./inc-parse-servers.sh
for SERVER in "${SERVERS[@]}"
do
    if [ $CONTROLLER != $SERVER ]
        then
	echo -e "${RED}Setting overlay module on ${SERVER}${NC}"
	ssh root@${SERVER} 'echo "overlay" > /etc/modules-load.d/overlay.conf ; reboot'
    fi
done
	echo -e "${RED}Setting overlay module on ${CONTROLLER}${NC}"
	ssh root@${CONTROLLER} 'echo "overlay" > /etc/modules-load.d/overlay.conf ; reboot'
