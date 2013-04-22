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
	print "  > " msg > "/dev/stderr"
	print msg
	if (!DEBUG)
		system("sleep 1")
	fflush()
}

// {
	#print ""         > "/dev/stderr"
	print "  < " $0  > "/dev/stderr"
}

function debug(msg) {
	print "  # " msg > "/dev/stderr"
	fflush()
}

function set() {
	debug("CMD:  [" CMD  "]")
	debug("SRC:  [" SRC  "]")
	debug("DST:  [" DST  "]")
	debug("FROM: [" FROM "]")
	debug("TO:   [" TO   "]")
	debug("ARG:  [" ARG  "]")
	debug("MSG:  [" MSG  "]")
	debug("$0:   [" $0   "]")
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

function say(to, msg) {
	if (msg == "") {
		msg = to
		if (DST ~ "^#")
			to = DST
		else if (DST == NICK && FROM)
			to = FROM
		else
			to = CHANNEL
	}
	send("PRIVMSG " to " :" msg)
}

function action(to, msg)
{
	if (msg)
		say(to, "\001ACTION " msg "\001")
	else
		say("\001ACTION " to "\001")
}

function reply(msg) {
	say(FROM ": " msg)
}

function join(chan) {
	send("JOIN " chan)
	send("TOPIC " chan)
}

function part(chan) {
	send("PART " chan)
}

function topic(chan, msg) {
	send("TOPIC " chan " :" msg)
}

# Reloading
BEGIN {
	if (CHILD == "") {
		debug("Starting server");
		cmd = "awk -f rhawk" \
		      " -v CHILD=1" \
		      " -v START=" systime() \
		      " -v DEBUG=" !!DEBUG
		status = system(cmd " -v FIRST=1");
		while (status)
			status = system(cmd);
		exit(0);
	} else {
		debug("Starting child:" \
		      " DEBUG=" DEBUG   \
		      " CHILD=" CHILD   \
		      " START=" START   \
		      " FIRST=" FIRST);
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
	gsub(/\s+/,     " ")
	gsub(/^ | $/,    "")
	gsub(/\3[0-9]*/, "")
	match($0, /(:([^ ]+) +)?(([A-Z0-9]+) +)(([^ ]+) +)?(([^: ]+) +)?(:(.*))/, arr);
	SRC = arr[2]
	CMD = arr[4]
	DST = arr[6]
	ARG = arr[8]
	MSG = arr[10]

	match(SRC, /([^! ]+)!([^@ ]+)@([^ ]+\/[^ ]+)?/, arr);
	FROM = arr[1]
	AUTH = arr[3]

	match(MSG, /(([^ :,]*)[:,] *)?(.*)/, arr);
	TO  = arr[2]
	$0  = TO ? arr[3] : MSG

	if (CMD == "PRIVMSG" && DST == NICK && FROM && !TO)
		TO = DST

	#set()
}

# IRC client
CMD == "001" && MSG ~ /Welcome/ {
	join(CHANNEL)
}

CMD == "PING" {
	send("PING " MSG)
}

CMD == "332" {
	CMD = "TOPIC"
	DST = ARG
}

CMD == "TOPIC" {
	topics[DST] = MSG
}
