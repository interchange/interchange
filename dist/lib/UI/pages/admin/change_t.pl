#!/usr/bin/perl -0777 -pi

#s/<p>\s*&nbsp;\s*<table(?:\s+width=100%)?\s+cellpadding=3\s+cellspacing=0>/<table __UI_T_PROPERTIES__>/i;
s/<p>\s*&nbsp;\s*<table\s+cellpadding=3\s+cellspacing=0>/<table __UI_T_PROPERTIES__>/i
	or 
s/<p>\s*&nbsp;\s*<table\s+cellspacing=0\s+cellpadding=3>/<table __UI_T_PROPERTIES__>/i
	or 
s/<table\s+cellspacing=0\s+cellpadding=3(\s+width=[\w"%]+)?>/<table __UI_T_PROPERTIES__>/i
	or 
s/<table\s+cellpadding=3\s+cellspacing=0(\s+width=[\w"%]+)?>/<table __UI_T_PROPERTIES__>/i
	;

