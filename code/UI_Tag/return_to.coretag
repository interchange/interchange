UserTag return_to Order type table_hack
UserTag return_to addAttr 
UserTag return_to Routine <<EOR
sub {
	use vars qw/$Tag/;
    my ($type, $tablehack, $opt) = @_;

	$type = 'form' unless $type;

	my ($page, @args) = split /\0/, $CGI::values{ui_return_to};
	if($CGI::values{ui_target}) {
		push @args, "ui_target=$CGI::values{ui_target}";
	}
	my $out = '';
	if ($opt->{page}) {
		$page = $opt->{page};
	}

			
	my $extra;
	if($tablehack) {
		my $found;
		for (@args) {
			if(s/^mv_data_table=(.*)//) {
				$extra = "mv_return_table=$1\n";
			}
			elsif (s/^(ui|mv)_return_table=//) {
				$found = "mv_return_table=$_\n";
			}
		}
		$extra = $found if $found;
	}

	if($type eq 'click') {
		$out .= qq{mv_nextpage=$page\n} if $page;
		for(@args) {
			my ($k, $v) = split /\s*=\s*/, $_, 2;
			next unless length $k;
			next if $k =~ /$opt->{exclude}/;
			$v =~ s/__NULL__/\0/g;
			$out .= qq{$k=$v\n};
		}
		if($opt->{stack} or $CGI::values{ui_return_stack}) {
			$type = 'formlink';
		}
		else {
			$type = 'done';
			$out .= "ui_return_to=\n";
		}
	}

	if($type eq 'formlink') {
		$page = $Global::Variable->{MV_PAGE} if ! $page;
		$out .= qq{ui_return_to=$page\n};
		for(@args) {
			tr/\n/\r/;
			$out .= qq{ui_return_to=$_\n}
		}
	}
	elsif($type eq 'url') {
		$page = $Global::Variable->{MV_PAGE} if ! $page;
		$out .= $Tag->area( {
								href => $page,
								form => join("\n", @args),
							});
	}
	elsif ($type eq 'form') {
		$page = $Global::Variable->{MV_PAGE} if ! $page;
		$out .= qq{<INPUT TYPE=hidden NAME=ui_return_to VALUE="$page">\n};
		for(@args) {
			s/"/&quot;/g;
			$out .= qq{<INPUT TYPE=hidden NAME=ui_return_to VALUE="$_">\n}
		}
	}
	elsif ($type eq 'regen') {
		$page = $Global::Variable->{MV_PAGE} if ! $page;
		$out .= qq{<INPUT TYPE=hidden NAME=ui_return_to VALUE="ui_return_to=$page">\n};
		for(@args) {
			s/"/&quot;/g;
			$out .= qq{<INPUT TYPE=hidden NAME=ui_return_to VALUE="ui_return_to=$_">\n}
		}
	}

	$out .= $extra if $extra;

    $::Scratch->{ui_location} = $Tag->area({
                                    href => $page,
                                    form => join "\n", @args,
                                })
		if $opt->{scratch};
    return $out;
}
EOR

