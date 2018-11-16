#!/bin/bash
#setup-nfs.sh
source ./inc-parse-servers.sh
NFSSERVER=10.111.4.24
DIR=(serverkeys appdefender app-config hostShellScripts consul license)

echo -e "${GREEN}Checking /etc/exports file on ${NFSSERVER}${NC}"
for d in ${DIR[@]}; do
	if ( cat /etc/exports | grep --quiet /opt/hpad/${d} ); then
		echo "${d} already in exports"
	else
		echo "/opt/hpad/${d} 10.111.4.0/255.255.255.0(ro,no_root_squash)" >> /etc/exports
	fi
done
if yum list installed 2>&1 | grep nfs-utils ; then
	echo -e "nfs-utils installed on ${NFSSERVER}"
else
	echo -e "${RED}Installing nfs-utils on ${SERVER}${NC}"
	ssh root@${SERVER} "yum -y install nfs-utils"
fi
systemctl enable nfs-server.service
systemctl start nfs-server.service

for SERVER in ${SERVERS[@]}
do
	if [ ${SERVER} != ${NFSSERVER} ]; then
		if ssh root@${SERVER} "yum list installed 2>&1 | grep nfs-utils" ; then
			echo -e "nfs-utils installed on ${SERVER}"
		else
			echo -e "${RED}Installing nfs-utils on ${SERVER}${NC}"
			ssh root@${SERVER} "yum -y install nfs-utils"
		fi
	    echo -e "${GREEN}Creating Mount Directories on ${SERVER}${NC}"
	    for d in ${DIR[@]}; do
		echo ssh root@${SERVER} "mkdir -p /mnt/nfs/${d}"
		ssh root@${SERVER} "mkdir -p /mnt/nfs/${d}"
	    done
	    
	    echo -e "${GREEN}Mounting NFS shares ${SERVER}${NC}"
	    for d in ${DIR[@]}; do
		if ssh root@${SERVER} "mount | grep /mnt/nfs/${d}"; then
		   	echo "${d} already mounted"
		else
			echo  "ssh root@${SERVER} 'mount ${NFSSERVER}:/opt/hpad/${d} /mnt/nfs/${d}'"
		   	ssh root@${SERVER} "mount ${NFSSERVER}:/opt/hpad/${d} /mnt/nfs/${d}"
		fi
		if ssh root@${SERVER} "cat /etc/fstab | grep /mnt/nfs/${d}"; then
		   	echo "${d} exists in fstab"
		else
		   	echo ssh root@${SERVER} "echo ${NFSSERVER}:/opt/hpad/${d} /mnt/nfs/${d} nfs  ro,sync,hard,intr 0 0 >> /etc/fstab"
		   	ssh root@${SERVER} "echo ${NFSSERVER}:/opt/hpad/${d} /mnt/nfs/${d} nfs  ro,sync,hard,intr 0 0 >> /etc/fstab"
		fi
	    done

	    echo -e "${GREEN}Linking NFS shares ${SERVER}${NC}"
	    for d in ${DIR[@]}; do
		if ( ssh root@${SERVER} "[ -d /opt/hpad/${d} ]" ); then
			echo ssh root@${SERVER} "mkdir -p /opt/hpad/backup/"
		    	echo ssh root@${SERVER} "cp -r /opt/hpad/${d} /opt/hpad/backup/"
		    	echo ssh root@${SERVER} "rm -rf /opt/hpad/${d}"
			ssh root@${SERVER} "mkdir -p /opt/hpad/backup/"
		    	ssh root@${SERVER} "cp -r /opt/hpad/${d} /opt/hpad/backup/"
		    	ssh root@${SERVER} "rm -rf /opt/hpad/${d}"
		fi
		if ( ssh root@${SERVER} "[ ! -L /opt/hpad/${d} ]" ); then
			echo ssh root@${SERVER} "ln -s /mnt/nfs/${d} /opt/hpad/${d}"
			ssh root@${SERVER} "ln -s /mnt/nfs/${d} /opt/hpad/${d}"
		fi
	    done
	fi
done
