UserTag fcounter Order file
UserTag fcounter PosNumber 1
UserTag fcounter addAttr
UserTag fcounter Routine <<EOF
sub {
    my $file = shift || 'etc/counter';
	my $opt = shift;
    $file = $Vend::Cfg->{VendRoot} . "/$file"
        unless index($file, '/') == 0;
    my $ctr = new Vend::CounterFile $file, $opt->{start} || undef;
    return $ctr->inc();
}
EOF
