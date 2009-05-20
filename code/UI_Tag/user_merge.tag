# Copyright 2005-2009 Interchange Development Group and others
# 
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.  See the LICENSE file for details.
# 
# $Id: user_merge.tag,v 1.4 2009-05-20 23:37:27 pajamian Exp $

UserTag user-merge Order from to
UserTag user-merge addAttr
UserTag user-merge Description Merges users based on order number or username
UserTag user-merge Routine <<EOR
sub {
	my ($from, $to, $opt) = @_;

#::logDebug("Called user merge");
	use vars qw/$Tag $CGI/;

	my $err = sub {
		my $msg = errmsg(@_);
		logError($msg);
		$Tag->error({ name => 'order merge', set => $msg });
		return undef;
	};

	unless($Vend::admin) {
		return $err->("Only admin can merge records.");
	}

	unless($Vend::superuser) {
		return $err->("Only admin can merge records.")
			unless $Tag->if_mm('advanced', 'merge_users');
	}

	$from ||= $CGI->{item_id};
	$to ||= $CGI->{item_radio};
	my $table = $opt->{table} || $CGI->{mv_data_table};


	if($opt->{from_user} or $opt->{from_order}) {
		## We are told what to do
	}
	elsif($table eq 'userdb') {
		$opt->{from_user} = 1;
	}
	elsif ($table eq 'transactions') {
		$opt->{from_order} = 1;
	}
	else {
		return $err->("Unable to determine what to do, no table or from_user...");
	}

	my $ufield = $opt->{user_field} || 'username';
	my $ofield = $opt->{order_field} || 'order_number';

	my $utab = $opt->{user_table} || $::Variable->{UI_USER_MERGE_USER_TABLE} || 'userdb';
	my $ttabs = $opt->{merge_tables} || $::Variable->{UI_USER_MERGE_TABLES} || 'transactions orderline';

	my @ttab = grep /\w/, split /[\s,\0]+/, $ttabs;

	my %kfield;
	my %sth;
	my %dbh;
	my %dbr;
	my %query;

	for(@ttab) {
		my ($t, $f) = split /[=:]+/, $_, 2;
		$_ = $t;
		$kfield{$t} = $f || $ufield;
	}

	my $tdb = dbref($ttab[0])
		or return $err->("No %s table.", $ttab[0]);
	my $udb = dbref($utab)
		or return $err->("No %s table.", $utab);

	for(@ttab) {
		my $db = $dbr{$_} = dbref($_)
			or return $err->("Unable to open '%s' table for merge.", $_);
		my $dbh = $dbh{$_} = $db->dbh();
		$query{$_} = "update $_ set $kfield{$_} = ? where $kfield{$_} = ?"; 
		$sth{$_} = $dbh->prepare($query{$_}) 
			or return $err->("Unable to prepare statement '%s' for merge.", $query{$_});
	}

	my $to_user = $to;

	if($opt->{from_order}) {
		$to_user = $tdb->field($to, $ufield);
	}

	my $urec = $udb->row_hash($to_user)
		or return $err->("%s does not exist, cannot merge to that user.", $to_user);

	my @from;

	if(ref($from) eq 'ARRAY') {
		@from = @$from;
	}
	else {
		@from = split /\0/, $from;
	}

	my %from_user;

	if($opt->{from_order}) {
		my @to;
		for(@from) {
			my $okey = $tdb->foreign($_, $ofield);
			my $user = $tdb->field($okey, $ufield);
			push @to, $user;
		}
		@from = @to;
	}

	for(@from) {
		next if $_ eq $to_user;
		unless($from_user{$_} or $udb->field($_, 'username')) {
			$err->("User '%s' does not exist.", $_);
			next;
		}
		$from_user{$_}++;
	}

	my $cart_hash = string_to_ref($urec->{carts});
	my $carts_changed;

	my @users = sort keys %from_user;

	my @record;
	@record = @users;

	my $logfile = $opt->{logfile} || 'logs/merged_users.log';
	my $done_one;
	my $save_rec;

	for my $user (@users) {
		$Tag->log({ type => 'text', file => $logfile, body => $Tag->time() . "\n" } )
			unless $done_one++;

		my $from_urec = $udb->row_hash($user);

		# If there's a user_merge specialsub run it here
		if (my $subname = $Vend::Cfg->{SpecialSub}{user_merge}) {
			my $sub = $Vend::Cfg->{Sub}{$subname} || $Global::GlobalSub->{$subname};
			my $status;
			eval { $status = $sub->($user, $from_urec, $to_user, $urec, $udb, $tdb) };
			if ($@) {
				::logError("Error running %s subroutine %s: %s", 'user_merge', $subname, $@);
			}

			elsif ($status) {
				# Skip further processing of this user
				next;
			}

			else {
				$save_rec = 1;
			}
		}

		for(@ttab) {
			$sth{$_}->execute($to_user, $user)
				or $err->("%s update failed: %s", $_, $dbh{$_}->errstr);
			my $o = $query{$_};
			$o =~ s/\?/$to_user/;
			$o =~ s/\?/$user/;
			push @record, $o;
		}

		my $chash = string_to_ref($from_urec->{carts});
		if(ref $chash) {
			for(keys %$chash) {
				if($cart_hash->{$_}) {
					$Tag->log({ type => 'text', file => $logfile, body => "unable to merge cart=$_ (already exists). Contents=$from_urec->{carts}\n"} );
				}
				else {
					$cart_hash->{$_} = $chash->{$_};
					$carts_changed++;
				}
			}
		}
		my $ustring = ::uneval($from_urec);
		$Tag->log({ type => 'text', file => $logfile, body => "delete user $user=$ustring\n"} );
		$udb->delete_record($user)
			unless $opt->{no_delete};
		push @record, "delete user $user" unless $opt->{no_delete};
	}

	if($carts_changed) {
		if ($save_rec) {
			$urec->{carts} = ::uneval($cart_hash);
		}

		else {
			$udb->set_field($to, 'carts', ::uneval($cart_hash));
		}
	}

	if ($save_rec) {
		delete $urec->{$udb->[$Vend::Table::DBI::KEY]};
		$udb->set_slice($to, $urec);
	}

	push @record, '';

	$Tag->log({ type => 'text', file => $logfile, body => join("\n", @record)} );
	::logDebug(join("\n", @record)) if $opt->{debug};
	return 1 unless $opt->{hide};
	return '';
}
EOR

