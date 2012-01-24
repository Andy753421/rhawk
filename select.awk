BEGIN {
	extension("./select.so", "dlload");

	nc0   = "netcat -l -p 12345"
	nc1   = "netcat -l -p 54321"
	stdin = "/dev/stdin"

	while (1) {
		# Open pipes
		printf "" |& nc0
		printf "" |& nc1

		# Wait for input 
		if (!(fd = select("from", stdin, nc0, nc1))) {
			print "timeout"
			continue
		}

		# Read a line
		if (fd == stdin)
			if (!(st = getline line < fd))
				exit 0
		if (fd == nc0 || fd == nc1)
			if (!(st = fd |& getline line)) {
				print "broken pipe"
				close(fd)
				continue
			}

		# Print output
		print "line: [" fd "] -> [" line "]"
	}
}
