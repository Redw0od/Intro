#!/bin/bash
#distribute-license.sh
source ./inc-parse-servers.sh
KEYS='/opt/hpad/serverkeys/*.jks'
for SERVER in ${APPIPS[@]}
do
    echo -e "${RED}Copying key files to ${SERVER}${NC}"
    ssh root@${SERVER} "mkdir -p /opt/hpad/serverkeys/"
    ssh root@${SERVER} "rm -rf /opt/hpad/serverkeys/*"
    scp ${KEYS} root@${SERVER}:/opt/hpad/serverkeys/
done

