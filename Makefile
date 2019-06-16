MACHINE := $(shell uname -m)
ifndef SYSTEM
  VERSION := $(shell cat Version.txt)
  TSTAMP := $(shell date "+%Y%m%d")
endif

ifeq ($(MACHINE), x86_64)
  ACFLAGS = -m32
  AAFLAGS = --32
endif

prefix=/usr
bindir=$(prefix)/bin
libdir=$(prefix)/lib
includedir=$(prefix)/include
datadir=$(prefix)/share

CC = gcc
AR = ar

ifdef DEBUG
  CDEBUG = -g
  RFMAIN = rfdbg.o
else
  CDEBUG = -g -DNO_DEBUG
  RFMAIN = mainrf.o
endif

ifdef SYSTEM
  RINCLUDE = $(includedir)/refal2
  RLIB = $(libdir)
else
  RINCLUDE = src/inter
  RLIB = lib
endif

COPT = -O0 -w
CFLAGS = -pipe $(COPT) $(CDEBUG) $(ACFLAGS) -I$(RINCLUDE)
ASFLAGS =  $(AAFLAGS)
CCOMP = $(wildcard src/comp/*.c)
CINTR = $(wildcard src/inter/*.c)
RTEST = $(wildcard tests/*.ref)
OCOMP = $(CCOMP:.c=.o)
OINTR = $(CINTR:.c=.o) src/inter/xcv.o

lib/%.o: src/main/%.o
	mkdir -p lib
	cp -a $< $@

%.s:	%.asm
	cp -a $< $@

%.asm:	%.ref
	PATH=$$PATH:bin refal2 $<

%.exe:	%.s
	$(CC) $(CFLAGS) $< $(RLIB)/$(RFMAIN) -o $@ -L$(RLIB) -lrefal2

.ONESHELL:

all:	bin/refal2 lib/librefal2.a lib/mainrf.o lib/rfdbg.o r2compile r2run r2debug

r2compile:
	cat <<- EOF > $@
		#!/bin/sh
		N=\$$(basename \$$1)
		P=\$${N%.*}
		cd \$$(dirname \$$1)
		make -f $(datadir)/refal2/Makefile SYSTEM=1 \$$P.exe
	EOF

r2run:	r2compile
	cp $< $@
	echo './$$P.exe' >> $@

r2debug:	r2run
	sed 's/SYSTEM=1/SYSTEM=1 DEBUG=1/' < $< > $@

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
	install -D Makefile $(datadir)/refal2/Makefile

test:	$(RTEST:.ref=.exe)
	for N in tests/*.exe; do echo -e "\n\t::: $$N"; { echo 7; echo 20; echo 0; } | $$N; done

dist:	clean
	sed -i -E '/vers_i.*Refal-2.*version/s/version[[:space:]]+[0-9.-]+/version $(VERSION)-$(TSTAMP)/' src/comp/refal.c
	tar czvf refal2-$(VERSION)-$(TSTAMP)-unix-src.tgz --transform=s,^,refal2-$(VERSION)-$(TSTAMP)/, *

clean:
	rm -rf lib/* bin/*
	rm -f r2run r2compile r2debug
	for e in exe tgz o S asm a s lst log; do find . -name \*.$$e -exec rm {} \; ; done
