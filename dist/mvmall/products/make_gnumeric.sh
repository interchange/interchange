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
