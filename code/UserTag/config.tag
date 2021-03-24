# Copyright 2002-2021 Interchange Development Group and others
# 
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.  See the LICENSE file for details.

UserTag config Order    key global
UserTag config Routine  <<EOR
sub {
    my ($key, $global) = @_;
    my $val = $global ? undef : $Vend::Cfg;

    for (split (/[.]/, $key)) {
        $val // do {
            no strict 'refs';
            $val = ${"Global::$_"};
            next if ref $val;
            last;
        };
        my $test = ref $val;
        if ($test eq 'HASH') {
            $val = $val->{$_};
        }
        elsif ($test eq 'ARRAY' && /^-?\d+$/a) {
            $val = $val->[$_];
        }
        else {
            ::logError(q{Invalid key on [config] call. Dotted key doesn't map to valid HASH or ARRAY reference.});
            return;
        }
    }
    return $val;
}
EOR
