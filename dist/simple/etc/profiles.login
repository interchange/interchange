
__NAME__ Logout

[if type=explicit compare="[userdb logout]"]
mv_nextpage=[either][cgi mv_successpage][or][cgi mv_nextpage][/either]
[else]
mv_nextpage=[either][cgi mv_failpage][or][cgi mv_nextpage][/either]
[/else]
[/if]

__END__

__NAME__ Login

[if type=explicit compare="[userdb login]"]
mv_nextpage=[either][cgi mv_successpage][or][cgi mv_nextpage][/either]
[else]
mv_nextpage=[either][cgi mv_failpage][or][cgi mv_nextpage][/either]
[/else]
[/if]

__END__
