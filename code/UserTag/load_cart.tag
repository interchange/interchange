UserTag load_cart Order nickname
UserTag load_cart Routine <<EOR
sub {
    my($nickname) = @_;

    my($jn,$updated,$recurring) = split(':',$nickname);

    $Tag->userdb({function => 'get_cart', nickname => $nickname, merge => 1});
    $Scratch->{just_nickname} = $jn;

    if($recurring eq 'c') {
        $Tag->userdb({function => 'delete_cart', nickname => $nickname});
    }

    return '';
}
EOR
