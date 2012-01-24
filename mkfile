CFLAGS   = -g -Wall -fPIC --std=c99
CPPFLAGS = -I/usr/include/awk -I. -DHAVE_CONFIG_H

test:Q: select.so
	awk -f select.awk
	#awk -f rhawk < testirc.txt
	#awk -f rhawk < testirc.txt
	#awk -f test.awk test.txt | awk -f rhawk #| grep 'points\|bid\|took'

%.so: %.o
	gcc $CFLAGS -shared -o $target $prereq $LDFLAGS

%.o: %.c
	gcc $CPPFLAGS $CFLAGS -c -o $target $prereq
