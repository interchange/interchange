UserTag reconfig-wait Order name
UserTag reconfig-wait Version $Revision: 2.1.2.1 $
UserTag reconfig-wait Routine <<EOR
sub {
	my $name = shift || $Vend::Cfg->{CatalogName};
	my $myname = $Vend::Cfg->{CatalogName};
	return '' unless $myname eq '_mv_admin' or $myname eq $name;
    my $now = time() - 2;
    my $mod;
	if($Global::HouseKeeping > 5) {
		my $link = Vend::Tags->page({
				href => "$::Variable->{UI_BASE}/genconfig",
				form => "start_at_index=1",
				});
		return qq{
HouseKeeping value of $Global::HouseKeeping seconds too long to wait. Check
$link last time changes applied </A> to ensure the reconfig worked.};
	}

	my $msg = errmsg('please wait');
	$msg .= '...';
	$msg .= ' ' x 8192;
	$msg .= "<br>\n";
	for( 1 .. ($Global::HouseKeeping + 3) ) {
		$mod = ( stat("$Global::RunDir/status." . $Vend::Cfg->{CatalogName}))[9];
		if($mod > $now) {
			$::Scratch->{possible_timeout} = 0;
			$::Scratch->{reconfigured} = 1;
			return;
		}
		else {
			::response($msg);
			$::Scratch->{possible_timeout} = 1;
			sleep 1;
		}
	}
}
EOR

