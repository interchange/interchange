#!/usr/bin/perl

# Copyright (C) 1998 Michael J. Heins <mikeh@minivend.com>

# Author: Michael J. Heins <mikeh@minivend.com>
# Maintainer: Stefan Hornburg <racke@linuxia.de>

# This file is free software; you can redistribute it and/or modify it
# under the terms of the GNU General Public License as published by the
# Free Software Foundation; either version 2, or (at your option) any
# later version.

# This file is distributed in the hope that it will be
# useful, but WITHOUT ANY WARRANTY; without even the implied warranty
# of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# General Public License for more details.

# You should have received a copy of the GNU General Public License
# along with this file; see the file COPYING.  If not, write to the Free
# Software Foundation, 675 Mass Ave, Cambridge, MA 02139, USA.

my($order, $label, %terms) = @_;

package MiniMate::CfgMgr;

$VERSION = substr(q$Revision: 1.1 $, 10);
$DEBUG = 0;

use vars qw!
	@EXPORT @EXPORT_OK
	$VERSION $DEBUG
	$DECODE_CHARS
	*hash_value *array_value
	*boolean_value *page_value
	!;

use Carp;
use File::Find;
use File::CounterFile;
use Exporter;
use strict;
use Vend::Util qw/errmsg/;
$DECODE_CHARS = qq{&[<"\000-\037\177-\377};

@EXPORT = qw( combo_select mm_check_acl mm_acl_enabled ) ;

=head1 NAME

CfgMgr.pm -- MiniMate Configuration Manager

=head1 SYNOPSIS

display_directive %options;

=head1 DESCRIPTION

The MiniMate Configuration Manager is a proprietary interface to configure
various configuration file parameters.

=cut

use vars qw($Directive_prefix $Configfile $Writing);
$Directive_prefix = 'mvc_value';
$Writing = 0;
$Configfile = 'catalog.cfg';
my $Counterfile = ".$Configfile.serial";
$Counterfile =~ tr/./_/ if $^O =~ /win32/i;
my $mm_safe = new Safe;
$mm_safe->untrap(@{$Global::SafeUntrap});

my @Out;
my @Mark;

my %Cfg = (

    actionmap       => { Complex => 1 },
    admindatabase   => { },
    adminpage       => { },
    alwayssecure    => { },
    asciibackend    => { },
    asciitrack      => { },
    autoload        => { },
    backendorder    => { },
    buttonbars      => { 'Unparse' => 'page', 'Source' => 1 },
    checkoutframe   => { },
    checkoutpage    => { 'Default' => 'basket', },
    clearcache      => { },
    collectdata     => { },
    commonadjust    => { },
    configdatabase  => { },
    configdir       => { },
    cookiedomain    => { },
    cookies         => { },
    creditcardauto  => { },
    customshipping  => { 'Unparse' => 'yesno' },
    cybercash       => { },
    database        => { },
    datadir         => { },
    dbdatabase      => { },
    debugmode       => { },
    defaultshipping => { },
    descriptionfield => { },
    displayerrors   => { },
    dynamicdata     => { },
    encryptprogram  => { },
    errorfile       => { },
    extrasecure     => { },
    fallbackip      => { },
    fielddelimiter  => { },
    finishorder     => { },
    formignore      => { },
    fractionalitems => { },
    frameflypage    => { },
    framelinkdir    => { },
    frameorderpage  => { },
    framesdefault   => { },
    framesearchpage => { },
    glimpse         => { },
    groupfile       => { },
    help            => { },
    imagealias      => { },
    imagedir        => { },
    imagedirinternal => { },
    imagedirsecure	=> { },
    itemlinkdir     => { },
    itemlinkvalue   => { },
    localedatabase  => { },
    logfile         => { },
    mailorderto     => { },
    masterhost      => { },
    mixmatch        => { },
    msqldb          => { },
    mv_alinkcolor   => { },
    mv_background   => { },
    mv_bgcolor      => { },
    mv_linkcolor    => { },
    mv_textcolor    => { },
    mv_vlinkcolor   => { },
    newescape       => { },
    newreport       => { },
    newtags         => { },
    nocache         => { Unparse => 'page', },
    noimport        => { },
    nontaxablefield => { },
    offlinedir      => { },
    oldshipping     => { },
    ordercounter    => { Default => 'etc/order.number', },
    orderframe      => { },
    orderlinelimit  => { Size => 4, },
    orderprofile    => { 'Source' => 1 },
    orderreport     => { },
    pagecache       => { },
    pagedir         => { },
    pageselectfield => { },
    parsevariables  => { },
    password        => { },
    passwordfile    => { },
    pgp             => { },
    priceadjustment => { },
    pricebreaks     => { },
    pricecommas     => { },
    pricedatabase   => { },
    pricedivide     => { },
    pricefield      => { },
    productdir      => { },
    productfiles    => { },
    random          => { 'Unparse' => 'page', 'Source' => 1 },
    receiptpage     => { },
    recorddelimiter => { },
    remoteuser      => { },
    replace         => { },
    reportignore    => { },
    requiredfields  => { },
    robotlimit      => { Size => 4, },
    rotate          => { 'Unparse' => 'page', 'Source' => 1 },
    salestax        => { },
    saveexpire      => { },
    scratchdir      => { 'Default' => 'tmp' },
    searchcache     => { },
    searchframe     => { },
    searchovermsg   => { },
    searchprofile   => { 'Source' => 1 },
    secureordermsg  => { },
    secureurl       => { },
    sendmailprogram => { },
    separateitems   => { },
    sessiondatabase => { },
    sessiondb       => { },
    sessionexpire   => { Source => 1 },
    sessionlockfile => { },
    setgroup        => { },
    shipping        => { },
    specialpage     => { Complex => 1 },
    static          => { },
    staticall       => { },
    staticdepth     => { },
    staticdir       => { },
    staticfly       => { },
    staticpage      => { Unparse => 'page', },
    staticpath      => { },
    staticpattern   => { },
    staticsuffix    => { },
    subargs         => { },
    taxshipping     => { },
    transparentitem => { },
    upszonefile     => { },
    usecode         => { },
    usemodifier     => { },
    userdatabase    => { },
    variabledatabase  => { },
    vendurl         => { },
    wideopen        => { },

    delimiter => {
          'Default' => 'TAB',
          'Choices' => [
                         'TAB',
                         'PIPE',
                         'CSV'
                       ],
          'Unparse' => 'choice'
        },

	readpermission	=> {
          'Choices' => [
                         'user',
                         'group',
                         'world'
                       ],
          'Unparse' => 'choice'
        },
	writepermission => {
          'Choices' => [
                         'user',
                         'group',
                         'world'
                       ],
          'Unparse' => 'choice',
        },
);

my %Display = (
	
	yesno		=> [\&yesno_box],
	boolean		=> [\&combo_select],
	array		=> [\&combo_select],
	hash		=> [\&combo_select],
	page		=> [\&combo_select, \&list_pages],
	variable	=> [\&variable_configure],
	choice		=> [\&select_box, 'Choices'],

);

# init region
CFGMGR_DEFAULTS: {
	my ($ary, $ref, $dir, $def, $parse, $cfg);
	$ary = Vend::Config::catalog_directives();
	foreach $ref (@$ary) {
		($dir,$parse,$def) = @$ref;
		$cfg = $Cfg{lc $dir} || undef;
		next unless defined $cfg;
		($cfg->{Name}, $cfg->{Parse}) = ($dir,$parse);
		next if defined $cfg->{Default};
		$cfg->{Default} = $def;
	}
}

sub mm_acl_enabled {
	my $table;
	my $default = defined $Global::Variable->{MINIMATE_ACL}
				 ? (! $Global::Variable->{MINIMATE_ACL})
				 : 1;
	$table = $::Variable->{MINIMATE_TABLE} || 'minimate';
	$Vend::WriteDatabase{$table} = 1;
	my $db = Vend::Data::database_exists_ref($table);
	return $default unless $db;
	$db = $db->ref() unless $Vend::Interpolate::Db{$table};
	my $uid = $Vend::Session->{username} || $CGI::remote_user;
	if(! $db->record_exists($uid) ) {
		return 0;
	}
	$Vend::Session->{mm_username} = $uid;
	my $ref = $db->row_hash($uid)
		or die "Bad database record for $uid.";
#::logDebug("ACL enabled, table_control=$ref->{table_control}");
	if($ref->{table_control}) {
		$ref->{table_control_ref} = $mm_safe->reval($ref->{table_control});
	}
	$Vend::Minimate_entry = $ref;
}

sub get_mm_table_acl {
	my ($table, $user, $keys) = @_;
	$table = $::Values->{mvc_data_table} unless $table;
#::logDebug("Call get_mm_table_acl: " . Vend::Util::uneval_it(\@_));
	my $acl_top;
	if($user and $user ne $Vend::Session->{mm_username}) {
		if ($Vend::Minimate_acl{$user}) {
			$acl_top = $Vend::Minimate_acl{$user};
		}
		else {
			my $mm_table = $::Variable->{MINIMATE_TABLE} || 'minimate';
			my $acl_txt = Vend::Interpolate::tag_data($mm_table, 'table_control', $user);
			return undef unless $acl_txt;
			$acl_top = $mm_safe->reval($acl_txt);
			return undef unless ref($acl_top);
		}
		$Vend::Minimate_acl{$user} = $acl_top;
		return keys %$acl_top if $keys;
		return $acl_top->{$table};
	}
	else {
		unless ($acl_top = $Vend::Minimate_entry) {
	#::logDebug("Call get_mm_table_acl: acl_top=" . ::uneval($acl_top));
			return undef unless ref($acl_top = mm_acl_enabled());
		}
	}
	return undef unless defined $acl_top->{table_control_ref};
	return $acl_top->{table_control_ref}{$table};
}

sub mm_acl_grep {
	my ($acl, $name, @entries) = @_;
#::logDebug("Call mm_acl_grep: " . ::uneval(\@_));
	my $val;
	my %ok;
	@ok{@entries} = @entries;
	if($val = $acl->{owner_field} and $name eq 'keys') {
		my $u = $Vend::Session->{mm_username};
		my $t = $acl->{table}
			or do{
				::logError("no table name with owner_field.");
				return undef;
			};
			for(@entries) {

				my $v = ::tag_data($t, $val, $_);
#::logDebug("mm_acl_grep owner: t=$t f=$val k=$_ v=$v u=$u");
				$ok{$_} = $v eq $u;
			}
	}
	else {
		if($val = $acl->{"no_$name"}) {
			for(@entries) {
				$ok{$_} = ! mm_check_acl($_, $val);
			}
		}
		if($val = $acl->{"yes_$name"}) {
			for(@entries) {
				$ok{$_} &&= mm_check_acl($_, $val);
			}
		}
	}
	return (grep $ok{$_}, @entries);
}

sub mm_acl_atom {
	my ($acl, $name, $entry) = @_;
	my $val;
	my $status = 1;
	if($val = $acl->{"no_$name"}) {
		$status = ! mm_check_acl($entry, $val);
	}
	if($val = $acl->{"yes_$name"}) {
		$status &&= mm_check_acl($entry, $val);
	}
	return $status;
}

sub mm_check_acl {
	my ($item, $string) = @_;
	$string = " $string ";
	return 0 if $string =~ /[\s,]!$item[,\s]/;
	return 1 if $string =~ /[\s,]$item[,\s]/;
	return '';
}

sub mm_acl_global {
	my $record = mm_acl_enabled('write');
	# First we see if we have ACL enforcement enabled
	# If you don't, then people can do anything!
	unless (ref $record) {
		$::Scratch->{mv_data_enable} = $record;
		return;
	}
	my $CGI = \%CGI::values;
	my $Tag = new Vend::Tags;
	$CGI->{mv_todo} = $CGI->{mv_doit}
		if ! $CGI->{mv_todo};
    if( $CGI->{mv_todo} eq 'set' ) {
		undef $::Scratch->{mv_data_enable};
		my $mml_enable = $Tag->if_mm('functions', 'mml');
		my $html_enable = ! $Tag->if_mm('functions', 'no_html');
		my $target = $CGI->{mv_data_table};
		$Vend::WriteDatabase{$target} = 1;
		my $keyname = $CGI->{mv_data_key};
		my @codes = grep /\S/, split /\0/, $CGI->{$keyname};
		my @fields = grep /\S/, split /[,\s\0]+/, $CGI->{mv_data_fields};
		if ($Tag->if_mm('!edit', undef, { table => $target }, 1) ) {
			$::Scratch->{mm_failure} = "Unauthorized to edit table $target";
			$CGI->{mv_todo} = 'return';
			return;
		}
		for(@codes) {
			next if $Tag->if_mm('keys', $_, { table => $target }, 1);
			$CGI->{mv_todo} = 'return';
			$::Scratch->{mm_failure} = errmsg("Unauthorized for key %s", $_);
 			return;
  		}
		for(@fields) {
			$CGI->{$_} =~ s/\[/&#91;/g unless $mml_enable;
			$CGI->{$_} =~ s/\</&lt;/g unless $html_enable;
			next if $Tag->if_mm('columns', $_, { table => $target }, 1);
			$CGI->{mv_todo} = 'return';
			$::Scratch->{mm_failure} = errmsg("Unauthorized for key %s", $_);
 			return;
  		}
 		$::Scratch->{mv_data_enable} = 1;
	}
    return;

}

sub yesno_box {
	my($name, $value) = @_;
	$name = lc $name;
	return undef unless defined $Cfg{$name};

	$value = read_directive($name) unless $value;

	my $dir = $Cfg{$name}->{Name};

	my $out = qq{<TABLE BORDER=2>};
	$out .= qq{<TR><TD VALIGN=TOP WIDTH=100>$dir</TD>};
	$out .= qq{</TD><TD VALIGN=TOP>};
	$out .= qq{<SELECT NAME="$Directive_prefix">};
	$out .= '<OPTION> Yes';
	$out .= '<OPTION';
	$out .= ' SELECTED' unless $value =~ /^[YyTt1]/;
	$out .= '> No';
	$out .= '</SELECT>';
	$out .= qq{</TD></TR></TABLE>};
}

sub yesno_value {
	my($value) = @_;
	return ($value =~ /^\s*[YyTt1]/) ? 'Yes' : 'No';
}

use Text::ParseWords;

sub hash_value {
	my @in;
	my @out;
	for(@_) {
		push @in, split /\0/, $_;
	}
	for(@in) {
		s/^\s+//;
		s/\s+$//;
		push @out, Text::ParseWords::quotewords('\s+', 1, $_);
	}
	return join " ", @out;
}

*array_value   = \&hash_value;
*boolean_value = \&hash_value;
*page_value    = \&hash_value;

sub select_box {
	my($name, $value, $choices) = @_;
	$name = lc $name;
	return undef unless defined $Cfg{$name};

	$choices = [$value] unless $choices;

	$value = read_directive($name) unless $value;

	my $dir = $Cfg{$name}->{Name};

	my $out = qq{<TABLE BORDER=2>};
	$out .= qq{<TR><TD VALIGN=TOP WIDTH=100>$dir</TD>};
	$out .= qq{</TD><TD VALIGN=TOP>};
	$out .= qq{<SELECT NAME="$Directive_prefix">};
	for(@$choices) {
		$out .= "<OPTION";
		$out .= " SELECTED" if $value eq $_;
		$out .= "> $_";
	}
	$out .= '</SELECT>';
	$out .= qq{</TD></TR></TABLE>};
}

sub text_box {
	my($name, $value) = @_;
	$name = lc $name;
	return undef unless defined $Cfg{$name};

	$value = read_directive($name) unless $value;

	my $dir = $Cfg{$name}->{Name};
	my $size = $Cfg{$name}->{Size} || 60;

	HTML::Entities::encode($value, $DECODE_CHARS);
	my $out = qq{<TABLE BORDER=2>};
	$out .= qq{<TR><TD VALIGN=TOP WIDTH=100>$dir</TD>};
	$out .= qq{</TD><TD VALIGN=TOP>};
	if($value =~ /\n/) {
		my $rows = ($value =~ s/(\r?\n)/$1/g) + 1; 
		$out .= qq{<TEXTAREA NAME="$Directive_prefix" COLS="$size" ROWS="$rows">};
		$out .= $value;
		$out .= '</TEXTAREA>';
	} else {
		$out .= qq{<INPUT NAME="$Directive_prefix" SIZE="$size" VALUE="$value">};
	}
	$out .= qq{</TD></TR></TABLE>};
}

sub combo_select {
	my($name, $ary, $possible) = @_;

	unless($name) {
#		Vend::Util::logError("CfgMgr - bad call combo_select: no name");
		Vend::Util::logError( errmsg('CfgMgr.pm:1', "CfgMgr - bad call combo_select: no name" ) );
	}

	if(! $ary) {
		$ary = $Vend::Cfg->{$name};
	}

	if(! ref $ary) {
		my @vals;
		@vals =  split /[\s,]+/, $ary ;
		$ary = {};
		for(@vals) { $ary->{$_} = 1 }
	}
	elsif ($ary =~ /ARRAY/) {
		my $in = $ary;
		$ary = {};
		for(@$in) { $ary->{$_} = 1 }
	}

	unless($ary) {
#		Vend::Util::logError("CfgMgr - bad call combo_select: name=$name");
		Vend::Util::logError( errmsg('CfgMgr.pm:2', "CfgMgr - bad call combo_select: name=%s" , $name) );
	}

	if(! $possible ) {
		$possible = [ sort keys %$ary ];
	}
	elsif (! ref $possible ) {
		$possible =~ s/^[\s,]+//;
		$possible =~ s/[\s,]+$//;
		$possible = [ split /[\s,]+/, $possible ];
	}
	elsif ($possible =~ /HASH/) {
		$possible = [ sort keys %$possible ];
	}

	my $size = @$possible;
	$size = $size > 5 ? 5 : $size;

	my $out = qq{<TABLE BORDER=2>};
	$out   .= qq{<TR><TD VALIGN=TOP>Existing</TD>};
	$out   .= qq{<TD VALIGN=TOP>Set new value(s)</TD></TR>};
	$out   .= qq{<TR><TD VALIGN=TOP>};
	$out .= qq{<SELECT NAME="$Directive_prefix" MULTIPLE SIZE="$size">};
	for(@$possible) {
		$out .= '<OPTION';
		$out .= ' SELECTED' if $ary->{$_};
		$out .= qq{> $_\n};
	}
	$out .= "</SELECT>";
	$out   .= qq{</TD><TD VALIGN=TOP>};
	$out .= qq{&nbsp;&nbsp;};
	$out .= qq{<TEXTAREA NAME="mvc_value" COLS="40" ROWS="$size">};
	$out .= qq{</TEXTAREA>};
	$out   .= qq{</TD></TR></TABLE>};
}

sub option_list {
	return join "<OPTION> ", @_;
}

sub space_list {
	return join " ", @_;
}

sub list_images {
	my ($base) = @_;
	return undef unless -d $base;
	my $suf = '\.(GIF|gif|JPG|JPEG|jpg|jpeg|png|PNG)';
	my @names;
	my $wanted = sub {
					return undef unless -f $_;
					return undef unless /$suf$/o;
					my $n = $File::Find::name;
					$n =~ s:^$base/?::;
					push(@names, $n);
				};
	find($wanted, $base);
	return sort @names;
}

sub list_glob {
	my($spec, $prefix) = @_;
	my $globspec = $spec;
	if($prefix) {
		$globspec =~ s:^\s+::;
		$globspec =~ s:\s+$::;
		$globspec =~ s:^:$prefix:;
		$globspec =~ s:\s+: $prefix:g;
	}
	my @files = glob($globspec);
	if($prefix) {
		@files = map { s:^$prefix::; $_ } @files;
	}
	return @files;
}

sub list_pages {
	my ($keep, $suf, $base) = @_;
	$suf = $Vend::Cfg->{StaticSuffix} if ! $suf;
	$base = Vend::Util::catfile($Vend::Cfg->{VendRoot}, $base) if $base;
	$base = $Vend::Cfg->{PageDir} if ! $base;
	my @names;
	my $wanted = sub {
					if(-d $_ and $Vend::Cfg->{AdminPage}{$_}) {
						$File::Find::prune = 1;
						return;
					}
					return undef unless -f $_;
					return undef unless /$suf$/;
					my $n = $File::Find::name;
					$n =~ s:^$base/?::;
					$n =~ s/$suf$// unless $keep;
					push(@names, $n);
				};
	find($wanted, $base);
	return sort @names;
}

my %Break = (
				'variable'   => 1,
				'subroutine' => 1,

);

my %Format_routine;

sub format_line {
	my($directive, $value, @complex) = @_;

	my($line,$multi,$sub, $cfg);

	if($cfg = $Cfg{lc $directive}) {
		$directive = $cfg->{Name};
		$sub = $cfg->{Unparse} || $cfg->{Parse};
	}

	$sub = 'undef' unless $sub;

	if ($value =~ /[\r\n]/) {
		$value =~ s/\r\n/\n/g;
		$value =~ s/\r/\n/g;
		$multi = 1;
	}

	no strict 'refs';

	if(defined &{"${sub}_value"}) {
		$value = &{"${sub}_value"}($value);
	}

	if(!$value) {
		return undef unless $cfg;
		$value = $cfg->{Default} || return undef;
	}

	# Returns
	if(defined $Format_routine{$sub}) {
		$line = &{$Format_routine{$sub}}($directive, $value, @complex);
		return $line;
	}

	if (@complex) {
		my $joiner = $multi ? "\n" : ' ';
		$value = join $joiner, @complex, $value;
	}

	if ($multi) {
		$line = $directive;
		$line .= " <<_END_$directive\n";
		$line .= $value;
		$line .= "\n" unless $value =~ /\n$/;
		$line .= "_END_$directive\n";
	}
	else {
		$line = sprintf("%-19s %s\n", $directive, $value);
	}
	return $line;
}

sub read_directive {
	my($dir, $complex) = @_;

	my $file = $Configfile;
	if(-f "$file+") {
		$file .= '+';
	}
	open(MiniMate::CfgMgr::CONFIG, "+<$file")				or die "read $file: $!\n";
	Vend::Util::lockfile(\*MiniMate::CfgMgr::CONFIG, 1, 1) 	or die "lock $file: $!\n";

	my ($var, $value, $lvar);
	my $complete = '';
	my $parsed;

	my $C = {};
	Vend::Config::setcat($C);

	if($Writing) {
		undef @Out;
		undef @Mark;
	}

	my $orig_line;
	while (<MiniMate::CfgMgr::CONFIG>) {
		$orig_line = $_;
        s/^\s+//;       #  leading whitespace, bye-bye
		unless (/^$dir\s+/io) {
			if ($value =~ /^(.*)<<(.*)/) {                  # "here" value
				my $begin  = $1 || '';
				my $mark  = $2;
				my $startline = $.;
				$value = 
					Vend::Config::read_here(\*MiniMate::CfgMgr::CONFIG, $mark);
				unless (defined $value) {
					die (sprintf('%d: %s', $startline,
						qq#no end marker ("$mark") found#));
				}
				$orig_line .= $value . "\n$mark\n";
            }
			push (@Out, $orig_line) if $Writing;
			next;
		}
        chomp;          # zap trailing newline,
        s/\s+$//;       #  trailing spaces

        # lines read from the config file become untainted
        m/^(\w+)\s+(.*)/ or die("Syntax error, config line '$_'");
        $var = $1;
        $value = $2;
        $lvar = lc $var;
		$var = $Cfg{$lvar}->{Name};
        my($codere) = '[\w-_#/.]+';

        if ($value =~ /^(.*)<<(.*)/) {                  # "here" value
            my $begin  = $1 || '';
            my $mark  = $2;
            my $startline = $.;
            $value = $begin .
					Vend::Config::read_here(\*MiniMate::CfgMgr::CONFIG, $mark);
            unless (defined $value) {
                die (sprintf('%d: %s', $startline,
                    qq#no end marker ("$mark") found#));
            }
			$orig_line .= "$value\n$mark\n";  # may need to reconstruct
        }
        elsif ($value =~ /^(\S+)?(\s*)?<\s*($codere)$/o) {   # read from file
            #local($^W) = 0;
            $value = $1 || '';
            my $file = $3;
            $value .= "\n" if $value;
            $file = $var unless $file;
            $file = "$Vend::Cfg->{ConfigDir}/$file" unless $file =~ m!^/!;
            $file = Vend::Util::escape_chars($file);   # make safe for filename
            my $tmpval = Vend::Util::readfile($file);
            unless( defined $tmpval ) {
                die ("$var: read from non-existent file.");
            }
            chomp($tmpval) unless $tmpval =~ m!.\n.!;
            $value .= $tmpval;
        }

		# see if we have a multi-level
		if (defined $Cfg{$lvar}->{Complex}) {
			if($complex and $value =~ /\s*$complex\s+/) {
				push (@Mark, $#Out) if $Writing;
			}
			elsif ($complex) {
				push (@Out, $orig_line) if $Writing;
				next;
			}
		}
		else {
			push (@Mark, $#Out) if $Writing;
		}

		$complete .= "\n" if $complete;
		$complete .= $value;
		next if defined $Cfg{$lvar}->{Source};
		next unless wantarray;
		my $parse;
		if (defined $Cfg{$lvar}->{Parse}) {
            $parse = 'Vend::Config::parse_' . $Cfg{$lvar}->{Parse};
        } else {
            $parse = undef;
        }
		no strict 'refs';
		if(! defined $parsed and defined $parse) {
			$parsed = &{$parse}($var, '')
				if defined $Cfg{$lvar}->{Complex};
			$parsed = &{$parse}($var, $Cfg{$lvar}->{Default});
		}
        $C->{$var} = $parsed = &{$parse}($var, $value)
            if defined $parse;
	}

	close MiniMate::CfgMgr::CONFIG;

	# see if we have a multi-level
	if (! defined $Cfg{$lvar}->{Complex}) { } # do nothing
	elsif ($complex) { $parsed = $parsed->{$complex} }
	else             {
		my $ary = $parsed;
		$parsed = [keys %$ary];

	}
	
	$lvar = lc $dir unless defined $lvar;
	if(!$complete) {
		$complete = $Cfg{$lvar}->{Default};
	}
	if (defined $Cfg{$lvar}->{Source}) {
		$parsed = $complete;
	}

	wantarray ? return ($complete, $parsed) : return $complete;
}

sub directive_box {
	my($name, $value, $option, $prefix) = @_;
	$Writing = 0;
	$Directive_prefix = $prefix if defined $prefix;
	$name = lc $name;
	return undef unless defined $Cfg{$name};

	my (@call);
	my (@args);
	push @args, $name;
	my $type = $Cfg{$name}->{Unparse} || $Cfg{$name}->{Parse};
	if ( defined $Display{$type} ) {
		@call = @{$Display{$type}};
	}
	else {
		@call = \&text_box;
	}
	my $call = shift @call;
	unless($value) {
		(undef, $value) = read_directive($name, defined $Cfg{$name}->{Complex});
	}
	push(@args, $value);
	push(@args, $option) if defined $option;

	for (@call) {
		if(! ref $_) {
			push @args, $Cfg{$name}->{$_};
		}
		elsif($_ =~ /CODE/) {
			my @ary = &$_;
			push @args, \@ary;
		}
		else {
			push @args, $_;
		}
	}
	return &$call(@args);

}

sub set_directive {
	my($name,$value,@complex) = @_;
	$Writing = 1;
	read_directive($name);

	$name = lc $name;
	my $new;

	my $begin = 0;
	my $mark = shift(@Mark) || $#Out;

	my $tmpfile;
	if(-f "$Configfile+") {
		$tmpfile = "$Configfile.$$";
		rename "$Configfile+", $tmpfile;
	}
	else {
		$new = "### Config file created by MiniMate configuration manager\n### ";
		$new .= scalar localtime;
		$new .= "\n### Serial ";
		my $serial = new File::CounterFile $Counterfile;
		$new .= $serial->inc();
		$new .= "\n";
	}

	open(OUT, ">$Configfile+")				or die "creat $Configfile+: $!\n";
	Vend::Util::lockfile(\*OUT, 1, 1)		or die "lock $Configfile+: $!\n";
	print OUT $new if defined $new;
	
#	@lines = (	'## <<< THIS IS A NEW LINE >>> ###',
#				'## <<< THIS IS ALSO A NEW LINE >>> ###',
#				);

	my ($line, @lines);
	HTML::Entities::decode($value);
	push @lines, format_line($name, $value, @complex);

	foreach $line (@lines) {
		if($mark) {
			print OUT @Out[$begin .. $mark];
			$begin = $mark + 1;
			if($mark > $#Out) {
				undef $mark;
			}
			else {
				$mark = shift(@Mark) || $#Out;
			}
		}
		print OUT "$line\n";
	}
	print OUT @Out[$begin .. $mark] if $mark;
	close OUT or die "close $Configfile+: $!\n";
	unlink $tmpfile if $tmpfile;
	return 1;
}

sub list_directives {
	my($dir, @out);
	foreach $dir (sort keys %Cfg) {
		push @out, $Cfg{$dir}->{Name};
	}
	return @out;
}

my %database_template = (
	1 => { qw/LABEL DEFAULT/ },
	2 => { qw/LABEL LINE/ },
	3 => { qw/LABEL %%/ },
	4 => { qw/LABEL CSV/ },
	5 => { qw/LABEL PIPE/ },
	6 => { qw/LABEL TAB/ },
	7 => { LABEL => 'mSQL (old)' },
	8 => { qw!LABEL SQL/DBI! },
);

sub database_display {
	my ($name) = @_;
	my $data = $Vend::Cfg->{Database}->{$name}
		or return "<STRONG>Undefined database table <I>$name</I></STRONG>";
	my $out = <<EOF;
<TABLE><TR><TD COLSPAN=2 ALIGN=CENTER><FONT SIZE="+1">$name</FONT></TD></TR>
<TR><TD ALIGN=RIGHT>Type</TD><TD><SELECT NAME=mvc_database_define_type>
EOF

	my $one;
	foreach $one (1..8) {
		$out .= qq!<OPTION VALUE="$one"!;
		$out .= qq! SELECTED! if $one == $data->{'type'};
		$out .= qq!>!;
		$out .= $database_template{$one}->{LABEL};
	}
	$out .= qq!</SELECT></TD></TR>!;

	$out .= <<EOF;
<TR><TD ALIGN=RIGHT>Source File</TD><TD>
	<INPUT NAME=mvc_database_define_file SIZE=40 VALUE="$data->{'file'}">
</TD></TR>
EOF

	foreach $one ( qw/EXCEL CONTINUE /) {
	}
	unless ($data->{'type'} == 7 or $data->{'type'} == 8) {
		$out .= '</TABLE>';
		return $out;
	}

	$out .= <<EOF;
<TR><TD ALIGN=RIGHT>Data Source Name (DSN)</TD><TD>
	<INPUT NAME=mvc_database_define_dsn SIZE=40 VALUE="$data->{DSN}">
</TD></TR>
EOF

	my $rows = 2;
	my $tmp = '';
	my $int = '';
	my $len = 0;
	DEF: {
		last DEF unless ref $data->{COLUMN_DEF};
		foreach $one (sort keys %{$data->{COLUMN_DEF}}) {
			$tmp .= $one;
			$tmp .= '=';
			$tmp .= $data->{COLUMN_DEF}{$one};
			if(rindex("\n", $tmp) == -1) {
				$len = length $tmp;
			}
			else {
				$len = length(substr($tmp, rindex("\n", $tmp)));
			}
			if($len > 60) {
				$tmp =~ s/,\s*([^,]*)$/,\n/;
				$int .= $tmp;
				$tmp = $1;
				$rows++;
			}
			$tmp .= ', ';
		}
		$tmp =~ s/[,\s]+$//;
		$int .= $tmp;
	}
	$out .= <<EOF;
<TR><TD ALIGN=RIGHT>Column Definitions</TD><TD>
<TEXTAREA COLS=60 ROWS=$rows NAME="mvc_database_define_column_def">$int</TEXTAREA>
</TD></TR>
EOF

	$rows = 2;
	$tmp = '';
	$int = '';
	DEF: {
		last DEF unless ref $data->{NAME};
		foreach $one (@{$data->{NAME}}) {
			$tmp .= $one;
			if(rindex("\n", $tmp) == -1) {
				$len = length $tmp;
			}
			else {
				$len = length(substr($tmp, rindex("\n", $tmp)));
			}
			if($len > 60) {
				$tmp =~ s/\s(\S+)\s*$/\n/;
				$int .= $tmp;
				$tmp = $1;
				$rows++;
			}
			$tmp .= ' ';
		}
		$tmp =~ s/[,\s]+$//;
		$int .= $tmp;
	}
	$out .= <<EOF;
<TR><TD ALIGN=RIGHT>Column Names</TD><TD>
<TEXTAREA COLS=60 ROWS=$rows NAME="mvc_database_define_name">$int</TEXTAREA>
</TD></TR>
EOF

	$rows = 2;
	$tmp = '';
	$int = '';
	DEF: {
		last DEF unless ref $data->{NUMERIC};
		foreach $one (keys %{$data->{NUMERIC}}) {
			$tmp .= $one;
			if(rindex("\n", $tmp) == -1) {
				$len = length $tmp;
			}
			else {
				$len = length(substr($tmp, rindex("\n", $tmp)));
			}
			if($len > 60) {
				$tmp =~ s/\s(\S+)\s*$/\n/;
				$int .= $tmp;
				$tmp = $1;
				$rows++;
			}
			$tmp .= ' ';
		}
		$tmp =~ s/[,\s]+$//;
		$int .= $tmp;
	}
	$out .= <<EOF;
<TR><TD ALIGN=RIGHT>Numeric Columns</TD><TD>
<TEXTAREA COLS=60 ROWS=$rows NAME="mvc_database_define_name">$int</TEXTAREA>
</TD></TR>
EOF

	$out .= '</TABLE>';
}

sub rotate {
	my($base, $options) = @_;

	$base = $Configfile unless $base;

	if(! $options) {
		$options = {};
	}
	elsif (! ref $options) {
		$options = {Motion => 'unsave'};
	}

	my $dir = $options->{Directory} || '.';
	my $motion = $options->{Motion} || 'save';

	$dir =~ s:/+$::;

	opendir(forwardDIR, $dir) || die "opendir $dir: $!\n";
	my @files;
	@files = grep /^$base/, readdir forwardDIR;
	my @forward;
	my @backward;
	my $add = '-';

	if("\L$motion" eq 'save') {
		return 0 unless -f "$dir/$base+";
		@backward = grep s:^($base\++):$dir/$1:, @files;
		@forward = grep s:^($base-+):$dir/$1:, @files;
	}
	elsif("\L$motion" eq 'unsave') {
		return 0 unless -f "$dir/$base-";
		@forward = grep s:^($base\++):$dir/$1:, @files;
		@backward = grep s:^($base-+):$dir/$1:, @files;
		$add = '+';
	}
	else { 
		die "Bad motion: $motion";
	}

	$base = "$dir/$base";

#::logGlobal( "rotate $base with options dir=$dir motion=$motion from >> " . Data::Dumper::Dumper($options));

	my $base_exists = -f $base;
	push @forward, $base if $base_exists;

	for(reverse sort @forward) {
		next unless -f $_;
		rename $_, $_ . $add or die "rename $_ => $_+: $!\n";
	}

	#return 1 unless $base_exists && @backward;

	@backward = sort @backward;

	unshift @backward, $base;
	my $i;
	for($i = 0; $i < $#backward; $i++) {
		rename $backward[$i+1], $backward[$i]
			or die "rename $backward[$i+1] => $backward[$i]: $!\n";
	}

	if($options->{Touch}) {
		my $now = time();
		utime $now, $now, $base;
	}
	return 1;
}

sub meta_display {
	my ($table,$column,$key,$value,$meta_db) = @_;

#::logDebug("metadisplay: t=$table c=$column k=$key v=$value md=$meta_db");
	return undef if $key =~ /::/;

	my $metakey;
	$meta_db = $::Variable->{MINIMATE_META} || 'mv_metadata' if ! $meta_db;
#::logDebug("metadisplay: t=$table c=$column k=$key v=$value md=$meta_db");
	my $meta = Vend::Data::database_exists_ref($meta_db)
		or return undef;
#::logDebug("metadisplay: got meta ref=$meta");
	my (@tries) = "${table}::$column";
	if($key) {
		unshift @tries, "${table}::${column}::$key", "${table}::$key";
	}
	for $metakey (@tries) {
#::logDebug("enter metadisplay record $metakey");
		next unless $meta->record_exists($metakey);
		$meta = $meta->ref();
		my $record = $meta->row_hash($metakey);
#::logDebug("metadisplay record: " . Vend::Util::uneval_it($record));
		my $opt;
		if($record->{lookup}) {
			my $fld = $record->{field} || $record->{lookup};
#::logDebug("metadisplay lookup");
			LOOK: {
				my $dbname = $record->{db} || $table;
				my $db = Vend::Data::database_exists_ref($dbname);
				last LOOK unless $db;
				my $query = "select DISTINCT $fld FROM $dbname ORDER BY $fld";
#::logDebug("metadisplay lookup, query=$query");
				my $ary = $db->query($query);
				last LOOK unless ref($ary) && @{$ary};
#::logDebug("metadisplay lookup, query succeeded");
				undef $record->{type} unless $record->{type} =~ /multi|combo/;
				$record->{passed} = join ",",
									map
										{ $_->[0] =~ s/,/&#44;/g; $_->[0]}
									@$ary;
#::logDebug("metadisplay lookup, passed=$record->{passed}");
			}
		}
		elsif ($record->{type} eq 'imagedir') {
			my $dir = $record->{'db'} || 'images';
			my @files = list_images($dir);
			$record->{type} = 'combo';
			$record->{passed} = join ",",
									map { s/,/&#44;/g; $_} @files;
		}
		$opt = {
			attribute	=> ($record->{'attribute'}	|| $column),
			table		=> ($record->{'db'}			|| $meta_db),
			column		=> ($record->{'field'}		|| 'options'),
			name		=> ($record->{'name'}		|| $column),
			outboard	=> ($record->{'outboard'}	|| $metakey),
			passed		=> ($record->{'passed'}		|| undef),
			type		=> ($record->{'type'}		|| undef),
		};
		my $o = Vend::Interpolate::tag_accessories(
				undef, undef, $opt, { $column => $value } );
		if($record->{filter}) {
			$o .= qq{<INPUT TYPE=hidden NAME="mm_filter:$column" VALUE="};
			$o .= $record->{filter};
			$o .= '">';
		}
		return $o;
	}
	return undef;
}

1;

__END__

