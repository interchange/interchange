UserTag delete_cart Order nickname
UserTag delete_cart Routine <<EOR
sub {
    my($nickname) = @_;

    $Tag->userdb({function => 'delete_cart', nickname => $nickname});

    return '';
}
EOR
