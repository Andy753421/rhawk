#!/bin/bash
KEEPALIVE="keepalive,keepidle=240,keepcnt=1,keepintvl=1"
cd /home/andy/src/rhawk
while true; do
	socat TCP:"irc.freenode.net:6667,$KEEPALIVE" EXEC:"awk -f rhawk"
	sleep 30
done
