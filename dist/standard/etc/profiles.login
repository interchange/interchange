__NAME__ Logout_choice

[if type=explicit compare="[userdb function=logout clear='[cgi clear_values]']"]
	[set mv_no_count]1[/set]
	[set mv_no_session_id]1[/set]
	[if cgi clear_cart]
	[calc] @$Items = (); return; [/calc]
	[/if]
	mv_nextpage=[either][cgi mv_successpage][or][cgi mv_nextpage][/either]
[else]
	mv_nextpage=[either][cgi mv_failpage][or][cgi mv_nextpage][/either]
[/else]
[/if]

__END__

__NAME__ Logout

[if type=explicit compare="[userdb function=logout clear=1]"]
	[set mv_no_count]1[/set]
	[set mv_no_session_id]1[/set]
	mv_nextpage=[either][cgi mv_successpage][or][cgi mv_nextpage][/either]
[else]
	mv_nextpage=[either][cgi mv_failpage][or][cgi mv_nextpage][/either]
[/else]
[/if]

__END__

__NAME__ Login

[if type=explicit compare="[userdb login]"]
	[set mv_no_count][/set]
	[set mv_no_session_id][/set]
	mv_nextpage=[either][cgi mv_successpage][or][cgi mv_nextpage][/either]
[else]
	mv_nextpage=[either][cgi mv_failpage][or][cgi mv_nextpage][/either]
[/else]
[/if]

__END__

__NAME__ Change_password

[if type=explicit compare="[userdb change_pass]"]
	mv_nextpage=[either][cgi mv_successpage][or][cgi mv_nextpage][/either]
[else]
	mv_nextpage=[either][cgi mv_failpage][or][cgi mv_nextpage][/either]
[/else]
[/if]

__END__

__NAME__ NewAccount

[if type=explicit compare="[userdb new_account]"]
	mv_nextpage=[either][cgi mv_successpage][or][cgi mv_nextpage][/either]
[else]
	mv_nextpage=[either][cgi mv_failpage][or][cgi mv_nextpage][/either]
[/else]
[/if]

__END__
