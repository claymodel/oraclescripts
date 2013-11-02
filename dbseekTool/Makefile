ORAINC=	/opt/oracle/db-11.2.0.3/rdbms/public
ORALIB= /opt/oracle/db-11.2.0.3/lib

BINDIR= /usr/local/bin
MANDIR= /usr/local/share/man

CFLAGS= -g -I$(ORAINC) -L$(ORALIB) -std=c99 -D_XOPEN_SOURCE=600 -Wall -Werror -pedantic
INC=	common.h
OBJ=	osql.o output.o oops.o input.o inputlex.o sqlcodes.o

all: osql osql.bin

osql: osql.in
	sed 's%@@ORALIB@@%$(ORALIB)%g' osql.in > osql
	chmod 755 osql

inputlex.c: inputlex.l
	lex -i -o$@ $<

osql.bin:	$(OBJ) $(INC)
	$(CC) $(CFLAGS) -lclntsh -lreadline -ltermcap -o $@ $(OBJ)

clean:
	rm -f $(OBJ) osql osql.bin

install:
	install    osql $(BINDIR)
	install -s osql.bin $(BINDIR)
	install osql.1 $(MANDIR)/man1/osql.1

