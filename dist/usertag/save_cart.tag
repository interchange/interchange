UserTag save_cart Order nickname recurring
UserTag save_cart Routine <<EOR
sub {
    my($nickname,$recurring) = @_;

    $nickname =~ s/://g;

    map {
        $Tag->userdb({function => 'delete_cart', nickname => $_});
    } grep(/^$nickname:/i,split("\n",$Tag->value('carts')));

    my $nn = join(':',$nickname,time(),$recurring?"r":"c");

    $Tag->userdb({function => 'set_cart', nickname => $nn});

    $Carts->{main} = [];

    return '';
}
EOR
