# Vend::Util - Interchange utility functions
#
# $Id: Util.pm,v 2.1.2.12 2003-01-24 04:59:36 jon Exp $
# 
# Copyright (C) 1996-2002 Red Hat, Inc. and
# Interchange Development Group, http://www.icdevgroup.org/
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
# Software Foundation, Inc., 59 Temple Place, Suite 330, Boston,
# MA  02111-1307  USA.

package Vend::Util;
require Exporter;

@ISA = qw(Exporter);

@EXPORT = qw(
	catfile
	check_security
	copyref
	currency
	dump_structure
	errmsg
	escape_chars
	evalr
	file_modification_time
	file_name_is_absolute
	find_special_page
	format_log_msg
	generate_key
	get_option_hash
	is_no
	is_yes
	lockfile
	logData
	logDebug
	logError
	logGlobal
	logtime
	random_string
	readfile
	readin
	round_to_frac_digits
	secure_vendUrl
	send_mail
	setup_escape_chars
	set_lock_type
	show_times
	string_to_ref
	tag_nitems
	uneval
	uneval_it
	uneval_fast
	unlockfile
	vendUrl
);

use strict;
use Config;
use Fcntl;
use Errno;
use subs qw(logError logGlobal);
use vars qw($VERSION @EXPORT @EXPORT_OK);
$VERSION = substr(q$Revision: 2.1.2.12 $, 10);

BEGIN {
	eval {
		require 5.004;
	};
}

my $Eval_routine;
my $Eval_routine_file;
my $Pretty_uneval;
my $Fast_uneval;
my $Fast_uneval_file;

### END CONFIGURABLE MODULES

## ESCAPE_CHARS

$ESCAPE_CHARS::ok_in_filename =
		'ABCDEFGHIJKLMNOPQRSTUVWXYZ' .
		'abcdefghijklmnopqrstuvwxyz' .
		'0123456789'				 .
		'-:_.$/'
	;

$ESCAPE_CHARS::ok_in_url =
		'ABCDEFGHIJKLMNOPQRSTUVWXYZ' .
		'abcdefghijklmnopqrstuvwxyz' .
		'0123456789'				 .
		'-_./~='
	;

my $need_escape;

sub setup_escape_chars {
    my($ok, $i, $a, $t);

    foreach $i (0..255) {
        $a = chr($i);
        if (index($ESCAPE_CHARS::ok_in_filename,$a) == -1) {
			$t = '%' . sprintf( "%02X", $i );
        }
		else {
			$t = $a;
        }
        $ESCAPE_CHARS::translate[$i] = $t;
        if (index($ESCAPE_CHARS::ok_in_url,$a) == -1) {
			$t = '%' . sprintf( "%02X", $i );
        }
		else {
			$t = $a;
        }
        $ESCAPE_CHARS::translate_url[$i] = $t;
    }

	my $string = "[^$ESCAPE_CHARS::ok_in_url]";
	$need_escape = qr{$string};

}

# Replace any characters that might not be safe in a filename (especially
# shell metacharacters) with the %HH notation.

