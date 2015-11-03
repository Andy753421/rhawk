# Testing
cat <<EOF > /tmp/test.awk
	BEGIN {
		offset = 0;
		FROM   = "andy";
	}

	function reply(msg) {
		print "\t" FROM ": " msg
	}

	function say(msg) {
		print "\t" msg
	}

	// {
		printf("%s", \$1)
	}

	/^\.wait +[0-9]+\$/ {
		offset += \$2;
	}

	/^\.atclr\$/ {
		delete remind;
		json_save("var/remind.json", remind);
		say("all jobs cleared");
	}
EOF

awk -f /tmp/test.awk -f remind.awk <<-EOF
	.atclr
	.in   "1 min" hello october
	.in   "2 min" hello november
	.atq
	.wait 60
	.atq
	.atq!
	.atc  3
	.atc  1
	.atrm 1
	.atrm 1
	.atq
	.atq!
EOF
