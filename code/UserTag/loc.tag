# Copyright 2002-2007 Interchange Development Group and others
# 
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.  See the LICENSE file for details.
# 
# $Id: loc.tag,v 1.7 2007-03-30 23:40:57 pajamian Exp $

# [loc locale*] message [/loc]
#
# This tag is the equivalent of [L] ... [/L] localization, except
# it works with contained tags
#
UserTag loc Order       locale
UserTag l   Alias       loc
UserTag loc hasEndTag   1
UserTag loc Interpolate 1
UserTag loc Version     $Revision: 1.7 $
UserTag loc Routine     <<EOF
sub {
    my ($locale, $message) = @_;
    if($::Pragma->{no_locale_parse}) {
		## Need to do this but might have side-effects in PreFork mode
		undef $Vend::Parse::myRefs{Alias}{l};
		my $begin = '[L';
		$begin .= " $locale" if $locale;
		$begin .= ']';
		return $begin . $message . '[/L]';
	}
    return $message unless $Vend::Cfg->{Locale};
    my $ref;
    if($locale) {
        return $message
            unless defined $Vend::Cfg->{Locale_repository}{$locale};
        $ref = $Vend::Cfg->{Locale_repository}{$locale}
    }
    else {
        $ref = $Vend::Cfg->{Locale};
    }
    return defined $ref->{$message} ? $ref->{$message} : $message;
}
EOF
