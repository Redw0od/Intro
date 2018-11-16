#!/bin/bash
for pid in `pgrep -f "/bin/bash /home/rockittech/services/OperaCron.sh"`;
do
	if [ $pid != $$ ]; then
		kill "$pid"
		fi
done

date > /home/rockittech/services/logs/cron.log

for i in `seq 1 59`;
do

if ! pgrep -f "php /home/rockittech/services/channel.php"; then
    	(php /home/rockittech/services/channel.php & disown) > /home/rockittech/services/logs/channel.log 2>&1
    fi

if ! pgrep -f "php /home/rockittech/services/irc/index.php"; then
    	(/bin/bash /home/rockittech/services/run.sh & disown) > /home/rockittech/services/logs/run.log 2>&1
    fi

if ! pgrep -f "php /home/rockittech/rockittech.com/opera/irc/run-chatters.php"; then
    	(php /home/rockittech/services/run-chatters.php) > /home/rockittech/services/logs/chatters.log 2>&1
    fi
	
if ! pgrep -f "php /home/rockittech/services/followers.php"; then
    	(php /home/rockittech/services/followers.php & disown) > /home/rockittech/services/logs/followers.log 2>&1
    fi

sleep 1m
date >> /home/rockittech/services/logs/cron.log
done