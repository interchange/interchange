UserTag run-profile Order check cgi profile
UserTag run-profile addAttr
UserTag run-profile Routine <<EOR
sub {
	my ($check, $cgi, $profile, $opt) = @_;
#::logDebug("call check $check");
	my $ref = $cgi ? (\%CGI::values) : $::Values;
	my %checks = (
		company => q{
			mailorderto=email
			emailinfo=email
			emailservice=email
			domainname=required
			address=required
			city=required
			company=required
			country=regex [A-Z][A-Z]
			state=regex [A-Z][A-Z]
			zip=required
		},
		pay => q{
			paygate=required
		},
		security => q{
			adminuser=required
			adminpass=required
			shopuser=required
			shoppass=required
			enablesecure=required
		},
		ship => q{
			shipmethod=required
		},
		style => q{
			style=required
			logo=required
			smlogo=required
		},
		tax => q{
			taxlocation=required
			taxrate=required
		},
		catalog => q{
			address=required
			adminpass=required
			adminuser=required
			city=required
			company=required
			country=regex [A-Z][A-Z]
			domainname=required
			emailinfo=email
			emailservice=email
			mailorderto=email
			paygate=required
			shipmethod=required
			shoppass=required
			shopuser=required
			state=regex [A-Z][A-Z]
			taxlocation=required
			taxrate=required
			zip=required
		},
	);
	if(! $profile) {
		$profile = $Scratch->{"profile_$check"} || $checks{$check} || '';
	}
	return 1 if ! $profile;

	$opt->{no_error} = 1 unless defined $opt->{no_error};

	my $pname = 'tmp_profile.' . $Vend::Session->{id};
#Debug("running check $check, pname=$pname profile=$profile");
	$profile .= "\n&fatal=1\n";
	$profile = "&noerror=1\n$profile" if $opt->{no_error};
	$::Scratch->{$pname} = $profile;

	my ($status) = ::check_order($pname, $ref);

	delete $::Scratch->{$pname};

	return $status;
}
EOR
