# [var name=variablename global=1]
#
# This tag is the equivalent of __VARIABLE__ except that it will
# works in other variables
#
UserTag var Interpolate 1
UserTag var PosNumber 2
UserTag var Order name global
UserTag var Routine <<EOR
sub {
    $_[1] and return $Global::Variable->{shift @_};
    my $key = shift;
	return $Vend::Cfg->{Member}{$key}
		if	$Vend::Session->{logged_in}
			&& defined $Vend::Cfg->{Member}{$key};
	return $Vend::Cfg->{Variable}{$key};
}
EOR
