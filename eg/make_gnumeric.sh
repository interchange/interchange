#!/bin/sh

if test -z "$1"
then
	echo usage: $0 file1.txt file2.txt ...
	exit 2
fi

for i in $*
do
	if test -n "$done_one"
	then
		echo -n 
	fi
	j=`echo $i | perl -pe 's/\..*//'`
	echo $j
	cat $i
	done_one=1
done
