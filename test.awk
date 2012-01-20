# Functions
function say(who, msg)
{
	print ":" who "! PRIVMSG #rhtest :" msg
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
	gsub(/\<[nbp]|[+-]/, "", arg)
	if      (cmd ~ /^\./)     0 # nop
	else if (cmd ~ /^n/)      say(who, ".newgame " arg)
	else if (cmd ~ /^e/)      say(who, ".endgame ")
	else if (cmd ~ /^j/)      say(who, ".join")
	else if (cmd ~ /^d/)      say("andy753421", ".deal " who " " hand[who])
	else if (cmd ~ /^l/)      say(who, ".look")
	else if (cmd ~ /^b/)      say(who, ".bid "  arg)
	else if (cmd ~ /^s/)      say(who, ".score")
	else if (cmd ~ /^B/)      say(who, ".bids")
	else if (cmd ~ /^t/)      say(who, ".tricks")
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
BEGIN { reset() }

//  { gsub(/#.*/, "") }

/^[^ ]+:/ {
	gsub(/:/, "")
	pi = length(players)
	if (NF-2 > nturns)
		nturns = NF-1
	for (i=2; i<=NF; i++)
		turns[pi][i-2] = $i
	players[pi] = $1
	hand[$1]    = $0
	gsub(/^\w*|[nbp-]\w+|\<[nejlbsBtpd]\>|[.+]/, "", hand[$1])
	gsub(/^ */, "", hand[$1])
	print $1 ": " hand[$1] > "/dev/stderr"
	say($1, "unicode :(")
}

/^\s*$/ {
	for (ti=0; ti<nturns; ti++)
		for (pi=0; pi<length(players); pi++)
			command(players[pi], turns[pi][ti])
	reset()
}
