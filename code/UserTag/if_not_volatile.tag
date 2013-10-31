UserTag if_not_volatile HasEndTag 1
UserTag if_not_volatile Interpolate 0
UserTag if_not_volatile NoReparse 0
UserTag if_not_volatile Routine <<EOF
sub {
    my $body = shift;
    return $body unless $::Instance->{Volatile};
    return '';
}
EOF
