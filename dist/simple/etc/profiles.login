
__NAME__ Logout

[if type=explicit compare="[userdb logout]"]
mv_nextpage=[cgi mv_successpage]
[else]
mv_nextpage=[cgi mv_failpage]
[/else]
[/if]

__END__

__NAME__ Login

[if type=explicit compare="[userdb login]"]
mv_nextpage=[either][cgi mv_successpage][or][cgi mv_nextpage][/either]
[perl minimate]
	$Session->{mm_username} = tag_data( '__MINIMATE_TABLE__',
										'username',
										$Session->{username},
										);
	return;
[/perl]
[else]
mv_nextpage=[either][cgi mv_failpage][or][cgi mv_nextpage][/either]
[/else]
[/if]

__END__
