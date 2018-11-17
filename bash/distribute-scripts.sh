#!/bin/bash
#distribute-scripts.sh
RED='\033[0;31m'
NC='\033[0;0m'
source ./inc-parse-servers.sh
COUNT=0
for SERVER in ${SERVERS[@]}
do
echo -e "${RED}Copying ${NAMES[$COUNT]}.sh to ${SERVER}${NC}"
ssh root@${SERVER} "mkdir -p /opt/stanton/hostShellScripts/"
ssh root@${SERVER} "mkdir -p /opt/stanton/app-config/"
scp /opt/stanton/hostShellScripts/${NAMES[$COUNT]}.sh root@${SERVER}:/opt/stanton/hostShellScripts/
scp /opt/stanton/app-config/* root@${SERVER}:/opt/stanton/app-config/
COUNT=$((COUNT + 1))
done

echo -e "${RED}Copying haproxy.tmpl to ${PROXY_HOST}${NC}"
ssh root@${PROXY_HOST} "mkdir -p /opt/stanton/haproxy/"
scp /opt/stanton/devops/haproxy.tmpl root@${PROXY_HOST}:/opt/stanton/haproxy/

