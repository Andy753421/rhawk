@include "json.awk"

# Load saved at queue
BEGIN {
	json_load("var/remind.json", remind);
}

# Parse an at style time
function atp(now, time,   cmd, iso, arr, month) {
	# Remove quotes if needed
	gsub(/["']/, "", time);

	# Normalize date
	cmd = "atp " now " " time " 2>/dev/null";
	cmd | getline iso;
	close(cmd);

	# Parse date
	gsub(/^\w+ |:/, " ", iso);
	if (!match(iso, /(\w+) +([0-9]+ [0-9]+ [0-9]+ [0-9]+) +([0-9]+)/, arr))
		return -1;
	month = (index("JanFebMarAprMayJunJulAugSepOctNovDec", arr[1])-1)/3+1;
	return mktime(arr[3] " " month " " arr[2])
}

# Queue a new job
function at(from, text, prefix,   now, arr, desc, time, mesg, cmd) {
	now = systime();

	# Check input
	if (!match(text, /^.(at|in) +([a-zA-Z0-9:+-]+|"[ a-zA-Z0-9:+-]+") +(.*)/, arr))
		return reply("invalid time");
	if (!arr[3])
		return reply("no message");
	desc = arr[2];
	mesg = arr[3];

	# Parse date
	time = atp(now, prefix desc);
	if (time < 0)
		return reply("unparsable time: " desc);
	if (time < now)
		return reply("time is in the past");
	if (time == now)
		return reply("date is right now");

	# Log message
	id = length(remind);
	remind[id]["time"] = time;
	remind[id]["from"] = from;
	remind[id]["mesg"] = mesg;
	remind[id]["done"] = "pending";
	json_save("var/remind.json", remind);

	say("queued job " id ": " \
		strftime("%Y-%m-%d %H:%M", time));
}

# Print the at queue
function atq(all,    i, from, time, done, desc, line) {
	for (i = 0; i < length(remind); i++) {
		from = remind[i]["from"];
		time = remind[i]["time"];
		done = remind[i]["done"];
		if (!all && done != "pending")
			continue;
		desc = strftime("%Y-%m-%d %H:%M", time);
		line = sprintf("%-3d %s  %s (%s)", i, desc, from, done);
		say(line);
	}
}

# Print an at job
function atc(id) {
	if (id >= length(remind))
		return reply("invalid job id");
	say("job " id ": " remind[id]["mesg"]);
}

# Remove job from the queue
function atrm(id) {
	if (id >= length(remind))
		return reply("invalid job id");
	if (remind[id]["done"] != "pending")
		return reply("job is not pending");
	remind[id]["done"] = "canceled";
	json_save("var/remind.json", remind);
	say("canceled job " id);
}

# Run the at daemon
function atd(now) {
	now = systime();
	for (i = 0; i < length(remind); i++) {
		if (remind[i]["done"] != "pending")
			continue;
		if (remind[i]["time"] > now)
			continue;
		remind[i]["done"] = "finished";
		say(CHANNEL, remind[i]["from"] ": " remind[i]["mesg"]);
	}
	json_save("var/remind.json", remind);
}


# At handlers
/^\.at / {
	at(FROM, $0, "");
}

/^\.in / {
	at(FROM, $0, "now+");
}

/^\.atq/ {
	atq($0 ~ /!/);
}

/^\.atc +[0-9]+$/ {
	atc($2);
}

/^\.atrm +[0-9]+$/ {
	atrm($2);
}

/^\.help$/ {
	say(".help at   -- queue reminders for later")
}

/^\.help at/ {
	say(".at [time] [msg] -- record a message for the given time")
	say(".in [len] [msg] -- same as .at \"now + len\"")
	say(".atq -- list any pending job")
	say(".atq! -- list all jobs in the queue")
	say(".atc [n] -- print the given job")
	say(".atrm [n] -- delete the given job")
	next
}

// { 
	atd();
}
