Usertag isindex Documentation <<EOD

  Summary: 
		Returns the ISINDEX input passed in a url ending with a single line
		text input appended to the URI:
		 ?foo+bar+baz+buz

  Parameters:

	arg
		The argument to return, starting at 1, where arguments
		are elements of the input string, separated by '+' (spaces).

	array
		Return the complete array. This would be used where isindex is
		called from within a perl block.

	joiner
		Specify the joiner to use between the ISINDEX elements when 
		returning the entire input. Default is a space.

  Example:

	With the string: ?foo+bar+baz

	 [isindex]

	returns:

	  foo bar baz

	 [isindex joiner=\n]

	returns:

	  foo
	  bar
	  baz

	 [isindex 1]

	returns:

	  foo

EOD

Usertag isindex Order arg
UserTag isindex addAttr
UserTag isindex Routine <<EOR
sub {
        my ($arg, $opt) = @_;
        return @Global::argv if $opt->{array};
        return $Global::argv[$arg - 1] if $arg;
        $opt->{joiner} = get_joiner($opt->{joiner}, ' ');
        return join $opt->{joiner}, @Global::argv;
}
EOR