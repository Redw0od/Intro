#!/bin/bash
#docker-shutdown.sh
RED='\033[0;31m'
NC='\033[0m'
source ./inc-parse-servers.sh

echo  -e "${RED}Disconnecting docker networks ${NC}"
docker network disconnect -f appdefender_default appdefender_backend_jobs_1
docker network disconnect -f appdefender_default appdefender_edge_1
docker network disconnect -f appdefender_default appdefender_command_channel_1
docker network disconnect -f appdefender_default appdefender_ui_customer_1
docker network disconnect -f appdefender_default appdefender_ui_internal_1
docker network disconnect -f appdefender_default appdefender_storm_supervisor_1
for NAME in "${NAMES[@]}"
do
docker network disconnect -f appdefender_default registrator${NAME}
done

for SERVER in "${SERVERS[@]}"
do
	echo -e "${RED}Stopping containers on ${SERVER}${NC}"
	ssh root@${SERVER} 'docker stop $(docker ps -a -q)'
	echo -e "${RED}Removing containers on ${SERVER}${NC}"
	ssh root@${SERVER} 'docker rm -v $(docker ps -a -q)'
done

