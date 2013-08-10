# Functions
function say(who, msg)
{
	print ":" who"!u@h PRIVMSG #rhtest :" msg
}

function auth(user, nick)
{
	print ":" nick "!u@c ACCOUNT " user
}

function error(msg)
{
	print "error: " msg > "/dev/stderr"
}

function debug(msg)
{
	print msg > "/dev/stderr"
}

function command(who, cmd)
{
	arg=cmd
	gsub(/\<[nbpYNS]|[+-]/, "", arg)
	if      (cmd ~ /^\./)     0 # nop
	else if (cmd ~ /^n/)      say(who, ".newgame " arg)
	else if (cmd ~ /^e/)      say(who, ".endgame ")
	else if (cmd ~ /^j/)      say(who, ".join")
	else if (cmd ~ /^Y/)      say(who, ".allow " arg)
	else if (cmd ~ /^N/)      say(who, ".deny " arg)
	else if (cmd ~ /^S/)      say(who, ".show ")
	else if (cmd ~ /^d/)      say("andy753421", ".deal " who " " hand[who])
	else if (cmd ~ /^l/)      say(who, ".look")
	else if (cmd ~ /^b/)      say(who, ".bid "  arg)
	else if (cmd ~ /^s/)      say(who, ".score")
	else if (cmd ~ /^B/)      say(who, ".bids")
	else if (cmd ~ /^t/)      say(who, ".tricks")
	else if (cmd ~ /^T/)      say(who, ".turn")
	else if (cmd ~ /^p/)      say(who, ".pass " arg)
	else if (arg ~ /[shdc]$/) say(who, ".play " arg)
	else                      error("unknown cmd '" cmd "'")
}

function reset()
{
	nturns = 0
	delete players # players[i]   -> "name"
	delete turns   # turns[pi][i] -> "cmd"
}

# Rules
BEGIN { 
	auth("andy753421", "andy753421")
	reset()
}

//  { gsub(/#.*/, "") }

/^[^ ]+:/ {
	gsub(/:/, " ")
	split($1, parts, "/");
	pi = length(players)
	if (NF-2 > nturns)
		nturns = NF-1
	for (i=2; i<=NF; i++)
		turns[pi][i-2] = $i
	who         = parts[1]
	players[pi] = parts[1]
	auths[pi]   = parts[2]
	hand[who]    = $0
	gsub(/^\w*(\/\w*)?|[nbpYN-]\w+|\<[nejadwlbsBtpdS]\>|[.+]/, "", hand[who])
	gsub(/^ */, "", hand[who])
	print who ": " hand[who] > "/dev/stderr"
	say(who, "unicode :(")
	say(who, "colors :(")
}

/^\s*$/ {
	for (pi=0; pi<length(players); pi++)
		if (auths[pi])
			auth(auths[pi], players[pi])
	for (ti=0; ti<nturns; ti++)
		for (pi=0; pi<length(players); pi++)
			command(players[pi], turns[pi][ti])
	reset()
}
