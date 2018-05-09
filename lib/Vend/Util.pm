# Vend::Util - Interchange utility functions
#
# Copyright (C) 2002-2017 Interchange Development Group
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

package Vend::Util;
require Exporter;

unless( $ENV{MINIVEND_DISABLE_UTF8} ) {
	require Encode;
	import Encode qw( is_utf8 encode_utf8 );
}
else {
    # sub returning false when UTF8 is disabled
    *is_utf8 = sub { };
}

@ISA = qw(Exporter);

@EXPORT = qw(
	adjust_time
	catfile
	check_security
	copyref
	currency
	dbref
	dump_structure
	errmsg
	escape_chars
	evalr
	dotted_hash
	file_modification_time
	file_name_is_absolute
	find_special_page
	format_log_msg
	generate_key
	get_option_hash
	hash_string
	header_data_scrub
	hexify
	is_hash
	is_ipv4
	is_ipv6
	is_no
	is_yes
	l
	lockfile
	logData
	logDebug
	logError
	logGlobal
	logOnce
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
	timecard_stamp
	timecard_read
	backtrace
	uneval
	uneval_it
	uneval_fast
	unhexify
	unlockfile
	vendUrl
);

use strict;
no warnings qw(uninitialized numeric);
no if $^V ge v5.22.0, warnings => qw(redundant);
use Config;
use Fcntl;
use Errno;
use Text::ParseWords;
require HTML::Entities;
use Vend::Safe;
use Vend::File;
use subs qw(logError logGlobal);
use vars qw($VERSION @EXPORT @EXPORT_OK);
$VERSION = '2.130';

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

