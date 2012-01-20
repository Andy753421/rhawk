# Connect with:
#   socat 'TCP:localhost:12345' 'EXEC:awk -f $0'
#
# Pre-defined variables:
#
# When connected:
#   SERVER:  IRC Server that is connected to
#   NICK:    Nickname given by the bot
#   CHANNEL: Channel the bot is currently in
#
# When a messages is recieved:
#   CMD:     Message, e.g. PRIVMSG
#   SRC:     Source of the message
#   DST:     Destination of the message, e.g. the channel
#   TO:      Nickname the message was addressed to
#   FROM:    Nickname of the user who sent the message
#   MSG:     Message sent
#   $0:      Message sans TO

# Debugging
function send(msg) {
	#print "  > " msg > "/dev/stderr"
	print msg
	#system("sleep 1")
	fflush()
}

// {
	#print ""         > "/dev/stderr"
	#print "  < " $0  > "/dev/stderr"
}

function debug(msg) {
	print "  # " msg > "/dev/stderr"
	fflush()
}

function set() {
	debug("CMD:  " CMD)
	debug("SRC:  " SRC)
	debug("DST:  " DST)
	debug("FROM: " FROM)
	debug("TO:   " TO)
	debug("MSG:  " MSG)
}

# Functions
function connect(server, nick, channel) {
	SERVER  = server
	NICK    = nick
	CHANNEL = channel
	if (FIRST) {
		"whoami"   | getline _name
		"hostname" | getline _host
		send("USER " _name " " _host " " server " :" nick)
		send("NICK " nick)
	}
}
function privmsg(to, msg) {
	send("PRIVMSG " to " :" msg)
}
function say(msg) {
	if (DST ~ "^#")
		privmsg(DST, msg)
	else if (DST == NICK && FROM)
		privmsg(FROM, msg)
	else
		privmsg(CHANNEL, msg)
}

function reply(msg) {
	say(FROM ": " msg)
}

function join(chan) {
	send("JOIN " chan)
}

function part(chan) {
	send("PART " chan)
}

# Reloading
BEGIN {
	if (CHILD == "") {
		debug("Starting server");
		status = system("awk -f rhawk -v CHILD=1 -v FIRST=1");
		while (status)
			status = system("awk -f rhawk -v CHILD=1");
		exit(0);
	} else {
		debug("Starting child: CHILD=" CHILD " FIRST=" FIRST);
	}
}

function quit() {
	exit(0)
}

function reload() {
	exit(1)
}

# Input parsing
// {
	match($0, /(:([^ ]+) +)?(([A-Z0-9]+) +)(([^ ]+) +)?([^:]*:(.*))/, arr);
	gsub(/\s+/,     " ", arr[8])
	gsub(/^ | $/,    "", arr[8])
	gsub(/\3[0-9]*/, "", arr[8])
	SRC = arr[2]
	CMD = arr[4]
	DST = arr[6]
	MSG = arr[8]

	match(SRC, /([^! ]+)!/, arr);
	FROM = arr[1]

	match(MSG, /(([^ :,]*)[:,] *)?(.*)/, arr);
	TO  = arr[2]
	$0  = TO == NICK ? arr[3] : MSG

	if (CMD == "PRIVMSG" && DST == NICK && FROM)
		TO = DST
}

# IRC client
CMD == "001" && MSG ~ /Welcome/ {
	join(CHANNEL)
}

CMD == "PING" {
	send("PING " MSG)
}
