undef $/;
my $count = '000001';
$_ = <>;
s/\%\%\%\n\d+/"%%%\n" . $count++/eg;
print;
__END__
