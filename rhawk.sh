#!/bin/bash
cd /home/andy/src/rhawk
while true; do
	socat TCP:'irc.freenode.net:6667' EXEC:'awk -f rhawk'
	sleep 30
done
