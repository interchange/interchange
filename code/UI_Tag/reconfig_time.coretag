UserTag reconfig-time Order name
UserTag reconfig-time Routine <<EOR
sub {
	my $name = shift || $Vend::Cfg->{CatalogName};
	my $myname = $Vend::Cfg->{CatalogName};
	return '' unless $myname eq '_mv_admin' or $myname eq $name;
	return Vend::Util::readfile($Global::RunDir . '/status.' . $name);
}
EOR


