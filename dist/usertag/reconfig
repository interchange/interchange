UserTag reconfig Order name
UserTag reconfig PosNumber  1
UserTag reconfig Routine <<EOR
use strict;
sub {
	my $name = shift || $Vend::Cfg->{CatalogName};

	my $myname = $Vend::Cfg->{CatalogName};
#::logGlobal("Trying to reconfig $name");

	if($myname ne '_mv_admin' and $myname ne $name) {
			$::Values{mv_error_tag_restart} =
				"Not authorized to reconfig that catalog.";
			return undef;
	}
#::logGlobal("Passed name check on reconfig $name");

	logData("$Global::ConfDir/reconfig", $Global::Catalog{$name}->{'script'});
	return 1;
}
EOR

