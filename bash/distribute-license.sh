#!/bin/bash
#distribute-license.sh
source ./inc-parse-servers.sh
LICENSE='/opt/stanton/devops-pdfile.pd'
COUNT=0
for SERVER in ${APPIPS[@]}
do
echo -e "${RED}Copying license file to ${SERVER}${NC}"
ssh root@${SERVER} "mkdir -p /opt/stanton/license/"
ssh root@${SERVER} "rm -rf /opt/stanton/license/*"
scp ${LICENSE} root@${SERVER}:/opt/stanton/license/
COUNT=$((COUNT + 1))
done