## This is a character class for HTML::Entities
$ESCAPE_CHARS::std = qq{^\n\t\\X !\#\$%\'-;=?-Z\\\]-~};

## Some standard error templates

## This is an alias for a commonly-used function
*dbref = \&Vend::Data::database_exists_ref;

my $need_escape;

sub setup_escape_chars {
    my($ok, $i, $a, $t);

	## HTML::Entities caches this, let's get it cached right away so
	## each child doesn't have to re-eval
	my $junk = ">>>123<<<";
	HTML::Entities::encode($junk, $ESCAPE_CHARS::std);

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
    foreach $c (split(m{}, $in)) {
		$r .= $ESCAPE_CHARS::translate[ord($c)];
    }

    # safe now
    return $r;
}

# Replace any characters that might not be safe in an URL
# with the %HH notation.

sub escape_chars_url {
    my($in) = @_;
	return $in unless $in =~ $need_escape;
    my($c, $r);

    $r = '';
    if ($::Variable->{MV_UTF8} || $Global::Variable->{MV_UTF8}) {
        # check if it's decoded
        if (is_utf8($in)) {
            $in = encode_utf8($in);
        }
    }
    foreach $c (split(m{}, $in)) {
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

# Returns time in HTTP common log format
sub logtime {
    return POSIX::strftime("[%d/%B/%Y:%H:%M:%S %z]", localtime());
}

sub format_log_msg {
	my($msg) = @_;
	my(@params);

	# IP, Session, REMOTE_USER (if any) and time
    push @params, ($CGI::remote_host || $CGI::remote_addr || '-');
	push @params, ($Vend::SessionName || '-');
	push @params, ($CGI::user || '-');
	push @params, logtime() unless $Global::SysLog;

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
	$num =~ /^(-?)(\d*)(?:\.(\d+))?$/
		or return $num;
	my $sign = $1 || '';
	my $int = $2;
	@frac = split(m{}, ($3 || 0));
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
	return "$sign$int.$frac";
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
						en_GB => 1,
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
	my $len = $pic =~ /(#+)\Q$point/
		? length($1)
		: 0
	;
	$amount = sprintf('%.' . $len . 'f', $amount);
	$amount =~ tr/0-9//cd;
	my (@dig) = split m{}, $amount;
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
        my $curr = $Vend::Cfg->{Currency_repository}{$currency};

        for(@Vend::Config::Locale_directives_currency) {
            $Vend::Cfg->{$_} = $curr->{$_}
                if defined $curr->{$_};
        }

        for(@Vend::Config::Locale_keys_currency) {
            $Vend::Cfg->{Locale}{$_} = $curr->{$_}
                if defined $curr->{$_};
        }
    }

	if(my $ref = $Vend::Cfg->{CodeDef}{LocaleChange}) {
		$ref = $ref->{Routine};
		if($ref->{all}) {
			$ref->{all}->($locale, $opt);
		}
		if($ref->{lc $locale}) {
			$ref->{lc $locale}->($locale, $opt);
		}
	}

    if($opt->{persist}) {
		$::Scratch->{mv_locale}   = $locale		if $locale;
		delete $::Scratch->{mv_currency_tmp};
		delete $::Scratch->{mv_currency};
		$::Scratch->{mv_currency} = $currency if $currency;
	}
	elsif($currency) {
		Vend::Interpolate::set_tmp('mv_currency_tmp')
			unless defined $::Scratch->{mv_currency_tmp};
		$::Scratch->{mv_currency_tmp} = $currency;
	}
	else {
		delete $::Scratch->{mv_currency_tmp};
		delete $::Scratch->{mv_currency};
	}

    return '';
}


sub currency {
	my($amount, $noformat, $convert, $opt) = @_;
	$opt = {} unless $opt;
	$convert ||= $opt->{convert};

	my $pd = $Vend::Cfg->{PriceDivide};
	if($opt->{locale}) {
		$convert = 1 unless length($convert);
		$pd = $Vend::Cfg->{Locale_repository}{$opt->{locale}}{PriceDivide};
	}

	if($pd and $convert) {
		$amount = $amount / $pd;
	}

	my $hash;
	if(
		$noformat =~ /\w+=\w\w/
			and
		ref($hash = get_option_hash($noformat)) eq 'HASH'
	)
	{
		$opt->{display} ||= $hash->{display};
		$noformat = $opt->{noformat} = $hash->{noformat};
	}

	return $amount if $noformat;
	my $sep;
	my $dec;
	my $fmt;
	my $precede = '';
	my $succede = '';

	my $loc = $opt->{locale}
			|| $::Scratch->{mv_currency_tmp}
			|| $::Scratch->{mv_currency}
			|| $Vend::Cfg->{Locale};

	if(ref($loc)) {
		## Do nothing, is a hash reference
	}
	elsif($loc) {
		$loc = $Vend::Cfg->{Locale_repository}{$loc};
	}
	
	if (! $loc) {
		$fmt = "%.2f";
	}
	else {
		$sep = $loc->{mon_thousands_sep} || $loc->{thousands_sep} || ',';
		$dec = $loc->{mon_decimal_point} || $loc->{decimal_point} || '.';
		return picture_format($amount, $loc->{price_picture}, $sep, $dec)
			if defined $loc->{price_picture};
		if (defined $loc->{frac_digits}) {
			$fmt = "%." . $loc->{frac_digits} .  "f";
		} else {
			$fmt = "%.2f";
		}
		my $cs;
		my $display = lc($opt->{display}) || 'symbol';
		my $sep_by_space = $loc->{p_sep_by_space};
		my $cs_precedes = $loc->{p_cs_precedes};

		if( $loc->{int_currency_symbol} && $display eq 'text' ) {
			$cs = $loc->{int_currency_symbol};
			$cs_precedes = 1;

			if (length($cs) > 3 || $cs =~ /\W$/) {
				$sep_by_space = 0;
			}
			else {
				$sep_by_space = 1;
			}
		}
		elsif ( $display eq 'none' ) {
			$cs = '';
		}
		elsif ( $display eq 'symbol' ) {
			$cs = $loc->{currency_symbol} || '';
		}
		if($cs) {
			if ($cs_precedes) {
				$precede = $cs;
				$precede = "$precede " if $sep_by_space;
			}
			else {
				$succede = $cs;
				$succede = " $succede" if $sep_by_space;
			}
		}
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

##  This block defines &Vend::Util::sha1_hex and $Vend::Util::SHA1
use vars qw($SHA1);

BEGIN {

	$SHA1 = 1;
	  FINDSHA: {
		eval {
			require Digest::SHA;
			*sha1_hex = \&Digest::SHA::sha1_hex;
		};
		last FINDSHA if defined &sha1_hex;
		eval {
			require Digest::SHA1;
			*sha1_hex = \&Digest::SHA1::sha1_hex;
		};
		last FINDSHA if defined &sha1_hex;
		$SHA1 = 0;
		*sha1_hex = sub { ::logError("Unknown filter or key routine sha1, no SHA modules."); return $_[0] };
	  }
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
					@_ = time() unless @_;
					$Md->reset();
					if($Global::UTF8) {
						$Md->add(map encode_utf8($_), @_);
					}
					else {
						$Md->add(@_);
					}
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
    $s =~ s/%([0-9A-Fa-f][0-9A-Fa-f])/chr(hex($1))/ge;
    return $s;
}

*unescape_chars = \&unhexify;

sub unescape_full {
    my $url = shift;
    $url =~ tr/+/ /;
    $url =~ s/<!--.*?-->//sg;
    return unhexify($url);
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
	    $key =~ s/(['\\])/\\$1/g;
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

	if ($ENV{MINIVEND_STORABLE_CODE}) {
		# allow code references to be stored to the session
		 $Storable::Deparse = 1;
		 $Storable::Eval = 1;
	}

	$Fast_uneval     = \&Storable::freeze;
	$Fast_uneval_file  = \&Storable::store;
	$Eval_routine    = \&Storable::thaw;
	$Eval_routine_file = \&Storable::retrieve;
};

# See if Data::Dumper is installed with XSUB
# If it is, session writes will be about 25-30% faster
eval {
		die if $ENV{MINIVEND_NO_DUMPER};
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
        my $err = $@;

		if($::Limit->{logdata_error_length} > 0) {
			$msg = substr($msg, 0, $::Limit->{logdata_error_length});
		}

		logError ("Could not %s log file '%s': %s\nto log this data:\n%s",
				$err,
				$file,
				$!,
				$msg,
				);
		return 0;
    }
	1;
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
		$f =~ s:.*/::;
		$gate = Vend::Interpolate::interpolate_html($gate);
		if($gate =~ m!^$f(?:\.html?)?[ \t]*:!m ) {
			$gate =~ s!.*(\n|^)$f(?:\.html?)?[ \t]*:!!s;
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
	if($MVSAFE::Safe) {
		return eval $string;
	}
	my $safe = $Vend::Interpolate::safe_safe || new Vend::Safe;
	return $safe->reval($string);
}

sub is_hash {
	return ref($_[0]) eq 'HASH';
}

# Verify that passed string is a valid IPv4 address.
sub is_ipv4 {
    my $addr = shift or return;
    my @segs = split /\./, $addr, -1;
    return unless @segs == 4;
    foreach (@segs) {
		return unless /^\d{1,3}$/ && !/^0\d/;
		return unless $_ <= 255;
    }
    return 1;
}

# Verify that passed string is a valid IPv6 address.
sub is_ipv6 {
    my $tosplit = my $addr = shift or return;
    $tosplit =~ s/^:://;
    $tosplit =~ s/::$//;
    my @segs = split /:+/, $tosplit, -1;

    my $quads = 8;
    # Check for IPv4 style ending
    if (@segs && $segs[-1] =~ /\./) {
	return unless is_ipv4(pop @segs);
	$quads = 6;
    }

    # Check the special case of the :: abbreviation.
    if ($addr =~ /::/) {
	# Three :'s together is wrong, though.
	return if $addr =~ /:::/;
	# Also only one set of :: is allowed.
	return if $addr =~ /::.*::/;
	# Check that we don't have too many quads.
	return if @segs >= $quads;
    }
    else {
	# No :: abbreviation, so the number of quads must be exact.
	return unless @segs == $quads;
    }

    # Check the validity of each quad
    foreach (@segs) {
	return unless /^[0-9a-f]{1,4}$/i;
    }

    return 1;
}

sub dotted_hash {
	my($hash, $key, $value, $delete_empty) = @_;
	$hash = get_option_hash($hash) unless is_hash($hash);
	unless (is_hash($hash)) {
		return undef unless defined $value;
		$hash = {};
	}
	my @keys = split /[\.:]+/, $key;
	my $final;
	my $ref;

	if(! defined $value) {
		# Retrieving
		$ref = $hash->{shift @keys};
		for(@keys) {
			return undef unless is_hash($ref);
			$ref = $ref->{$_};
		}
		return $ref;
	}

	# Storing
	$final = pop @keys;
	$ref = $hash;

	for(@keys) {
		$ref->{$_} = {} unless is_hash($ref->{$_});
		$ref = $ref->{$_};
	}

	if($delete_empty and ! length($value)) {
		delete $ref->{$final};
	}
	else {
		$ref->{$final} = $value;
	}

	$hash = uneval_it($hash);
	return $hash;
}

sub get_option_hash {
	my $string = shift;
	my $merge = shift;
	if (ref $string eq 'HASH') {
		my $ref = { %$string };
		return $ref unless ref $merge;
		for(keys %{$merge}) {
			$ref->{$_} = $merge->{$_}
				unless defined $ref->{$_};
		}
		return $ref;
	}
	return {} unless $string and $string =~ /\S/;
	$string =~ s/^\s+//;
	$string =~ s/\s+$//;
	if($string =~ /^{/ and $string =~ /}/) {
		return string_to_ref($string);
	}

	my @opts;
	unless ($string =~ /,/) {
		@opts = grep $_ ne "=", Text::ParseWords::shellwords($string);
		for(@opts) {
			s/^(\w[-\w]*\w)=(["'])(.*)\2$/$1$3/;
		}
	}
	else {
		@opts = split /\s*,\s*/, $string;
	}

	my %hash;
	for(@opts) {
		my ($k, $v) = split /[\s=]+/, $_, 2;
		$k =~ s/-/_/g;
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

sub word2ary {
	my $val = shift;
	return $val if ref($val) eq 'ARRAY';
	my @ary = grep /\w/, split /[\s,\0]+/, $val;
	return \@ary;
}

sub ary2word {
	my $val = shift;
	return $val if ref($val) ne 'ARRAY';
	@$val = grep /\w/, @$val;
	return join " ", @$val;
}

## Takes an IC scalar form value (parm=val\nparm2=val) and translates it
## to a reference

sub scalar_to_hash {
	my $val = shift;

	$val =~ s/^\s+//mg;
	$val =~ s/\s+$//mg;
	my @args;

	@args = split /\n+/, $val;

	my $ref = {};

	for(@args) {
		m!([^=]+)=(.*)!
			and $ref->{$1} = $2;
	}
	return $ref;
}

## Takes a form reference (i.e. from \%CGI::values) and makes into a
## scalar value value (i.e. parm=val\nparm2=val). Also translates it
## via HTML entities -- it is designed to make it into a hidden
## form value

sub hash_to_scalar {
	my $ref = shift
		or return '';

	unless (ref($ref) eq 'HASH') {
		die __PACKAGE__ . " hash_to_scalar routine got bad reference.\n";
	}

	my @parms;
	while( my($k, $v) = each %$ref ) {
		$v =~ s/\r?\n/\r/g;
		push @parms, HTML::Entities::encode("$k=$v");
	}
	return join "\n", @parms;
}

## This simply returns a hash of words, which may be quoted shellwords
## Replaces most of parse_hash in Vend::Config
sub hash_string {
	my($settings, $ref) = @_;

	return $ref if ! $settings or $settings !~ /\S/;

	$ref ||= {};

	$settings =~ s/^\s+//;
	$settings =~ s/\s+$//;
	my(@setting) = Text::ParseWords::shellwords($settings);

	my $i;
	for ($i = 0; $i < @setting; $i += 2) {
		$ref->{$setting[$i]} = $setting[$i + 1];
	}
	return $ref;
}

## READIN

my $Lang;

sub find_locale_bit {
	my $text = shift;
	unless (defined $Lang) {
		$Lang = $::Scratch->{mv_locale} || $Vend::Cfg->{DefaultLocale};
	}
	$text =~ m{\[$Lang\](.*)\[/$Lang\]}s
		and return $1;
	$text =~ s{\[(\w+)\].*\[/\1\].*}{}s;
	return $text;
}

sub parse_locale {
	my ($input) = @_;

	return if $::Pragma->{no_locale_parse};

	# avoid copying big strings
	my $r = ref($input) ? $input : \$input;
	
	if($Vend::Cfg->{Locale}) {
		my $key;
		$$r =~ s~\[L(\s+([^\]]+))?\]((?s:.)*?)\[/L\]~
						$key = $2 || $3;		
						defined $Vend::Cfg->{Locale}{$key}
						?  ($Vend::Cfg->{Locale}{$key})	: $3 ~eg;
		$$r =~ s~\[LC\]((?s:.)*?)\[/LC\]~
						find_locale_bit($1) ~eg;
		undef $Lang;
	}
	else {
		$$r =~ s~\[L(?:\s+[^\]]+)?\]((?s:.)*?)\[/L\]~$1~g;
	}

	# return scalar string if one get passed initially
	return ref($input) ? $input : $$r;
}

sub teleport_name {
	my ($file, $teleport, $table) = @_;
	my $db;
	return $file
		unless	 $teleport
			and  $db = Vend::Data::database_exists_ref($table);

	my @f = qw/code base_code expiration_date show_date page_text/;
	my ($c, $bc, $ed, $sd, $pt) = @{$Vend::Cfg->{PageTableMap}}{@f};
	my $q = qq{
		SELECT $c from $table
		WHERE  $bc = '$file'
		AND    $ed <  $teleport
		AND    $sd >= $teleport
		ORDER BY $sd DESC
	};
	my $ary = $db->query($q);
	if($ary and $ary->[0]) {
		$file = $ary->[0][0];
	}
	return $file;
}

# Reads in a page from the page directory with the name FILE and ".html"
# appended. If the HTMLsuffix configuration has changed (because of setting in
# catalog.cfg or Locale definitions) it will substitute that. Returns the
# entire contents of the page, or undef if the file could not be read.
# Substitutes Locale bits as necessary.

sub readin {
    my($file, $only, $locale) = @_;

	## We don't want to try if we are forcing a flypage
	return undef if $Vend::ForceFlypage;

    my($fn, $contents, $gate, $pathdir, $dir, $level);
    local($/);

	if($file =~ m{[\[<]}) {
		::logGlobal("Possible code/SQL injection attempt with file name '%s'", $file);
		$file = escape_chars($file);
		::logGlobal("Suspect file changed to '%s'", $file);
	}

	$Global::Variable->{MV_PREV_PAGE} = $Global::Variable->{MV_PAGE}
		if defined $Global::Variable->{MV_PAGE};
	$Global::Variable->{MV_PAGE} = $file;

	$file =~ s#^\s+##;
	$file =~ s#\s+$##;
	$file =~ s#\.html?$##;
	if($file =~ m{\.\.} and $file =~ /\.\..*\.\./) {
		logError( "Too many .. in file path '%s' for security.", $file );
		$file = find_special_page('violation');
	}

	if(index($file, '/') < 0) {
		$pathdir = '';
	}
	else {
		$file =~ s#//+#/#g;
		$file =~ s#/+$##g;
		($pathdir = $file) =~ s#/[^/]*$##;
		$pathdir =~ s:^/+::;
	}

	my $try;
	my $suffix = $Vend::Cfg->{HTMLsuffix};
	my $db_tried;
	$locale = 1 unless defined $locale;
	my $record;
  FINDPAGE: {
  	## If PageTables is set, we try to find the page in the table first
	## but only once, without the suffix
  	if(! $db_tried++ and $Vend::Cfg->{PageTables}) {
		my $teleport = $Vend::Session->{teleport};
		my $field = $Vend::Cfg->{PageTableMap}{page_text};
		foreach my $t (@{$Vend::Cfg->{PageTables}}) {
			my $db = Vend::Data::database_exists_ref($t);
			next unless $db;

			if($teleport) {
				$file = teleport_name($file, $teleport, $t);
			}
			$record = $db->row_hash($file)
				or next;
			$contents = $record->{$field};
			last FINDPAGE if length $contents;
			undef $contents;
		}
	}

	my @dirs = ($Vend::Cfg->{PreviewDir},
				$Vend::Cfg->{PageDir},
				@{$Vend::Cfg->{TemplateDir} || []},
				@{$Global::TemplateDir || []});

	foreach $try (@dirs) {
		next unless $try;
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
			binmode(MVIN, ":utf8") if $::Variable->{MV_UTF8} || $Global::Variable->{MV_UTF8};
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

	return $contents unless wantarray;
	return ($contents, $record);
}

sub is_yes {
    return scalar( defined($_[0]) && ($_[0] =~ /^[yYtT1]/));
}

sub is_no {
	return scalar( !defined($_[0]) || ($_[0] =~ /^[nNfF0]/));
}

# Returns a URL which will run the ordering system again.  Each URL
# contains the session ID as well as a unique integer to avoid caching
# of pages by the browser.

my @scratches = qw/
				add_dot_html
				add_source
				link_relative
				match_security
				no_count
				no_session
				/;

sub vendUrl {
    my($path, $arguments, $r, $opt) = @_;

	$opt ||= {};

	if($opt->{auto_format}) {
		return $path if $path =~ m{^/};
		$path =~ s:#([^/.]+)$::
            and $opt->{anchor} = $1;
		$path =~ s/\.html?$//i
			and $opt->{add_dot_html} = 1;
	}

    $r = $Vend::Cfg->{VendURL}
		unless defined $r;

	my $secure;
	my @parms;

	my %skip = qw/form 1 href 1 reparse 1/;

	for(@scratches) {
		next if defined $opt->{$_};
		next unless defined $::Scratch->{"mv_$_"};
		$skip{$_} = 1;
		$opt->{$_} = $::Scratch->{"mv_$_"};
	}

	my $extra;
	if($opt->{form}) {
		$path ||= $Vend::Cfg->{ProcessPage} unless $opt->{no_default_process};
		if($opt->{form} eq 'auto') {
			my $form = '';
			while( my ($k, $v) = each %$opt) {
				next if $skip{$k};
				$k =~ s/^__//;
				$form .= "$k=$v\n";
			}
			$opt->{form} = $form;
		}
		push @parms, Vend::Interpolate::escape_form($opt->{form});
	}

	my($id, $ct);
	$id = $Vend::SessionID
		unless $opt->{no_session_id}
		or     ($Vend::Cookie and $::Scratch->{mv_no_session_id});
	$ct = ++$Vend::Session->{pageCount}
		unless $opt->{no_count};

	if($opt->{no_session} or $::Pragma->{url_no_session_id}) {
		undef $id;
		undef $ct;
	}

	if($opt->{link_relative}) {
		my $cur = $Global::Variable->{MV_PAGE};
		$cur =~ s{/[^/]+$}{}
			and $path = "$cur/$path";
	}

	if($opt->{match_security}) {
		$opt->{secure} = $CGI::secure;
	}

	my $asg = $Vend::Cfg->{AlwaysSecureGlob};
	if ($opt->{secure}
		or exists $Vend::Cfg->{AlwaysSecure}{$path}
		or ($asg and $path =~ $asg)
	) {
		$r = $Vend::Cfg->{SecureURL};
	}

	$path = escape_chars_url($path)
		if $path =~ $need_escape;
    	$r .= '/' . $path;
	$r .= '.html' if $opt->{add_dot_html} and $r !~ m{(?:/|\.html?)$};

	if($opt->{add_source} and $Vend::Session->{source}) {
		my $sn = hexify($Vend::Session->{source});
		push @parms, "$::VN->{mv_source}=$sn";
	}

	push @parms, "$::VN->{mv_session_id}=$id"		if $id;
	push @parms, "$::VN->{mv_arg}=" . hexify($arguments) 	if defined $arguments;
	push @parms, "$::VN->{mv_pc}=$ct"                 	if $ct;
	push @parms, "$::VN->{mv_cat}=$Vend::Cat"            	if $Vend::VirtualCat;

    	$r .= '?' . join($Global::UrlJoiner, @parms) if @parms;
	if($opt->{anchor}) {
		$opt->{anchor} =~ s/^#//;
		$r .= '#' . $opt->{anchor};
	}

	# return full-path portion of the URL
	if ($opt->{path_only}) {
		$r =~ s!^https?://[^/]*!!i;
	}
	return $r;
} 

sub secure_vendUrl {
	return vendUrl($_[0], $_[1], $Vend::Cfg->{SecureURL}, $_[3]);
}

my %strip_vars;
my $strip_init;

sub change_url {
	my $url = shift;
	return $url if $url =~ m{^\w+:};
	return $url if $url =~ m{^/};
	if(! $strip_init) {
		for(qw/mv_session_id mv_pc/) {
			$strip_vars{$_} = 1;
			$strip_vars{$::IV->{$_}} = 1;
		}
	}
	my $arg;
	my @args;
	($url, $arg) = split /[?&]/, $url, 2;
	@args = grep ! $strip_vars{$_}, split $Global::UrlSplittor, $arg;
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

	if($opt->{lines}) {
		return scalar(grep {! $attr or $sub->($_->{$attr})} @$cart);
	}

    $total = 0;
    foreach $item (@$cart) {
		next if $attr and ! $sub->($item->{$attr});

                if ($opt->{gift_cert} && $item->{$opt->{gift_cert}}) {
                    $total++;
                    next;
                }

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
	if(	$user eq $Vend::Cfg->{RemoteUser}	and
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
			logError("auth error host=%s ip=%s script=%s page=%s",
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
		logGlobal({ level => 'warning' },
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

	# Check to see if password enabled, then check
	if (
		$reconfig eq '1'		and
		!$CGI::user				and
		$Vend::Cfg->{Password}	and
		crypt($CGI::reconfigure_catalog, $Vend::Cfg->{Password})
		ne  $Vend::Cfg->{Password})
	{
		::logGlobal(
				{ level => 'warning' },
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
			{ level => 'warning' },
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
		::logGlobal(
				{ level => 'warning' },
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

	if(my $re = $Vend::Cfg->{DebugHost}) {
		return unless
			 Net::IP::Match::Regexp::match_ip($CGI::remote_addr, $re);
	}

	if(my $sub = $Vend::Cfg->{SpecialSub}{debug_qualify}) {
		return unless $sub->();
	}

	my $msg;

	if (my $tpl = $Global::DebugTemplate) {
		my %debug;
		$tpl = POSIX::strftime($tpl, localtime());
		$tpl =~ s/\s*$//;
		$debug{page} = $Global::Variable->{MV_PAGE};
		$debug{tag} = $Vend::CurrentTag;
		$debug{host} = $CGI::host || $CGI::remote_addr;
		$debug{remote_addr} = $CGI::remote_addr;
		$debug{request_method} = $CGI::request_method;
		$debug{request_uri} = $CGI::request_uri;
		$debug{catalog} = $Vend::Cat;
        if($tpl =~ /\{caller\d+\}/i) {
            my @caller = caller();
            for(my $i = 0; $i < @caller; $i++) {
                $debug{"caller$i"} = $caller[$i];
            }
        }
        $tpl =~ s/\{session\.([^}|]+)(.*?)\}/
                $debug{"session_\L$1"} = $Vend::Session->{$1};
                "{SESSION_\U$1$2}"
            /iegx;
		$debug{message} = errmsg(@_);

		$msg = Vend::Interpolate::tag_attr_list($tpl, \%debug, 1);
	}
	else {
		$msg = caller() . ":debug: " . errmsg(@_);
	}

	if ($Global::SysLog) {
		logGlobal({ level => 'debug' }, $msg);
	}
	else {
		print $msg, "\n";
	}

	return;
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

*l = \&errmsg;

sub show_times {
	my $message = shift || 'time mark';
	my @times = times();
	for( my $i = 0; $i < @times; $i++) {
		$times[$i] -= $Vend::Times[$i];
	}
	logDebug("$message: " . join " ", @times);
}

# This %syslog_constant_map is an attempt to work around a strange problem
# where the eval inside &Sys::Syslog::xlate fails, which then croaks.
# The cause of this freakish problem is still to be determined.

my %syslog_constant_map;

sub setup_syslog_constant_map {
	for (
		(map { "local$_" } (0..7)),
		qw(
			auth
			authpriv
			cron
			daemon
			ftp
			kern
			lpr
			mail
			news
			syslog
			user
			uucp

			emerg
			alert
			crit
			err
			warning
			notice
			info
			debug
		)
	) {
		$syslog_constant_map{$_} = Sys::Syslog::xlate($_);
	}
	return;
}

sub logGlobal {
	return 1 if $Vend::ExternalProgram;

	my $opt;
	my $msg = shift;
	if (ref $msg) {
		$opt = $msg;
		$msg = shift;
	}
	else {
		$opt = {};
	}

	$msg = errmsg($msg, @_) if @_;

	$Vend::Errors .= $msg . "\n" if $Global::DisplayErrors;

	my $nl = $opt->{strip} ? '' : "\n";
	print "$msg$nl"
		if $Global::Foreground
			and ! $Vend::Log_suppress
			and ! $Vend::Quiet
			and ! $Global::SysLog;

	my ($fn, $facility, $level);
	if ($Global::SysLog) {
		$facility = $Global::SysLog->{facility} || 'local3';
		$level    = $opt->{level} || 'info';

		# remap deprecated synonyms supported by logger(1)
		my %level_map = (
			error => 'err',
			panic => 'emerg',
			warn  => 'warning',
		);

		# remap levels according to any user-defined global configuration
		my $level_cfg;
		if ($level_cfg = $Global::SysLog->{$level_map{$level} || $level}) {
			if ($level_cfg =~ /(.+)\.(.+)/) {
				($facility, $level) = ($1, $2);
			}
			else {
				$level = $level_cfg;
			}
		}
		$level = $level_map{$level} if $level_map{$level};

		my $tag = $Global::SysLog->{tag} || 'interchange';

		my $socket = $opt->{socket} || $Global::SysLog->{socket};

		if ($Global::SysLog->{internal}) {
			unless ($Vend::SysLogReady) {
				eval {
					use Sys::Syslog ();
					if ($socket) {
						my ($socket_path, $types) = ($socket =~ /^(\S+)(?:\s+(.*))?/);
						$types ||= 'native,tcp,udp,unix,pipe,stream,console';
						my $type_array = [ grep /\S/, split /[,\s]+/, $types ];
						Sys::Syslog::setlogsock($type_array, $socket_path) or die "Error calling setlogsock\n";
					}
					Sys::Syslog::openlog $tag, 'ndelay,pid', $facility;
				};
				if ($@) {
					print "\nError opening syslog: $@\n";
					print "to report this error:\n", $msg;
					exit 1;
				}
				setup_syslog_constant_map() unless %syslog_constant_map;
				$Vend::SysLogReady = 1;
			}
		}
		else {
			$fn = '|' . ($Global::SysLog->{command} || 'logger');
			$fn .= " -p $facility.$level";
			$fn .= " -t $tag" unless lc($tag) eq 'none';
			$fn .= " -u $socket" if $socket;
		}
	}
	else {
		$fn = $Global::ErrorFile;
	}

	if ($fn) {
		my $lock;
		if ($fn =~ s/^([^|>])/>>$1/) {
			$lock = 1;
			$msg = format_log_msg($msg);
		}

		eval {
			# We have checked for beginning > or | previously
			open(MVERROR, $fn) or die "open\n";
			if ($lock) {
				lockfile(\*MVERROR, 1, 1) or die "lock\n";
				seek(MVERROR, 0, 2) or die "seek\n";
			}
			print(MVERROR $msg, "\n") or die "write to\n";
			if ($lock) {
				unlockfile(\*MVERROR) or die "unlock\n";
			}
			close(MVERROR) or die "close\n";
		};
		if ($@) {
			chomp $@;
			print "\nCould not $@ error file '$Global::ErrorFile':\n$!\n";
			print "to report this error:\n", $msg, "\n";
			exit 1;
		}

	}
	elsif ($Vend::SysLogReady) {
		eval {
			# avoid eval in Sys::Syslog::xlate() by using cached constants where possible
			my $level_mapped = $syslog_constant_map{$level};
			$level_mapped = $level unless defined $level_mapped;
			my $facility_mapped = $syslog_constant_map{$facility};
			$facility_mapped = $facility unless defined $facility_mapped;
			my $priority = "$level_mapped|$facility_mapped";
			Sys::Syslog::syslog $priority, $msg;
		};
	}

	return 1;
}

sub logError {
	return unless $Vend::Cfg;

	my $msg = shift;
	my $opt;
	if (ref $_[0]) {
		$opt = shift;
	}
	else {
		$opt = {};
	}

	unless ($Global::SysLog) {
		if (! $opt->{file}) {
			my $tag = $opt->{tag} || $msg;
			if (my $dest = $Vend::Cfg->{ErrorDestination}{$tag}) {
				$opt->{file} = $dest;
			}
		}
		$opt->{file} ||= $Vend::Cfg->{ErrorFile};
	}

	$msg = errmsg($msg, @_) if @_;

	print "$msg\n"
		if $Global::Foreground
			and ! $Vend::Log_suppress
			and ! $Vend::Quiet
			and ! $Global::SysLog;

	$Vend::Session->{last_error} = $msg;

	$msg = format_log_msg($msg) unless $msg =~ s/^\\//;

	if ($Global::SysLog) {
		logGlobal({ level => 'err' }, $msg);
		return;
	}

	$Vend::Errors .= $msg . "\n"
		if $Vend::Cfg->{DisplayErrors} || $Global::DisplayErrors;

    my $reason;
    if (! allowed_file($opt->{file}, 1)) {
        $@ = 'access';
        $reason = 'prohibited by global configuration';
    }
    else {
        eval {
            open(MVERROR, '>>', $opt->{file})
                                        or die "open\n";
            lockfile(\*MVERROR, 1, 1)   or die "lock\n";
            seek(MVERROR, 0, 2)         or die "seek\n";
            print(MVERROR $msg, "\n")   or die "write to\n";
            unlockfile(\*MVERROR)       or die "unlock\n";
            close(MVERROR)              or die "close\n";
        };
    }
    if ($@) {
		chomp $@;
		logGlobal ({ level => 'info' },
					"Could not %s error file %s: %s\nto report this error: %s",
					$@,
					$opt->{file},
					$reason || $!,
					$msg,
				);
		}

	return;
}

# Front-end to log routines that ignores repeated identical
# log messages after the first occurrence
my %logOnce_cache;
my %log_sub_map = (
	data	=> \&logData,
	debug	=> \&logDebug,
	error	=> \&logError,
	global	=> \&logGlobal,
);

# First argument should be log type (see above map).
# Rest of arguments are same as if calling log routine directly.
sub logOnce {
	my $tag = join "", @_;
	return if exists $logOnce_cache{$tag};
	my $log_sub = $log_sub_map{ lc(shift) } || $log_sub_map{error};
	my $status = $log_sub->(@_);
	$logOnce_cache{$tag} = 1;
	return $status;
}


# Here for convenience in calls
sub set_cookie {
    my ($name, $value, $expire, $domain, $path, $secure) = @_;

    # Set expire to now + some time if expire string is something like
    # "30 days" or "7 weeks" or even "60 minutes"
	if($expire =~ /^\s*\d+[\s\0]*[A-Za-z]\S*\s*$/) {
	    $expire = adjust_time($expire);
	}

	if (! $::Instance->{Cookies}) {
		$::Instance->{Cookies} = []
	}
	else {
		@{$::Instance->{Cookies}} =
			grep $_->[0] ne $name, @{$::Instance->{Cookies}};
	}
    push @{$::Instance->{Cookies}}, [$name, $value, $expire, $domain, $path, $secure];
    return;
}

# Here for convenience in calls
sub read_cookie {
	my ($lookfor, $string) = @_;
	$string = $CGI::cookie
		unless defined $string;
    return cookies_hash($string) unless defined $lookfor && length($lookfor);
    return undef unless $string =~ /(?:^|;)\s*\Q$lookfor\E=([^\s;]+)/i;
 	return unescape_chars($1);
}

sub cookies_hash {
    my $string = shift || $CGI::cookie;
    my %cookies = map {
        my ($k,$v) = split '=', $_, 2;
        $k => unescape_chars($v)
    } split(/;\s*/, $string);
    return \%cookies;
}

sub send_mail {
	my($to, $subject, $body, $reply, $use_mime, @extra_headers) = @_;

	if(ref $to) {
		my $head = $to;

		for(my $i = $#$head; $i > 0; $i--) {
			if($head->[$i] =~ /^\s/) {
				my $new = splice @$head, $i, 1;
				$head->[$i - 1] .= "\n$new";
			}
		}

		$body = $subject;
		undef $subject;
		for(@$head) {
			s/\s+$//;
			if (/^To:\s*(.+)/si) {
				$to = $1;
			}
			elsif (/^Reply-to:\s*(.+)/si) {
				$reply = $1;
			}
			elsif (/^subj(?:ect)?:\s*(.+)/si) {
				$subject = $1;
			}
			elsif($_) {
				push @extra_headers, $_;
			}
		}
	}

	# If configured, intercept all outgoing email and re-route
	if (
		my $intercept = $::Variable->{MV_EMAIL_INTERCEPT}
		                || $Global::Variable->{MV_EMAIL_INTERCEPT}
	) {
		my @info_headers;
		$to = "To: $to";
		for ($to, @extra_headers) {
			next unless my ($header, $value) = /^(To|Cc|Bcc):\s*(.+)/si;
			logError(
				"Intercepting outgoing email (%s: %s) and instead sending to '%s'",
				$header, $value, $intercept
			);
			$_ = "$header: $intercept";
			push @info_headers, "X-Intercepted-$header: $value";
		}
		$to =~ s/^To: //;
		push @extra_headers, @info_headers;
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
		my $helo =  $Global::Variable->{MV_HELO} || $::Variable->{SERVER_NAME};
		last SMTP unless $none and $mhost;
		eval {
			require Net::SMTP;
		};
		last SMTP if $@;
		$ok = 0;
		$using = "Net::SMTP (mail server $mhost)";
#::logDebug("using $using");
		undef $none;

		my $smtp = Net::SMTP->new($mhost, Debug => $Global::Variable->{DEBUG}, Hello => $helo) or last SMTP;
#::logDebug("smtp object $smtp");

		my $from = $::Variable->{MV_MAILFROM}
				|| $Global::Variable->{MV_MAILFROM}
				|| $Vend::Cfg->{MailOrderTo};
		
		for(@extra_headers) {
			s/\s*$/\n/;
			next unless /^From:\s*(\S.+)$/mi;
			$from = $1;
		}
		push @extra_headers, "From: $from" unless (grep /^From:\s/i, @extra_headers);
		push @extra_headers, 'Date: ' . POSIX::strftime('%a, %d %b %Y %H:%M:%S %Z', localtime(time())) unless (grep /^Date:\s/i, @extra_headers);

		my $mime = '';
		$mime = Vend::Interpolate::mime('header', {}, '') if $use_mime;
		$smtp->mail($from)
			or last SMTP;
#::logDebug("smtp accepted from=$from");

		my @to;
		my @addr = split /\s*,\s*/, $to;
		for(@extra_headers) {
			s/\s*$/\n/;
			next unless /^(Cc|Bcc):\s*(\S.+)$/mi;
#::logDebug("smtp adding receipients for $1=$2");
			push @addr, split(/\s*,\s*/, $2);
		}
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

sub codedef_routine {
	my ($tag, $routine, $modifier) = @_;

	my $area = $Vend::Config::tagCanon{lc $tag}
		or do {
			logError("Unknown CodeDef type %s", $tag);
			return undef;
		};

	$routine =~ s/-/_/g;
	my @tries;
	if ($tag eq 'UserTag') {
		@tries = ($Vend::Cfg->{UserTag}, $Global::UserTag);
		}
	else {
		@tries = ($Vend::Cfg->{CodeDef}{$area}, $Global::CodeDef->{$area});
	}

	no strict 'refs';

	my $ref;

	for my $base (@tries) {
		next unless $base;
	    $ref = $base->{Routine}{$routine}
			 and return $ref;
		$ref = $base->{MapRoutine}{$routine}
		   and return \&{"$ref"};
	}

	return undef unless $Global::AccumulateCode;
#::logDebug("trying code_from file for area=$area routine=$routine");
	$ref = Vend::Config::code_from_file($area, $routine)
		or return undef;
#::logDebug("returning ref=$ref for area=$area routine=$routine");
	return $ref;
}

sub codedef_options {
	my ($tag, $modifier) = @_;

	my @out;
	my $empty;

	my @keys = keys %{$Vend::Cfg->{CodeDef}};
	push @keys, keys %{$Global::CodeDef};

	my %gate = ( public => 1 );

	my @mod = grep /\w/, split /[\s\0,]+/, $modifier;
	for(@mod) {
		if($_ eq 'all') {
			$gate{private} = 1;
		}

		if($_ eq 'empty') {
			$empty = ['', errmsg('--select--')];
		}

		if($_ eq 'admin') {
			$gate{admin} = 1;
		}
	}

	for(@keys) {
		if(lc($tag) eq lc($_)) {
			$tag = $_;
			last;
		}
	}

	my %seen;

	for my $repos ( $Vend::Cfg->{CodeDef}{$tag}, $Global::CodeDef->{$tag} ) {
		if(my $desc = $repos->{Description}) {
			my $vis = $repos->{Visibility} || {};
			my $help = $repos->{Help} || {};
			while( my($k, $v) = each %$desc) {
				next if $seen{$k}++;
				if(my $perm = $vis->{$k}) {
					if($perm =~ /^with\s+([\w:]+)/) {
						my $mod = $1;
						no strict 'refs';
						next unless ${$mod . "::VERSION"};
					}
					else {
						next unless $gate{$perm};
					}
				}
				push @out, [$k, $v, $help->{$k}];
			}
		}
	}

	if(@out) {
		@out = sort { $a->[1] cmp $b->[1] } @out;
		unshift @out, $empty if $empty;
	}
	else {
		push @out, ['', errmsg('--none--') ];
	}
	return \@out;
}


# Adds a timestamp to the end of a binary timecard file. You can specify the timestamp
# as the second arg (unixtime) or just leave it out (or undefined) and it will be set
# to the current time.
sub timecard_stamp {
	my ($filename,$timestamp) = @_;
	$timestamp ||= time;

	open(FH, '>>', $filename) or die "Can't open $filename for append: $!";
	lockfile(\*FH, 1, 1);
	binmode FH;
	print FH pack('N',time);
	unlockfile(\*FH);
	close FH;
}


# Reads a timestamp from a binary timecard file.  If $index is negative indexes back from
# the end of the file, otherwise indexes from the front of the file so that 0 is the first
# (oldest) timestamp and -1 the last (most recent). Returns the timestamp or undefined if
# the file doesn't exist or the index falls outside of the bounds of the timecard file.
sub timecard_read {
	my ($filename,$index) = @_;
	$index *= 4;
	my $limit = $index >= 0 ? $index + 4 : $index * -1;

	if (-f $filename && (stat(_))[7] % 4) {
	    # The file is corrupt, delete it and start over.
	    ::logError("Counter file $filename found to be corrupt, deleting.");
	    unlink($filename);
	    return;
	}
	return unless (-f _ && (stat(_))[7] > $limit);

	# The file exists and is big enough to cover the $index. Seek to the $index
	# and return the timestamp from that position.

	open (FH, '<', $filename) or die "Can't open $filename for read: $!";
	lockfile(\*FH, 0, 1);
	binmode FH;
	seek(FH, $index, $index >= 0 ? 0 : 2) or die "Can't seek $filename to $index: $!";
	my $rtime;
	read(FH,$rtime,4) or die "Can't read from $filename: $!";
	unlockfile(\*FH);
	close FH;

	return unpack('N',$rtime);
}

#
# Adjusts a unix time stamp (2nd arg) by the amount specified in the first arg.  First arg should be
# a number (signed integer or float) followed by one of second(s), minute(s), hour(s), day(s)
# week(s) month(s) or year(s).  Second arg defaults to the current time.  If the third arg is true
# the time will be compensated for daylight savings time (so that an adjustment of 6 months will
# still cause the same time to be displayed, even if it is transgressing the DST boundary).
#
# This will accept multiple adjustments strung together, so you can do: "-5 days, 2 hours, 6 mins"
# and the time will have thost amounts subtracted from it.  You can also add and subtract in the
# same line, "+2 years -3 days".  If you specify a sign (+ or -) then that sign will remain in
# effect until a new sign is specified on the line (so you can do,
# "+5 years, 6 months, 3 days, -4 hours, 7 minutes").  The comma (,) between adjustments is
# optional.
#
sub adjust_time {
    # We need special adjustments to take into account end of month or leap year
    # issues in adjusting the month or year.  This sub will adjust the time
    # passed in $time as well as kick back a unixtime of the adjusted time.
    my $perform_adjust = sub {
	my ($time, $adjust) = @_;
	# Do an adjustment based on year and month first to check for issues
	# with leap year and end of month variances.  We set isdst to -1 to
	# avoid variances due to DST time change.
	my @timecheck = @$time;
	$timecheck[5] += $adjust->[5];
	$timecheck[4] += $adjust->[4];
	$timecheck[8] = -1;
	my @adjusted = localtime(POSIX::mktime(@timecheck));
	# If the day is off we need to add an additional adjustment for it.
	$adjust->[3] -= $adjusted[3] if $adjusted[3] < $timecheck[3];
	$time->[$_] += $adjust->[$_] for (0..5);
	my $unixtime = POSIX::mktime(@$time);
	@$time = localtime($unixtime);
	return $unixtime;
    };

    my ($adjust, $time, $compensate_dst) = @_;
    $time ||= time;

    unless ($adjust =~ /^(?:\s*[+-]?\s*[\d\.]+\s*[a-z]*\s*,?)+$/i) {
	::logError("adjust_time(): bad format: $adjust");
	return $time;
    }

    # @times: 0: sec, 1: min, 2: hour, 3: day, 4: month, 5: year, 8: isdst
    # 6,7: dow and doy, but mktime ignores these (and so do we).

    # A note about isdst: localtime returns 1 if returned time is adjusted for dst and 0 otherwise.
    # mktime expects the same, but if this is set to -1 mktime will determine if the date should be
    # dst adjusted according to dst rules for the current timezone.  The way that we use this is we
    # leave it set to the return value from locatime and we end up with a time that is adjusted by
    # an absolute amount (so if you adjust by six months the actual time returned may be different
    # but only because of DST).  If we want mktime to compensate for dst then we set this to -1 and
    # mktime will make the appropriate adjustment for us (either add one hour or subtract one hour
    # or leave the time the same).

    my @times = localtime($time);
    my @adjust = (0)x6;
    my $sign = 1;

    foreach my $amount ($adjust =~ /([+-]?\s*[\d\.]+\s*[a-z]*)/ig) {
	my $unit = 'seconds';
	$amount =~ s/\s+//g;

	if ($amount =~ s/^([+-])//)   { $sign = $1 eq '+' ? 1 : -1 }
	if ($amount =~ s/([a-z]+)$//) { $unit = lc $1 }
	$amount *= $sign;

	# A week is simply 7 days.
	if ($unit =~ /^w/) {
	    $unit = 'days';
	    $amount *= 7;
	}

	if ($unit =~ /^s/) { $adjust[0] += $amount }
	elsif ($unit =~ /^mo/) { $adjust[4] += $amount } # has to come before min
	elsif ($unit =~ /^m/) { $adjust[1] += $amount }
	elsif ($unit =~ /^h/) { $adjust[2] += $amount }
	elsif ($unit =~ /^d/) { $adjust[3] += $amount }
	elsif ($unit =~ /^y/) { $adjust[5] += $amount }

	else {
	    ::logError("adjust_time(): bad unit: $unit");
	    return $time;
	}
    }

    if ($compensate_dst) { $times[8] = -1 }

    # mktime can only handle integers, so we need to convert real numbers:
    my @multip = (0, 60, 60, 24, 0, 12);
    my $monfrac = 0;
    foreach my $i (reverse 0..5) {
	if ($adjust[$i] =~ /\./) {
	    if ($multip[$i]) {
		$adjust[$i-1] += ($adjust[$i] - int $adjust[$i]) * $multip[$i];
	    }

	    elsif ($i == 4) {
		# Fractions of a month need some really extra special handling.
		$monfrac = $adjust[$i] - int $adjust[$i];
	    }

	    $adjust[$i] = int $adjust[$i];
	}
    }

    $time = $perform_adjust->(\@times, \@adjust);

    # This is how we handle a fraction of a month:
    if ($monfrac) {
	@adjust = (0)x6;
	$adjust[4] = $monfrac > 0 ? 1 : -1;
	my $timediff = $perform_adjust->(\@times, \@adjust);
	$timediff = int(abs($timediff - $time) * $monfrac);
	$time += $timediff;
    }

    return $time;
}

sub backtrace {
    my $msg = "Backtrace:\n\n";
    my $frame = 1;

    my $assertfile = '';
    my $assertline = 0;

    while (my ($package, $filename, $line, $subroutine, $hasargs, $wantarray, $evaltext, $is_require) = caller($frame++) ) {
	$msg .= sprintf("   frame %d: $subroutine ($filename line $line)\n", $frame - 2);
	if ($subroutine =~ /assert$/) {
	    $assertfile = $filename;
	    $assertline = $line;
	}
    }
    if ($assertfile) {
	open(SRC, $assertfile) and do {
	    my $line;
	    my $line_n = 0;

	    $msg .= "\nProblem in $assertfile line $assertline:\n\n";

	    while ($line = <SRC>) {
		$line_n++;
		$msg .= "$line_n\t$line" if (abs($assertline - $line_n) <= 10);
	    }
	    close(SRC);
	};
    }

    ::logGlobal($msg);
    undef;
}

sub header_data_scrub {
	my ($head_data) = @_;

	## "HTTP Response Splitting" Exploit Fix
	## http://www.securiteam.com/securityreviews/5WP0E2KFGK.html
	$head_data =~ s/(?:%0[da]|[\r\n]+)+//ig;

	return $head_data;
}

### Provide stubs for former Vend::Util functions relocated to Vend::File
*canonpath = \&Vend::File::canonpath;
*catdir = \&Vend::File::catdir;
*catfile = \&Vend::File::catfile;
*exists_filename = \&Vend::File::exists_filename;
*file_modification_time = \&Vend::File::file_modification_time;
*file_name_is_absolute = \&Vend::File::file_name_is_absolute;
*get_filename = \&Vend::File::get_filename;
*lockfile = \&Vend::File::lockfile;
*path = \&Vend::File::path;
*readfile = \&Vend::File::readfile;
*readfile_db = \&Vend::File::readfile_db;
*set_lock_type = \&Vend::File::set_lock_type;
*unlockfile = \&Vend::File::unlockfile;
*writefile = \&Vend::File::writefile;

1;
__END__
