#
#	$Id: Makefile,v 2.2 2003-01-09 04:54:26 kwalsh Exp $
#
#	mod_interchange makefile
#
APXS=apxs
APACHECTL=apachectl

#
#	uncomment if you are running some weird OS that
#	doesn't have a socklen_t, such as OS/X
#
#OSX=-DOSX

all: mod_interchange.so

mod_interchange.so: mod_interchange.c
	$(APXS) $(OSX) -c $(DEF) $(INC) $(LIB) mod_interchange.c

#install: all
#	$(APXS) -i -a -n 'interchange' mod_interchange.so

clean:
	-rm -f mod_interchange.o mod_interchange.so

test: reload
	lynx -mime_header http://localhost/mod_interchange

reload: install restart

start:
	$(APACHECTL) start
restart:
	$(APACHECTL) restart
stop:
	$(APACHECTL) stop

