#!/bin/bash
#nfs-unmount.sh
source ./inc-parse-servers.sh
NFSSERVER=10.0.0.24
DIR=(serverkeys devops app-config hostShellScripts consul license)

for SERVER in ${SERVERS[@]}
do
	if [ ${SERVER} != ${NFSSERVER} ]; then
		echo -e "${RED}Unmounting Directories on ${SERVER}${NC}"
		for d in ${DIR[@]}; do
			ssh root@${SERVER} "umount /mnt/nfs/${d}"
		done

		echo -e "${RED}Unmounting Directories on ${SERVER}${NC}"
		for d in ${DIR[@]}; do
			echo ssh root@${SERVER} "sed -i '/\/mnt\/nfs\/${d}/d' /etc/fstab"
			ssh root@${SERVER} "sed -i '/\/mnt\/nfs\/${d}/d' /etc/fstab"
		done

		echo -e "${RED}Unlinking NFS shares ${SERVER}${NC}"
		for d in ${DIR[@]}; do
			if ( ssh root@${SERVER} "[ -L /opt/stanton/${d} ]" ); then
				ssh root@${SERVER} "rm -f /opt/stanton/${d}"
			fi
		done
		for d in ${DIR[@]}; do
			if ( ssh root@${SERVER} "[ -d /opt/stanton/backup/${d} ]" ); then
				ssh root@${SERVER} "mv /opt/stanton/backup/${d} /opt/stanton/"
			fi
		done
	fi
done
