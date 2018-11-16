#!/bin/bash
#nfs-unmount.sh
source ./inc-parse-servers.sh
NFSSERVER=10.111.4.24
DIR=(serverkeys appdefender app-config hostShellScripts consul license)

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
			if ( ssh root@${SERVER} "[ -L /opt/hpad/${d} ]" ); then
				ssh root@${SERVER} "rm -f /opt/hpad/${d}"
			fi
		done
		for d in ${DIR[@]}; do
			if ( ssh root@${SERVER} "[ -d /opt/hpad/backup/${d} ]" ); then
				ssh root@${SERVER} "mv /opt/hpad/backup/${d} /opt/hpad/"
			fi
		done
	fi
done
