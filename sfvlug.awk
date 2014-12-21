# SFV Lug
function email(to, from, subj, body, sendmail)
{
	from     = NICK "<andy@pileus.org>"
	subj     = "Update sfvlug.org!"
	body     = "The next SFVLUG meeting is TBA!"
	sendmail = "/usr/sbin/sendmail '" to "'"
	print "To: " to        | sendmail
	print "From: " from    | sendmail
	print "Subject: " subj | sendmail
	print ""               | sendmail
	print body             | sendmail
	say("Topic out of date, emailing " to);
	close(sendmail)
}

BEGIN { pollchan = "#sfvlug" }
(CMD == "PING"    && systime()-lastpoll > 60*60*24) ||
(CMD == "PRIVMSG" && /^\.poll/) {
	if (!TOPICS[pollchan]) {
		debug("Unknown topic for " pollchan);
		send("TOPIC " pollchan)
		next
	}
	_curl     = "curl -s http://sfvlug.org/"
	_day      = "(Sun|Mon|Tue|Wed|Thu|Fri|Sat)"
	_web_tba  = "next meeting is: TBA"
	_web_ptrn = "next meeting.*" _day "\\w+[, ]+([A-Z]\\w+) +([0-9]+)[, ]+([0-9]+)"
	_irc_ptrn = _day "\\w*[, ]+([A-Z]\\w+) +([0-9]+)"
	while (_curl | getline _line) {
		#if (match(_line, _web_tba))
		#	email("Brian <brian@zimage.com>");
		if (match(_line, _web_ptrn, _parts)) {
			_date  = _parts[1] " " _parts[2] " " _parts[3]
			_topic = TOPICS[pollchan]
			sub(_irc_ptrn, _date, _topic)
			if (_topic != TOPICS[pollchan])
				topic(pollchan, TOPICS[pollchan] = _topic)
			else
				debug("topic is already correct")
			break
		}
	}
	lastpoll = systime()
	close(_curl)
}

