UserTag benchmark Order start display
UserTag benchmark AddAttr
UserTag benchmark Routine <<EOR
sub {
    my ($start, $display, $opt) = @_;
    my @times = times();
	my @bench_times;
    if($start or ! defined $::Instance->{bench_start}) {
        $::Instance->{bench_start} = 0;
        $::Instance->{bench_times} = [ @times ];
        for(@times) {
            $::Instance->{bench_start} += $_;
        }
    }
    my $current_total;
    if($display or ! $start) {
		my $bench_times = $::Instance->{bench_times};
        for(@times) {
            $current_total += $_;
        }
        unless ($start) {
            $current_total = sprintf '%.3f', $current_total - $::Instance->{bench_start};
            for(my $i = 0; $i < 4; $i++) {
                $times[$i] = sprintf '%.3f', $times[$i] - $bench_times->[$i];
            }
        }
        return $current_total if ! $opt->{verbose};
        return "total=$current_total user=$times[0] sys=$times[1] cuser=$times[2] csys=$times[3]";
    }
    return;
}
EOR
