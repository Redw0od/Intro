#!/bin/bash
#distribute-license.sh
source ./inc-parse-servers.sh
LICENSE='/opt/hpad/appdefender-pdfile.pd'
COUNT=0
for SERVER in ${APPIPS[@]}
do
echo -e "${RED}Copying license file to ${SERVER}${NC}"
ssh root@${SERVER} "mkdir -p /opt/hpad/license/"
ssh root@${SERVER} "rm -rf /opt/hpad/license/*"
scp ${LICENSE} root@${SERVER}:/opt/hpad/license/
COUNT=$((COUNT + 1))
done

