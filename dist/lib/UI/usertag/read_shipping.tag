UserTag read-shipping Order file
UserTag read-shipping PosNumber 1
UserTag read-shipping addAttr
UserTag read-shipping Routine <<EOR
sub {
	my ($file, $opt) = @_;
	my $status = read_shipping($file, $opt);
	if(
		$Vend::Cfg->{Shipping_line}[0]->[0] eq 'code'
			and
		$Vend::Cfg->{Shipping_line}[0]->[1] eq 'description'
		)
	{
		shift (@{ $Vend::Cfg->{Shipping_line} });
		delete $Vend::Cfg->{Shipping_desc}{code};
	}
	return $status;
}
EOR

