# SFV Lug
function sfvlug_email(to,   from, subj, body, sendmail)
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

function sfvlug_website(   curl, day, tba, ptrn, line, date, parts)
{
	debug("Polling SFVLUG Website");

	curl = "curl -s http://sfvlug.org/"
	day  = "(Sun|Mon|Tue|Wed|Thu|Fri|Sat)"
	tba  = "next meeting is: TBA"
	ptrn = "next meeting.*" day "\\w+[, ]+([A-Z]\\w+) +([0-9]+)[, ]+([0-9]+)"
	while (curl | getline line) {
		if (match(line, tba))
			debug("Website date is TBA");
		if (match(line, ptrn, parts))
			date = parts[1] " " parts[2] " " parts[3]
		#sfvlug_email("Brian <brian@zimage.com>");
	}
	close(curl)
	return date
}

function sfvlug_meetup(   url, curl, line, text, name, where, when)
{
	debug("Polling SFVLUG Meetup");

	# Signed API URL (this cannot be changed)
	url = "http://api.meetup.com/2/events?" \
			"group_id=2575122&"     \
			"status=upcoming&"      \
			"order=time&"           \
			"limited_events=False&" \
			"desc=false&"           \
			"offset=0&"             \
			"photo-host=public&"    \
			"format=json&"          \
			"page=500&"             \
			"fields=&"              \
			"sig_id=28045742&"      \
			"sig=42d2f7ec48b697ba087db2d8f2c65a2f144de8b1"

	# Download JSON data
	curl = "curl -s \'" url "\'"
	while (curl | getline line)
		text = text "\n" line
	close(curl);

	# Parse JSON and save extracted data
	json_decode(text, events)
	if (!isarray(events) ||
	    !isarray(events["results"]) ||
	    !isarray(events["results"][0]) ||
	    !isarray(events["results"][0]["venue"])) {
		debug("No results from Meetup");
		return
	}
	for (key in events["results"][0])
		json_copy(sfvlug_event, key, events["results"][0][key])

	# Lookup time
	name   = sfvlug_event["name"]
	where  = sfvlug_event["venue"]["name"] " " \
	         sfvlug_event["venue"]["city"]
	when   = sfvlug_event["time"] + \
	         sfvlug_event["utc_offset"]
	when   = strftime("%a %B %d, %l:%M%P", when/1000)
	gsub(/[.!?:]+$/,   "",  name)
 	gsub(/Restaurant/, "",  where)
	gsub(/  +/,        " ", where)
	gsub(/  +/,        " ", when)
	debug("event: ...\n" json_encode(sfvlug_event))
	debug("name:  " name)
	debug("when:  " when)
	debug("where: " where)
	return name ": " when " " where
}

function sfvlug_update(chan)
{
	# Make sure we have the current topic
	if (!TOPICS[chan]) {
		debug("Unknown topic for " chan);
		send("TOPIC " chan)
		return
	}

	# Testing
	#text = sfvlug_website()
	text = sfvlug_meetup()
	if (!text)
		return

	# Update IRC
	update = TOPICS[chan]
	sub(/\| [^|]+ \|/, "| " text " |", update)
	if (update != TOPICS[chan]) {
		topic(chan, TOPICS[chan] = update)
	} else {
		debug("topic is already correct")
	}
}

# Main
BEGIN {
	debug("Loading SFVLUG");
	sfvlug_channel       = "#sfvlug"
	sfvlug_polled        = 0
	sfvlug_event["time"] = 0
	sfvlug_event["name"] = 0
}

(CMD == "PING"    && systime()-sfvlug_polled > 60*60*24) ||
(CMD == "PRIVMSG" && /^\.poll/) {
	debug("Updating SFVLUG topic")
	sfvlug_update(sfvlug_channel)
	sfvlug_polled = systime()
}

