UserTag export_quicken_items Order file
UserTag export_quicken_items addAttr
UserTag export_quicken_items Routine <<EOR
sub {
	my($file, $opt) = @_;
	local($SIG{__DIE__});
	$SIG{"__DIE__"} = sub {
                            my $msg = shift;
                            ::response(<<EOF);
<HTML><HEAD><TITLE>Fatal Administration Error</TITLE></HEAD><BODY>
<H1>FATAL error</H1>
<PRE>$msg</PRE>
</BODY></HTML>
EOF
                            exit 0;
                        };

	die "export_quicken: No file passed.\n"
		if ! $file;

	my @interest = grep /^qb:/, keys %CGI::values;
	my @names;
	my %fmap;
	my %pmap;
	my %rmap;
	my $keyname;
	my %subs;
	my $limit = $CGI::values{ui_qbitem_types} || '';
	my $limit_idx;
	if($limit) {
		$limit =~ s/^\s+//;
		$limit =~ s/\s+$//;
		$limit =~ s/\s+/|/g;
		$limit = qr/$limit/;
	}
	for(@interest) {
		next if ! $CGI::values{$_};
		my $k = $_;
		my $v = $CGI::values{$_};
		my $pfunc;
		if($v =~ s/^\s*=\s*//) {
			$pfunc = sub { Vend::Util::is_yes($_[0]) and return 'Y'; return 'N'; };
		}
		elsif($v =~ s/^\s*!\s*//) {
			$pfunc = sub { Vend::Util::is_yes($_[0]) and return 'N'; return 'Y'; };
		}
		else {
			$pfunc = sub {
					my $val = shift;
					return $val unless $val =~ /[",]/;
					$val =~ s/"/""/g;
					return qq{"$val"};
				};
		}
		$k =~ s/^qb://;
		my $dt;
		my($t, $f) = split /:+/, $k;
		$rmap{$t}{$v} = $f;
		$dt = ::database_exists_ref($t);
		if($dt->config('KEY') eq $f) {
			$keyname = $v;
		}
		die "Bad database $t\n" if ! $dt;
		my $get = $dt->field_accessor($f);
		if($subs{$v}) {
			::logError("Field routine $v defined twice, skipping second.");
			next;
		}
		$subs{$v} = sub { $pfunc->( $get->(shift) )};
	}

	my @keys = keys %subs;

	# Quickbooks requires an INVITEMTYPE, we will set it to
	# PART if not appropriate. This step is to set the index
	# position of INVITEMTYPE
	#
	# If $limit is set then we don't need to worry....
	my $i = 0;
	for(@keys) {
		if($_ eq 'INVITEMTYPE') {
			$limit_idx = $i;
			last;
		}
		$i++;
	}

	my $keystring = join "\t", @keys;

	die "No key mapped." if ! $keyname;
	my $delimiter = quotemeta $opt->{delimiter} || "\t";
	my $now = time();
	my $date = POSIX::strftime('%m/%d/%y', localtime($now));
	open(EXPORT, ">$file")
		or die "write $file: $!\n";
	print EXPORT <<EOF;
!HDR	PROD	VER	REL	IIFVER	DATE	TIME	ACCNTNT	ACCNTNTSPLITTIME\r
HDR	Interchange	Version $::VERSION	Release $::VERSION	1	$date	$now	N	0\r
!INVITEM	$keystring\r
EOF
	my $fields;
	my $count = 0;
	my $out = '';
	ITEMLOOP:
	my $table;
	my @out;
	my $ctr;
	my $rename_msg = <<EOF;
To make import match export, do query (for all relevant TABLEs):

EOF

	foreach $table (@{$Vend::Cfg->{ProductFiles}}) {
		my $db = ::database_exists_ref($table);
		die "Bad products table '$table'" if ! $db;
		my $k;
		while ( ($k) = $db->each_record() ) {
::logError("exporting key='$k'");
			@out = ();
			for(@keys) {
				if($_ eq 'REFNUM') {
					if($k !~ /^\d+$/) {
						my $n = $Tag->counter(
									"$Vend::Cfg->{ProductDir}/quickbooks.refnum",
								);
						my $fname = $rmap{$table}{$_};
						$out .= $rename_msg . "update TABLE set $fname = $n where $fname = '$k'\n";
						$rename_msg = '';
					}
					else {
						push @out, $k;
					}
				}
				else {
					push @out, $subs{$_}->($k);
				}
			}
			if($limit) {
::logError("Checking limit '$out[$limit_idx]'");
				next unless $out[$limit_idx] =~ $limit;
			}
			elsif ($out[$limit_idx] =~ /[^A-Z]/) {
				$out[$limit_idx] = 'PART';
			}
			print EXPORT join $delimiter, 'INVITEM', @out;
			print EXPORT "\r\n";
			$count++;
		}
	}
	$out .= "$count records exported.</PRE>";
	close EXPORT;
	return $out;
}
EOR

