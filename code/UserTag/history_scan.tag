UserTag history-scan Order find exclude default
UserTag history-scan addAttr
UserTag history-scan Routine <<EOR
my %var_exclude = ( qw/
	mv_credit_card_number 1
	mv_pc                 1
	mv_session_id         1
	expand                1
	collapse              1
	expandall             1
	collapseall           1
/);
sub {
	my ($find, $exclude, $default, $opt) = @_;
	$default ||= $Config->{SpecialPage}{catalog};
	my $ref = $Vend::Session->{History} or return $Tag->area($default);
	my ($hist, $href, $cgi);
	$exclude = qr/$exclude/ if $exclude;
	for (my $i = $#$ref - abs($opt->{count}); $i >= 0; $i--) {
		next if $ref->[$i][0] eq 'expired';
		if ($exclude and $ref->[$i][0] =~ $exclude) {
			next;
		}
		if($find) {
			next unless $ref->[$i][0] =~ /$find/;
		}
		($href, $cgi) = @{$ref->[$i]};
		last;
	}
	return $Tag->area($default) if ! $href;
	my $form = '';
	if($opt->{var_exclude}) {
		for(split /[\s,\0]+/, $opt->{var_exclude}) {
			$var_exclude{$_} = 1;
		}
	}
	for(grep !$var_exclude{$_}, keys %$cgi) {
		$form .= "\n$_=";
		$form .= join("\n$_=", split /\0/, $cgi->{$_});
	}
	$href =~ s|/+|/|g;
	return $Tag->area( { href => $href, form => $form} );
}
EOR