sub escape_chars {
    my($in) = @_;
    my($c, $r);

    $r = '';
    foreach $c (split(//, $in)) {
		$r .= $ESCAPE_CHARS::translate[ord($c)];
    }

    # safe now
    return $r;
}

# Replace any characters that might not be safe in an URL
# with the %HH notation.

sub escape_chars_url {
    my($in) = @_;
    my($c, $r);

    $r = '';
    foreach $c (split(//, $in)) {
		$r .= $ESCAPE_CHARS::translate_url[ord($c)];
    }

    # safe now
    return $r;
}

# Returns its arguments as a string of tab-separated fields.  Tabs in the
# argument values are converted to spaces.

sub tabbed {        
    return join("\t", map { $_ = '' unless defined $_;
                            s/\t/ /g;
                            $_;
                          } @_);
}

# Finds common-log-style offset
# Unproven, authoratative code welcome
my $Offset;
FINDOFFSET: {
    my $now = time;
    my ($gm,$gh,$gd,$gy) = (gmtime($now))[1,2,5,7];
    my ($lm,$lh,$ld,$ly) = (localtime($now))[1,2,5,7];
    if($gy != $ly) {
        $gy < $ly ? $lh += 24 : $gh += 24;
    }
    elsif($gd != $ld) {
        $gd < $ld ? $lh += 24 : $gh += 24;
    }
    $gh *= 100;
    $lh *= 100;
    $gh += $gm;
    $lh += $lm;
    $Offset = sprintf("%05d", $lh - $gh);
    $Offset =~ s/0(\d\d\d\d)/+$1/;
}

# Returns time in HTTP common log format
sub logtime {
    return POSIX::strftime("[%d/%B/%Y:%H:%M:%S $Offset]", localtime());
}

sub format_log_msg {
	my($msg) = @_;
	my(@params);

	# IP, Session, REMOTE_USER (if any) and time
    push @params, ($CGI::remote_host || $CGI::remote_addr || '-');
	push @params, ($Vend::SessionName || '-');
	push @params, ($CGI::user || '-');
	push @params, logtime();

	# Catalog name
	my $string = ! defined $Vend::Cfg ? '-' : ($Vend::Cat || '-');
	push @params, $string;

	# Path info and script
	$string = $CGI::script_name || '-';
	$string .= $CGI::path_info || '';
	push @params, $string;

	# Message, quote newlined area
	$msg =~ s/\n/\n> /g;
	push @params, $msg;
	return join " ", @params;
}

sub round_to_frac_digits {
	my ($num, $digits) = @_;
	if (defined $digits) {
		# use what we were given
	}
	elsif ( $Vend::Cfg->{Locale} ) {
		$digits = $Vend::Cfg->{Locale}{frac_digits};
		$digits = 2 if ! defined $digits;
	}
	else {
		$digits = 2;
	}
	my @frac;
	$num =~ /^(\d*)\.(\d+)$/
		or return $num;
	my $int = $1;
	@frac = split //, $2;
	local($^W) = 0;
	my $frac = join "", @frac[0 .. $digits - 1];
	if($frac[$digits] > 4) {
		$frac++;
	}
	if(length($frac) > $digits) {
		$int++;
		$frac = 0 x $digits;
	}
	$frac .= '0' while length($frac) < $digits;
	return "$int.$frac";
}

use vars qw/%MIME_type/;
%MIME_type = (qw|
			jpg		image/jpeg
			gif		image/gif
			jpeg	image/jpeg
			png		image/png
			xpm		image/xpm
			htm		text/html
			html	text/html
			txt		text/plain
			asc		text/plain
			csv		text/plain
			xls		application/vnd.ms-excel
			default application/octet-stream
		|
		);
# Return a mime type based on either catalog configuration or some defaults
sub mime_type {
	my ($val) = @_;
	$val =~ s:.*\.::s;

	! length($val) and return $Vend::Cfg->{MimeType}{default} || 'text/plain';

	$val = lc $val;

	return $Vend::Cfg->{MimeType}{$val}
				|| $MIME_type{$val}
				|| $Vend::Cfg->{MimeType}{default}
				|| $MIME_type{default};
}

# Return AMOUNT formatted as currency.
sub commify {
    local($_) = shift;
	my $sep = shift || ',';
    1 while s/^(-?\d+)(\d{3})/$1$sep$2/;
    return $_;
}

my %safe_locale = ( 
						C     => 1,
						en_US => 1,
						en_UK => 1,
					);

sub safe_sprintf {
	# need to supply $fmt as a scalar to prevent prototype problems
	my $fmt = shift;

	# query the locale
	my $save = POSIX::setlocale (&POSIX::LC_NUMERIC);

	# This should be faster than doing set every time....but when
	# is locale C anymore? Should we set this by default?
	return sprintf($fmt, @_) if $safe_locale{$save};

	# Need to set.
	POSIX::setlocale (&POSIX::LC_NUMERIC, 'C');
	my $val = sprintf($fmt, @_);
	POSIX::setlocale (&POSIX::LC_NUMERIC, $save);
	return $val;
}

sub picture_format {
	my($amount, $pic, $sep, $point) = @_;
    $pic	= reverse $pic;
	$point	= '.' unless defined $point;
	$sep	= ',' unless defined $sep;
	$pic =~ /(#+)\Q$point/;
	my $len = length($1);
	$amount = sprintf('%.' . $len . 'f', $amount);
	$amount =~ tr/0-9//cd;
	my (@dig) = split //, $amount;
	$pic =~ s/#/pop(@dig)/eg;
	$pic =~ s/\Q$sep\E+(?!\d)//;
	$pic =~ s/\d/*/g if @dig;
	$amount = reverse $pic;
	return $amount;
}

sub setlocale {
    my ($locale, $currency, $opt) = @_;
#::logDebug("original locale " . (defined $locale ? $locale : 'undef') );
#::logDebug("default locale  " . (defined $::Scratch->{mv_locale} ? $::Scratch->{mv_locale} : 'undef') );

	if($opt->{get}) {
	    my $loc     = $Vend::Cfg->{Locale_repository} or return;
	    my $currloc = $Vend::Cfg->{Locale} or return;
	    for(keys %$loc) {
			return $_ if $loc->{$_} eq $currloc;
	    }
	    return;
	}

    $locale = $::Scratch->{mv_locale} unless defined $locale;
#::logDebug("locale is now   " . (defined $locale ? $locale : 'undef') );

    if ( $locale and not defined $Vend::Cfg->{Locale_repository}{$locale}) {
        ::logError( "attempt to set non-existant locale '%s'" , $locale );
        return '';
    }

    if ( $currency and not defined $Vend::Cfg->{Locale_repository}{$currency}) {
        ::logError("attempt to set non-existant currency '%s'" , $currency);
        return '';
    }

    if($locale) {
        my $loc = $Vend::Cfg->{Locale} = $Vend::Cfg->{Locale_repository}{$locale};

        for(@Vend::Config::Locale_directives_scalar) {
            $Vend::Cfg->{$_} = $loc->{$_}
                if defined $loc->{$_};
        }

        for(@Vend::Config::Locale_directives_ary) {
            @{$Vend::Cfg->{$_}} = split (/\s+/, $loc->{$_})
                if $loc->{$_};
        }

        for(@Vend::Config::Locale_directives_code) {
			next unless $loc->{$_->[0]};
			my ($routine, $args) = @{$_}[1,2];
			if($args) {
				$routine->(@$args);
			}
			else {
				$routine->();
			}
        }

		no strict 'refs';
		for(qw/LC_COLLATE LC_CTYPE LC_TIME/) {
			next unless $loc->{$_};
			POSIX::setlocale(&{"POSIX::$_"}, $loc->{$_});
		}
    }

    if ($currency) {
        my $curr = $Vend::Cfg->{Locale_repository}{$currency};

        for(@Vend::Config::Locale_directives_currency) {
            $Vend::Cfg->{$_} = $curr->{$_}
                if defined $curr->{$_};
        }
        @{$Vend::Cfg->{Locale}}{@Vend::Config::Locale_keys_currency} =
                @{$curr}{@Vend::Config::Locale_keys_currency};
    }

    $::Scratch->{mv_locale}   = $locale    if $opt->{persist} and $locale;
    $::Scratch->{mv_currency} = $currency  if $opt->{persist} and $currency;
    return '';
}


sub currency {
	my($amount, $noformat, $convert, $opt) = @_;
#::logDebug("currency called: amount=$amount no=$noformat convert=$convert");
	$opt = {} unless $opt;
	
	$amount = $amount / $Vend::Cfg->{PriceDivide}
		if $convert and $Vend::Cfg->{PriceDivide} != 0;
	return $amount if $noformat;
	my $loc;
	my $sep;
	my $dec;
	my $fmt;
	my $precede = '';
	my $succede = '';
	if ($loc = $opt->{locale} || $Vend::Cfg->{Locale}) {
		$sep = $loc->{mon_thousands_sep} || $loc->{thousands_sep} || ',';
		$dec = $loc->{mon_decimal_point} || $loc->{decimal_point} || '.';
		return picture_format($amount, $loc->{price_picture}, $sep, $dec)
			if defined $loc->{price_picture};
		$fmt = "%." . $loc->{frac_digits} .  "f";
		my $cs;
		if($cs = ($loc->{currency_symbol} ||$loc->{currency_symbol} || '') ) {
			if($loc->{p_cs_precedes}) {
				$precede = $cs;
				$precede = "$precede " if $loc->{p_sep_by_space};
			}
			else {
				$succede = $cs;
				$succede = " $succede" if $loc->{p_sep_by_space};
			}
		}
	}
	else {
		$fmt = "%.2f";
	}

	$amount = safe_sprintf($fmt, $amount);
	$amount =~ s/\./$dec/ if defined $dec;
	$amount = commify($amount, $sep || undef)
		if $Vend::Cfg->{PriceCommas};
	return "$precede$amount$succede";
}

## random_string

# leaving out 0, O and 1, l
my $random_chars = "ABCDEFGHIJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz23456789";

# Return a string of random characters.

sub random_string {
    my ($len) = @_;
    $len = 8 unless $len;
    my ($r, $i);

    $r = '';
    for ($i = 0;  $i < $len;  ++$i) {
	$r .= substr($random_chars, int(rand(length($random_chars))), 1);
    }
    $r;
}

# To generate a unique key for caching
# Not very good without MD5
#
my $Md;
my $Keysub;

eval {require Digest::MD5 };

if(! $@) {
	$Md = new Digest::MD5;
	$Keysub = sub {
#::logDebug("key gen args: '@_'");
					@_ = time() unless @_;
					$Md->reset();
					$Md->add(@_);
					$Md->hexdigest();
				};
}
else {
	$Keysub = sub {
		my $out = '';
		@_ = time() unless @_;
		for(@_) {
			$out .= unpack "%32c*", $_;
			$out .= unpack "%32c*", substr($_,5);
			$out .= unpack "%32c*", substr($_,-1,5);
		}
		$out;
	};
}

sub generate_key { &$Keysub(@_) }

sub hexify {
    my $string = shift;
    $string =~ s/(\W)/sprintf '%%%02x', ord($1)/ge;
    return $string;
}

sub unhexify {
    my $s = shift;
    $s =~ s/%(..)/chr(hex($1))/ge;
    return $s;
}

## UNEVAL

# Returns a string representation of an anonymous array, hash, or scaler
# that can be eval'ed to produce the same value.
# uneval([1, 2, 3, [4, 5]]) -> '[1,2,3,[4,5,],]'
# Uses either Storable::freeze or Data::Dumper::DumperX or uneval 
# in 

sub uneval_it {
    my($o) = @_;		# recursive
    my($r, $s, $i, $key, $value);

	local($^W) = 0;
    $r = ref $o;
    if (!$r) {
	$o =~ s/([\\"\$@])/\\$1/g;
	$s = '"' . $o . '"';
    } elsif ($r eq 'ARRAY') {
	$s = "[";
	foreach $i (0 .. $#$o) {
	    $s .= uneval_it($o->[$i]) . ",";
	}
	$s .= "]";
    } elsif ($r eq 'HASH') {
	$s = "{";
	while (($key, $value) = each %$o) {
	    $s .= "'$key' => " . uneval_it($value) . ",";
	}
	$s .= "}";
    } else {
	$s = "'something else'";
    }

    $s;
}

use subs 'uneval_fast';

sub uneval_it_file {
	my ($ref, $fn) = @_;
	open(UNEV, ">$fn") 
		or die "Can't create $fn: $!\n";
	print UNEV uneval_fast($ref);
	close UNEV;
}

sub eval_it_file {
	my ($fn) = @_;
	local($/) = undef;
	open(UNEV, "< $fn") or return undef;
	my $ref = evalr(<UNEV>);
	close UNEV;
	return $ref;
}

# See if we have Storable and the user has OKed its use
# If so, session storage/write will be about 5x faster
eval {
	die unless $ENV{MINIVEND_STORABLE};
	require Storable;
	import Storable 'freeze';
	$Fast_uneval     = \&Storable::freeze;
	$Fast_uneval_file  = \&Storable::store;
	$Eval_routine    = \&Storable::thaw;
	$Eval_routine_file = \&Storable::retrieve;
};

# See if Data::Dumper is installed with XSUB
# If it is, session writes will be about 25-30% faster
eval {
		require Data::Dumper;
		import Data::Dumper 'DumperX';
		$Data::Dumper::Indent = 1;
		$Data::Dumper::Terse = 1;
		$Data::Dumper::Deepcopy = 1;
		if(defined $Fast_uneval) {
			$Pretty_uneval = \&Data::Dumper::Dumper;
		}
		else {
			$Pretty_uneval = \&Data::Dumper::DumperX;
			$Fast_uneval = \&Data::Dumper::DumperX
		}
};

*uneval_fast = defined $Fast_uneval       ? $Fast_uneval       : \&uneval_it;
*evalr       = defined $Eval_routine      ? $Eval_routine      : sub { eval shift };
*eval_file   = defined $Eval_routine_file ? $Eval_routine_file : \&eval_it_file;
*uneval_file = defined $Fast_uneval_file  ? $Fast_uneval_file  : \&uneval_it_file;
*uneval      = defined $Pretty_uneval     ? $Pretty_uneval     : \&uneval_it;

sub writefile {
    my($file, $data, $opt) = @_;

	$file = ">>$file" unless $file =~ /^[|>]/;
	if (ref $opt and $opt->{umask}) {
		$opt->{umask} = umask oct($opt->{umask});
	}
    eval {
		unless($file =~ s/^[|]\s*//) {
			if (ref $opt and $opt->{auto_create_dir}) {
				my $dir = $file;
				$dir =~ s/>+//;

				## Need to make this OS-independent, requires File::Spec support
				$dir =~ s:[\r\n]::g;   # Just in case
				$dir =~ s:(.*)/.*:: or $dir = '';
				if($dir and ! -d $dir) {
					File::Path::mkpath($dir);
				}
			}
			# We have checked for beginning > or | previously
			open(MVLOGDATA, $file) or die "open\n";
			lockfile(\*MVLOGDATA, 1, 1) or die "lock\n";
			seek(MVLOGDATA, 0, 2) or die "seek\n";
			if(ref $data) {
				print(MVLOGDATA $$data) or die "write to\n";
			}
			else {
				print(MVLOGDATA $data) or die "write to\n";
			}
			unlockfile(\*MVLOGDATA) or die "unlock\n";
		}
		else {
            my (@args) = grep /\S/, Text::ParseWords::shellwords($file);
			open(MVLOGDATA, "|-") || exec @args;
			if(ref $data) {
				print(MVLOGDATA $$data) or die "pipe to\n";
			}
			else {
				print(MVLOGDATA $data) or die "pipe to\n";
			}
		}
		close(MVLOGDATA) or die "close\n";
    };

	my $status = 1;
    if ($@) {
		::logError ("Could not %s file '%s': %s\nto write this data:\n%s",
				$@,
				$file,
				$!,
				$data,
				);
		$status = 0;
    }

    if (ref $opt and defined $opt->{umask}) {                                        
        $opt->{umask} = umask oct($opt->{umask});                                    
    }

	return $status;
}


# Log data fields to a data file.

sub logData {
    my($file,@msg) = @_;
    my $prefix = '';

	$file = ">>$file" unless $file =~ /^[|>]/;

	my $msg = tabbed @msg;

    eval {
		unless($file =~ s/^[|]\s*//) {
			# We have checked for beginning > or | previously
			open(MVLOGDATA, $file)		or die "open\n";
			lockfile(\*MVLOGDATA, 1, 1)	or die "lock\n";
			seek(MVLOGDATA, 0, 2)		or die "seek\n";
			print(MVLOGDATA "$msg\n")	or die "write to\n";
			unlockfile(\*MVLOGDATA)		or die "unlock\n";
		}
		else {
            my (@args) = grep /\S/, Text::ParseWords::shellwords($file);
			open(MVLOGDATA, "|-") || exec @args;
			print(MVLOGDATA "$msg\n") or die "pipe to\n";
		}
		close(MVLOGDATA) or die "close\n";
    };
    if ($@) {
		::logError ("Could not %s log file '%s': %s\nto log this data:\n%s",
				$@,
				$file,
				$!,
				$msg,
				);
		return 0;
    }
	1;
}


sub file_modification_time {
    my ($fn, $tolerate) = @_;
    my @s = stat($fn) or ($tolerate and return 0) or die "Can't stat '$fn': $!\n";
    return $s[9];
}

sub quoted_comma_string {
	my ($text) = @_;
	my (@fields);
	push(@fields, $+) while $text =~ m{
   "([^\"\\]*(?:\\.[^\"\\]*)*)"[\s,]?  ## std quoted string, w/possible space-comma
   | ([^\s,]+)[\s,]?                   ## anything else, w/possible space-comma
   | [,\s]+                            ## any comma or whitespace
        }gx;
    @fields;
}

# Modified from old, old module called Ref.pm
sub copyref {
    my($x,$r) = @_; 

    my($z, $y);

    my $rt = ref $x;

    if ($rt =~ /SCALAR/) {
        # Would \$$x work?
        $z = $$x;
        return \$z;
    } elsif ($rt =~ /HASH/) {
        $r = {} unless defined $r;
        for $y (sort keys %$x) {
            $r->{$y} = &copyref($x->{$y}, $r->{$y});
        }
        return $r;
    } elsif ($rt =~ /ARRAY/) {
        $r = [] unless defined $r;
        for ($y = 0; $y <= $#{$x}; $y++) {
            $r->[$y] = &copyref($x->[$y]);
        }
        return $r;
    } elsif ($rt =~ /REF/) {
        $z = &copyref($x);
        return \$z;
    } elsif (! $rt) {
        return $x;
    } else {
        die "do not know how to copy $x";
    }
}

sub check_gate {
	my($f, $gatedir) = @_;

	my $gate;
	if ($gate = readfile("$gatedir/.access_gate") ) {
#::logDebug("found access_gate");
		$f =~ s:.*/::;
		$gate = Vend::Interpolate::interpolate_html($gate);
#::logDebug("f=$f gate=$gate");
		if($gate =~ m!^$f(?:\.html?)?[ \t]*:!m ) {
			$gate =~ s!.*(\n|^)$f(?:\.html?)?[ \t]*:!!s;
#::logDebug("gate=$gate");
			$gate =~ s/\n[\S].*//s;
			$gate =~ s/^\s+//;
		}
		elsif($gate =~ m{^\*(?:\.html?)?[: \t]+(.*)}m) {
			$gate = $1;
		}
		else {
			undef $gate;
		}
	}
	return $gate;
}

sub string_to_ref {
	my ($string) = @_;
	if(! $Vend::Cfg->{ExtraSecure} and $MVSAFE::Safe) {
		return eval $string;
	}
	elsif ($MVSAFE::Safe) {
		die ::errmsg("not allowed to eval in Safe mode.");
	}
	return $Vend::Interpolate::safe_safe->reval($string);
}

sub get_option_hash {
	my $string = shift;
	my $merge = shift;
	if (ref $string) {
		return $string unless ref $merge;
		for(keys %{$merge}) {
			$string->{$_} = $merge->{$_}
				unless defined $string->{$_};
		}
		return $string;
	}
	return {} unless $string =~ /\S/;
	$string =~ s/^\s+//;
	$string =~ s/\s+$//;
	if($string =~ /^{/ and $string =~ /}/) {
		return string_to_ref($string);
	}

	my @opts;
	unless ($string =~ /,/) {
		@opts = grep $_ ne "=", Text::ParseWords::shellwords($string);
		for(@opts) {
			s/^(\w+)=(["'])(.*)\2$/$1$3/;
		}
	}
	else {
		@opts = split /\s*,\s*/, $string;
	}

	my %hash;
	for(@opts) {
		my ($k, $v) = split /[\s=]+/, $_, 2;
		$hash{$k} = $v;
	}
	if($merge) {
		return \%hash unless ref $merge;
		for(keys %$merge) {
			$hash{$_} = $merge->{$_}
				unless defined $hash{$_};
		}
	}
	return \%hash;
}

## READIN

my $Lang;

sub find_locale_bit {
	my $text = shift;
	$Lang = $::Scratch->{mv_locale} unless defined $Lang;
#::logDebug("find_locale: $Lang");
	$text =~ m{\[$Lang\](.*)\[/$Lang\]}s
		and return $1;
	$text =~ s{\[(\w+)\].*\[/\1\].*}{}s;
	return $text;
}

sub parse_locale {
	my ($input) = @_;

	# avoid copying big strings
	my $r = ref($input) ? $input : \$input;
	
	if($Vend::Cfg->{Locale}) {
		my $key;
		$$r =~ s~\[L(\s+([^\]]+))?\]([\000-\377]*?)\[/L\]~
						$key = $2 || $3;		
						defined $Vend::Cfg->{Locale}{$key}
						?  ($Vend::Cfg->{Locale}{$key})	: $3 ~eg;
		$$r =~ s~\[LC\]([\000-\377]*?)\[/LC\]~
						find_locale_bit($1) ~eg;
		undef $Lang;
	}
	else {
		$$r =~ s~\[L(?:\s+[^\]]+)?\]([\000-\377]*?)\[/L\]~$1~g;
	}

	# return scalar string if one get passed initially
	return ref($input) ? $input : $$r;
}

# Reads in a page from the page directory with the name FILE and ".html"
# appended. If the HTMLsuffix configuration has changed (because of setting in
# catalog.cfg or Locale definitions) it will substitute that. Returns the
# entire contents of the page, or undef if the file could not be read.
# Substitutes Locale bits as necessary.

sub readin {
    my($file, $only) = @_;
    my($fn, $contents, $gate, $pathdir, $dir, $level);
    local($/);

	$Global::Variable->{MV_PREV_PAGE} = $Global::Variable->{MV_PAGE}
		if defined $Global::Variable->{MV_PAGE};
	$Global::Variable->{MV_PAGE} = $file;

	$file =~ s#\.html?$##;
	if($file =~ m{\.\.} and $file =~ /\.\..*\.\./) {
		::logError( "Too many .. in file path '%s' for security.", $file );
		$file = find_special_page('violation');
	}
	$file =~ s#//+#/#g;
	$file =~ s#/+$##g;
	($pathdir = $file) =~ s#/[^/]*$##;
	$pathdir =~ s:^/+::;
	my $try;
	my $suffix = $Vend::Cfg->{HTMLsuffix};
  FINDPAGE: {
	foreach $try (
					$Vend::Cfg->{PageDir},
					@{$Vend::Cfg->{TemplateDir}},
					@{$Global::TemplateDir}          )
	{
		$dir = $try . "/" . $pathdir;
		if (-f "$dir/.access") {
			if (-s _) {
				$level = 3;
			}
			else {
				$level = '';
			}
			if(-f "$dir/.autoload") {
				my $status = ::interpolate_html( readfile("$dir/.autoload") );
				$status =~ s/\s+//g;
				undef $level if $status;
			}
			$gate = check_gate($file,$dir)
				if defined $level;
		}

		if( defined $level and ! check_security($file, $level, $gate) ){
			my $realm = $::Variable->{COMPANY} || $Vend::Cat;
			$Vend::StatusLine = <<EOF if $Vend::InternalHTTP;
HTTP/1.0 401 Unauthorized
WWW-Authenticate: Basic realm="$realm"
EOF
			if(-f "$try/violation$suffix") {
				$fn = "$try/violation$suffix";
			}
			else {
				$file = find_special_page('violation');
				$fn = $try . "/" . escape_chars($file) . $suffix;
			}
		}
		else {
			$fn = $try . "/" . escape_chars($file) . $suffix;
		}

		if (open(MVIN, "< $fn")) {
			binmode(MVIN) if $Global::Windows;
			undef $/;
			$contents = <MVIN>;
			close(MVIN);
			last;
		}
		last if defined $only;
	}
	if(! defined $contents) {
		last FINDPAGE if $suffix eq '.html';
		$suffix = '.html';
		redo FINDPAGE;
	}
  }

	if(! defined $contents) {
		$contents = readfile_db("pages/$file");
	}

	return unless defined $contents;

	parse_locale(\$contents);

	return $contents;
}

sub readfile_db {
	my ($name) = @_;
	return unless $Vend::Cfg->{FileDatabase};
	my ($tab, $col) = split /:+/, $Vend::Cfg->{FileDatabase};
	my $db = $Vend::Interpolate::Db{$tab} || ::database_exists_ref($tab)
		or return undef;
#::logDebug("tab=$tab exists, db=$db");

	# I guess this is the best test
	if($col) {
		return undef unless $db->column_exists($col);
	}
	elsif ( $col = $Global::Variable->{LANG} and $db->column_exists($col) ) {
		#do nothing
	}
	else {
		$col = 'default';
		return undef unless $db->column_exists($col);
	}

#::logDebug("col=$col exists, db=$db");
	return undef unless $db->record_exists($name);
#::logDebug("ifile=$name exists, db=$db");
	return $db->field($name, $col);
}

# Reads in an arbitrary file.  Returns the entire contents,
# or undef if the file could not be read.
# Careful, needs the full path, or will be read relative to
# VendRoot..and will return binary. Should be tested by
# the user.

# Will also look in the *global* TemplateDir. (No need for the
# extra overhead of local TemplateDir, probably also insecure.)
#
# To ensure security in multiple catalog setups, leading /
# is not allowed if the second subroutine argument passed
# (caller usually sends $Global::NoAbsolute) is true.

# If catalog FileDatabase is enabled and there are no contents, we can retrieve
# the file from the database.

sub readfile {
    my($ifile, $no, $loc) = @_;
    my($contents);
    local($/);

	if($no and (file_name_is_absolute($ifile) or $ifile =~ m#\.\./.*\.\.#)) {
		::logError("Can't read file '%s' with NoAbsolute set" , $ifile);
		::logGlobal({ level => 'auth'}, "Can't read file '%s' with NoAbsolute set" , $ifile );
		return undef;
	}

	my $file;

#::logDebug("readfile ifile=$ifile");
	if (file_name_is_absolute($ifile) and -f $ifile) {
		$file = $ifile;
	}
	else {
		for( ".", @{$Global::TemplateDir} ) {
#::logDebug("trying ifile=$_/$ifile");
			next if ! -f "$_/$ifile";
			$file = "$_/$ifile";
#::logDebug("readfile file=$file FOUND");
			last;
		}
	}

	if(! $file) {
		$contents = readfile_db($ifile);
		return undef unless defined $contents;
	}
	else {
		return undef unless open(READIN, "< $file");
		$Global::Variable->{MV_FILE} = $file;

		binmode(READIN) if $Global::Windows;
		undef $/;
		$contents = <READIN>;
		close(READIN);
	}

	if (
		$Vend::Cfg->{Locale}
			and
		(defined $loc ? $loc : $Vend::Cfg->{Locale}->{readfile} )
		)
	{
		my $key;
		$contents =~ s~\[L(\s+([^\]]+))?\]([\000-\377]*?)\[/L\]~
						$key = $2 || $3;		
						defined $Vend::Cfg->{Locale}->{$key}
						?  ($Vend::Cfg->{Locale}->{$key})	: $3 ~eg;
		$contents =~ s~\[LC\]([\000-\377]*?)\[/LC\]~
						find_locale_bit($1) ~eg;
		undef $Lang;
	}
    return $contents;
}

sub is_yes {
    return( defined($_[$[]) && ($_[$[] =~ /^[yYtT1]/));
}

sub is_no {
	return( !defined($_[$[]) || ($_[$[] =~ /^[nNfF0]/));
}

# Returns a URL which will run the ordering system again.  Each URL
# contains the session ID as well as a unique integer to avoid caching
# of pages by the browser.

sub vendUrl {
    my($path, $arguments, $r) = @_;
    $r = $Vend::Cfg->{VendURL}
		unless defined $r;

	my $can_cache = ! $Vend::Cfg->{NoCache}{$path};
	my @parms;

	if(exists $Vend::Cfg->{AlwaysSecure}{$path}) {
		$r = $Vend::Cfg->{SecureURL};
	}

	my($id, $ct);
	$id = $Vend::SessionID
		unless $can_cache and $Vend::Cookie && $::Scratch->{mv_no_session_id};
	$ct = ++$Vend::Session->{pageCount}
		unless $can_cache and $::Scratch->{mv_no_count};

	$path = escape_chars_url($path)
		if $path =~ $need_escape;
    $r .= '/' . $path;
	$r .= '.html' if $::Scratch->{mv_add_dot_html} and $r !~ /\.html?$/;
	push @parms, "$::VN->{mv_session_id}=$id"			 	if defined $id;
	push @parms, "$::VN->{mv_arg}=" . hexify($arguments)	if defined $arguments;
	push @parms, "$::VN->{mv_pc}=$ct"                 	if defined $ct;
	push @parms, "$::VN->{mv_cat}=$Vend::Cat"
														if defined $Vend::VirtualCat;
	if($Vend::AccumulatingLinks) {
		my $key = $path;
		$key =~ s/\.html?$//;
		my $value = '';
		if($arguments) {
			$value = [ $key, $arguments ];
			$key .= "/$arguments";
		}
		push(@Vend::Links, [$key, $value]) unless $Vend::LinkFound{$key}++;

	}
	return $r unless @parms;
    return $r . '?' . join($Global::UrlJoiner, @parms);
} 

sub secure_vendUrl {
	return vendUrl($_[0], $_[1], $Vend::Cfg->{SecureURL});
}

sub change_url {
	my $url = shift;
	return $url if $url =~ m{^\w+:};
	return $url if $url =~ m{^/};
#::logDebug("changed $url");
	my $arg;
	my @args;
	($url, $arg) = split /[?&]/, $url, 2;
	@args = split $Global::UrlSplittor, $arg;
	return Vend::Interpolate::tag_area( $url, '', {
											form => join "\n", @args,
										} );
}

sub resolve_links {
	my $html = shift;
	$html =~ s/(<a\s+[^>]*href\s*=\s*)(["'])([^'"]+)\2/$1 . $2 . change_url($3) . $2/gei;
	return $html;
}

### flock locking

# sys/file.h:
my $flock_LOCK_SH = 1;          # Shared lock
my $flock_LOCK_EX = 2;          # Exclusive lock
my $flock_LOCK_NB = 4;          # Don't block when locking
my $flock_LOCK_UN = 8;          # Unlock

sub flock_lock {
    my ($fh, $excl, $wait) = @_;
    my $flag = $excl ? $flock_LOCK_EX : $flock_LOCK_SH;

    if ($wait) {
        flock($fh, $flag) or die "Could not lock file: $!\n";
        return 1;
    }
    else {
        if (! flock($fh, $flag | $flock_LOCK_NB)) {
            if ($!{EAGAIN} or $!{EWOULDBLOCK}) {
				return 0;
            }
            else {
                die "Could not lock file: $!\n";
            }
        }
        return 1;
    }
}

sub flock_unlock {
    my ($fh) = @_;
    flock($fh, $flock_LOCK_UN) or die "Could not unlock file: $!\n";
}

sub fcntl_lock {
    my ($fh, $excl, $wait) = @_;
    my $flag = $excl ? F_WRLCK : F_RDLCK;
    my $op = $wait ? F_SETLKW : F_SETLK;

	my $struct = pack('sslli', $flag, 0, 0, 0, $$);

    if ($wait) {
        fcntl($fh, $op, $struct) or die "Could not fcntl_lock file: $!\n";
        return 1;
    }
    else {
        if (fcntl($fh, $op, $struct) < 0) {
            if ($!{EAGAIN} or $!{EWOULDBLOCK}) {
                return 0;
            }
            else {
                die "Could not lock file: $!\n";
            }
        }
        return 1;
    }
}

sub fcntl_unlock {
    my ($fh) = @_;
	my $struct = pack('sslli', F_UNLCK, 0, 0, 0, $$);
	if (fcntl($fh, F_SETLK, $struct) < 0) {
		if ($!{EAGAIN} or $!{EWOULDBLOCK}) {
			return 0;
		}
		else {
			die "Could not un-fcntl_lock file: $!\n";
		}
	}
	return 1;
}

my $lock_function = \&flock_lock;
my $unlock_function = \&flock_unlock;

sub set_lock_type {
	if ($Global::LockType eq 'none') {
		logDebug("using NO locking");
		$lock_function = sub {1};
		$unlock_function = sub {1};
	}
	elsif ($Global::LockType =~ /fcntl/i) {
		logDebug("using fcntl(2) locking");
		$lock_function = \&fcntl_lock;
		$unlock_function = \&fcntl_unlock;
	}
	else {
		$lock_function = \&flock_lock;
		$unlock_function = \&flock_unlock;
	}
	return; # VOID
}
 
sub lockfile {
    &$lock_function(@_);
}

sub unlockfile {
    &$unlock_function(@_);
}

### Still necessary, sad to say.....
if($Global::Windows) {
	set_lock_type('none');
}
elsif($^O =~ /hpux/) {
	set_lock_type('fcntl');
}

# Returns the total number of items ordered.
# Uses the current cart if none specified.

sub tag_nitems {
	my($ref, $opt) = @_;
    my($cart, $total, $item);
	
	if($ref) {
		 $cart = $::Carts->{$ref}
		 	or return 0;
	}
	else {
		$cart = $Vend::Items;
	}

	my ($attr, $sub);
	if($opt->{qualifier}) {
		$attr = $opt->{qualifier};
		my $qr;
		eval { 
			$qr = qr{$opt->{compare}} if $opt->{compare};
		};
		if($qr) {
			$sub = sub { 
							$_[0] =~ $qr;
						};
		}
		else {
			$sub = sub { return $_[0] };
		}
	}

    $total = 0;
    foreach $item (@$cart) {
		next if $attr and ! $sub->($item->{$attr});
		$total += $item->{'quantity'};
    }
    $total;
}

sub dump_structure {
	my ($ref, $name) = @_;
	my $save;
	$name =~ s/\.cfg$//;
	$name .= '.structure';
	open(UNEV, ">$name") or die "Couldn't write structure $name: $!\n";
	local($Data::Dumper::Indent);
	$Data::Dumper::Indent = 2;
	print UNEV uneval($ref);
	close UNEV;
}

# Do an internal HTTP authorization check
sub check_authorization {
	my($auth, $pwinfo) = @_;

	$auth =~ s/^\s*basic\s+//i or return undef;
	my ($user, $pw) = split(
						":",
						MIME::Base64::decode_base64($auth),
						2,
						);
	my $cmp_pw;
	my $use_crypt = 1;
	if(!defined $Vend::Cfg) {
		$pwinfo = $Global::AdminUser;
		$pwinfo =~ s/^\s+//;
		$pwinfo =~ s/\s+$//;
		my (%compare) = split /[\s:]+/, $pwinfo;
		return undef unless $compare{$user};
		$cmp_pw = $compare{$user};
		undef $use_crypt if $Global::Variable->{MV_NO_CRYPT};
	}
	elsif(	$user eq $Vend::Cfg->{RemoteUser}	and
			$Vend::Cfg->{Password}					)
	{
		$cmp_pw = $Vend::Cfg->{Password};
		undef $use_crypt if $::Variable->{MV_NO_CRYPT};
	}
	else {
		$pwinfo = $Vend::Cfg->{UserDatabase} unless $pwinfo;
		undef $use_crypt if $::Variable->{MV_NO_CRYPT};
		$cmp_pw = Vend::Interpolate::tag_data($pwinfo, 'password', $user)
			if defined $Vend::Cfg->{Database}{$pwinfo};
	}

	return undef unless $cmp_pw;

	if(! $use_crypt) {
		return $user if $pw eq $cmp_pw;
	}
	else {
		my $test = crypt($pw, $cmp_pw);
		return $user
			if $test eq $cmp_pw;
	}
	return undef;
}

# Check that the user is authorized by one or all of the
# configured security checks
sub check_security {
	my($item, $reconfig, $gate) = @_;

	my $msg;
	if(! $reconfig) {
# If using the new USERDB access control you may want to remove this next line
# for anyone with an HTTP basic auth will have access to everything
		#return 1 if $CGI::user and ! $Global::Variable->{MV_USERDB};
		if($gate) {
			$gate =~ s/\s+//g;
			return 1 if is_yes($gate);
		}
		elsif($Vend::Session->{logged_in}) {
			return 1 if $::Variable->{MV_USERDB_REMOTE_USER};
			my $db;
			my $field;
			if ($db = $::Variable->{MV_USERDB_ACL_TABLE}) {
				$field = $::Variable->{MV_USERDB_ACL_COLUMN};
				my $access = Vend::Data::database_field(
								$db,
								$Vend::Session->{username},
								$field,
								);
				return 1 if $access =~ m{(^|\s)$item(\s|$)};
			}
		}
		if($Vend::Cfg->{UserDB} and $Vend::Cfg->{UserDB}{log_failed}) {
			my $besthost = $CGI::remote_host || $CGI::remote_addr;
			::logError("auth error host=%s ip=%s script=%s page=%s",
							$besthost,
							$CGI::remote_addr,
							$CGI::script_name,
							$CGI::path_info,
							);
		}
        return '';  
	}
	elsif($reconfig eq '1') {
		$msg = 'reconfigure catalog';
	}
	elsif ($reconfig eq '2') {
		$msg = "access protected database $item";
#::logDebug("passed gate of $gate");
		return 1 if is_yes($gate);
	}
	elsif ($reconfig eq '3') {
		$msg = "access administrative function $item";
	}

	# Check if host IP is correct when MasterHost is set to something
	if (	$Vend::Cfg->{MasterHost}
				and
		(	$CGI::remote_host !~ /^($Vend::Cfg->{MasterHost})$/
				and
			$CGI::remote_addr !~ /^($Vend::Cfg->{MasterHost})$/	)	)
	{
			my $fmt = <<'EOF';
ALERT: Attempt to %s at %s from:

	REMOTE_ADDR  %s
	REMOTE_USER  %s
	USER_AGENT   %s
	SCRIPT_NAME  %s
	PATH_INFO    %s
EOF
		logGlobal ({level => 'auth'}, $fmt,
						$msg,
						$CGI::script_name,
						$CGI::host,
						$CGI::user,
						$CGI::useragent,
						$CGI::script_name,
						$CGI::path_info,
						);
		return '';
	}

	# Check to see if password enabled, then check
	if (
		$reconfig eq '1'		and
		!$CGI::user				and
		$Vend::Cfg->{Password}	and
		crypt($CGI::reconfigure_catalog, $Vend::Cfg->{Password})
		ne  $Vend::Cfg->{Password})
	{
		::logGlobal(
				{level => 'auth'},
				"ALERT: Password mismatch, attempt to %s at %s from %s",
				$msg,
				$CGI::script_name,
				$CGI::host,
				);
			return '';
	}

	# Finally check to see if remote_user match enabled, then check
	if ($Vend::Cfg->{RemoteUser} and
		$CGI::user ne $Vend::Cfg->{RemoteUser})
	{
		my $fmt = <<'EOF';
ALERT: Attempt to %s %s per user name:

	REMOTE_HOST  %s
	REMOTE_ADDR  %s
	REMOTE_USER  %s
	USER_AGENT   %s
	SCRIPT_NAME  %s
	PATH_INFO    %s
EOF

		::logGlobal(
			{level => 'auth'},
			$fmt,
			$CGI::script_name,
			$msg,
			$CGI::remote_host,
			$CGI::remote_addr,
			$CGI::user,
			$CGI::useragent,
			$CGI::script_name,
			$CGI::path_info,
		);
		return '';
	}

	# Don't allow random reconfigures without one of the three checks
	unless ($Vend::Cfg->{MasterHost} or
			$Vend::Cfg->{Password}   or
			$Vend::Cfg->{RemoteUser})
	{
		my $fmt = <<'EOF';
Attempt to %s on %s, secure operations disabled.

	REMOTE_ADDR  %s
	REMOTE_USER  %s
	USER_AGENT   %s
	SCRIPT_NAME  %s
	PATH_INFO    %s
EOF
		::logGlobal (
				{level => 'auth'},
				$fmt,
				$msg,
				$CGI::script_name,
				$CGI::host,
				$CGI::user,
				$CGI::useragent,
				$CGI::script_name,
				$CGI::path_info,
				);
			return '';

	}

	# Authorized if got here
	return 1;
}

# Replace the escape notation %HH with the actual characters.
#
sub unescape_chars {
    my($in) = @_;

    $in =~ s/%(..)/chr(hex($1))/ge;
    $in;
}


# Checks the Locale for a special page definintion mv_special_$key and
# returns it if found, otherwise goes to the default Vend::Cfg->{Special} array
sub find_special_page {
    my $key = shift;
	my $dir = '';
	$dir = "../$Vend::Cfg->{SpecialPageDir}/"
		if $Vend::Cfg->{SpecialPageDir};
    return $Vend::Cfg->{Special}{$key} || "$dir$key";
}

## ERROR

# Log the error MSG to the error file.

sub logDebug {
	return unless $Global::DebugFile;
	print caller() . ':debug: ', errmsg(@_), "\n";
}

sub errmsg {
	my($fmt, @strings) = @_;
	my $location;
	if($Vend::Cfg->{Locale} and defined $Vend::Cfg->{Locale}{$fmt}) {
	 	$location = $Vend::Cfg->{Locale};
	}
	elsif($Global::Locale and defined $Global::Locale->{$fmt}) {
	 	$location = $Global::Locale;
	}
	if($location) {
		if(ref $location->{$fmt}) {
			$fmt = $location->{$fmt}[0];
			@strings = @strings[ @{ $location->{$fmt}[1] } ];
		}
		else {
			$fmt = $location->{$fmt};
		}
	}
	return scalar(@strings) ? sprintf $fmt, @strings : $fmt;
}

sub show_times {
	my $message = shift || 'time mark';
	my @times = times();
	for( my $i = 0; $i < @times; $i++) {
		$times[$i] -= $Vend::Times[$i];
	}
	logDebug("$message: " . join " ", @times);
}

sub logGlobal {
    my($msg) = shift;
	my $opt;
	if(ref $msg) {
		$opt = $msg;
		$msg = shift;
	}
	if(@_) {
		$msg = errmsg($msg, @_);
	}
	my $nolock;

	my $fn = $Global::ErrorFile;
	my $flags;
	if($opt and $Global::SysLog) {
		$fn = "|" . ($Global::SysLog->{command} || 'logger');

		my $prioritized;
		my $tagged;
		my $facility = 'local3';
		if($opt->{level} and defined $Global::SysLog->{$opt->{level}}) {
			my $stuff =  $Global::SysLog->{$opt->{level}};
			if($stuff =~ /\./) {
				$facility = $stuff;
			}
			else {
				$facility .= ".$stuff";
			}
			$prioritized = 1;
		}

		my $tag = $Global::SysLog->{tag} || 'interchange';

		$facility .= ".info" unless $prioritized;

		$fn .= " -p $facility";
		$fn .= " -t $tag" unless "\L$tag" eq 'none';

		if($opt->{socket}) {
			$fn .= " -u $opt->{socket}";
		}
	}

	my $nl = ($opt and $opt->{strip}) ? '' : "\n";

	print "$msg$nl" if $Global::Foreground and ! $Vend::Log_suppress && ! $Vend::Quiet;

	$fn =~ s/^([^|>])/>>$1/
		or $nolock = 1;
#::logDebug("logging with $fn");
    $msg = format_log_msg($msg) if ! $nolock;

	$Vend::Errors .= $msg if $Global::DisplayErrors;

    eval {
		# We have checked for beginning > or | previously
		open(MVERROR, $fn) or die "open\n";
		if(! $nolock) {
			lockfile(\*MVERROR, 1, 1) or die "lock\n";
			seek(MVERROR, 0, 2) or die "seek\n";
		}
		print(MVERROR $msg, "\n") or die "write to\n";
		if(! $nolock) {
			unlockfile(\*MVERROR) or die "unlock\n";
		}
		close(MVERROR) or die "close\n";
    };
    if ($@) {
		chomp $@;
		print "\nCould not $@ error file '";
		print $Global::ErrorFile, "':\n$!\n";
		print "to report this error:\n", $msg;
		exit 1;
    }
}


# Log the error MSG to the error file.

sub logError {
    my $msg = shift;
	return unless defined $Vend::Cfg;
	if(@_) {
		$msg = errmsg($msg, @_);
	}

	print "$msg\n" if $Global::Foreground and ! $Vend::Log_suppress && ! $Vend::Quiet;

	$Vend::Session->{last_error} = $msg;

    $msg = format_log_msg($msg) unless $msg =~ s/^\\//;

	$Vend::Errors .= $msg if ($Vend::Cfg->{DisplayErrors} ||
							  $Global::DisplayErrors);

    eval {
		open(MVERROR, ">>$Vend::Cfg->{ErrorFile}")
											or die "open\n";
		lockfile(\*MVERROR, 1, 1)		or die "lock\n";
		seek(MVERROR, 0, 2)				or die "seek\n";
		print(MVERROR $msg, "\n")		or die "write to\n";
		unlockfile(\*MVERROR)			or die "unlock\n";
		close(MVERROR)					or die "close\n";
    };
    if ($@) {
		chomp $@;
		logGlobal ({ level => 'info' },
					"Could not %s error file %s: %s\nto report this error: %s",
					$@,
					$Vend::Cfg->{ErrorFile},
					$!,
					$msg,
				);
    }
}

# Here for convenience in calls
sub set_cookie {
    my ($name, $value, $expire, $domain, $path) = @_;
	if (! $::Instance->{Cookies}) {
		$::Instance->{Cookies} = []
	}
	else {
		@{$::Instance->{Cookies}} =
			grep $_->[0] ne $name, @{$::Instance->{Cookies}};
	}
    push @{$::Instance->{Cookies}}, [$name, $value, $expire, $domain, $path];
    return;
}

# Here for convenience in calls
sub read_cookie {
	my ($lookfor, $string) = @_;
	$string = $CGI::cookie
		unless defined $string;
	return undef unless $string =~ /\b$lookfor=([^\s;]+)/i;
 	return unescape_chars($1);
}

# Return a quasi-hashed directory/file combo, creating if necessary
sub exists_filename {
    my ($file,$levels,$chars, $dir) = @_;
	my $i;
	$levels = 1 unless defined $levels;
	$chars = 1 unless defined $chars;
	$dir = $Vend::Cfg->{ScratchDir} unless $dir;
    for($i = 0; $i < $levels; $i++) {
		$dir .= "/";
		$dir .= substr($file, $i * $chars, $chars);
		return 0 unless -d $dir;
	}
	return -f "$dir/$file" ? 1 : 0;
}

# Return a quasi-hashed directory/file combo, creating if necessary
sub get_filename {
    my ($file,$levels,$chars, $dir) = @_;
	my $i;
	$levels = 1 unless defined $levels;
	$chars = 1 unless defined $chars;
	$dir = $Vend::Cfg->{ScratchDir} unless $dir;
    for($i = 0; $i < $levels; $i++) {
		$dir .= "/";
		$dir .= substr($file, $i * $chars, $chars);
		mkdir $dir, 0777 unless -d $dir;
	}
    die "Couldn't make directory $dir (or parents): $!\n"
		unless -d $dir;
    return "$dir/$file";
}

# These were stolen from File::Spec
# Can't use that because it INSISTS on object
# calls without returning a blessed object

my $abspat = $^O =~ /win32/i ? '^([a-z]:)?[\\\\/]' : '^/';

sub file_name_is_absolute {
    my($file) = @_;
    $file =~ m{$abspat}oi ;
}

sub win_catfile {
    my $file = pop @_;
    return $file unless @_;
    my $dir = catdir(@_);
    $dir =~ s/(\\\.)$//;
    $dir .= "\\" unless substr($dir,length($dir)-1,1) eq "\\";
    return $dir.$file;
}

sub unix_catfile {
    my $file = pop @_;
    return $file unless @_;
    my $dir = catdir(@_);
    for ($dir) {
	$_ .= "/" unless substr($_,length($_)-1,1) eq "/";
    }
    return $dir.$file;
}

sub unix_path {
    my $path_sep = ":";
    my $path = $ENV{PATH};
    my @path = split $path_sep, $path;
    foreach(@path) { $_ = '.' if $_ eq '' }
    @path;
}

sub win_path {
    local $^W = 1;
    my $path = $ENV{PATH} || $ENV{Path} || $ENV{'path'};
    my @path = split(';',$path);
    foreach(@path) { $_ = '.' if $_ eq '' }
    @path;
}

sub win_catdir {
    my @args = @_;
    for (@args) {
	# append a slash to each argument unless it has one there
	$_ .= "\\" if $_ eq '' or substr($_,-1) ne "\\";
    }
    my $result = canonpath(join('', @args));
    $result;
}

sub win_canonpath {
    my($path) = @_;
    $path =~ s/^([a-z]:)/\u$1/;
    $path =~ s|/|\\|g;
    $path =~ s|\\+|\\|g ;                          # xx////xx  -> xx/xx
    $path =~ s|(\\\.)+\\|\\|g ;                    # xx/././xx -> xx/xx
    $path =~ s|^(\.\\)+|| unless $path eq ".\\";   # ./xx      -> xx
    $path =~ s|\\$|| 
             unless $path =~ m#^([a-z]:)?\\#;      # xx/       -> xx
    $path .= '.' if $path =~ m#\\$#;
    $path;
}

sub unix_canonpath {
    my($path) = @_;
    $path =~ s|/+|/|g ;                            # xx////xx  -> xx/xx
    $path =~ s|(/\.)+/|/|g ;                       # xx/././xx -> xx/xx
    $path =~ s|^(\./)+|| unless $path eq "./";     # ./xx      -> xx
    $path =~ s|/$|| unless $path eq "/";           # xx/       -> xx
    $path;
}

sub unix_catdir {
    my @args = @_;
    for (@args) {
	# append a slash to each argument unless it has one there
	$_ .= "/" if $_ eq '' or substr($_,-1) ne "/";
    }
    my $result = join('', @args);
    # remove a trailing slash unless we are root
    substr($result,-1) = ""
	if length($result) > 1 && substr($result,-1) eq "/";
    $result;
}


my $catdir_routine;
my $canonpath_routine;
my $catfile_routine;
my $path_routine;

if($^O =~ /win32/i) {
	$catdir_routine = \&win_catdir;
	$catfile_routine = \&win_catfile;
	$path_routine = \&win_path;
	$canonpath_routine = \&win_canonpath;
}
else {
	$catdir_routine = \&unix_catdir;
	$catfile_routine = \&unix_catfile;
	$path_routine = \&unix_path;
	$canonpath_routine = \&unix_canonpath;
}

sub path {
	return &{$path_routine}(@_);
}

sub catfile {
	return &{$catfile_routine}(@_);
}

sub catdir {
	return &{$catdir_routine}(@_);
}

sub canonpath {
	return &{$canonpath_routine}(@_);
}

#print "catfile a b c --> " . catfile('a', 'b', 'c') . "\n";
#print "catdir a b c --> " . catdir('a', 'b', 'c') . "\n";
#print "canonpath a/b//../../c --> " . canonpath('a/b/../../c') . "\n";
#print "file_name_is_absolute a/b/c --> " . file_name_is_absolute('a/b/c') . "\n";
#print "file_name_is_absolute a:b/c --> " . file_name_is_absolute('a:b/c') . "\n";
#print "file_name_is_absolute /a/b/c --> " . file_name_is_absolute('/a/b/c') . "\n";

#my $MIME_Lite;
#eval {
#	require MIME::Lite;
#	$MIME_Lite = 1;
#	require Net::SMTP;
#};
#
#sub mime_lite_send {
#	my ($opt, $body) = @_;
#
#	if(! $MIME_Lite) {
#		return send_mail(
#			$opt->{to},
#			$opt->{subject},
#			$body,
#			$opt->{reply},
#			undef,
#			split /\n+/, $opt->{extra}
#			);
#	}
#
#	my %special = qw/
#		as_string 1
#		internal  1
#	/;
#	my $mime = new MIME::Lite;;
#
#	my @ary;
#	my $popt = {};
#	my $mopt = {};
#	for(keys %$opt) {
#		if(ref $opt->{$_}) {
#			push @ary, [ $_, delete $opt->{$_} ];
#		}
#		if($special{$_}) {
#			$popt->{$_} = delete $opt->{$_};
#		}
#		my $m = $_;
#		s/_/-/g;
#		s/(\w+)/\L\u$1/g;
#		s/-/_/g;
#		$mopt->{$_} = $opt->{$m};
#	}
#
#}

sub send_mail {
	my($to, $subject, $body, $reply, $use_mime, @extra_headers) = @_;

	my @headers;
	if(ref $to) {
		my $head = $to;
		$body = $subject;
		undef $subject;
		for(@$head) {
#::logDebug("processing head=$_");
			if( /^To:\s*(.+)/ ) {
				$to = $1;
			}
			elsif (/Reply-to:\s*(.+)/) {
				$reply = $_;
			}
			elsif (/^subj(?:ect)?:\s*(.+)/i) {
				$subject = $1;
			}
			elsif($_) {
				push @extra_headers, $_;
			}
		}
	}


	my($ok);
#::logDebug("send_mail: to=$to subj=$subject r=$reply mime=$use_mime\n");

	unless (defined $use_mime) {
		$use_mime = $::Instance->{MIME} || undef;
	}

	if(!defined $reply) {
		$reply = $::Values->{mv_email}
				?  "Reply-To: $::Values->{mv_email}\n"
				: '';
	}
	elsif ($reply) {
		$reply = "Reply-To: $reply\n"
			unless $reply =~ /^reply-to:/i;
		$reply =~ s/\s+$/\n/;
	}

	$ok = 0;
	my $none;
	my $using = $Vend::Cfg->{SendMailProgram};

	if($using =~ /^(none|Net::SMTP)$/i) {
		$none = 1;
		$ok = 1;
	}

	SEND: {
#::logDebug("testing sendmail send none=$none");
		last SEND if $none;
#::logDebug("in Sendmail send $using");
		open(MVMAIL,"|$Vend::Cfg->{SendMailProgram} -t") or last SEND;
		my $mime = '';
		$mime = Vend::Interpolate::mime('header', {}, '') if $use_mime;
		print MVMAIL "To: $to\n", $reply, "Subject: $subject\n"
			or last SEND;
		for(@extra_headers) {
			s/\s*$/\n/;
			print MVMAIL $_
				or last SEND;
		}
		$mime =~ s/\s*$/\n/;
		print MVMAIL $mime
			or last SEND;
		print MVMAIL $body
				or last SEND;
		print MVMAIL Vend::Interpolate::do_tag('mime boundary') . '--'
			if $use_mime;
		print MVMAIL "\r\n\cZ" if $Global::Windows;
		close MVMAIL or last SEND;
		$ok = ($? == 0);
	}

	SMTP: {
		my $mhost = $::Variable->{MV_SMTPHOST} || $Global::Variable->{MV_SMTPHOST};
		my $helo =  $Global::Variable->{MV_HELO};
		last SMTP unless $none and $mhost;
		eval {
			require Net::SMTP;
		};
		last SMTP if $@;
		$ok = 0;
		$using = "Net::SMTP (mail server $mhost)";
#::logDebug("using $using");
		undef $none;

		my $smtp = new Net::SMTP $mhost;
		$smtp->hello($helo) if $helo;
#::logDebug("smtp object $smtp");

		my $from = $::Variable->{MV_MAILFROM}
				|| $Global::Variable->{MV_MAILFROM}
				|| $Vend::Cfg->{MailOrderTo};
		
		for(@extra_headers) {
			s/\s*$/\n/;
			next unless /^From:\s*(\S.+)$/mi;
			$from = $1;
		}
		my $mime = '';
		$mime = Vend::Interpolate::mime('header', {}, '') if $use_mime;
		$smtp->mail($from)
			or last SMTP;
#::logDebug("smtp accepted from=$from");

		my @to;
		my @addr = split /\s*,\s*/, $to;
		for (@addr) {
			if(/\s/) {
				## Uh-oh. Try to handle
				if ( m{( <.+?> | [^\s,]+\@[^\s,]+ ) }x ) {
					push @to, $1
				}
				else {
					logError("Net::SMTP sender skipping unparsable address %s", $_);
				}
			}
			else {
				push @to, $_;
			}
		}
		
		@addr = $smtp->recipient(@to, { SkipBad => 1 });
		if(scalar(@addr) != scalar(@to)) {
			logError(
				"Net::SMTP not able to send to all addresses of %s",
				join(", ", @to),
			);
		}

#::logDebug("smtp accepted to=" . join(",", @addr));

		$smtp->data();

		push @extra_headers, $reply if $reply;
		for ("To: $to", "Subject: $subject", @extra_headers) {
			next unless $_;
			s/\s*$/\n/;
#::logDebug(do { my $it = $_; $it =~ s/\s+$//; "datasend=$it" });
			$smtp->datasend($_)
				or last SMTP;
		}

		if($use_mime) {
			$mime =~ s/\s*$/\n/;
			$smtp->datasend($mime)
				or last SMTP;
		}
		$smtp->datasend("\n");
		$smtp->datasend($body)
			or last SMTP;
		$smtp->datasend(Vend::Interpolate::do_tag('mime boundary') . '--')
			if $use_mime;
		$smtp->dataend()
			or last SMTP;
		$ok = $smtp->quit();
	}

	if ($none or !$ok) {
		logError("Unable to send mail using %s\nTo: %s\nSubject: %s\n%s\n\n%s",
				$using,
				$to,
				$subject,
				$reply,
				$body,
		);
	}

	$ok;
}

1;
__END__
