UserTag set-alias Order alias real permanent
UserTag set-alias PosNumber 3
UserTag set-alias Routine <<EOR
sub {
	my ($alias, $real, $permanent) = @_;
	my $one = $permanent ? 'path_alias' : 'one_time_path_alias';
	$Vend::Session->{$one} = {}
		if ! defined $Vend::Session->{$one};
	$Vend::Session->{$one}{$alias} = $real;
	return;
}
EOR

