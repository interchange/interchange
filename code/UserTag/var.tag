# [var name=variablename global=1|2 filter=somefilter]
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
UserTag var Order name global filter
UserTag var Routine <<EOR
sub {
    my ($key, $global, $filter) = @_;
	my $value;
	if ($global and $global != 2) {
		$value = $Global::Variable->{$key};
	}
	elsif ($Vend::Session->{logged_in} and defined $Vend::Cfg->{Member}{$key}) {
		$value = $Vend::Cfg->{Member}{$key};
	}
	else {
		$value = (
			$::Pragma->{dynamic_variables}
			? Vend::Interpolate::dynamic_var($key)
			: $::Variable->{$key}
		);
		$value ||= $Global::Variable->{$key} if $global;
	}
	$value = filter_value($filter, $value, $key) if $filter;
	return $value;
}
EOR
