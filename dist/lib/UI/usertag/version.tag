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
		push @out,
			ref $Global::Environment eq 'ARRAY' ?
			join ' ', @{$Global::Environment} :
			'(none)';
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

	if($opt->{global_locale_options}) {
		my @loc;
		my $curr = $Global::Locale;
		
		while ( my($k,$v) = each %$Global::Locale_repository ) {
			next unless $k =~ /_/;
			push @loc, "$v->{MV_LANG_NAME}~:~$k=$v->{MV_LANG_NAME}";
		}
		if(@loc > 1) {
			push @out, join ",", map { s/.*~:~//; $_ } sort @loc;
		}
		$done_something = 1;
	}

	if($opt->{perl}) {
		push @out, ($^V ? sprintf("%vd", $^V) : $]) . errmsg(" (called with: %s)", $^X);
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
			push @out, errmsg('%s available (v%s)', 'GDBM', $GDBM_File::VERSION);
		}
		else {
			push @out, errmsg('No %s.', 'GDBM');
		}
		if($Global::DB_File) {
			push @out, errmsg('%s available (v%s)', 'Berkeley DB_File', $DB_File::VERSION);
		}
		else {
			push @out, errmsg('No %s.', 'Berkeley DB_File');
		}
		if($Global::LDAP) {
			push @out, errmsg('%s available (v%s)', 'LDAP', $Net::LDAP::VERSION);
		}
		if($Global::DBI and $DBI::VERSION) {
			push @out, errmsg ('DBI enabled (v%s), available drivers:', $DBI::VERSION);
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
				my $info = errmsg($info{$_} || "May affect program operation.");
				push @out, "$_ " . errmsg('not found') . ". $info"
			}
			else {
				no strict 'refs';
				my $ver = ${"$_" . "::VERSION"};
				$ver = $ver ? "v$ver" : 'no version info';
				push @out, "$_ " . errmsg('found') . " ($ver).";
			}
		}
	}
	return join $joiner, @out;
}
EOR
