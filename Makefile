MACHINE := $(shell uname -m)
VERSION := $(shell cat Version.txt)
TSTAMP := $(shell date "+%Y%m%d")

ifeq ($(MACHINE), x86_64)
  lib = lib64
  ACFLAGS = -m32
  AAFLAGS = --32
else
  lib = lib
endif

prefix=/usr
bindir=$(prefix)/bin
libdir=$(prefix)/$(lib)
CC = gcc
AR = ar
ifdef DEBUG
  CDEBUG = -g
  RFMAIN = rfdbg.o
else
  CDEBUG = -g -DNO_DEBUG
  RFMAIN = mainrf.o
endif
COPT = -O0
CFLAGS = -pipe -w $(COPT) $(CDEBUG) $(ACFLAGS) -Isrc/inter
ASFLAGS =  $(AAFLAGS)
CCOMP = $(wildcard src/comp/*.c)
CINTR = $(wildcard src/inter/*.c)
RTEST = $(wildcard tests/*.ref)
OCOMP = $(CCOMP:.c=.o)
OINTR = $(CINTR:.c=.o) src/inter/xcv.o

lib/%.o: src/main/%.o
	cp -a $< $@

%.s:	%.asm
	cp -a $< $@

%.asm:	%.ref bin/refal2
	./bin/refal2 $<

%.exe:	%.s lib/librefal2.a
	$(CC) $(CFLAGS) $< lib/$(RFMAIN) -o $@ -Llib -lrefal2

all:	bin/refal2 lib/librefal2.a lib/mainrf.o lib/rfdbg.o

bin/refal2:	$(OCOMP)
	$(CC) $(CFLAGS) -o $@ $?

lib/librefal2.a:	$(OINTR)
	ar rcs $@ $?

install: all
	install -D bin/refal2 $(bindir)/refal2
	install -d $(libdir)
	install lib/* $(libdir)/

test:	$(RTEST:.ref=.exe)
	for N in tests/*.exe; do echo -e "\n\t::: $$N"; { echo 7; echo 20; echo 0; } | $$N; done

dist:	clean
	tar czvf refal2-$(VERSION)-$(TSTAMP)-unix-src.tgz --transform=s,^,refal2-$(VERSION)-$(TSTAMP)/, *

clean:
	rm -rf lib/* bin/*
	for e in tgz o S asm a s lst log; do find . -name \*.$$e -exec rm {} \; ; done
