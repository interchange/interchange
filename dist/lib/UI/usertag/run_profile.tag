UserTag run-profile Order check cgi profile
UserTag run-profile addAttr
UserTag run-profile Routine <<EOR
sub {
	my ($check, $cgi, $profile, $opt) = @_;
#::logDebug("call check $check");
	my $ref = $cgi ? (\%CGI::values) : $::Values;

	# check scratch for profile if none specified
	$profile = $Scratch->{"profile_$check"} unless $profile;

#::logDebug("PROFILE(" . $Tag->var('MV_PAGE',1) . "):***$profile***");
	# test passes if no profile exists
	return 1 if ! $profile;

	$opt->{no_error} = 1 unless defined $opt->{no_error};

	my $pname = 'tmp_profile.' . $Vend::Session->{id};
#Debug("running check $check, pname=$pname profile=$profile");
	$profile .= "\n&fatal=1\n";
	$profile = "&noerror=1\n$profile" if $opt->{no_error};
	$profile = "&overwrite=1\n$profile" if $opt->{overwrite_error};
	$::Scratch->{$pname} = $profile;

	my ($status) = ::check_order($pname, $ref);

	delete $::Scratch->{$pname};

	return $status;
}
EOR
