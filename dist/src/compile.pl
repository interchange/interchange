#!/usr/bin/perl

do 'syscfg';
system "$CC $CFLAGS $DEFS $LIBS tlink.c -o ../bin/tlink";
system "$CC $CFLAGS $DEFS $LIBS vlink.c -o ../bin/vlink";
