package Vend::Diagnostic::Memory;

use warnings;
use 5.14.1;
use Time::HiRes qw(gettimeofday tv_interval);

use Exporter qw(import);
our @EXPORT_OK = qw(get_growth get_info MEM_KEYS save_info);
our %EXPORT_TAGS = (all => [@EXPORT_OK]);

our $loaded = 1;

=head1 NAME

Vend::Diagnostic::Memory

=head1 DESCRIPTION

This module retrieves process memory usage numbers from the Linux kernel,
and calculates how much memory used by our process increased since an
earlier measurement, and how much wallclock time elapsed.

In Interchange when these global directives are set in e.g. C<interchange.cfg>:

    ShowTimes Yes
    Require module Vend::Diagnostic::Memory

then at the end of each connection's request will be added to the debug
log memory statistics like the following:

    Memory final: VmPeak=459852 VmSize=459712 VmHWM=210936 VmRSS=210812 kB; increase: VmPeak=2348 VmSize=2208 VmHWM=2472 VmRSS=2348 kB; elapsed: 3.22888 sec

The "increase" is measured between the start and the end of Interchange
serving the request.

The memory measurements used are from L<proc(5)> under F</proc/[pid]/status>:

=over

=item * VmPeak: Peak virtual memory size

=item * VmSize: Virtual memory size

=item * VmHWM: Peak resident set size ("high water mark")

=item * VmRSS: Resident set size

=back

This works on most modern Linux kernels and should fail gracefully on
any system lacking the kernel-provided F</proc/[pid]/status> file.

=head1 RELATED CPAN MODULES

There are a few CPAN modules that fill a similar role, but we do not use them.

Compared to L<Memory::Usage>, our module here:

=over

=item * lets the kernel calculate kB from memory page counts rather than hardcoding page size

=item * includes memory "high-water" numbers

=item * keeps only start and end stats

=item * lets callers report in the format they choose

=back

L<Proc::ProcessTable> works with operating systems other than Linux
but reads in the whole process table and has a lot more overhead than
reading only what we need for our own process in a Linux-specific way.

=head1 AUTHOR

Jon Jensen <jon@endpointdev.com>

2020-01-16 initial version

2023-09-14 revised to run only upon request, and skip some extra work per request

=cut

my $saved_info = {};

use constant MEM_KEYS => [qw( VmPeak VmSize VmHWM VmRSS )];

{
    my $keys_or = join('|', map { quotemeta } @{MEM_KEYS()});
    my $re = qr/^($keys_or):\s+(\d+)\s+kB\b/a;

    sub get_info {
        my %out = (time => [gettimeofday]);
        local $@;
        eval {
            local @ARGV = "/proc/$$/status";
            while (<>) {
                next unless /$re/;
                $out{$1} = $2;
            }
        };
        $out{error} = $@ if $@;
        return \%out;
    }
}

sub save_info {
    $saved_info = get_info();
    #::logDebug("Memory info updated: " . ::uneval($saved_info));
    return;
}

sub get_growth {
    return $saved_info if !%$saved_info or $saved_info->{error};

    my $new_info = get_info();
    return $new_info if !%$new_info or $new_info->{error};

    my %diff = (
        time => tv_interval($saved_info->{time}, $new_info->{time}),
    );
    for my $k (grep { $_ ne 'time' } keys %$saved_info) {
        $diff{$k} = $new_info->{$k} - $saved_info->{$k};
    }

    return {
        old  => $saved_info,
        new  => $new_info,
        diff => \%diff,
    };
}

1;
