#!/bin/bash
for pid in `pgrep -f "/bin/bash /home/rockittech/services/run.sh"`;
do
	if [ $pid != $$ ]; then
		kill "$pid"
		fi
done

while : 
do
    if ! pgrep -f "php /home/rockittech/services/irc/index.php"; then
    	(php /home/rockittech/services/irc/index.php & disown) > /home/rockittech/services/logs/irc.log 2>&1
    fi
    sleep 1m
	
date >> /home/rockittech/services/logs/run.log
done