UserTag reconfig-wait Order name
UserTag reconfig-wait Routine <<EOR
sub {
	my $name = shift || $Vend::Cfg->{CatalogName};
	my $myname = $Vend::Cfg->{CatalogName};
	return '' unless $myname eq '_mv_admin' or $myname eq $name;
    my $now = time();
    my $mod = ( stat("$Global::ConfDir/status." . $Vend::Cfg->{CatalogName}))[9];
    if( ($now - $mod) < $Global::HouseKeeping ) {
        $::Scratch->{possible_timeout} = 0;
        $::Scratch->{reconfigured} = 1;
        return '';
    }
    else {
        sleep 1;
        $::Scratch->{possible_timeout} = 1;
        return 'please wait...<BR>';
    }
}
EOR

