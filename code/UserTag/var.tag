# [var name=variablename global=1|2]
#
# This tag allows access to variables within other variables (or
# anywhere else, but in regular pages the direct non-tag notations
# shown on the right-hand side below are faster).
#
# [var VARIABLE]   is equivalent to __VARIABLE__
# [var VARIABLE 1] is equivalent to @@VARIABLE@@
# [var VARIABLE 2] is equivalent to @_VARIABLE_@
#
UserTag var Interpolate 1
UserTag var PosNumber 2
UserTag var Order name global
UserTag var Routine <<EOR
sub {
    my ($key, $global) = @_;
    $global and $global != 2 and return $Global::Variable->{$key};
	return $Vend::Cfg->{Member}{$key}
		if	$Vend::Session->{logged_in}
			&& defined $Vend::Cfg->{Member}{$key};

	if($::Pragma->{dynamic_variables}) {
		return Vend::Interpolate::dynamic_var($key) || $Global::Variable->{$key}
			if $global;
		return Vend::Interpolate::dynamic_var($key);
	}
	return $::Variable->{$key} || $Global::Variable if $global;
	return $::Variable->{$key};
}
EOR
