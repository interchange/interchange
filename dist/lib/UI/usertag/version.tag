UserTag version Order extended
UserTag version attrAlias  module_test modtest
UserTag version attrAlias  moduletest modtest
UserTag version attrAlias  require modtest
UserTag version addAttr
UserTag version Routine <<EOR
sub {
	return $::VERSION unless shift;
	my $opt = shift;
	my $joiner = $opt->{joiner} || '<BR>';
	my @out;
	my $done_something;

	if($opt->{global_error}) {
		push @out, $Global::ErrorFile;
		$done_something = 1;
	}

	if($opt->{local_error}) {
		my $fn = $Vend::Cfg->{ErrorFile};
		push @out, $Tag->page( "$::Variable->{UI_BASE}/do_view", $fn) . "$fn</A>";
		$done_something = 1;
	}

	if($opt->{env}) {
		push @out, join " ", @{$Global::Environment};
		$done_something = 1;
	}

	if($opt->{safe}) {
		push @out, join " ", @{$Global::SafeUntrap};
		$done_something = 1;
	}

	if($opt->{child_pid}) {
		push @out, $$;
		$done_something = 1;
	}

	if($opt->{modtest}) {
		eval "require $opt->{modtest}";
		if($@) {
			push @out, 0;
		}
		else {
			push @out, 1;
		}
		$done_something = 1;
	}

	if($opt->{pid}) {
		push @out, ::readfile($Global::PIDfile);
		$done_something = 1;
	}

	if($opt->{uid}) {
		push @out, scalar getpwuid($>) . " (uid $>)";
		$done_something = 1;
	}

	if($opt->{perl}) {
		push @out, "$] (called with: $^X)";
		$done_something = 1;
	}

	if($opt->{perl_config}) {
		require Config;
		push @out, "<PRE>\n" . Config::myconfig() . "</PRE>";
		$done_something = 1;
	}

	if(not $opt->{db} || $opt->{modules} || $done_something) {
		$opt->{db} = 1;
		push @out, "Interchange Version $::VERSION";
		push @out, "";
	}

	if($opt->{db}) {
		if($Global::GDBM) {
			push @out, "GDBM available (v$GDBM_File::VERSION)";
		}
		else {
			push @out, "No GDBM.";
		}
		if($Global::DB_File) {
			push @out, "Berkeley DB_File available (v$DB_File::VERSION)";
		}
		else {
			push @out, "No Berkeley DB_File.";
		}
		if($Global::LDAP) {
			push @out, "LDAP available (v$Net::LDAP::VERSION)";
		}
		if($Global::DBI and $DBI::VERSION) {
			push @out, "DBI enabled (v$DBI::VERSION), available drivers:";
			my $avail = join $joiner, DBI->available_drivers;
			push @out, "<BLOCKQUOTE>$avail</BLOCKQUOTE>";
		}
	}
	if($opt->{modules}) {
		my %wanted = ( qw/
					Safe::Hole       Safe::Hole
					SQL::Statement   SQL::Statement
					MD5              MD5
					LWP::Simple      LWP
					Tie::Watch       Tie::Watch       
					MIME::Base64     MIME::Base64
					URI::URL         URI::URL 
					Storable         Storable
				/);
		my %info = (
				'Safe::Hole'    => 'IMPORTANT: SQL and some tags will not work in embedded Perl.',
				'SQL::Statement'=> 'IMPORTANT: UI Database editors will not work properly.',
				'MD5'           => 'IMPORTANT: cache keys and other search-related functions will not work.',
				'LWP::Simple'   => 'External UPS lookup and other internet-related functions will not work.',
				'Tie::Watch'    => 'Minor: cannot set watch points in catalog.cfg.',
				'MIME::Base64'  => 'Minor: Internal HTTP server will not work.',
				'URI::URL'      => 'Minor: Internal HTTP server will not work.', 
				'Storable'      => 'Session and search storage will be slower.',
		);
		for( sort keys %wanted) {
			eval "require $_";
			if($@) {
				my $info = $info{$_} || "May affect program operation.";
				push @out, "$_ not found. $info"
			}
			else {
				no strict 'refs';
				my $ver = ${"$_" . "::VERSION"};
				$ver = $ver ? "v$ver" : 'no version info';
				push @out, "$_ found ($ver).";
			}
		}
	}
	return join $joiner, @out;
}
EOR
