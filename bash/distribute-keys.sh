#!/bin/bash
#distribute-license.sh
source ./inc-parse-servers.sh
KEYS='/opt/stanton/serverkeys/*.jks'
for SERVER in ${APPIPS[@]}
do
    echo -e "${RED}Copying key files to ${SERVER}${NC}"
    ssh root@${SERVER} "mkdir -p /opt/stanton/serverkeys/"
    ssh root@${SERVER} "rm -rf /opt/stanton/serverkeys/*"
    scp ${KEYS} root@${SERVER}:/opt/stanton/serverkeys/
done

