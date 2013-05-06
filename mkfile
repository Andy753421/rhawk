CFLAGS   = -g -Wall -fPIC --std=c99
CPPFLAGS = -I/usr/include/awk -I. -DHAVE_CONFIG_H

test:Q:
	rm -f var/sp_cur.json
	#awk -f rhawk < testirc.txt
	#awk -f rhawk < testirc.txt
	awk -f test.awk test.txt \
	| awk '-vDEBUG=1' -frhawk 2>&1 \
	| grep -v '^  >\|USER\|NICK\|CAP\|JOIN\|TOPIC\|WHO\|unicode'
	#| grep 'points\|bid\|took'

test-select:Q: select.so
	#awk -f select.awk

%.so: %.o
	gcc $CFLAGS -shared -o $target $prereq $LDFLAGS

%.o: %.c
	gcc $CPPFLAGS $CFLAGS -c -o $target $prereq
