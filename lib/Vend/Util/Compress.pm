# Vend::Util::Compress - Interchange compression management
#
# Copyright (C) 2002-2023 Interchange Development Group
# Copyright (C) 1996-2002 Red Hat, Inc.
#
# This program was originally based on Vend 0.2 and 0.3
# Copyright 1995 by Andrew M. Wilcox <amw@wilcoxsolutions.com>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public
# License along with this program; if not, write to the Free
# Software Foundation, Inc., 51 Franklin St, Fifth Floor, Boston,
# MA  02110-1301  USA.

package Vend::Util::Compress;
require Exporter;

use Time::HiRes qw();
use vars qw($VERSION @EXPORT_OK);
$VERSION = '1.0';

@ISA = qw(Exporter);

@EXPORT_OK = qw(
    compress
    uncompress
);

use strict;
use warnings;

my %has;
eval {
    require IO::Compress::Zstd;
    require IO::Uncompress::UnZstd;
    $has{Zstd} = {
        compress => sub {
            my $in = shift;
            my $out;
            IO::Compress::Zstd::zstd($in => \$out)
                or die $IO::Compress::Zstd::ZstdError;
            return \$out;
        },
        uncompress => sub {
            my $in = shift;
            my $out;
            IO::Uncompress::UnZstd::unzstd($in => \$out)
                or die $IO::Uncompress::UnZstd::UnZstdError;
            return \$out;
        },
    };
};

eval {
    require IO::Compress::Gzip;
    require IO::Uncompress::Gunzip;
    $has{Gzip} = {
        compress => sub {
            my $in = shift;
            my $out;
            IO::Compress::Gzip::gzip($in => \$out)
                or die $IO::Compress::Gzip::GzipError;
            return \$out;
        },
        uncompress => sub {
            my $in = shift;
            my $out;
            IO::Uncompress::Gunzip::gunzip($in => \$out)
                or die $IO::Uncompress::Gunzip::GunzipError;
            return \$out;
        },
    };
};

eval {
    require IO::Compress::Brotli;
    require IO::Uncompress::Brotli;
    $has{Brotli} = {
        compress => sub {
            my $in = shift;
            my $out = IO::Compress::Brotli::bro($$in)
                or die "bro() failed: $!";
            return \$out;
        },
        uncompress => sub {
            my $in = shift;

            # Assuming 90% reduction is highly optimistic
            my ($size) = _byte_size($in);
            my $out = IO::Uncompress::Brotli::unbro($$in, $size*10)
                or die "unbro() failed: $!";

            return \$out;
        },
    };
};

sub compress { wantarray ? _compress_list(@_) : _compress_scalar(@_) }

sub uncompress { wantarray ? _uncompress_list(@_) : _uncompress_scalar(@_) }

sub _compress_scalar {
    my $ref = shift;
    my $type = shift;

    my $subs = $has{$type}
        or do {
            ::logError("Compression type '$type' is not enabled. Returning original payload.");
            return $ref;
        }
    ;

    local $@;
    my $out = eval { $subs->{compress}->($ref) }
        or ::logError('%s compression error - returning original ref - %s', $type, $@);

    return $out // $ref;
}

sub _compress_list {
    my $ref = shift;
    my $type = shift;

    my $subs = $has{$type}
        or do {
            my $msg = "Compression type '$type' is not enabled. Returning original payload.";
            return ($ref, _byte_size($ref) x 2, '0', $msg);
        }
    ;

    my $msg = '';

    local $@;
    my $s = Time::HiRes::time;
    my $out = eval { $subs->{compress}->($ref) }
        or $msg = ::errmsg('%s compression error - returning original ref - %s', $type, $@);
    my $e = Time::HiRes::time;

    $out //= $ref;

    return ($out, _byte_size($ref, $out), $e - $s, $msg);
}

sub _uncompress_scalar {
    my $ref = shift;
    my $type = shift;

    my $subs = $has{$type}
        or do {
            ::logError("Compression type '$type' is not enabled. Returning original payload.");
            return $ref;
        }
    ;

    local $@;
    my $out = eval { $subs->{uncompress}->($ref) }
        or ::logError('%s uncompression error - %s', $type, $@);

    return $out // $ref;
}

sub _uncompress_list {
    my $ref = shift;
    my $type = shift;
    my $subs = $has{$type}
        or do {
            my $msg = "Compression type '$type' is not enabled. Returning original payload.";
            return ($ref, '0', $msg);
        }
    ;

    my $msg = '';

    local $@;
    my $s = Time::HiRes::time;
    my $out = eval { $subs->{uncompress}->($ref) }
        or $msg = ::errmsg('%s uncompression error - returning original ref - %s', $type, $@);
    my $e = Time::HiRes::time;

    $out //= $ref;

    return ($out, $e - $s, $msg);
}

sub _byte_size {
    my @out;

    use bytes;
    for (@_) {
        push @out, length $$_;
    }
    return @out;
}

1;

__END__
