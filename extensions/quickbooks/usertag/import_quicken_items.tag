UserTag import_quicken_items Order file
UserTag import_quicken_items addAttr
UserTag import_quicken_items Routine <<EOR
sub {
	my($file, $opt) = @_;
	use strict;
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

	die "import_quicken: No file passed.\n"
		if ! $file;
	die "import_quicken: No file found.\n"
		unless -f $file;

	my @interest = grep /^qb:/, keys %CGI::values;
	my @names;
	my %fmap;
	my %pmap;
	my %rmap;
	my $keyname;
	my %subs;
	my $limit = $CGI::values{ui_qbitem_types} || 'PART INVENTORY';
	$limit =~ s/^\s+//;
	$limit =~ s/\s+$//;
	$limit =~ s/\s+/|/g;
	$limit = qr/$limit/;
	for(@interest) {
		next if ! $CGI::values{$_};
		my $k = $_;
		my $v = $CGI::values{$_};
		my $pfunc;
		if($v =~ s/^\s*=\s*//) {
			$pfunc = \&Vend::Util::is_yes;
		}
		elsif($v =~ s/^\s*!\s*//) {
			$pfunc = sub { ! Vend::Util::is_yes(@_) } ;
		}
		else {
			$pfunc = sub {
					my $val = shift;
					return $val unless $val =~ /^"/;
					return $val unless $val =~ /"$/;
					$val =~ s/^"//;
					$val =~ s/"$//;
					$val =~ s/""/"/g;
					return $val;
				};
		}
		$k =~ s/^qb://;
		my $dt;
		my($t, $f) = split /:+/, $k;
		$dt = ::database_exists_ref($t);
		if($dt->config('KEY') eq $f) {
			$keyname = $v;
		}
		die "Bad database $t\n" if ! $dt;
		$subs{$v} = [
			sub {
				my $k = shift;
				return if $dt->record_exists($k);
				$dt->set_row($k);
			}
		] if ! $subs{$v};
		my $set = $dt->field_settor($f);
		push @{$subs{$v}},
			sub { $set->($_[0], $pfunc->($_[1])) };
	}
	die "No key mapped." if ! $keyname;
	my $delimiter = quotemeta $opt->{delimiter} || "\t";
	open(UPDATE, $file)
		or die "read $file: $!\n";
	my $fields;
	my $count = 0;
	my $out = '';
	ITEMLOOP:
	while (<UPDATE>) {
		if(s/^!INVITEM$delimiter//o) {
			chomp;
			$fields = $_;
			@names = split /$delimiter/, $fields;
			my $i = 0;
			%fmap = ();
			for(@names) {
				my $x = 1;
				while (defined $fmap{$_}) {
					$_ .= $x++;
				}
				$fmap{$_} = $i++;
				$rmap{$i} = $_;
			}
			next;
		}
		next unless s/^INVITEM$delimiter//o;
		die "Can't find fields.\n" if ! $fields;
		chomp;
		my (@f) = split /$delimiter/o, $_;
		if(defined $fmap{INVITEMTYPE}) {
			next unless $f[ $fmap{INVITEMTYPE} ] =~ $limit;
		}
		next if $f[$fmap{HIDDEN}] =~ /^Y/i;
		next if $f[$fmap{PRICE}] < .01;
		my $k = $f[$fmap{$keyname}];
		die "No key for $_!\n" if ! defined $k;
		for (keys %subs) {
			my $ref = $subs{$_};
			my $val = $f[$fmap{$_}];
::logError("doing $_ for key=$k and val='$val'");
			for(@$ref) {
				$_->($k, $val);
			}
		}
		$count++;
	}
	$out .= "$count records updated.</PRE>";
	close UPDATE;
	if($opt->{'move'}) {
		my $ext = POSIX::strftime("%Y%m%d%H%M%S", localtime());
		rename $file, "$file.$ext"
			or die "rename $file --> $file.$ext: $!\n";
		if(	$opt->{dir}
			and (-d $opt->{dir} or File::Path::mkpath($opt->{dir}))
			and -w $opt->{dir}
			)
		{
			File::Copy::move("$file.$ext", $opt->{dir})
				or die "move $file.$ext --> $opt->{dir}: $!\n";
		}
	}
	return $out;
}
EOR

