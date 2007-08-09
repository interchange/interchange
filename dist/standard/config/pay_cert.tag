# Copyright 2004-2007 Interchange Development Group and others
# 
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.  See the LICENSE file for details.
# 
# $Id: pay_cert.tag,v 1.3 2007-08-09 13:40:53 pajamian Exp $

UserTag pay-cert Order code
UserTag pay-cert addAttr
UserTag pay-cert Routine <<EOR
sub {
	my ($code, $opt) = @_;

	use vars qw/$Tag/;
	my $counter_file = $::Variable->{GIFT_CERT_COUNTER} || 'etc/pay_cert.number';
	my $cert_table   = $::Variable->{GIFT_CERT_TABLE}		 || 'pay_certs';
	my $redeem_table = $::Variable->{GIFT_CERT_REDEEM_TABLE} || 'pay_cert_redeem';
	my $lock_table   = $::Variable->{GIFT_CERT_LOCK_TABLE}   || 'pay_cert_lock';

	my $ldb = dbref($lock_table) 
		or die errmsg("cannot open payment certs lock table '%s'", $lock_table);

	my $ltab = $ldb->name();
	my $ldbh = $ldb->dbh()
		or die errmsg("cannot get handle for certs lock table '%s'", $lock_table);
	my $q = "insert into $ltab (code, pid, ip_addr) values (?,?,?)";

	my $locked;

	my $sth_lock = $ldbh->prepare($q)
		or die errmsg("cannot prepare lock query '%s'", $q);

	$q = "delete from $ltab where code = ?";
	my $sth_unlock = $ldbh->prepare($q)
		or die errmsg("cannot prepare lock query '%s'", $q);

	$opt->{code_scratch} = 'pay_cert_code'		unless defined $opt->{code_scratch};
	$opt->{check_scratch} = 'pay_cert_check'	unless defined $opt->{check_scratch};
	$opt->{order_number} ||= $::Values->{mv_order_number};

	if($opt->{transaction}) {
		$opt->{$opt->{transaction}} = 1;
	}

	my $errname;

	my $die = sub {
		my $msg = errmsg(@_);
		::logError($msg);
		$errname ||= 'pay_certificate';
		eval {
			$sth_unlock->execute($code) if $locked;
		};
		$Tag->error( { name => $errname, set => $msg } );
		return undef;
	};

	if($opt->{issue}) {
		if(! $opt->{order_number}) {
			return $die->("Must have order number to issue payment certificate. Not issued.");
		}
		if(! $opt->{amount}) {
			return $die->("Must specify amount to issue payment certificate. Not issued.");
		}
		
		## Time to issue a certificate
		my $start = int(rand 300000);
		$start .= '0' while length($start) < 6;
		my $base = $Tag->counter({ file => $counter_file, start => $start });
		$base .= int(rand(10));
		for(0 .. 9) {
			$code = $base . $_;
			last if Vend::Order::luhn($code, 8);
		}

		my $now = time;
		my @date_issued = localtime($now);
		my @date_expires;
		my $issue_date = POSIX::strftime('%Y%m%d%H%M%S', @date_issued);
		my $expire_date = '';
		$opt->{expires} ||= $opt->{expire} || $opt->{expiration};
		if($opt->{expires} =~ /^\s*(\d+)\s*y/i) {
			@date_expires = @date_issued;
			$date_expires[5] += $1;
		}
		elsif($opt->{expires} =~ /^\s*(\d+)\s*mon/i) {
			@date_expires = @date_issued;
			$date_expires[4] += $1;
		}
		elsif($opt->{expires} =~ /^\s*(\d+)\s*[mhdw]/) {
			my $adder = Vend::Config::time_to_seconds($opt->{expires});
			@date_expires = localtime($now + $adder);
		}
		elsif($opt->{expires}) {
			::logError("Expiration date '%s' not understood, ingoring.", $opt->{expires});
		}

		if(@date_expires) {
			$expire_date = POSIX::strftime('%Y%m%d%H%M%S', @date_expires);
		}

#::logDebug("generated code=$code, expires=$opt->{expires} date_expires=$expire_date ");
		my $check = int rand(10);
		$check .= int(rand(10)) while length($check) < 4;
#::logDebug("generated check=$check");
		my %record = (
			amount => $opt->{amount},
			ip_addr => $CGI::remote_addr,
			order_number => $opt->{order_number},
			date_issued => $issue_date,
			date_expires => $expire_date,
			check_value => $check,
			orig_amount => $opt->{amount},
			process_flag => 0,
		);
		my $db = dbref($cert_table)
			or die errmsg("cannot open pay_cert table '%s'", $cert_table);
		$db->set_slice($code, \%record)
			or die errmsg("cannot write cert number $code in pay_cert table '%s'", $cert_table);

		## Create expire date for cookie
		my $edate;
		$edate = POSIX::strftime("%a, %d-%b-%Y %H:%M:%S GMT ", @date_expires)
			unless ! $expire_date or $opt->{no_cookie};

		if($opt->{code_scratch}) {
			$::Scratch->{$opt->{code_scratch}} = $code;
			unless( ! $edate or $opt->{no_cookie}) {
#::logDebug("setting cookie");
				my $prior_cookie = $Tag->read_cookie({name => 'MV_GIFT_CERT_CODE'});
				my $cvalue = $code;
				if($prior_cookie) {
					$cvalue = join ",", $prior_cookie, $cvalue;
				}
				$Tag->set_cookie({
								name => 'MV_GIFT_CERT_CODE',
								expire => $edate,
								value => $cvalue,
							});
			}
		}

		if($opt->{check_scratch}) {
			$::Scratch->{$opt->{check_scratch}} = $check;
			my $prior_cookie = $Tag->read_cookie({name => 'MV_GIFT_CERT_CHECK'});
			my $cvalue = $check;
			if($prior_cookie) {
				$cvalue = join ",", $prior_cookie, $cvalue;
			}
			unless( ! $edate or $opt->{no_cookie}) {
#::logDebug("setting cookie");
				$Tag->set_cookie({
									name => 'MV_GIFT_CERT_CHECK',
									expire => $edate,
									value => $cvalue,
							});
			}
		}

		if(defined $opt->{item_pointer}) {
			my $ptr =  $opt->{item_pointer};
			my $cart	= $opt->{cart}
						? ($Vend::Session->{carts}{$opt->{cart}})
						: $Vend::Items;
			my $item = $cart->[$ptr];
			$item->{pay_cert_code} = $code;
			$item->{pay_cert_check} = $check;
		}
		return $code;
	}

	my $cdb = dbref($cert_table)
		or die errmsg("cannot open pay_certs table '%s'", $cert_table);

	my $status;

	my $record;

	my $rdb = dbref($redeem_table)
		or return $die->("Cannot open redemption table %s", $redeem_table);
	my $rname = $rdb->name();
	my $rdbh  = $rdb->dbh()
		or return $die->("Cannot get redemption table %s DBI handle", $redeem_table);

	if($opt->{auth}) {
		eval {
			$sth_lock->execute($code, $$, $CGI::remote_addr)
				and $locked = 1;
		};

		not $locked and return $die->("Cannot lock pay cert %s", $code);

		$code or return $die->("Must have payment certificate number.");
		$record = $cdb->row_hash($code)
			or return $die->("Gift certificate %s does not exist.", $code);
		if($opt->{amount} > $record->{amount}) {
			return $die->("Tried to redeem, limit (%s) exceeded.", $record->{amount} );
		}
		my %redeem = (
			pay_id => $code,
			trans_date => POSIX::strftime('%Y%m%d%H%M%S', localtime()),
			ip_addr => $CGI::remote_addr,
			trans_type => 'auth',
			voided => 0,
			captured => 0,
			username => $Vend::username,
			amount => $opt->{amount},
			items => $opt->{items},
			);

		$opt->{tid} = $status = $rdb->set_slice(undef, \%redeem)
			or $die->("Auth redemption of %s failed: %s", $code, $rdb->errstr());
#::logDebug("Redemption auth tid=$status");
		my $new_amount = $cdb->set_field(
								$code,
								'amount',
								$record->{amount} - $opt->{amount},
							);
#::logDebug("Redemption amount=$record->{amount} redeeming=$opt->{amount} new_amount=$new_amount");

		defined $new_amount
			or $die->("Auth redemption of %s failed: %s", $code, $rdb->errstr());

	}
	elsif($opt->{capture}) {
		$opt->{tid}	or return $die->("Must have transaction ID to capture.");
		my $red_record = $rdb->row_hash($opt->{tid}) 
			or return $die->("Unknown transaction ID %s.", $opt->{tid});
		if($red_record->{voided}) {
			return $die->("Cannot capture voided auth %s.", $opt->{tid});
		}

		if($red_record->{captured}) {
			return $die->("Auth %s already captured.", $opt->{tid});
		}

		$code = $red_record->{pay_id};

		eval {
			$sth_lock->execute($code, $$, $CGI::remote_addr)
				and $locked = 1;
		};

		not $locked and return $die->("Cannot lock payment cert %s", $code);

		my %redeem = (
			pay_id => $code,
			trans_date => POSIX::strftime('%Y%m%d%H%M%S', localtime()),
			link_tid => $opt->{tid},
			ip_addr => $CGI::remote_addr,
			trans_type => 'capture',
			voided => 0,
			captured => 0,
			username => $Vend::username,
			amount => $red_record->{amount},
			);

		$opt->{new_tid} = $status = $rdb->set_slice(undef, \%redeem)
			or $die->("Auth redemption of %s failed: %s", $code, $rdb->errstr());
#::logDebug("Redemption auth tid=$status");

		$rdb->set_field($opt->{tid}, 'captured', 1);
#::logDebug("Capture amount=$red_record->{amount}");

	}
	elsif($opt->{void}) {
		$opt->{tid}	or return $die->("Must have transaction ID to void.");

		my $red_record = $rdb->row_hash($opt->{tid}) 
			or return $die->("Unknown transaction ID %s.", $opt->{tid});

		if($red_record->{voided}) {
			return $die->("Cannot void already voided auth %s.", $opt->{tid});
		}

		if($red_record->{captured}) {
			return $die->("Cannot void captured auth %s.", $opt->{tid});
		}

		$code = $red_record->{pay_id};

		$record = $cdb->row_hash($code)
			or return $die->("Gift certificate %s does not exist.", $code);

		eval {
			$sth_lock->execute($code, $$, $CGI::remote_addr)
				and $locked = 1;
		};

		not $locked and return $die->("Cannot lock payment cert %s", $code);

		if( ($red_record->{amount} + $record->{amount}) > $record->{orig_amount}) {
			return $die->(
						"Cannot void to equal more than original_amount %s.",
						$record->{orig_amount},
					);
		}

		my %redeem = (
			pay_id => $code,
			trans_date => POSIX::strftime('%Y%m%d%H%M%S', localtime()),
			link_tid => $opt->{tid},
			ip_addr => $CGI::remote_addr,
			trans_type => 'void',
			voided => 0,
			captured => 1,
			username => $Vend::username,
			amount => $red_record->{amount},
			);

		$opt->{new_tid} = $status = $rdb->set_slice(undef, \%redeem)
			or $die->("Auth redemption of %s failed: %s", $code, $rdb->errstr());
#::logDebug("Redemption auth tid=$status");

		$rdb->set_field($opt->{tid}, 'voided', 1);
#::logDebug("Capture amount=$red_record->{amount}");

		my $new_amount = $cdb->set_field($code, 'amount', $record->{amount} + $red_record->{amount});
#::logDebug("void amount=$red_record->{amount} new_amount=$new_amount");

	}
	elsif ($opt->{return}) {
		$code or return $die->("Must have payment certificate number for a return.");
		eval {
			$sth_lock->execute($code, $$, $CGI::remote_addr)
				and $locked = 1;
		};

		not $locked and return $die->("Cannot lock payment cert %s", $code);

		$record = $cdb->row_hash($code)
			or return $die->("Gift certificate %s does not exist.", $code);
		if( ($opt->{amount} + $record->{amount}) > $record->{orig_amount}) {
			return $die->(
						"Cannot return more than original_amount %s.",
						$record->{orig_amount},
					);
		}
		my %redeem = (
			pay_id => $code,
			trans_date => POSIX::strftime('%Y%m%d%H%M%S', localtime()),
			ip_addr => $CGI::remote_addr,
			trans_type => 'return',
			voided => 0,
			captured => 1,
			username => $Vend::username,
			amount => $opt->{amount},
			items => $opt->{items},
			);

		$opt->{tid} = $status = $rdb->set_slice(undef, \%redeem)
			or $die->("Auth redemption of %s failed: %s", $code, $rdb->errstr());
#::logDebug("Redemption auth tid=$status");
		my $new_amount = $cdb->set_field(
								$code,
								'amount',
								$record->{amount} + $opt->{amount},
							);
#::logDebug("return amount=$record->{amount} redeeming=$opt->{amount} new_amount=$new_amount");

		defined $new_amount
			or $die->("Return of %s failed: %s", $code, $rdb->errstr());
	}

	if($locked) {
		my $rc = $sth_unlock->execute($code) and $locked = 0;
#::logDebug("unlock rc=$rc");
		if($locked) {
			undef $locked;
			return $die->("Gift certificate %s lock was not released.", $code);
		}
	}
	else {
#::logDebug("Not locked??!!?? THis should not happen.");
	}
	return $status;
}
EOR
