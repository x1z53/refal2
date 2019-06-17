MACHINE := $(shell uname -m)
VERSION := $(shell cat Version.txt)
TSTAMP := $(shell date "+%Y%m%d")

prefix=dist
bindir=$(prefix)/bin
libdir=$(prefix)/lib
includedir=$(prefix)/include
datadir=$(prefix)/share

CC = gcc
AR = ar

CSPECIAL = -DNO_DEBUG -Isrc/inter

ifdef FASM
CSPECIAL += -DFASM
TOEXE = -dynamic-linker /lib/ld-linux.so.2 /usr/lib/crt1.o /usr/lib/crti.o /usr/lib/crtn.o -lc
endif

OPTFLAGS = -pipe -O0 -w
ifeq ($(MACHINE), x86_64)
OPTFLAGS += -m32
endif
CFLAGS += $(OPTFLAGS) $(CSPECIAL)

CCOMP = $(wildcard src/comp/*.c)
CINTR = $(wildcard src/inter/*.c)
RTEST = $(wildcard tests/*.ref)
OCOMP = $(CCOMP:.c=.o)
OINTR = $(CINTR:.c=.o) src/inter/xcv.o

lib/%.o: src/main/%.o
	mkdir -p lib
	cp -a $< $@

ifdef FASM
%.o:	%.asm
	fasm $< $@
else
%.o:	%.asm
	$(CC) -c $(CFLAGS) -x assembler $< -o $@
endif

%.asm:	%.ref
	bin/refal2 $<

%.exe:	%.o
ifdef FASM
	ld $< -o $@ lib/mainrf.o -Llib -lrefal2 $(TOEXE)
else
	$(CC) $(CFLAGS) $< -o $@ lib/mainrf.o -Llib -lrefal2
endif

.ONESHELL:

all:	bin/refal2 lib/librefal2.a lib/mainrf.o lib/rfdbg.o r2compile r2run r2debug

r2compile:
	cat <<- EOF > $@
		#!/bin/sh
		case "\$$0" in
		 .*) LIBDIR=\$${LIBDIR:-\$$(pwd)/lib}; export PATH=\$$PATH:\$$(pwd)/bin ;;
		  *) LIBDIR=\$${LIBDIR:-/usr/lib};;
		esac
		N=\$$(basename \$$1)
		P=\$${N%.*}
		cd \$$(dirname \$$1)
		refal2 \$$N
	EOF
ifdef FASM
	cat <<- EOF >> $@
		fasm \$$P.asm \$$P.o && rm \$$P.asm
		ld \$$P.o -o \$$P \$$LIBDIR/mainrf.o -L\$$LIBDIR -lrefal2 $(TOEXE) && rm \$$P.o
	EOF
else
	cat <<- EOF >> $@
		$(CC) $(OPTFLAGS) -o \$$P -x assembler \$$P.asm -x none \$$LIBDIR/mainrf.o -L\$$LIBDIR -lrefal2 && rm \$$P.asm
	EOF
endif
	chmod +x $@

r2run:	r2compile
	cp $< $@
	echo './$$P' >> $@
	chmod +x $@

r2debug:	r2run
	sed 's/mainrf.o/rfdbg.o/g' < $< > $@
	chmod +x $@

bin/refal2:	$(OCOMP)
	mkdir -p bin
	$(CC) $(CFLAGS) -o $@ $?

lib/librefal2.a:	$(OINTR)
	mkdir -p lib
	ar rcs $@ $?

install: all
	install -D bin/refal2 $(bindir)/refal2
	install -m755 r2run r2compile r2debug $(bindir)/
	install -d $(libdir) $(includedir)
	install lib/* $(libdir)/
	install src/inter/*.def $(includedir)/

test:	$(RTEST:.ref=.exe)
	for N in tests/*.exe; do echo -e "\n\t::: $$N"; { echo 7; echo 20; echo 0; } | $$N; done

dist:	clean
	sed -i -E '/vers_i.*Refal-2.*version/s/version[[:space:]]+[0-9.-]+/version $(VERSION)-$(TSTAMP)/' src/comp/refal.c
	tar czvf refal2-$(VERSION)-$(TSTAMP)-unix-src.tgz --transform=s,^,refal2-$(VERSION)-$(TSTAMP)/, *

clean:
	rm -rf lib/* bin/*
	rm -f r2run r2compile r2debug
	for e in exe tgz o S asm a s lst log; do find . -name \*.$$e -exec rm {} \; ; done
