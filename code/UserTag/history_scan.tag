UserTag history-scan Order find exclude default
UserTag history-scan addAttr

UserTag history-scan Documentation <<EOF

=pod

=head1 history-scan

This tag returns a complete link (or optionally just the page name of) a previously
visited page.

Options:
	default=      Page to return if nothing else matches
	exclude=      A RegEx of page names to skip
	pageonly=1    Return just the name of a page, not a link to it.
	count=#N      Skip the #N most recently visited pages
	var_exclude   A list of parameters that should NOT be included in the 
			   links returned.

Examples:

A continue shopping button from an email by Jeff Dafoe
	[button
	  text="Continue shopping"
	  src="__THEME_IMG_DIR__/continueshopping.gif"
	  hidetext=1
	  extra="class=maincontent"
	  form=basket
	]
	    [bounce href='[history-scan exclude="^/ord|^/multi/|^/process|^/login" default=index]']
	    mv_nextpage=nothing
	[/button]


A simple login form that returns to the calling page when login was successful.
	<FORM ACTION="[process secure=1]" METHOD=POST>
	<INPUT TYPE=hidden   NAME=mv_todo  	VALUE=return>
	<INPUT TYPE=hidden   NAME=mv_click 	VALUE=Login>
	<INPUT TYPE=hidden   NAME=mv_failpage 	VALUE="login">
	<INPUT TYPE=hidden   NAME=mv_successpage 
		VALUE="[history-scan exclude="^/ord|^/multi/|^/process|^/login|^/logout" pageonly=1]">   
	<INPUT TYPE=hidden   NAME=mv_nextpage 	VALUE="index">
	<INPUT TYPE=hidden   NAME=mv_session_id VALUE="[data session id]">
	<INPUT TYPE=text     NAME=mv_username 	VALUE="[read-cookie MV_USERNAME]">
	<INPUT TYPE=password NAME=mv_password 	VALUE="">
	<INPUT TYPE=submit   NAME=submit	VALUE="Log In">
	</FORM>


=cut

EOF



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
	$href =~ s|/+|/|g;
	if ($opt->{pageonly}) {
		$href =~ s|^/||;
		return $href;
	}
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
	return $Tag->area( { href => $href, form => $form} );
}
EOR
