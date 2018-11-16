#!/bin/bash
#distribute-scripts.sh
RED='\033[0;31m'
NC='\033[0;0m'
source ./inc-parse-servers.sh
COUNT=0
for SERVER in ${SERVERS[@]}
do
echo -e "${RED}Copying ${NAMES[$COUNT]}.sh to ${SERVER}${NC}"
ssh root@${SERVER} "mkdir -p /opt/hpad/hostShellScripts/"
ssh root@${SERVER} "mkdir -p /opt/hpad/app-config/"
scp /opt/hpad/hostShellScripts/${NAMES[$COUNT]}.sh root@${SERVER}:/opt/hpad/hostShellScripts/
scp /opt/hpad/app-config/* root@${SERVER}:/opt/hpad/app-config/
COUNT=$((COUNT + 1))
done

echo -e "${RED}Copying haproxy.tmpl to ${PROXY_HOST}${NC}"
ssh root@${PROXY_HOST} "mkdir -p /opt/hpad/haproxy/"
scp /opt/hpad/appdefender/haproxy.tmpl root@${PROXY_HOST}:/opt/hpad/haproxy/

