#!/usr/local/bin/perl

## This module just needs to be included once, and early.
## 
## Can use:
## 
##   Require module Vend::InDev
##
##
#
package Vend::InDev;

-f '_indev' and $Global::Variable->{INDEV} = 1;

1;
