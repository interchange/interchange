# Copyright 2002 Interchange Development Group (http://www.icdevgroup.org/)
# Licensed under the GNU GPL v2. See file LICENSE for details.
# $Id: loc.tag,v 1.5 2005-02-10 14:38:39 docelic Exp $

# [loc locale*] message [/loc]
#
# This tag is the equivalent of [L] ... [/L] localization, except
# it works with contained tags
#
UserTag loc Order       locale
UserTag l   Alias       loc
UserTag loc hasEndTag   1
UserTag loc Interpolate 1
UserTag loc Version     $Revision: 1.5 $
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
