UserTag export_quicken_coa Order file
UserTag export_quicken_coa addAttr
UserTag export_quicken_coa Routine <<EOR
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

	die "export_quicken_coa: No file passed.\n"
		if ! $file;

	my @interest = grep /^qb:/, keys %CGI::values;
	my @names;
	my %fmap;
	my %pmap;
	my %rmap;
	my $keyname;
	my %subs;
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
		die "Bad database $t\n" if ! $dt;
		my $get = $dt->field_accessor($f);
		if($subs{$v}) {
			::logError("Field routine $v defined twice, skipping second.");
			next;
		}
		$subs{$v} = sub { $pfunc->( $get->(shift) )};
	}

	if(! $subs{ACCNTTYPE}) {
		my $string = $CGI->{ui_qbcoa_type} || 'INC';
		$subs{ACCNTTYPE} = sub { return $string };
	}

	my @keys = keys %subs;

	# Quickbooks requires an INVITEMTYPE, we will set it to
	# PART if not appropriate. This step is to set the index
	# position of INVITEMTYPE
	#
	# If $limit is set then we don't need to worry....
	my $i = 0;

	my $keystring = join "\t", @keys;

	my $delimiter = quotemeta $opt->{delimiter} || "\t";
	my $now = time();
	my $date = POSIX::strftime('%m/%d/%Y', localtime($now));
	open(EXPORT, ">$file")
		or die "write $file: $!\n";
	print EXPORT <<EOF;
!HDR	PROD	VER	REL	IIFVER	DATE	TIME	ACCNTNT	ACCNTNTSPLITTIME\r
HDR	Interchange	Version $::VERSION	Release $::VERSION	1	$date	$now	N	0\r
!ACCNT	$keystring\r
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

	my $prepend = $CGI->{ui_qbcoa_prepend} || '';

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
									"$Vend::Cfg->{ProductDir}/quickbooks.coa.refnum",
								);
						push @out, $n;
					}
					else {
						push @out, $k;
					}
				}
				elsif($prepend and $_ eq 'NAME') {
					push @out, $prepend . $subs{$_}->($k);
				}
				else {
					push @out, $subs{$_}->($k);
				}
			}
			print EXPORT join $delimiter, 'ACCNT', @out;
			print EXPORT "\r\n";
			$count++;
		}
	}
	$out .= "$count records exported.</PRE>";
	close EXPORT;
	return $out;
}
EOR

