# makefile for <https://github.com/howerj/subleq-network>, see help
# target for more information.
default all: help

.PHONY: all clean test run gforth help

CFLAGS=-std=gnu99 -fwrapv -Wall -Wextra -pedantic -O2 -g -march=native
# TODO -lwpcap on Windows
LDFLAGS=-lpcap
FORTH=subleq.fth
IMAGE=subleq.dec
SAVED=saved.dec
DEVICE=lo

help:
	@echo
	@echo "Project: Networking stack for 16-bit SUBLEQ VM and Forth image"
	@echo "Author:  Richard James Howe"
	@echo "License: 0BSD (excludes eForth image and code)"
	@echo "Repo:    https://github.com/howerj/subleq-network"
	@echo "Email:   howe.r.j.89@gmail.com"
	@echo
	@echo "Parameters:"
	@echo
	@echo "	CFLAGS   : ${CFLAGS}"
	@echo "	IMAGE    : ${IMAGE}"
	@echo "	FORTH    : ${FORTH}"
	@echo "	NETWORK  : ${DEVICE}"
	@echo
	@echo "Targets:"
	@echo
	@echo "	subleq   : build executable SUBLEQ VM"
	@echo "	run      : run ${IMAGE} with SUBLEQ VM"
	@echo "	clean    : remove build files using 'git clean -dffx'"
	@echo "	help     : display this help message"
	@echo "	gforth   : compile and run ${FORTH} with gforth"
	@echo
	@echo "Consult subleq.fth for more information along"
	@echo "with the project "readme.md" file."
	@echo
	@echo "Happy Hacking!"
	@echo

subleq: subleq.c
	${CC} ${CFLAGS} $< ${LDFLAGS} -o $@

run: subleq ${IMAGE}
	./subleq ${DEVICE} ${IMAGE} ${SAVED}

gforth.dec: ${FORTH}
	gforth $< > $@

gforth: subleq gforth.dec
	./subleq gforth.dec

clean:
	git clean -dffx


