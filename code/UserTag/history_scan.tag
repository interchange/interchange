UserTag history-scan Order find exclude default
UserTag history-scan addAttr
UserTag history-scan Routine <<EOR
my %var_exclude = ( qw/
	mv_credit_card_number 1
	mv_pc                 1
	mv_session_id         1
/);
sub {
	my ($find, $exclude, $default) = @_;
	my $ref = $Vend::Session->{History}
		or return $Tag->area($default || $Config->{SpecialPage}{catalog});
	my ($hist, $href, $cgi);
	$exclude = qr/$exclude/ if $exclude;
	for(my $i = $#$ref; $i >= 0; $i--) {
		next if $ref->[$i][0] eq 'expired';
		#Log("checking $ref->[$i][0] for $exclude");
		if ($exclude and $ref->[$i][0] =~ $exclude) {
			next;
		}
		if($find) {
			next unless $ref->[$i][0] =~ /$find/;
		}
		($href, $cgi) = @{$ref->[$i]};
		last;
	}
	return $Tag->area($default || $Config->{SpecialPage}{catalog})
		if ! $href;
	my $form = '';
	for(grep !$var_exclude{$_}, keys %$cgi) {
		$form .= "\n$_=";
		$form .= join("\n$_=", split /\0/, $cgi->{$_});
	}
	return $Tag->area( { href => $href, form => $form} );
}
EOR
