# Copyright 2002-2007 Interchange Development Group and others
# 
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.  See the LICENSE file for details.
# 
# $Id: update_order_status.tag,v 1.12 2007-03-30 23:40:54 pajamian Exp $

UserTag update-order-status Order   order_number
UserTag update-order-status addAttr
UserTag update-order-status Version $Revision: 1.12 $
UserTag update-order-status Routine <<EOR
sub {
	my ($on, $opt) = @_;
#::logDebug("Shipping order number $on, opt=" . ::uneval($opt));
	my $die = sub {
		logError(@_);
		return undef;
	};
	my $odb = database_exists_ref($opt->{orderline_table} || 'orderline')
		or return $die->("No %s table!", 'orderline');
	my $tdb = database_exists_ref($opt->{transactions_table} || 'transactions')
		or return $die->("No %s table!", 'transactions');
	my $udb = database_exists_ref($opt->{userdb_table} || 'userdb')
		or return $die->("No %s table!", 'userdb');

	my $trec = $tdb->row_hash($on);

	if(! $trec) {
		return $die->("Bad transaction number: %s", $on);
	}

	my $user       = $trec->{username};
	my $wants_copy = $udb->field($user, 'email_copy');

	for(qw/
			archive
			auth_code
			cancel_order
			do_archive
			lines_shipped
			send_email
			settle_transaction
			ship_all
			status
			tracking_number
			void_transaction
		/)
	{
		$opt->{$_} = $CGI::values{$_} if ! defined $opt->{$_};
	}

	if($opt->{ship_all} == 2 or $opt->{void_transaction} or $opt->{cancel_order}) {
		$opt->{cancel_order} = 1;
		$opt->{ship_all} = 2;
	}

	$opt->{archive} ||= $opt->{do_archive};

	$wants_copy = $opt->{send_email} if length $opt->{send_email};
#Log("Order number=$on username=$user wants=$wants_copy");
	delete $::Scratch->{ship_notice_username};
	delete $::Scratch->{ship_notice_email};
	if($wants_copy) {
		$::Scratch->{ship_notice_username} = $user;
		$::Scratch->{ship_notice_email} = $udb->field($user, 'email')
			or delete $::Scratch->{ship_notice_username};
	}

	 
	if($opt->{settle_transaction}) {
		my $oid = $trec->{order_id};
		my $amount = $trec->{total_cost};
		SETTLE: {
			if(! $oid) {
				Vend::Tags->error( {
								name => 'settle_transaction',
								set => "No order ID to settle!",
							});
				return undef;
			}
			elsif($oid =~ /\*$/) {
				Vend::Tags->error( {
								name => 'settle_transaction',
								set => "Order ID $oid already settled!",
							});
				return undef;
			}
			else {
#::logDebug("auth-code: $trec->{auth_code} oid=$oid");
				my $settled  = Vend::Tags->charge( {
									route => $::Variable->{MV_PAYMENT_MODE},
									order_id => $oid,
									amount => $amount,
									auth_code => $trec->{auth_code},
									transaction => 'settle_prior',
								});
				if($settled) {
					$tdb->set_field($on, 'order_id', "$oid*");
					Vend::Tags->warning(
								 errmsg(
								 	"Order ID %s settled with processor.",
									$oid,
								 ),
							);
				}
				else {
					Vend::Tags->error( {
						name => 'settle_transaction',
						set => errmsg(
								"Order ID %s settle operation failed. Reason: %s",
								$oid,
								$Vend::Session->{payment_result}{MErrMsg},
								),
							});
						return undef;
				}

			}
		}
	}
	elsif($opt->{void_transaction}) {
		my $oid = $trec->{order_id};
		$oid =~ s/\*$//;
		my $amount = $trec->{total_cost};
		SETTLE: {
			if(! $oid) {
				Vend::Tags->error( {
								name => 'void_transaction',
								set => "No order ID to void!",
							});
				return undef;
			}
			elsif($oid =~ /-$/) {
				Vend::Tags->error( {
								name => 'void_transaction',
								set => "Order ID $oid already voided!",
							});
				return undef;
			}
			else {
#::logDebug("auth-code: $trec->{auth_code} oid=$oid");
				my $voided  = Vend::Tags->charge( {
									route => $::Variable->{MV_PAYMENT_MODE},
									order_id => $oid,
									amount => $amount,
									auth_code => $trec->{auth_code},
									transaction => 'void',
								});
				if($voided) {
					$tdb->set_field($on, 'order_id', $oid . "-");
					Vend::Tags->warning(
								 errmsg(
								 	"Order ID %s voided.",
									$oid,
								 ),
							);
				}
				else {
					Vend::Tags->error( {
						name => 'void_transaction',
						set => errmsg(
								"Order ID %s void operation failed. Reason: %s",
								$oid,
								$Vend::Session->{payment_result}{MErrMsg},
								),
							});
						return undef;
				}

			}
		}
	}

	if($opt->{status} =~ /\d\d\d\d/) {
		$tdb->set_field($on, 'status', $opt->{status});
	}
	else {
		$tdb->set_field($on, 'status', 'shipped');
	}

	if($opt->{tracking_number} =~ /\w/) {
		$tdb->set_field($on, 'tracking_number', $opt->{tracking_number});
	}

	my $need_shiplines;
	my @shiplines;
	if($opt->{lines_shipped}) {
		@shiplines = grep /\S/, split /\0/, $opt->{lines_shipped};
	}
	else {
		$need_shiplines = 1;
	}

	if(! @shiplines and ! $opt->{ship_all}) {
		my @keys = grep /status__1/, keys %CGI::values;
#::logDebug("keys to ship: " . join(',', @keys));
		my %stuff;
		for(@keys) {
#::logDebug("examining $_");
			my $n = 0;
			m/^(\d+)_/ and $n = $1;
			$n++;
			if($opt->{ship_all} or $CGI::values{$_} eq 'shipped') {
				push @shiplines, $n;
#::logDebug("ship $n");
			}
		}
		undef $need_shiplines;
	}
	else {
		@shiplines = map { s/.*\D//; $_; } @shiplines;
	}

	my $count_q = "select * from orderline where order_number = '$on'";
	my $lines_ary =  $odb->query($count_q);
	if(! $lines_ary) {
		$::Scratch->{ui_message} = "No order lines for order $on";
		return;
	}
	my $total_lines = scalar @$lines_ary;

	my $odb_keypos = $odb->config('KEY_INDEX');

	# See if some items have already shipped
	my %shipping;
	my %already;

	my $target_status = $opt->{cancel_order} ? 'canceled' : 'shipped';

	for(@$lines_ary) {
		my $code = $_->[$odb_keypos];
		my $status = $odb->field($code, 'status');
		my $line = $code;
		push @shiplines, $line if $need_shiplines;
		$line =~ s/.*\D//;
		$line =~ s/^0+//;
		if($status eq $target_status and ! $opt->{cancel_order}) {
			$already{$line} = 1;
		}
		elsif($opt->{ship_all}) {
			$shipping{$line} = 1;
		}
	}

	my $to_ship = scalar @shiplines;

#::logDebug("total_lines=$total_lines to_ship=$to_ship shiplines=" . uneval(\@shiplines));
	
	my $ship_mesg;
	my $g_status;

	@shiplines = grep ! $already{$_}, @shiplines;
	@shipping{@shiplines} = @shiplines;

	if($total_lines == $to_ship) {
		$ship_mesg = "Order $on complete, $total_lines lines set shipped.";
		$::Scratch->{ship_notice_complete} = $ship_mesg;
		$g_status = $target_status;
	}
	else {
		$ship_mesg = "Order $on partially shipped ($to_ship of $total_lines lines).";
		delete $::Scratch->{ship_notice_complete};
		$g_status = 'partial';
	}

	my $minor_mesg = '';

	my $email_mesg = $::Scratch->{ship_notice_username}
					? "Email copy sent to $::Scratch->{ship_notice_email}."
					: "No email copy sent as per user preference.";

	my $dotime = $odb->config('DSN');
	my $update_date;
	$dotime = $dotime =~ /dbi:mysql:/ ? 0 : 1;
	$update_date = POSIX::strftime('%Y-%m-%d %H:%M:%S %z', localtime());
	
	# Actually update the orderline database
	for(@$lines_ary) {
		my $code = $_->[$odb_keypos];
		my $line = $code;
		$line =~ s/.*\D//;
		next if $already{$line};
		my $status = $shipping{$line} ? $target_status : 'backorder';
		$odb->set_field($code, 'status', $status)
			or do {
				$::Scratch->{ui_message} = "Orderline $code ship status update failed.";
				return;
			};
		if($dotime) {
			$odb->set_field($code, 'update_date', $update_date)
				or do {
					$::Scratch->{ui_message} = "Orderline $code ship date update failed.";
					return;
				};
		}

	}

	for(keys %already) {
		$shipping{$_} = $_;
	}

	my $total_shipped_now = scalar keys %shipping; 

	delete $::Scratch->{ship_now_complete};
	
	if($opt->{cancel_order}) {
		$g_status = 'canceled';
		$ship_mesg = "Order $on canceled.";
	}
	elsif (
		$total_lines != scalar @shiplines
			and
		$total_shipped_now == $total_lines 
	  )
	{
		$g_status = 'shipped';
		$::Scratch->{ship_now_complete} = 1
			if $total_shipped_now == $total_lines;
		$ship_mesg = "Order $on now complete (all $total_lines lines).";
	}

	$tdb->set_field($on, 'status', $g_status);
	$tdb->set_field($on, 'archived', 1)
		if $opt->{archive} and $g_status eq $target_status;

	Vend::Tags->warning("$ship_mesg $email_mesg");
	delete $::Scratch->{ship_notice_username};
	delete $::Scratch->{ship_notice_email};
	delete $::Scratch->{ship_notice_order_number};
	if($wants_copy) {
		$::Scratch->{ship_notice_order_number} = $on;
		$::Scratch->{ship_notice_username} = $user;
		$::Scratch->{ship_notice_email} = $trec->{email}
			or delete $::Scratch->{ship_notice_username};
		if($opt->{send_email}) {
			my $filename = $opt->{ship_notice_template} || 'etc/ship_notice';
			my $contents = $Tag->file($filename);
			if($contents) {
				$contents = interpolate_html($contents);
				$contents =~ s/^\s+//;
				$contents =~ s/\s*$/\n/;
				$Tag->email_raw({}, $contents);
			}
			else {
				$Tag->warnings(
						errmsg("No ship_notice_template '%s' found", $filename),
					);
			}
		}
	}
	return;
}
EOR
