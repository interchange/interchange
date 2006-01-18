UserTag pay-cert-redeem Order certs
UserTag pay-cert-redeem addAttr
UserTag pay-cert-redeem Routine <<EOR
sub {
	my ($certs, $opt) = @_;

	my $ctab = $opt->{table} || 'pay_certs';
	my $cdb = dbref($ctab) 
				or die errmsg("No payment cert table '%s'", $ctab);

	use vars qw/$Tag/;
	$opt->{set_scratch} = 'amount_remaining' unless defined $opt->{set_scratch};

	my $svar = $opt->{set_scratch};

	my @tid;

	if($opt->{capture}) {
		$certs ||= $::Scratch->{pay_certs_to_capture};
		return unless $certs;
		my @certs = split /[\s,\0]+/, $certs;
		
		foreach my $code (@certs) {
			my $success = $Tag->pay_cert({ capture => 1, tid => $code });
			if($success) {
				push @tid, $code;
			}
			else {
				for(@tid) {
					my $o = {
						void => 1,
						code => $_,
					};
					$Tag->pay_cert( $o );
					::logError(
						"Voided capture tid %s due to capture error on %s",
						$_,
						$code,
					);
				}
			}
		}
	}
	else {
		my $total_cost = round_to_frac_digits($Tag->total_cost( { noformat => 1 }));
		my $remaining = $total_cost;

		$certs ||= $::Values->{use_pay_cert} || $::Scratch->{pay_cert_code};
		return $remaining unless $certs;
		my @certs = split /[\s,\0]+/, $certs;

		foreach my $code (@certs) {
			last if $remaining <= 0;
			my $this = $cdb->field($code, 'amount');
			my $amount;
			if($this < $remaining) {
				$remaining -= $this;
				$amount = $this;
			}
			else {
				$amount = $remaining;
				$remaining = 0;
			}
			my $o = {
				auth => 1,
				amount => $amount,
				code => $code,
			};
			my $tid = $Tag->pay_cert($o);
			if($tid) {
				push @tid, $tid;
#::logDebug("authorized pay_cert=$code amount=$amount tid=$tid");
			}
			else {
#::logDebug("failed to auth pay_cert=$code amount=$amount tid=$tid");
				for(@tid) {
					my $o = {
						void => 1,
						code => $_,
					};
					$Tag->pay_cert( $o );
					my $msg = errmsg(
						"Voided authorization tid %s due to auth error on %s",
						$_,
						$code,
					);
					::logError($msg);
				}
				die errmsg("failed to authorize pay_cert %s", $code)
					if $opt->{die};
				return $total_cost;
			}
		}

		$::Scratch->{pay_certs_to_capture} = join ",", @tid;
		if($opt->{set_scratch}) {
			$::Scratch->{$svar} = $remaining;
		}
		return $opt->{success} if $opt->{success};
		return $remaining;
	}

}
EOR
