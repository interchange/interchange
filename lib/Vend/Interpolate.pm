# Vend::Interpolate - Interpret Interchange tags
# 
# $Id: Interpolate.pm,v 2.161 2003-05-05 22:29:27 racke Exp $
#
# Copyright (C) 1996-2002 Red Hat, Inc. <interchange@redhat.com>
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

package Vend::Interpolate;

require Exporter;
@ISA = qw(Exporter);

$VERSION = substr(q$Revision: 2.161 $, 10);

@EXPORT = qw (

cache_html
interpolate_html
subtotal
tag_data
tag_attr_list
$Tag
$CGI
$Session
$Values

);

=head1 NAME

Vend::Interpolate -- Interchange tag interpolation routines

=head1 SYNOPSIS

(no external use)

=head1 DESCRIPTION

The Vend::Interpolate contains the majority of the Interchange Tag
Language implementation rouines. Historically, it contained the entire
tag language implementation for MiniVend, accounting for its name.

It contains most of the handler routines pointed to by Vend::Parse, which
accepts the parsing output of Vend::Parser. (Vend::Parser was originally based
on HTML::Parser 1.x).

There are two interpolative parsers in Vend::Interpolate,
iterate_array_list() and iterate_hash_list() -- these routines parse
the lists used in the widely employed [loop ..], [search-region ...],
[item-list], and [query ..] ITL tag constructs.

This module makes heavy use of precompiled regexes. You will notice variables
being used in the regular expression constructs. For example, C<$All> is a
a synonym for C<[\000-\377]*>, C<$Some> is equivalent to C<[\000-\377]*?>, etc.
This is not only for clarity of the regular expression, but for speed.

=cut

# SQL
push @EXPORT, 'tag_sql_list';
# END SQL

@EXPORT_OK = qw( sort_cart );

use Safe;

my $hole;
BEGIN {
	eval {
		require Safe::Hole;
		$hole = new Safe::Hole;
	};
}
my $tag_wrapped;

use strict;
use Vend::Util;
use Vend::File;
use Vend::Data;
use Vend::Form;
require Vend::Cart;


use Vend::Server;
use Vend::Scan;
use Vend::Tags;
use Vend::Document;
use Vend::Parse;
use POSIX qw(ceil strftime);

use constant MAX_SHIP_ITERATIONS => 100;
use constant MODE  => 0;
use constant DESC  => 1;
use constant CRIT  => 2;
use constant MIN   => 3;
use constant MAX   => 4;
use constant COST  => 5;
use constant QUERY => 6;
use constant OPT   => 7;

use vars qw(%Data_cache);

my $wantref = 1;

# MVASP

my @Share_vars;
my @Share_routines;

BEGIN {
	@Share_vars = qw/
							$s
							$q
							$item
							$CGI_array
							$CGI
							$Document
							%Db
							$DbSearch
							%Filter
							$Search
							$Carts
							$Config
							%Sql
							%Safe
							$Items
							$Scratch
							$Shipping
							$Session
							$Tag
							$Tmp
							$TextSearch
							$Values
							$Variable
						/;
	@Share_routines = qw/
							&tag_data
							&errmsg
							&Log
							&Debug
							&uneval
							&get_option_hash
							&dotted_hash
							&HTML
							&interpolate_html
						/;
}

use vars @Share_vars, @Share_routines,
		 qw/$ready_safe $safe_safe/;
use vars qw/%Filter %Ship_handler $Safe_data/;

$ready_safe = new Safe;
$ready_safe->trap(qw/:base_io/);
$ready_safe->untrap(qw/sort ftfile/);

sub reset_calc {
#::logDebug("reset_state=$Vend::Calc_reset -- resetting calc from " . caller);
	if(! $Global::Foreground and $Vend::Cfg->{ActionMap}{_mvsafe}) {
#::logDebug("already made");
		$ready_safe = $Vend::Cfg->{ActionMap}{_mvsafe};
	}
	else {
		my $pkg = 'MVSAFE' . int(rand(100000));
		undef $MVSAFE::Safe;
		$ready_safe = new Safe $pkg;
		$ready_safe->share_from('MVSAFE', ['$safe']);
#::logDebug("new safe made=$ready_safe->{Root}");
		$ready_safe->trap(@{$Global::SafeTrap});
		$ready_safe->untrap(@{$Global::SafeUntrap});
		no strict 'refs';
		$Document   = new Vend::Document;
		*Log = \&Vend::Util::logError;
		*Debug = \&Vend::Util::logDebug;
		*uneval = \&Vend::Util::uneval_it;
		*HTML = \&Vend::Document::HTML;
		$ready_safe->share(@Share_vars, @Share_routines);
		$DbSearch   = new Vend::DbSearch;
		$TextSearch = new Vend::TextSearch;
		$Tag        = new Vend::Tags;
	}
	$Tmp        = {};
	undef $s;
	undef $q;
	undef $item;
	%Db = ();
	%Sql = ();
	undef $Shipping;
	$Vend::Calc_reset = 1;
	undef $Vend::Calc_initialized;
	return $ready_safe;
}

sub init_calc {
#::logDebug("reset_state=$Vend::Calc_reset init_state=$Vend::Calc_initialized -- initting calc from " . caller);
	reset_calc() unless $Vend::Calc_reset;
	$CGI_array                   = \%CGI::values_array;
	$CGI        = $Safe{cgi}     = \%CGI::values;
	$Carts      = $Safe{carts}   = $::Carts;
	$Items      = $Safe{items}   = $Vend::Items;
	$Config     = $Safe{config}  = $Vend::Cfg;
	$Scratch    = $Safe{scratch} = $::Scratch;
	$Values     = $Safe{values}  = $::Values;
	$Session                     = $Vend::Session;
	$Search                      = $::Instance->{SearchObject} ||= {};
	$Variable   = $::Variable;
	$Vend::Calc_initialized = 1;
	
	return;
}

# Regular expression pre-compilation
my %T;
my %QR;

my $All = '[\000-\377]*';
my $Some = '[\000-\377]*?';
my $Codere = '[-\w#/.]+';
my $Coderex = '[-\w:#=/.%]+';
my $Mandx = '\s+([-\w:#=/.%]+)';
my $Mandf = '(?:%20|\s)+([-\w#/.]+)';
my $Spacef = '(?:%20|\s)+';
my $Spaceo = '(?:%20|\s)*';

my $Optx = '\s*([-\w:#=/.%]+)?';
my $Optr = '(?:\s+([^]]+))?';
my $Mand = '\s+([-\w#/.]+)';
my $Opt = '\s*([-\w#/.]+)?';
my $T    = '\]';
my $D    = '[-_]';

my $XAll = qr{[\000-\377]*};
my $XSome = qr{[\000-\377]*?};
my $XCodere = qr{[-\w#/.]+};
my $XCoderex = qr{[-\w:#=/.%]+};
my $XMandx = qr{\s+([-\w:#=/.%]+)};
my $XMandf = qr{(?:%20|\s)+([-\w#/.]+)};
my $XSpacef = qr{(?:%20|\s)+};
my $XSpaceo = qr{(?:%20|\s)*};
my $XOptx = qr{\s*([-\w:#=/.%]+)?};
my $XMand = qr{\s+([-\w#/.]+)};
my $XOpt = qr{\s*([-\w#/.]+)?};
my $XD    = qr{[-_]};
my $Gvar  = qr{\@\@([A-Za-z0-9]\w+[A-Za-z0-9])\@\@};
my $Evar  = qr{\@_([A-Za-z0-9]\w+[A-Za-z0-9])_\@};
my $Cvar  = qr{__([A-Za-z0-9]\w*?[A-Za-z0-9])__};


my @th = (qw!

		/_alternate
		/_calc
		/_change
		/_exec
		/_filter
		/_last
		/_modifier
		/_next
		/_param
		/_pos
		/_sub
		/col
		/comment
		/condition
		/else
		/elsif
		/more_list
		/no_match
		/on_match
		/sort
		/then
		_accessories
		_alternate
		_calc
		_change
		_code
		_common
		_data
		_description
		_discount
		_exec
		_field
		_filter
		_increment
		_last
		_line
		_match
		_modifier
		_next
		_options
		_param
		_parent
		_pos
		_price
		_quantity
		_sku
		_subtotal
		_sub
		col
		comment
		condition
		discount_price
		_discount_price
		_discount_subtotal
		_difference
		else
		elsif
		matches
		match_count
		modifier_name
		more
		more_list
		no_match
		on_match
		quantity_name
		sort
		then

		! );

	my $shown = 0;
	my $tag;
	for (@th) {
		$tag = $_;
		s/([A-Za-z0-9])/[\u$1\l$1]/g;
		s/[-_]/[-_]/g;
		$T{$tag} = $_;
		next if $tag =~ m{^_};
		$T{$tag} = "\\[$T{$tag}";
		next unless $tag =~ m{^/};
		$T{$tag} = "$T{$tag}\]";
	}

%QR = (
	'/_alternate'	=> qr($T{_alternate}\]),
	'/_calc'		=> qr($T{_calc}\]),
	'/_change'		=> qr([-_]change\s+)i,
	'/_data'		=> qr($T{_data}\]),
	'/_exec'		=> qr($T{_exec}\]),
	'/_field'		=> qr($T{_field}\]),
	'/_filter'		=> qr($T{_filter}\]),
	'/_last'		=> qr($T{_last}\]),
	'/_modifier'	=> qr($T{_modifier}\]),
	'/_next'		=> qr($T{_next}\]),
	'/_pos'			=> qr($T{_pos}\]),
	'/_sub'			=> qr($T{_sub}\]),
	'/order'		=> qr(\[/order\])i,
	'/page'			=> qr(\[/page(?:target)?\])i,
	'_accessories'  => qr($T{_accessories}($Spacef[^\]]+)?\]),
	'_alternate'	=> qr($T{_alternate}$Opt\]($Some)),
	'_calc' 		=> qr($T{_calc}\]($Some)),
	'_exec' 		=> qr($T{_exec}$Mand\]($Some)),
	'_filter' 		=> qr($T{_filter}\s+($Some)\]($Some)),
	'_sub'	 		=> qr($T{_sub}$Mand\]($Some)),
	'_change'		=> qr($T{_change}$Mand$Opt\] \s*
						$T{condition}\]
						($Some)
						$T{'/condition'}
						($Some))xi,
	'_code'			=> qr($T{_code}\]),
	'_sku'			=> qr($T{_sku}\]),
	'col'			=> qr(\[col(?:umn)?\s+
				 		([^\]]+)
				 		\]
				 		($Some)
				 		\[/col(?:umn)?\] )ix,

	'comment'		=> qr($T{comment}(?:\s+$Some)?\]
						(?!$All$T{comment}\])
						$Some
						$T{'/comment'})x,

	'_description'	=> qr($T{_description}\]),
	'_difference'	=> qr($T{_difference}(?:\s+(?:quantity=)?"?(\d+)"?)?$Optx\]),
	'_discount'		=> qr($T{_discount}(?:\s+(?:quantity=)?"?(\d+)"?)?$Optx\]),
	'_field_if'		=> qr($T{_field}(\d*)$Spacef(!?)\s*($Codere)$Optr\]($Some)),
	'_field_if_wo'	=> qr($T{_field}$Spacef(!?)\s*($Codere$Optr)\]),
	'_field'		=> qr($T{_field}$Mandf\]),
	'_common'		=> qr($T{_common}$Mandf\]),
	'_increment'	=> qr($T{_increment}\]),
	'_last'			=> qr($T{_last}\]\s*($Some)\s*),
	'_line'			=> qr($T{_line}$Opt\]),
	'_modifier_if'	=> qr($T{_modifier}(\d*)$Spacef(!?)$Spaceo($Codere)$Optr\]($Some)),
	'_modifier'		=> qr($T{_modifier}$Spacef(\w+)\]),
	'_next'			=> qr($T{_next}\]\s*($Some)\s*),
	'_options'		=> qr($T{_options}($Spacef[^\]]+)?\]),
	'_param_if'		=> qr($T{_param}(\d*)$Spacef(!?)\s*($Codere)$Optr\]($Some)),
	'_param'		=> qr($T{_param}$Mandf\]),
	'_parent_if'	=> qr($T{_parent}(\d*)$Spacef(!?)\s*($Codere)$Optr\]($Some)),
	'_parent'		=> qr($T{_parent}$Mandf\]),
	'_pos_if'		=> qr($T{_pos}(\d*)$Spacef(!?)\s*(\d+)$Optr\]($Some)),
	'_pos' 			=> qr($T{_pos}$Spacef(\d+)\]),
	'_price'		=> qr!$T{_price}(?:\s+(\d+))?$Optx\]!,
	'_quantity'		=> qr($T{_quantity}\]),
	'_subtotal'		=> qr($T{_subtotal}$Optx\]),
	'_tag'			=> qr([-_] tag [-_] ([-\w]+) \s+)x,
	'condition'		=> qr($T{condition}$T($Some)$T{'/condition'}),
	'condition_begin' => qr(^\s*$T{condition}\]($Some)$T{'/condition'}),
	'_discount_price' => qr($T{_discount_price}(?:\s+(\d+))?$Optx\]),
	'discount_price' => qr($T{discount_price}(?:\s+(\d+))?$Optx\]),
	'_discount_subtotal' => qr($T{_discount_subtotal}$Optx\]),
	'has_else'		=> qr($T{'/else'}\s*$),
	'else_end'		=> qr($T{else}\]($All)$T{'/else'}\s*$),
	'elsif_end'		=> qr($T{elsif}\s+($All)$T{'/elsif'}\s*$),
	'matches'		=> qr($T{matches}\]),
	'match_count'		=> qr($T{match_count}\]),
	'modifier_name'	=> qr($T{modifier_name}$Spacef(\w+)\]),
	'more'			=> qr($T{more}\]),
	'more_list'		=> qr($T{more_list}$Optx$Optx$Optx$Optx$Optx\]($Some)$T{'/more_list'}),
	'no_match'   	=> qr($T{no_match}\]($Some)$T{'/no_match'}),
	'on_match'   	=> qr($T{on_match}\]($Some)$T{'/on_match'}),
	'quantity_name'	=> qr($T{quantity_name}\]),
	'then'			=> qr(^\s*$T{then}$T($Some)$T{'/then'}),
);

FINTAG: {
	for(keys %T) {
		$QR{$_} = qr($T{$_})
			if ! defined $QR{$_};
	}
}

undef @th;
undef %T;

sub get_joiner {
	my ($joiner, $default) = @_;
	return $default      unless defined $joiner and length $joiner;
	if($joiner eq '\n') {
		$joiner = "\n";
	}
	elsif($joiner =~ m{\\}) {
		$joiner = $safe_safe->reval("qq{$joiner}");
	}
	return length($joiner) ? $joiner : $default;
}

sub substitute_image {
	my ($text) = @_;

	## Allow no substitution of downloads
	return if $::Pragma->{download};

	## If post_page routine processor returns true, return. Otherwise,
	## continue image rewrite
	if($::Pragma->{post_page}) {
		Vend::Dispatch::run_macro($::Pragma->{post_page}, $text)
			and return;
	}

	unless ( $::Pragma->{no_image_rewrite} ) {
		my $dir = $CGI::secure											?
			($Vend::Cfg->{ImageDirSecure} || $Vend::Cfg->{ImageDir})	:
			$Vend::Cfg->{ImageDir};

		if ($dir) {
			$$text =~ s#(<i\w+\s+[^>]*?src=")(?!\w+:)([^/'][^"]+)#
						$1 . $dir . $2#ige;
	        $$text =~ s#(<body\s+[^>]*?background=")(?!\w+:)([^/'][^"]+)#
						$1 . $dir . $2#ige;
	        $$text =~ s#(<t(?:[dhr]|able)\s+[^>]*?background=")(?!\w+:)([^/'][^"]+)#
						$1 . $dir . $2#ige;
		}
	}

	if ( $::Pragma->{path_adjust} ) {
		my $dir = $Vend::Cfg->{StaticPath};
#::logDebug("have a dir for path_adjust, $dir");
		if ($dir) {
			$$text =~ s{(<a(?:rea)?\s+[^>]*?href=)"(/[^"]+)"} {$1'$dir$2'}ig;
			$$text =~ s{(<link\s+[^>]*?href=)"(/[^"]+)"}      {$1'$dir$2'}ig;
			$$text =~ s{(<i\w+\s+[^>]*?src=)"(/[^"]*)"}       {$1'$dir$2'}ig;
	        $$text =~ s{(<body\s+[^>]*?background=)"(/[^"]+)"}{$1'$dir$2'}ig;
	        $$text =~ s{(<t(?:[dhr]|able)\s+[^>]*?background=)"(/[^"]+)"}
					   {$1'$dir$2'}ig;
		}
	}

    if($Vend::Cfg->{ImageAlias}) {
		for (keys %{$Vend::Cfg->{ImageAlias}} ) {
        	$$text =~ s#(<i\w+\s+[^>]*?src=")($_)#
                         $1 . ($Vend::Cfg->{ImageAlias}->{$2} || $2)#ige;
        	$$text =~ s#(<body\s+[^>]*?background=")($_)#
                         $1 . ($Vend::Cfg->{ImageAlias}->{$2} || $2)#ige;
        	$$text =~ s#(<t(?:[dhr]|able)\s+[^>]*?background=")($_)#
                         $1 . ($Vend::Cfg->{ImageAlias}->{$2} || $2)#ige;
		}
    }
}

sub dynamic_var {
	my $varname = shift;

	return readfile($Vend::Cfg->{DirConfig}{Variable}{$varname})
		if $Vend::Cfg->{DirConfig}
			and defined $Vend::Cfg->{DirConfig}{Variable}{$varname};

	VARDB: {
		last VARDB if $::Pragma->{dynamic_variables_file_only};
		last VARDB unless $Vend::Cfg->{VariableDatabase};
		if($Vend::VarDatabase) {
			last VARDB unless $Vend::VarDatabase->record_exists($varname);
			return $Vend::VarDatabase->field($varname, 'Variable');
		}
		else {
			$Vend::VarDatabase = database_exists_ref($Vend::Cfg->{VariableDatabase})
				or undef $Vend::Cfg->{VariableDatabase};
			redo VARDB;
		}
	}
	return $::Variable->{$varname};
}

sub vars_and_comments {
	my $html = shift;
	## We never want to interpolate vars if in restricted mode
	return if $Vend::restricted;
	local($^W) = 0;

	# Remove Minivend 3 legacy [new] tags
	$$html =~ s/\[new\]//g;

	# Set whole-page pragmas from [pragma] tags
	1 while $$html =~ s/\[pragma\s+(\w+)(?:\s+(\w+))?\]/
		$::Pragma->{$1} = (length($2) ? $2 : 1), ''/ige;

	undef $Vend::PageInit unless $::Pragma->{init_page};

	if(defined $Vend::PageInit and ! $Vend::PageInit++) {
		Vend::Dispatch::run_macro($::Pragma->{init_page}, $html);
	}

	# Substitute in Variable values
	$$html =~ s/$Gvar/$Global::Variable->{$1}/g;
	if($::Pragma->{dynamic_variables}) {
		$$html =~ s/$Evar/dynamic_var($1) || $Global::Variable->{$1}/ge
			and
		$$html =~ s/$Evar/dynamic_var($1) || $Global::Variable->{$1}/ge;
		$$html =~ s/$Cvar/dynamic_var($1)/ge;
	}
	else {
		$$html =~ s/$Evar/$::Variable->{$1} || $Global::Variable->{$1}/ge
			and
		$$html =~ s/$Evar/$::Variable->{$1} || $Global::Variable->{$1}/ge;
		$$html =~ s/$Cvar/$::Variable->{$1}/g;
	}

	if($::Pragma->{pre_page}) {
		Vend::Dispatch::run_macro($::Pragma->{pre_page}, $html);
	}

	# Strip out [comment] [/comment] blocks
	1 while $$html =~ s%$QR{comment}%%go;

	# Translate legacy atomic [/page] and [/order] tags
	$$html =~ s,\[/page(?:target)?\],</A>,ig;
	$$html =~ s,\[/order\],</A>,ig;

	# Translate Interchange tags embedded in HTML comments like <!--[tag ...]-->
	$$html =~ s/<!--+\[/[/g
		and $$html =~ s/\]--+>/]/g;
}

sub interpolate_html {
	my ($html, $wantref, $opt) = @_;
	return undef if $Vend::NoInterpolate;
	my ($name, @post);
	my ($bit, %post);

	my $toplevel;
	if(defined $Vend::PageInit and ! $Vend::PageInit) {
		defined $::Variable->{MV_AUTOLOAD}
			and $html =~ s/^/$::Variable->{MV_AUTOLOAD}/;
		$toplevel = 1;
	}
#::logDebug("opt=" . uneval($opt));

	vars_and_comments(\$html)
		unless $opt and $opt->{onfly};

    # Returns, could be recursive
	my $parse = new Vend::Parse $wantref;
	$parse->parse($html);
	while($parse->{_buf}) {
		if($toplevel and $parse->{SEND}) {
			delete $parse->{SEND};
			::response();
			$parse->destination($parse->{_current_output});
		}
		$parse->parse('');
	}
	return $parse->{OUT} if defined $wantref;
	return ${$parse->{OUT}};
}

*cache_html = \&interpolate_html;

my $Filters_initted;

sub filter_value {
	my($filter, $value, $tag, @passed_args) = @_;
#::logDebug("filter_value: filter='$filter' value='$value' tag='$tag'");
	my @filters = Text::ParseWords::shellwords($filter); 
	my @args;

	if(! $Filters_initted++ and my $ref = $Vend::Cfg->{CodeDef}{Filter}) {
		while (my($k, $v) = each %{$ref->{Routine}}) {
			$Filter{$k} = $v;
		}
	}

	for (@filters) {
		next unless length($_);
		@args = @passed_args;
		if(/^[^.]*%/) {
			$value = sprintf($_, $value);
			next;
		}
		if (/^(\d+)(\.?)$/) {
			substr($value, $1) = $2 ? '...' : ''
				if length($value) > $1;
			next;
		}
		while( s/\.([^.]+)$//) {
			unshift @args, $1;
		}
		if(/^\d+$/) {
			substr($value , $_) = ''
				if length($value) > $_;
			next;
		}
		unless (defined $Filter{$_}) {
			logError ("Unknown filter '%s'", $_);
			next;
		}
		unshift @args, $value, $tag;
		$value = $Filter{$_}->(@args);
	}
#::logDebug("filter_value returns: value='$value'");
	return $value;
}

sub try {
	my ($label, $opt, $body) = @_;
	$label = 'default' unless $label;
	$Vend::Session->{try}{$label} = '';
	my $out;
	my $save;
	$save = delete $SIG{__DIE__} if defined $SIG{__DIE__};
	$Vend::Try = $label;
	eval {
		$out = interpolate_html($body);
	};
	undef $Vend::Try;
	$SIG{__DIE__} = $save if defined $save;
	if($@) {
		$Vend::Session->{try}{$label} .= "\n" 
			if $Vend::Session->{try}{$label};
		$Vend::Session->{try}{$label} .= $@;
	}
	if ($opt->{status}) {
		return ($Vend::Session->{try}{$label}) ? 0 : 1;
	}
	elsif ($opt->{hide}) {
		return '';
	}
	elsif ($opt->{clean}) {
		return ($Vend::Session->{try}{$label}) ? '' : $out;
	}

	return $out;
}

# Returns the text of a configurable database field or a 
# session variable
sub tag_data {
	my($selector,$field,$key,$opt,$flag) = @_;

	local($Safe_data);
	$Safe_data = 1 if $opt->{safe_data};
	
	my $db;

	if ( not $db = database_exists_ref($selector) ) {
		if($selector eq 'session') {
			if(defined $opt->{value}) {
				$opt->{value} = filter_value($opt->{filter}, $opt->{value}, $field)
					if $opt->{filter};
				if ($opt->{increment}) {
					$Vend::Session->{$field} += (+ $opt->{value} || 1);
				}
				elsif ($opt->{append}) {
					$Vend::Session->{$field} .= $opt->{value};
				}
				else  {
					$Vend::Session->{$field} = $opt->{value};
				}
				return '';
			}
			else {
				my $value = $Vend::Session->{$field} || '';
				$value = filter_value($opt->{filter}, $value, $field)
					if $opt->{filter};
				return $value;
			}
		}
		else {
			logError( "Bad data selector='%s' field='%s' key='%s'",
						$selector,
						$field,
						$key,
			);
			return '';
		}
	}
	elsif($opt->{increment}) {
#::logDebug("increment_field: key=$key field=$field value=$opt->{value}");
		return increment_field($Vend::Database{$selector},$key,$field,$opt->{value} || 1);
	}
	elsif (defined $opt->{value}) {
#::logDebug("alter table: table=$selector alter=$opt->{alter} field=$field value=$opt->{value}");
		if ($opt->{alter}) {
			$opt->{alter} =~ s/\W+//g;
			$opt->{alter} = lc($opt->{alter});
			if ($opt->{alter} eq 'change') {
				return $db->change_column($field, $opt->{value});
			}
			elsif($opt->{alter} eq 'add') {
				return $db->add_column($field, $opt->{value});
			}
			elsif ($opt->{alter} eq 'delete') {
				return $db->delete_column($field, $opt->{value});
			}
			else {
				logError("alter function '%s' not found", $opt->{alter});
				return undef;
			}
		}
		else {
			$opt->{value} = filter_value($opt->{filter}, $opt->{value}, $field)
				if $opt->{filter};
#::logDebug("set_field: table=$selector key=$key field=$field foreign=$opt->{foreign} value=$opt->{value}");
			my $orig = $opt->{value};
			if($opt->{serial}) {
				$field =~ s/\.(.*)//;
				my $hk = $1;
				my $current = database_field($selector,$key,$field,$opt->{foreign});
				$opt->{value} = dotted_hash($current, $hk, $orig);
			}
			my $result = set_field(
							$selector,
							$key,
							$field,
							$opt->{value},
							$opt->{append},
							$opt->{foreign},
						);
			return $orig if $opt->{serial};
			return $result
		}
	}
	elsif ($opt->{serial}) {
		$field =~ s/\.(.*)//;
		my $hk = $1;
		return ed(
					dotted_hash(
						database_field($selector,$key,$field,$opt->{foreign}),
						$hk,
					)
				);
	}
	elsif ($opt->{hash}) {
		return undef unless $db->record_exists($key);
		return $db->row_hash($key);
	}
	elsif ($opt->{filter}) {
		return filter_value(
			$opt->{filter},
			ed(database_field($selector,$key,$field,$opt->{foreign})),
			$field,
		);
	}

	#The most common , don't enter a block, no accoutrements
	return ed(database_field($selector,$key,$field,$opt->{foreign}));
}

%Filter = (
	
	'value' =>	sub { return $::Values->{$_[0]}; },
	'cgi' =>	sub { return $CGI::values{$_[0]}; },
	'filesafe' =>	sub {
						return Vend::Util::escape_chars(shift);
				},
	'calculated' =>	sub {
						my ($val, $tag, $table, $column, $key, $indirect) = @_;
						$key = $CGI::values{$indirect}
							if $indirect;
						my $code = tag_data($table, $column, $key);
						$code =~ s/\r/\n/g;
#::logDebug("calculated code=$code");
						$s = $val;
						my $result = $ready_safe->reval($code);
#::logDebug("calculated result='$result'");
						return $result;
				},
	'mime_type' =>	sub {
						return Vend::Util::mime_type(shift);
				},
	'currency' =>	sub {
						my ($val, $tag, $locale) = @_;
						my $convert = $locale ? 1 : 0;
						return Vend::Util::currency(
								$val,
								0,
								$convert,
								{ locale => $locale }
							);
				},
	'mailto' =>	sub {
						my ($val,$tag,@arg) = @_;
						my $out = qq{<A HREF="mailto:$val">};
						my $anchor = $val;
						if(@arg) {
							$anchor = join " ", @arg;
						}
						$out .= "$anchor</A>";
				},
	'tt' =>			sub { return '<TT>' . shift(@_) . '</TT>'; },
	'pre' =>		sub { return '<PRE>' . shift(@_) . '</PRE>'; },
	'bold' =>		sub { return '<B>' . shift(@_) . '</B>'; },
	'italics' =>	sub { return '<I>' . shift(@_) . '</I>'; },
	'strikeout' =>	sub { return '<strike>' . shift(@_) . '</strike>'; },
	'small' =>		sub { return '<small>' . shift(@_) . '</small>'; },
	'large' =>		sub { return '<large>' . shift(@_) . '</large>'; },
	'commify' =>	sub {
						my ($val, $tag, $places) = @_;
						$places = 2 unless defined $places;
						$val = sprintf("%.${places}f", $val) if $places;
						return Vend::Util::commify($val);
				},
	'integer' => sub { return int(shift); },
	'lookup' =>	sub {
						my ($val, $tag, $table, $column) = @_;
						return tag_data($table, $column, $val) || $val;
				},
	'uc' =>		sub {
					use locale;
					return uc(shift);
				},
	'date_change' =>		sub {
					my $val = shift;
					$val =~ s/\0+//g;
					return $val 
						unless $val =~ m:(\d+)[-/]+(\d+)[-/]+(\d+):;
					my ($yr, $mon, $day);

					if (length($1) == 4) {
						# MySQL date style 2003-03-20
						($yr, $mon, $day) = ($1, $2, $3);
					} else {
						($yr, $mon, $day) = ($3, $1, $2);
					}
					
					my $time;
					$val =~ /:(\d+)$/
						and $time = $1;
					if(length($yr) < 4) {
						$yr =~ s/^0//;
						$yr = $yr < 50 ? $yr + 2000 : $yr + 1900;
					}
					$mon =~ s/^0//;
					$day =~ s/^0//;
					$val = sprintf("%d%02d%02d", $yr, $mon, $day);
					return $val unless $time;
					$val .= sprintf('%04d', $time);
					return $val;
				},
	'checkbox' =>		sub {
					my $val = shift;
					return length($val) ? $val : '';
				},
	'compress_space' =>		sub {
					my $val = shift;
					$val =~ s/\s+$//g;
					$val =~ s/^\s+//g;
					$val =~ s/\s+/ /g;
					return $val;
				},
	'null_to_space' =>		sub {
					my $val = shift;
					$val =~ s/\0+/ /g;
					return $val;
				},
	'null_to_comma' =>		sub {
					my $val = shift;
					$val =~ s/\0+/,/g;
					return $val;
				},
	'null_to_colons' =>		sub {
					my $val = shift;
					$val =~ s/\0+/::/g;
					return $val;
				},
	'space_to_null' =>		sub {
					my $val = shift;
					$val =~ s/\s+/\0/g;
					return $val;
				},
	'colons_to_null' =>		sub {
					my $val = shift;
					$val =~ s/::/\0/g;
					return $val;
				},
	'last_non_null' =>		sub {
					my @some = reverse split /\0+/, shift;
					for(@some) {
						return $_ if length $_;
					}
					return '';
				},
	'line2options' =>		sub {
					my ($value, $tag, $delim) = @_;
					return $value unless length $value;
					$value =~ s/\s+$//;
					$value =~ s/^\s+//;
					my @opts = split /[\r\n]+/, $value;
					for(@opts) {
						s/^\s+//;
						s/[,\s]+$//;
						s/,/&#44;/g;
					}
					return join ",", @opts;
				},
	'options2line' =>		sub {
					my ($value, $tag, $delim) = @_;
					return $value unless length $value;
					$value =~ s/\s+$//;
					$value =~ s/^\s+//;
					my @opts = split /\s*,\s*/, $value;
					for(@opts) {
						s/&#44;/,/g;
					}
					$value = return join "\n", @opts;
					return $value;
				},
	'option_format' =>		sub {
					my ($value, $tag, $delim) = @_;

					return $value unless $value =~ /\0.*\0/s;

					my $scrubcommas;
					if(! length($delim) ) {
						$delim = ',';
						$scrubcommas = 1;
					}
					else {
						$delim =~ /pipe/i and $delim = '|' 
						 or
						$delim =~ /semicolon/i and $delim = ';'  
						 or
						$delim =~ /colon/i and $delim = ':'  
						 or
						$delim =~ /null/i and $delim = "\0"
						;
					}

					my @opts = split /\0/, $value;
					my @out;

					while(@opts) {
						my ($v, $l, $d) = splice @opts, 0, 3;
						$l = length($l) ? "=$l" : '';
						$l =~ s/,/&#44;/g if $scrubcommas;
						$d = $d ? '*' : '';
						next unless length("$v$l");
						push @out, "$v$l$d";
					}
					return join $delim, @out;
				},
	'nullselect' =>		sub {
					my @some = split /\0+/, shift;
					for(@some) {
						return $_ if length $_;
					}
					return '';
				},
	'tabbed' =>		sub {
						my @items = split /\r?\n/, shift;
						return join "\t", @items;
				},
	'digits_dot' => sub {
					my $val = shift;
					$val =~ s/[^\d.]+//g;
					return $val;
				},
	'backslash' => sub {
					my $val = shift;
					$val =~ s/\\+//g;
					return $val;
				},
	'crypt' => sub {
					my $val = shift;
					return crypt($val, random_string(2));
				},
	'html2text' => sub {
					my $val = shift;
					$val =~ s|\s*<BR>\s*|\n|gi;
					$val =~ s|\s*<P>\s*|\n|gi;
					$val =~ s|\s*</P>\s*||gi;
					return $val;
				},
	'upload' => sub {
					my ($fn, $vn) = @_;
					if( tag_value_extended($vn, { test => 'isfile', })) {
						return tag_value_extended($vn, { file_contents => 1 });
					}
					else {
						return $fn;
					}
				},
	'namecase' => sub {
					use locale;
					my $val = shift;
					$val =~ s/([A-Z]\w+)/\L\u$1/g;
					return $val;
				},
	'name' => sub {
					my $val = shift;
					return $val unless $val =~ /,/;
					my($last, $first) = split /\s*,\s*/, $val, 2;
					return "$first $last";
				},
	'digits' => sub {
					my $val = shift;
					$val =~ s/\D+//g;
					return $val;
				},
	'alphanumeric' =>	sub {
					my $val = shift;
					$val =~ s/\W+//g;
					$val =~ s/_+//g;
					return $val;
				},
	'word' =>	sub {
					my $val = shift;
					$val =~ s/\W+//g;
					return $val;
				},
	'unix' =>	sub {
					my $val = shift;
					$val =~ s/\r\n|\r/\n/g;
					return $val;
				},
	'dos' =>	sub {
					my $val = shift;
					$val =~ s/\r?\n/\r\n/g;
					return $val;
				},
	'mac' =>	sub {
					my $val = shift;
					$val =~ s/\r?\n|\r\n?/\r/g;
					return $val;
				},
	'gate' =>	sub {
					my ($val, $var) = @_;
					return '' unless $::Scratch->{$var};
					return $val;
				},
	'no_white' =>	sub {
					my $val = shift;
					$val =~ s/\s+//g;
					return $val;
				},
	'strip' =>	sub {
					my $val = shift;
					$val =~ s/^\s+//;
					$val =~ s/\s+$//;
					return $val;
				},
	'sql'		=> sub {
					my $val = shift;
					$val =~ s:':'':g; # '
					return $val;
				},
	'textarea_put' => sub {
					my $val = shift;
					$val =~ s/\&/\&amp;/g;
					$val =~ s/\[/&#91;/g;
					$val =~ s/</&lt;/g;
					return $val;
				},
	'textarea_get' => sub {
					my $val = shift;
					$val =~ s/\&amp;/\&/g;
					return $val;
				},
	'text2html' => sub {
					my $val = shift;
					$val =~ s!\r?\n\r?\n!<P>!g;
					$val =~ s!\r\r!<P>!g;
					$val =~ s!\r?\n!<BR>!g;
					$val =~ s!\r!<BR>!g;
					return $val;
				},
	'urldecode' => sub {
					my $val = shift;
					$val =~ s|\%([a-fA-F0-9][a-fA-F0-9])|chr(hex($1))|eg;
					return $val;
				},
	'urlencode' => sub {
					my $val = shift;
					$val =~ s|([^\w:])|sprintf "%%%02x", ord $1|eg;
					return $val;
				},
	'pagefile' => sub {
					$_[0] =~ s:^[./]+::;
					return $_[0];
				},
	'strftime' => sub {
					my $time = shift(@_);
					shift(@_);
					my $fmt = shift(@_);
					while(my $add = shift(@_)) {
						$fmt .= " $add";
					}
					if($fmt) {
						return POSIX::strftime($fmt, localtime($time));
					}
					else {
						return scalar localtime($time);
					}
				},
	'encode_entities' => sub {
					return HTML::Entities::encode(shift, $ESCAPE_CHARS::std);
				},
	'decode_entities' => sub {
					return HTML::Entities::decode(shift);
				},
	encrypt => sub {
					my ($val, $tag, $key) = @_;
					return Vend::Order::pgp_encrypt($val, $key);
				},
	'yesno' => sub {
					my $val = shift(@_) ? 'Yes' : 'No';
					return $val unless $Vend::Cfg->{Locale};
					return $val unless defined $Vend::Cfg->{Locale}{$val};
					return $Vend::Cfg->{Locale}{$val};
				},

	show_null => sub {
					my $val = shift;
					$val =~ s/\0/\\0/g;
					return $val;
				},

	loc => sub {
					my $val = shift;
					return errmsg($val);
				},

	restrict_html => sub {
					my $val = shift;
					shift;
					my %allowed;
					$allowed{lc $_} = 1 for @_;
					$val =~ s{<(/?(\w[-\w]*)[\s>])}
						     { ($allowed{lc $2} ? '<' : '&lt;') . $1 }ge;
					return $val;
				},

	zerofix => sub {
					$_[0] =~ /^0*(.*)/; return $1;
				},

	);

$Filter{upper} = $Filter{uc};
$Filter{lower} = $Filter{lc};
$Filter{entities} = $Filter{encode_entities};
$Filter{e} = $Filter{encode_entities};

sub input_filter_do {
	my($varname, $opt, $routine) = @_;
#::logDebug("filter var=$varname opt=" . uneval_it($opt));
	return undef unless defined $CGI::values{$varname};
#::logDebug("before filter=$CGI::values{$varname}");
	$routine = $opt->{routine} || ''
		if ! $routine;
	if($routine =~ /\S/) {
		$routine = interpolate_html($routine);
		$CGI::values{$varname} = tag_calc($routine);
	}
	if ($opt->{op}) {
		$CGI::values{$varname} = filter_value($opt->{op}, $CGI::values{$varname}, $varname);
	}
#::logDebug("after filter=$CGI::values{$varname}");
	return;
}

sub input_filter {
	my ($varname, $opt, $routine) = @_;
	if($opt->{remove}) {
		return if ! ref $Vend::Session->{Filter};
		delete $Vend::Session->{Filter}{$_};
		return;
	}
	$opt->{routine} = $routine if $routine =~ /\S/;
	$Vend::Session->{Filter} = {} if ! $Vend::Session->{Filter};
	$Vend::Session->{Filter}{$varname} = $opt->{op} if $opt->{op};
	return;
}

sub conditional {
	my($base,$term,$operator,$comp, @addl) = @_;
	my $reverse;
	$base = lc $base;
	$base =~ s/^!// and $reverse = 1;
	my ($op, $status);
	my $noop;
	$noop = 1 unless defined $operator;
	local($^W) = 0;
	undef $@;
#::logDebug("cond: base=$base term=$term op=$operator comp=$comp\n");
#::logDebug (($reverse ? '!' : '') . "cond: base=$base term=$term op=$operator comp=$comp");
	my %stringop = ( qw! eq 1 ne 1 gt 1 lt 1! );

	if(defined $stringop{$operator}) {
		$comp =~ /^(["']).*\1$/ or
		$comp =~ /^qq?([{(]).*[})]$/ or
		$comp =~ /^qq?(\S).*\1$/ or
		(index ($comp, '}') == -1 and $comp = 'q{' . $comp . '}')
			or
		(index ($comp, '!') == -1 and $comp = 'q{' . $comp . '}')
	}

#::logDebug ("cond: base=$base term=$term op=$operator comp=$comp\n");

	my $total;
	if($base eq 'total') {
		$base = $term;
		$total = 1;
	}

	if($base eq 'session') {
		$op =	qq%$Vend::Session->{$term}%;
		$op = "q{$op}" unless defined $noop;
		$op .=	qq%	$operator $comp%
				if defined $comp;
	}
	elsif($base eq 'scratch') {
		$op =	qq%$::Scratch->{$term}%;
		$op = "q{$op}" unless defined $noop;
		$op .=	qq%	$operator $comp%
				if defined $comp;
	}
	elsif($base =~ /^value/) {
		$op =	qq%$::Values->{$term}%;
		$op = "q{$op}" unless defined $noop;
		$op .=	qq%	$operator $comp%
				if defined $comp;
	}
	elsif($base eq 'cgi') {
		$op =	qq%$CGI::values{$term}%;
		$op = "q{$op}" unless defined $noop;
		$op .=	qq%	$operator $comp%
				if defined $comp;
	}
	elsif($base eq 'pragma') {
		$op =	qq%$::Pragma->{$term}%;
		$op = "q{$op}" unless defined $noop;
		$op .=	qq%	$operator $comp%
				if defined $comp;
	}
	elsif($base eq 'explicit') {
		undef $noop;
		$status = $ready_safe->reval($comp);
	}
	elsif($base eq 'variable') {
		$op =	qq%$::Variable->{$term}%;
		$op = "q{$op}" unless defined $noop;
		$op .=	qq%	$operator $comp%
				if defined $comp;
	}
	elsif($base eq 'global') {
		$op =	qq%$Global::Variable->{$term}%;
		$op = "q{$op}" unless defined $noop;
		$op .=	qq%	$operator $comp%
				if defined $comp;
	}
    elsif($base eq 'items') {
		my $cart;
        if($term) {
        	$cart = $::Carts->{$term} || undef;
		}
		else {
			$cart = $Vend::Items;
		}
		$op =   defined $cart ? scalar @{$cart} : 0;

        $op .=  qq% $operator $comp%
                if defined $comp;
    }
	elsif($base eq 'data') {
		my($d,$f,$k) = split /::/, $term;
		$op = database_field($d,$k,$f);
#::logDebug ("tag_if db=$d fld=$f key=$k\n");
		$op = "q{$op}" unless defined $noop;
		$op .=	qq%	$operator $comp%
				if defined $comp;
	}
	elsif($base eq 'field') {
		my($f,$k) = split /::/, $term;
		$op = product_field($f,$k);
#::logDebug("tag_if field fld=$f key=$k\n");
		$op = "q{$op}" unless defined $noop;
		$op .=	qq%	$operator $comp%
				if defined $comp;
	}
	elsif($base eq 'discount') {
		$op =	qq%$Vend::Session->{discount}->{$term}%;
		$op = "q{$op}" unless defined $noop;
		$op .=	qq%	$operator $comp%
				if defined $comp;
	}
	elsif($base eq 'ordered') {
		$operator = 'main' unless $operator;
		my ($attrib, $i);
		$op = '';
		unless ($comp) {
			$attrib = 'quantity';
		}
		else {
			($attrib,$comp) = split /\s+/, $comp;
		}
		foreach $i (@{$::Carts->{$operator}}) {
			next unless $i->{code} eq $term;
			($op++, next) if $attrib eq 'lines';
			$op = $i->{$attrib};
			last;
		}
		$op = "q{$op}" unless defined $noop;
		$op .=  qq% $comp% if $comp;
	}
	elsif($base eq 'file') {
		#$op =~ s/[^rwxezfdTsB]//g;
		#$op = substr($op,0,1) || 'f';
		undef $noop;
		$op = 'f';
		$op = qq|-$op "$term"|;
	}
	elsif($base =~ /^errors?$/) {
		my $err;
		if(! $term or $total) {
			$err	= is_hash($Vend::Session->{errors})
					? scalar (keys %{$Vend::Session->{errors}})
					: 0;
		}
		else {
			$err	= is_hash($Vend::Session->{errors})
					? $Vend::Session->{errors}{$term}
					: 0;
		}
		$op = $err;
		$op .=	qq%	$operator $comp%
				if defined $comp;
	}
	elsif($base =~ /^warnings?$/) {
		my $warn = 0;
		if(my $ary = $Vend::Session->{warnings}) {
			ref($ary) eq 'ARRAY' and $warn = scalar(@$ary);
		}
		$op = $warn;
	}
	elsif($base eq 'validcc') {
		no strict 'refs';
		$status = Vend::Order::validate_whole_cc($term, $operator, $comp);
	}
    elsif($base eq 'config') {
		$op = qq%$Vend::Cfg->{$term}%;
		$op = "q{$op}" unless defined $noop;
		$op .=	qq%	$operator $comp%
				if defined $comp;
    }
	elsif($base =~ /^accessor/) {
        if ($comp) {
            $op = qq%$Vend::Cfg->{Accessories}->{$term}%;
			$op = "q{$op}" unless defined $noop;
            $op .=  qq% $operator $comp%;
        }
        else {
            for(@{$Vend::Cfg->{UseModifier}}) {
                next unless product_field($_,$term);
                $status = 1;
                last;
            }
        }
	}
	else {
		$op =	qq%$term%;
		$op = "q{$op}" unless defined $noop;
		$op .=	qq%	$operator $comp%
				if defined $comp;
	}

#::logDebug("noop='$noop' op='$op'");

	RUNSAFE: {
		last RUNSAFE if defined $status;
		last RUNSAFE if $status = ($noop && $op);
		$ready_safe->trap(@{$Global::SafeTrap});
		$ready_safe->untrap(@{$Global::SafeUntrap});
		$status = $ready_safe->reval($op)
			unless ($@ or $status);
		if ($@) {
			logError qq%Bad if '@_': $@%;
			$status = 0;
		}
	}

	$status = $reverse ? ! $status : $status;

	for(@addl) {
		my $chain = /^\[[Aa]/;
		last if ($chain ^ $status);
		$status = ${(new Vend::Parse)->parse($_)->{OUT}};
	}
#::logDebug("if status=$status");

	return $status;
}

sub find_close_square {
    my $chunk = shift;
    my $first = index($chunk, ']');
    return undef if $first < 0;
    my $int = index($chunk, '[');
    my $pos = 0;
    while( $int > -1 and $int < $first) {
        $pos   = $int + 1;
        $first = index($chunk, ']', $first + 1);
        $int   = index($chunk, '[', $pos);
    }
    return substr($chunk, 0, $first);
}

sub find_andor {
	my($text) = @_;
	return undef
		unless $$text =~ s# \s* \[
								( (?:[Aa][Nn][Dd]|[Oo][Rr]) \s+
									$All)
									#$1#x;
	my $expr = find_close_square($$text);
	return undef unless defined $expr;
	$$text = substr( $$text,length($expr) + 1 );
	return "[$expr]";
}

sub split_if {
	my ($body) = @_;

	my ($then, $else, $elsif, $andor, @addl);
	$else = $elsif = '';

	push (@addl, $andor) while $andor = find_andor(\$body);

	$body =~ s#$QR{then}##o
		and $then = $1;

	$body =~ s#$QR{has_else}##o
		and $else = find_matching_else(\$body);

	$body =~ s#$QR{elsif_end}##o
		and $elsif = $1;

	$body = $then if defined $then;

	return($body, $elsif, $else, @addl);
}

sub tag_if {
	my ($cond,$body,$negate) = @_;
#::logDebug("Called tag_if: $cond\n$body\n");
	my ($base, $term, $op, $operator, $comp);
	my ($else, $elsif, $else_present, @addl);

	($base, $term, $operator, $comp) = split /\s+/, $cond, 4;
	if ($base eq 'explicit') {
		$body =~ s#$QR{condition_begin}##o
			and ($comp = $1, $operator = '');
	}
#::logDebug("tag_if: base=$base term=$term op=$operator comp=$comp");

	#Handle unless
	($base =~ s/^\W+// or $base = "!$base") if $negate;

	$else_present = 1 if
		$body =~ /\[[EeTtAaOo][hHLlNnRr][SsEeDd\s]/;

	($body, $elsif, $else, @addl) = split_if($body)
		if $else_present;

#::logDebug("Additional ops found:\n" . join("\n", @addl) ) if @addl;

	unless(defined $operator) {
		undef $operator;
		undef $comp;
	}

	my $status = conditional ($base, $term, $operator, $comp, @addl);

#::logDebug("Result of if: $status\n");

	my $out;
	if($status) {
		$out = $body;
	}
	elsif ($elsif) {
		$else = '[else]' . $else . '[/else]' if length $else;
		$elsif =~ s#(.*?)$QR{'/elsif'}(.*)#$1${2}[/elsif]#s;
		$out = '[if ' . $elsif . $else . '[/if]';
	}
	elsif (length $else) {
		$out = $else;
	}
	return $out;
}

# This generates a *session-based* Autoload routine based
# on the contents of a preset Profile (see the Profile directive).
#
# Normally used for setting pricing profiles with CommonAdjust,
# ProductFiles, etc.
# 
sub restore_profile {
	my $save;
	return unless $save = $Vend::Session->{Profile_save};
	for(keys %$save) {
		$Vend::Cfg->{$_} = $save->{$_};
	}
	return;
}

sub tag_profile {
	my($profile, $opt) = @_;
#::logDebug("in tag_profile=$profile opt=" . uneval_it($opt));

	$opt = {} if ! $opt;
	my $tag = $opt->{tag} || 'default';

	if(! $profile) {
		if($opt->{restore}) {
			restore_profile();
			if(ref $Vend::Session->{Autoload}) {
				 @{$Vend::Session->{Autoload}} = 
					 grep $_ !~ /^$tag-/, @{$Vend::Session->{Autoload}};
			}
		}
		return if ! ref $Vend::Session->{Autoload};
		$opt->{joiner} = ' ' unless defined $opt->{joiner};
		return join $opt->{joiner},
			grep /^\w+-\w+$/, @{ $Vend::Session->{Autoload} };
	}

	if($profile =~ s/(\w+)-//) {
		$opt->{tag} = $1;
		$opt->{run} = 1;
	}
	elsif (! $opt->{set} and ! $opt->{run}) {
		$opt->{set} = $opt->{run} = 1;
	}

	if( "$profile$tag" =~ /\W/ ) {
		logError(
			"profile: invalid characters (tag=%s profile=%s), must be [A-Za-z_]+",
			$tag,
			$profile,
		);
		return $opt->{failure};
	}

	if($opt->{run}) {
#::logDebug("running profile=$profile tag=$tag");
		my $prof = $Vend::Cfg->{Profile_repository}{$profile};
	    if (not $prof) {
			logError( "profile %s (%s) non-existant.", $profile, $tag );
			return $opt->{failure};
		} 
#::logDebug("found profile=$profile");
		$Vend::Cfg->{Profile} = $prof;
		restore_profile();
#::logDebug("restored profile");
		PROFSET: 
		for my $one (keys %$prof) {
#::logDebug("doing profile $one");
			next unless defined $Vend::Cfg->{$one};
			my $string;
			my $val = $prof->{$one};
			if( ! ref $Vend::Cfg->{$one} ) {
				# Do nothing
			}
			elsif( ref($Vend::Cfg->{$one}) eq 'HASH') {
				if( ref($val) ne 'HASH') {
				$string = '{' .  $prof->{$one}	. '}'
					unless	$prof->{$one} =~ /^{/
					and		$prof->{$one} =~ /}\s*$/;
			}
			}
			elsif( ref($Vend::Cfg->{$one}) eq 'ARRAY') {
				if( ref($val) ne 'ARRAY') {
				$string = '[' .  $prof->{$one}	. ']'
					unless	$prof->{$one} =~ /^\[/
					and		$prof->{$one} =~ /]\s*$/;
			}
			}
			else {
				logError( "profile: cannot handle object of type %s.",
							$Vend::Cfg->{$one},
							);
				logError("profile: profile for $one not changed.");
				next;
			}

#::logDebug("profile value=$val, string=$string");
			$val = $ready_safe->reval($string) if $string;

			if($@) {
				logError( "profile: bad object %s: %s", $one, $string );
				next;
			}
			$Vend::Session->{Profile_save}{$one} = $Vend::Cfg->{$one}
				unless defined $Vend::Session->{Profile_save}{$one};

#::logDebug("set $one to value=$val, string=$string");
			$Vend::Cfg->{$one} = $val;
		}
		return $opt->{success}
			unless $opt->{set};
	}

#::logDebug("setting profile=$profile tag=$tag");
	my $al;
	if(! $Vend::Session->{Autoload}) {
		# Do nothing....
	}
	elsif(ref $Vend::Session->{Autoload}) {
		$al = $Vend::Session->{Autoload};
	}
	else {
		$al = [ $Vend::Session->{Autoload} ];
	}

	if($al) {
		@$al = grep $_ !~ m{^$tag-\w+$}, @$al;
	}
	$al = [] if ! $al;
	push @$al, "$tag-$profile";
#::logDebug("profile=$profile Autoload=" . uneval_it($al));
	$Vend::Session->{Autoload} = $al;

	return $opt->{success};
}

*tag_options = \&Vend::Options::tag_options;

sub produce_range {
	my ($ary, $max) = @_;
	$max = $Vend::Cfg->{Limit}{option_list} if ! $max;
	my @do;
	for (my $i = 0; $i < scalar(@$ary); $i++) {
		$ary->[$i] =~ /^\s* ([a-zA-Z0-9]+) \s* \.\.+ \s* ([a-zA-Z0-9]+) \s* $/x
			or next;
		my @new = $1 .. $2;
		if(@new > $max) {
			logError(
				"Refuse to add %d options to option list via range, max %d.",
				scalar(@new),
				$max,
				);
			next;
		}
		push @do, $i, \@new;
	}
	my $idx;
	my $new;
	while($new = pop(@do)) {
		my $idx = pop(@do);
		splice @$ary, $idx, 1, @$new;
	}
	return;
}

sub tag_accessories {
	my($code,$extra,$opt,$item) = @_;

	my $ishash;
	if(ref $item) {
#::logDebug("tag_accessories: item is a hash");
		$ishash = 1;
	}

	# Had extra if got here
#::logDebug("tag_accessories: code=$code opt=" . uneval_it($opt) . " item=" . uneval_it($item) . " extra=$extra");
	my($attribute, $type, $field, $db, $name, $outboard, $passed);
	$opt = {} if ! $opt;
	if($extra) {
		$extra =~ s/^\s+//;
		$extra =~ s/\s+$//;
		@{$opt}{qw/attribute type column table name outboard passed/} =
			split /\s*,\s*/, $extra;
	}
	($attribute, $type, $field, $db, $name, $outboard, $passed) = 
		@{$opt}{qw/attribute type column table name outboard passed/};

	## Code only passed when we are a product
	if($code) {
		GETACC: {
			my $col =  $opt->{column} || $opt->{attribute};
			my $key = $opt->{outboard} || $code;
			last GETACC if ! $col;
			if($opt->{table}) {
				$opt->{passed} ||= tag_data($opt->{table}, $col, $key);
			}
			else {
				$opt->{passed} ||= product_field($col, $key);
			}
		}

		return unless $opt->{passed} || $opt->{type};
		$opt->{type} ||= 'select';
		return unless
			$opt->{passed}
				or
			$opt->{type} =~ /^(text|password|hidden)/i;
	}

	return Vend::Form::display($opt, $item);
}

# MVASP

sub mvasp {
	my ($tables, $opt, $text) = @_;
	my @code;
	$opt->{no_return} = 1 unless defined $opt->{no_return};
	
	while ( $text =~ s/(.*?)<%//s || $text =~ s/(.+)//s ) {
		push @code, <<EOF;
; my \$html = <<'_MV_ASP_EOF$^T';
$1
_MV_ASP_EOF$^T
chop(\$html);
		HTML( \$html );
EOF
		$text =~ s/(.*?)%>//s
			or last;;
		my $bit = $1;
		if ($bit =~ s/^\s*=\s*//) {
			$bit =~ s/;\s*$//;
			push @code, "; HTML( $bit );"
		}
		else {
			push @code, $bit, ";\n";
		}
	}
	my $asp = join "", @code;
#::logDebug("ASP CALL:\n$asp\n");
	return tag_perl ($tables, $opt, $asp);
}

# END MVASP

$safe_safe = new Safe;

sub tag_perl {
	my ($tables, $opt,$body) = @_;
	my ($result,@share);
#::logDebug("tag_perl MVSAFE=$MVSAFE::Safe opts=" . uneval($opt));

	if($Vend::NoInterpolate) {
		logGlobal({ level => 'alert' },
					"Attempt to interpolate perl/ITL from RPC, no permissions."
					);
		return undef;
	}

	if ($MVSAFE::Safe) {
		logGlobal({ level => 'alert' }, "Attempt to call perl from within Safe.");
		return undef;
	}

#::logDebug("tag_perl: tables=$tables opt=" . uneval($opt) . " body=$body");
#::logDebug("tag_perl initialized=$Vend::Calc_initialized: carts=" . uneval($::Carts));
	if($opt->{subs} || (defined $opt->{arg} and $opt->{arg} =~ /\bsub\b/)) {
		no strict 'refs';
		for(keys %{$Global::GlobalSub}) {
#::logDebug("tag_perl share subs: GlobalSub=$_");
			next if defined $Global::AdminSub->{$_}
				and ! $Global::AllowGlobal->{$Vend::Cat};
			*$_ = \&{$Global::GlobalSub->{$_}};
			push @share, "&$_";
		}
		for(keys %{$Vend::Cfg->{Sub} || {}}) {
#::logDebug("tag_perl share subs: Sub=$_");
			*$_ = \&{$Vend::Cfg->{Sub}->{$_}};
			push @share, "&$_";
		}
	}

	if($tables) {
		my (@tab) = grep /\S/, split /\s+/, $tables;
		foreach my $tab (@tab) {
			next if $Db{$tab};
			my $db = database_exists_ref($tab);
			next unless $db;
			$db = $db->ref();
			if($db->config('type') == 10) {
				my @extra_tabs = $db->_shared_databases();
				push (@tab, @extra_tabs);
			}
			if($hole) {
				$Sql{$tab} = $hole->wrap($db->dbh())
					if $db->can('dbh');
				$Db{$tab} = $hole->wrap($db);
				if($db->config('name') ne $tab) {
					$Db{$db->config('name')} = $Db{$tab};
				}
			}
			else {
				$Sql{$tab} = $db->[$Vend::Table::DBI::DBI]
					if $db =~ /::DBI/;
				$Db{$tab} = $db;
			}
		}
	}

	$Tag = $hole->wrap($Tag) if $hole and ! $tag_wrapped++;

	init_calc() if ! $Vend::Calc_initialized;
	$ready_safe->share(@share) if @share;

	if($Vend::Cfg->{Tie_Watch}) {
		eval {
			for(@{$Vend::Cfg->{Tie_Watch}}) {
				logGlobal("touching $_");
				my $junk = $Config->{$_};
			}
		};
	}

	#$hole->wrap($Tag);

	$MVSAFE::Safe = 1;
	if (
		$opt->{global}
			and
		$Global::AllowGlobal->{$Vend::Cat}
		)
	{
		$MVSAFE::Safe = 0 unless $MVSAFE::Unsafe;
	}

	$body = readfile($opt->{file}) . $body
		if $opt->{file};

	$body =~ tr/\r//d if $Global::Windows;

	$Items = $Vend::Items;

	if(! $MVSAFE::Safe) {
		$result = eval($body);
	}
	else {
		$result = $ready_safe->reval($body);
	}

	undef $MVSAFE::Safe;

	if ($@) {
#::logDebug("tag_perl failed $@");
		my $msg = $@;
		if($Vend::Try) {
			$Vend::Session->{try}{$Vend::Try} .= "\n" 
				if $Vend::Session->{try}{$Vend::Try};
			$Vend::Session->{try}{$Vend::Try} .= $@;
		}
        if($opt->{number_errors}) {
            my @lines = split("\n",$body);
            my $counter = 1;
            map { $_ = sprintf("% 4d %s",$counter++,$_); } @lines;
            $body = join("\n",@lines);
        }
        if($opt->{trim_errors}) {
            if($msg =~ /line (\d+)\.$/) {
                my @lines = split("\n",$body);
                my $start = $1 - $opt->{trim_errors} - 1;
                my $length = (2 * $opt->{trim_errors}) + 1;
                @lines = splice(@lines,$start,$length);
                $body = join("\n",@lines);
            }
        }
        if($opt->{eval_label}) {
            $msg =~ s/\(eval \d+\)/($opt->{eval_label})/g;
        }
        if($opt->{short_errors}) {
            chomp($msg);
            logError( "Safe: %s" , $msg );
            logGlobal({ level => 'debug' }, "Safe: %s" , $msg );
        } else {
            logError( "Safe: %s\n%s\n" , $msg, $body );
            logGlobal({ level => 'debug' }, "Safe: %s\n%s\n" , $msg, $body );
        }
		return $opt->{failure};
	}
#::logDebug("tag_perl initialized=$Vend::Calc_initialized: carts=" . uneval($::Carts));

	if ($opt->{no_return}) {
		$Vend::Session->{mv_perl_result} = $result;
		$result = join "", @Vend::Document::Out;
		@Vend::Document::Out = ();
	}
#::logDebug("tag_perl succeeded result=$result\nEND");
	return $result;
}

sub ed {
	return $_[0] if ! $_[0] or $Safe_data or $::Pragma->{safe_data};
	$_[0] =~ s/\[/&#91;/g;
	return $_[0];
}

sub show_tags {
	my($type, $opt, $text) = @_;

	$type = 'html interchange' unless $type;
	$type =~ s/minivend/interchange/g;

	if ($type =~ /interchange/i) {
		$text =~ s/\[/&#91;/g;
	}
	if($type =~ /html/i) {
		$text =~ s/\</&lt;/g;
	}
	return $text;
}

sub pragma {
	my($pragma, $opt, $text) = @_;
	$pragma =~ s/\W+//g;

	my $value = defined $opt->{value} ? $opt->{value} : 1;
	if(! defined $opt->{value} and $text =~ /\S/) {
		$value = $text;
	}

	$::Pragma->{$pragma} = $value;
	return;
}

sub flag {
	my($flag, $opt, $text) = @_;
	$flag = lc $flag;

	if(! $text) {
		($flag, $text) = split /\s+/, $flag;
	}
	my $value = defined $opt->{value} ? $opt->{value} : 1;
	my $fmt = $opt->{status} || '';
	my @status;

#::logDebug("tag flag=$flag text=$text value=$value opt=". uneval_it($opt));
	if($flag eq 'write' || $flag eq 'read') {
		my $arg = $opt->{table} || $text;
		$value = 0 if $flag eq 'read';
		my (@args) = Text::ParseWords::shellwords($arg);
		my $dbname;
		foreach $dbname (@args) {
			# Handle table:column:key
			$dbname =~ s/:.*//;
#::logDebug("tag flag write $dbname=$value");
			$Vend::WriteDatabase{$dbname} = $value;
		}
	}
	elsif($flag =~ /^transactions?/i) {
		my $arg = $opt->{table} || $text;
		my (@args) = Text::ParseWords::shellwords($arg);
		my $dbname;
		foreach $dbname (@args) {
			# Handle table:column:key
			$dbname =~ s/:.*//;
			$Vend::TransactionDatabase{$dbname} = $value;
			$Vend::WriteDatabase{$dbname} = $value;

			# we can't do anything else if in Safe
			next if $MVSAFE::Safe;

			# Now we close and reopen
			my $db = database_exists_ref($dbname)
				or next;
			if($db->isopen()) {
				# need to reopen in transactions mode. 
				$db->close_table();
				$db->suicide();
				$db = database_exists_ref($dbname);
				$db = $db->ref();
			}
			$Db{$dbname} = $db;
			$Sql{$dbname} = $db->dbh()
				if $db->can('dbh');
		}
	}
	elsif($flag eq 'commit' || $flag eq 'rollback') {
		my $arg = $opt->{table} || $text;
		$value = 0 if $flag eq 'rollback';
		my $method = $value ? 'commit' : 'rollback';
		my (@args) = Text::ParseWords::shellwords($arg);
		my $dbname;
		foreach $dbname (@args) {
			# Handle table:column:key
			$dbname =~ s/:.*//;
#::logDebug("tag commit $dbname=$value");
			my $db = database_exists_ref($dbname);
			next unless $db->isopen();
			next unless $db->config('Transactions');
			if( ! $db ) {
				logError("attempt to $method on unknown database: %s", $dbname);
				return undef;
			}
			if( ! $db->$method() ) {
				logError("problem doing $method for table: %s", $dbname);
				return undef;
			}
		}
	}
	elsif($flag eq 'build') {
		$Vend::ForceBuild = $value;
		$text = $opt->{name} if $opt->{name};
		if($text) {
			$Vend::ScanName = Vend::Util::escape_chars(interpolate_html($text));
		}
		@status = ("Set build flag: %s name=%s", $value, $Vend::ScanName);
	}
	elsif($flag eq 'checkhtml') {
		$Vend::CheckHTML = $value;
		@status = ("Set CheckHTML flag: %s", $value);
	}
	else {
		@status = ("Unknown flag operation '%s', ignored.", $flag);
		$status[0] = $opt->{status} if $opt->{status};
		logError( @status );
	}
	return '' unless $opt->{show};
	$status[0] = $opt->{status} if $opt->{status};
	return errmsg(@status);
}

sub tag_export {
	my ($args, $opt, $text) = @_;
	$opt->{base} = $opt->{table} || $opt->{database} || undef
		unless defined $opt->{base};
	unless (defined $opt->{base}) {
		@{$opt}{ qw/base file type/ } = split /\s+/, $args;
	}
	if($opt->{delete}) {
		undef $opt->{delete} unless $opt->{verify};
	}
#::logDebug("exporting " . join (",", @{$opt}{ qw/base file type field delete/ }));
	my $status = Vend::Data::export_database(
			@{$opt}{ qw/base file type/ }, $opt,
		);
	return $status unless $opt->{hide};
	return '';
}

sub export {
	my ($table, $opt, $text) = @_;
	if($opt->{delete}) {
		undef $opt->{delete} unless $opt->{verify};
	}
#::logDebug("exporting " . join (",", @{$opt}{ qw/table file type field delete/ }));
	my $status = Vend::Data::export_database(
			@{$opt}{ qw/table file type/ }, $opt,
		);
	return $status unless $opt->{hide};
	return '';
}

sub mime {
	my ($option, $opt, $text) = @_;
	my $id;

	my $out;

#::logDebug("mime call, opt=" . uneval($opt));
	$Vend::TIMESTAMP = POSIX::strftime("%y%m%d%H%M%S", localtime())
		unless defined $Vend::TIMESTAMP;

	$::Instance->{MIME_BOUNDARY} =
							$::Instance->{MIME_TIMESTAMP} . '-' .
							$Vend::SessionID . '-' .
							$Vend::Session->{pageCount} . 
							':=' . $$
		unless defined $::Instance->{MIME_BOUNDARY};

	my $msg_type = $opt->{attach_only} ? "multipart/mixed" : "multipart/alternative";
	if($option eq 'reset') {
		undef $::Instance->{MIME_TIMESTAMP};
		undef $::Instance->{MIME_BOUNDARY};
		$out = '';
	}
	elsif($option eq 'boundary') {
		$out = "--$::Instance->{MIME_BOUNDARY}";
	}
	elsif($option eq 'id') {
		$::Instance->{MIME} = 1;
		$out =	_mime_id();
	}
	elsif($option eq 'header') {
		$id = _mime_id();
		$out = <<EndOFmiMe;
MIME-Version: 1.0
Content-Type: $msg_type; BOUNDARY="$::Instance->{MIME_BOUNDARY}"
Content-ID: $id
EndOFmiMe
	}
	elsif ( $text !~ /\S/) {
		$out = '';
	}
	else {
		$id = _mime_id();
		$::Instance->{MIME} = 1;
		my $desc = $opt->{description} || $option;
		my $type = $opt->{type} || 'TEXT/PLAIN; CHARSET=US-ASCII';
		$out = <<EndOFmiMe;
--$::Instance->{MIME_BOUNDARY}
Content-Type: $type
Content-ID: $id
Content-Description: $desc

$text
EndOFmiMe

	}
#::logDebug("tag mime returns:\n$out");
	return $out;
}

sub log {
	my($file, $opt, $data) = @_;
	my(@lines);
	my(@fields);

	my $status;

	$file = $opt->{file} || $Vend::Cfg->{LogFile};
	if($file =~ s/^\s*>\s*//) {
		$opt->{create} = 1;
	}

	$file = Vend::Util::escape_chars($file);
	unless(Vend::File::allowed_file($file)) {
		Vend::File::log_file_violation($file, 'log');
		return undef;
	}

	$file = ">$file" if $opt->{create};

	unless($opt->{process} =~ /\bnostrip\b/i) {
		$data =~ s/\r\n/\n/g;
		$data =~ s/^\s+//;
		$data =~ s/\s+$/\n/;
	}

	my ($delim, $record_delim);
	for(qw/delim record_delim/) {
		next unless defined $opt->{$_};
		$opt->{$_} = $ready_safe->reval(qq{$opt->{$_}});
	}
	if($opt->{type} =~ /^text/) {
		$status = Vend::Util::writefile($file, $data, $opt);
	}
	elsif($opt->{type} =~ /^\s*quot/) {
		$record_delim = $opt->{record_delim} || "\n";
		@lines = split /$record_delim/, $data;
		for(@lines) {
			@fields = Text::ParseWords::shellwords $_;
			$status = logData($file, @fields)
				or last;
		}
	}
	elsif($opt->{type} =~ /^(?:error|debug)/) {
		if ($opt->{file}) {
			$data = format_log_msg($data) unless $data =~ s/^\\//;;
			$status = Vend::Util::writefile($file, $data, $opt);
		}
		elsif ($opt->{type} =~ /^debug/) {
			$status = Vend::Util::logDebug($data);
		}
		else {
			$status = Vend::Util::logError($data);
		}
	}
	else {
		$record_delim = $opt->{record_delim} || "\n";
		$delim = $opt->{delimiter} || "\t";
		@lines = split /$record_delim/, $data;
		for(@lines) {
			@fields = split /$delim/, $_;
			$status = logData($file, @fields)
				or last;
		}
	}

	return $status unless $opt->{hide};
	return '';
}

sub _mime_id {
	'<Interchange.' . $::VERSION . '.' .
	$Vend::TIMESTAMP . '.' .
	$Vend::SessionID . '.' .
	++$Vend::Session->{pageCount} . '@' .
	$Vend::Cfg->{VendURL} . '>';
}

sub http_header {
	shift;
	my ($opt, $text) = @_;
	$text =~ s/^\s+//;
	if($opt->{name}) {
		my $name = lc $opt->{name};
		$name =~ s/-/_/g;
		$name =~ s/\W+//g;
		$name =~ tr/_/-/s;
		$name =~ s/(\w+)/\u$1/g;
		my $content = $opt->{content} || $text;
		$content =~ s/^\s+//;
		$content =~ s/\s+$//;
		$content =~ s/[\r\n]/; /g;
		$text = "$name: $content";
	}
	if($Vend::StatusLine and ! $opt->{replace}) {
		$Vend::StatusLine =~ s/\s*$/\r\n/;
		$Vend::StatusLine .= $text;
	}
	else {
		$Vend::StatusLine = $text;
	}
	return $text if $opt->{show};
	return '';
}

sub mvtime {
	my ($locale, $opt, $fmt) = @_;
	my $current;

	if($locale) {
		$current = POSIX::setlocale(&POSIX::LC_TIME);
		POSIX::setlocale(&POSIX::LC_TIME, $locale);
	}

	local($ENV{TZ}) = $opt->{tz} if $opt->{tz};
	
	my $now = $opt->{time} || time();
	$fmt = '%Y%m%d' if $opt->{sortable};

	if($opt->{adjust}) {
		my $neg = $opt->{adjust} =~ s/^\s*-\s*//;
		my $diff;
		$opt->{adjust} =~ s/^\s*\+\s*//;
		if($opt->{hours}) {
			$diff = (60 * 60) * ($opt->{adjust} || $opt->{hours});
		}
		elsif($opt->{adjust} !~ /[A-Za-z]/) {
			$opt->{adjust} =~ s:(\d+)(\d[05])$:$1 + $2 / 60:e;
			$opt->{adjust} =~ s/00$//;
			$diff = (60 * 60) * $opt->{adjust};
		}
		else {
			$diff = Vend::Config::time_to_seconds($opt->{adjust});
		}
		$now = $neg ? $now - $diff : $now + $diff;
	}

	$fmt ||= $opt->{format} || $opt->{fmt} || '%c';
    my $out = $opt->{gmt} ? ( POSIX::strftime($fmt, gmtime($now)    ))
                          : ( POSIX::strftime($fmt, localtime($now) ));
	$out =~ s/\b0(\d)\b/$1/g if $opt->{zerofix};
	POSIX::setlocale(&POSIX::LC_TIME, $current) if defined $current;
	return $out;
}

use vars qw/ %Tag_op_map /;
%Tag_op_map = (
			PRAGMA	=> \&pragma,
			FLAG	=> \&flag,
			LOG		=> \&log,
			TIME	=> \&mvtime,
			HEADER	=> \&http_header,
			EXPORT	=> \&tag_export,
			TOUCH	=> sub {1},
			EACH	=> sub {
							my $table = shift;
							my $opt = shift;
							$opt->{search} = "ra=yes\nst=db\nml=100000\nfi=$table";
#::logDebug("tag each: table=$table opt=" . uneval($opt));
							return tag_loop_list('', $opt, shift);
						},
			MIME	=> \&mime,
			SHOW_TAGS	=> \&show_tags,
		);

sub do_tag {
	my $op = uc $_[0];
#::logDebug("tag op: op=$op opt=" . uneval(\@_));
	return $_[3] if !  defined $Tag_op_map{$op};
	shift;
#::logDebug("tag args now: op=$op opt=" . uneval(\@_));
	return &{$Tag_op_map{$op}}(@_);
}

sub tag_counter {
    my $file = shift || 'etc/counter';
	my $opt = shift;
#::logDebug("counter: file=$file start=$opt->{start} sql=$opt->{sql} caller=" . scalar(caller()) );
	if($opt->{sql}) {
		my ($tab, $seq) = split /:+/, $opt->{sql}, 2;
		my $db = database_exists_ref($tab);
		my $dbh;
		my $dsn;
		if($opt->{bypass}) {
			$dsn = $opt->{dsn} || $ENV{DBI_DSN};
			$dbh = DBI->connect(
						$dsn,
						$opt->{user},
						$opt->{pass},
						$opt->{attr},
					);
		}
		elsif($db) {
			$dbh = $db->dbh();
			$dsn = $db->config('DSN');
		}

		my $val;

		eval {
			my $diemsg = errmsg(
							"Counter sequence '%s' failed, using file.\n",
							$opt->{sql},
						);
			if(! $dbh) {
				die errmsg(
						"No database handle for counter sequence '%s', using file.",
						$opt->{sql},
					);
			} 
			elsif($dsn =~ /^dbi:mysql:/i) {
				$seq ||= $tab;
				$dbh->do("INSERT INTO $seq VALUES (0)")		or die $diemsg;
				my $sth = $dbh->prepare("select LAST_INSERT_ID()")
					or die $diemsg;
				$sth->execute()								or die $diemsg;
				($val) = $sth->fetchrow_array;
			}
			elsif($dsn =~ /^dbi:Pg:/i) {
				my $sth = $dbh->prepare("select nextval('$seq')")
					or die $diemsg;
				$sth->execute()
					or die $diemsg;
				($val) = $sth->fetchrow_array;
			}
			elsif($dsn =~ /^dbi:Oracle:/i) {
				my $sth = $dbh->prepare("select $seq.nextval from dual")
					or die $diemsg;
				$sth->execute()
					or die $diemsg;
				($val) = $sth->fetchrow_array;
			}

		};

		logOnce('error', $@) if $@;

		return $val if defined $val;
	}

	unless (allowed_file($file)) {
		log_file_violation ($file, 'counter');
		return undef;
	}
	
    $file = $Vend::Cfg->{VendRoot} . "/$file"
        unless Vend::Util::file_name_is_absolute($file);
    my $ctr = new Vend::CounterFile $file, $opt->{start} || undef;
    return $ctr->value() if $opt->{value};
    return $ctr->dec() if $opt->{decrement};
    return $ctr->inc();
}

# Returns the text of a user entered field named VAR.
sub tag_value_extended {
    my($var, $opt) = @_;

	my $yes = $opt->{yes} || 1;
	my $no = $opt->{'no'} || '';

	if($opt->{test}) {
		$opt->{test} =~ /(?:is)?put/i
			and
			return defined $CGI::put_ref ? $yes : $no;
		$opt->{test} =~ /(?:is)?file/i
			and
			return defined $CGI::file{$var} ? $yes : $no;
		$opt->{test} =~ /defined/i
			and
			return defined $CGI::values{$var} ? $yes : $no;
		return length $CGI::values{$var}
			if $opt->{test} =~ /length|size/i;
		return '';
	}

	if($opt->{put_contents}) {
		return undef if ! defined $CGI::put_ref;
		return $$CGI::put_ref;
	}

	my $val = $CGI::values{$var} || $::Values->{$var} || return undef;
	$val =~ s/</&lt;/g unless $opt->{enable_html};
	$val =~ s/\[/&#91;/g unless $opt->{enable_itl};
	
	if($opt->{file_contents}) {
		return '' if ! defined $CGI::file{$var};
		return $CGI::file{$var};
	}

	if($opt->{put_ref}) {
		return $CGI::put_ref;
	}

	if($opt->{outfile}) {
		my $file = $opt->{outfile};
		$file =~ s/^\s+//;
		$file =~ s/\s+$//;
		if($file =~ m{^([A-Za-z]:)?[\\/.]}) {
			logError("attempt to write absolute file $file");
			return '';
		}
		if($opt->{ascii}) {
			my $replace = $^O =~ /win32/i ? "\r\n" : "\n";
			if($CGI::file{$var} !~ /\n/) {
				# Must be a mac file.
				$CGI::file{$var} =~ s/\r/$replace/g;
			}
			elsif ( $CGI::file{$var} =~ /\r\n/) {
				# Probably a PC file
				$CGI::file{$var} =~ s/\r\n/$replace/g;
			}
			else {
				$CGI::file{$var} =~ s/\n/$replace/g;
			}
		}
		if($opt->{maxsize} and length($CGI::file{$var}) > $opt->{maxsize}) {
			logError(
				"Uploaded file write of %s bytes greater than maxsize %s. Aborted.",
				length($CGI::file{$var}),
				$opt->{maxsize},
			);
			return $opt->{no} || '';
		}
#::logDebug(">$file \$CGI::file{$var}" . uneval($opt)); 
		Vend::Util::writefile(">$file", \$CGI::file{$var}, $opt)
			and return $opt->{yes} || '';
		return $opt->{'no'} || '';
	}

	my $joiner;
	if (defined $opt->{joiner}) {
		$joiner = $opt->{joiner};
		if($joiner eq '\n') {
			$joiner = "\n";
		}
		elsif($joiner =~ m{\\}) {
			$joiner = $ready_safe->reval("qq{$joiner}");
		}
	}
	else {
		$joiner = ' ';
	}

	my $index = defined $opt->{'index'} ? $opt->{'index'} : '*';

	$index = '*' if $index =~ /^\s*\*?\s*$/;

	my @ary;
	if (!ref $val) {
		@ary = split /\0/, $val;
	}
	elsif($val =~ /ARRAY/) {
		@ary = @$val;
	}
	else {
		logError( "value-extended %s: passed non-scalar, non-array object", $var);
	}

	return join " ", 0 .. $#ary if $opt->{elements};

	eval {
		@ary = @ary[$ready_safe->reval( $index eq '*' ? "0 .. $#ary" : $index )];
	};
	logError("value-extended $var: bad index") if $@;

	if($opt->{filter}) {
		for(@ary) {
			$_ = filter_value($opt->{filter}, $_, $var);
		}
	}
	return join $joiner, @ary;
}

sub format_auto_transmission {
	my $ref = shift;

	## Auto-transmission from Vend::Data::update_data
	## Looking for structure like:
	##
	##	[ '### BEGIN submission from', 'ckirk' ],
	##	[ 'username', 'ckirk' ],
	##	[ 'field2', 'value2' ],
	##	[ 'field1', 'value1' ],
	##	[ '### END submission from', 'ckirk' ],
	##	[ 'mv_data_fields', [ username, field1, field2 ]],
	##

	return $ref unless ref($ref);

	my $body = '';
	my %message;
	my $header  = shift @$ref;
	my $fields  = pop   @$ref;
	my $trailer = pop   @$ref;

	$body .= "$header->[0]: $header->[1]\n";

	for my $line (@$ref) {
		$message{$line->[0]} = $line->[1];
	}

	my @order;
	if(ref $fields->[1]) {
		@order = @{$fields->[1]};
	}
	else {
		@order = sort keys %message;
	}

	for (@order) {
		$body .= "$_: ";
		if($message{$_} =~ s/\r?\n/\n/g) {
			$body .= "\n$message{$_}\n";
		}
		else {
			$body .= $message{$_};
		}
		$body .= "\n";
	}

	$body .= "$trailer->[0]: $trailer->[1]\n";
	return $body;
}

sub tag_mail {
    my($to, $opt, $body) = @_;
    my($ok);

	my @todo = (
					qw/
						From      
						To		   
						Subject   
						Reply-To  
						Errors-To 
					/
	);

	my $abort;
	my $check;

	my $setsub = sub {
		my $k = shift;
		return if ! defined $CGI::values{"mv_email_$k"};
		$abort = 1 if ! $::Scratch->{mv_email_enable};
		$check = 1 if $::Scratch->{mv_email_enable};
		return $CGI::values{"mv_email_$k"};
	};

	my @headers;
	my %found;

	unless($opt->{raw}) {
		for my $header (@todo) {
			logError("invalid email header: %s", $header)
				if $header =~ /[^-\w]/;
			my $key = lc $header;
			$key =~ tr/-/_/;
			my $val = $opt->{$key} || $setsub->($key); 
			if($key eq 'subject' and ! length($val) ) {
				$val = errmsg('<no subject>');
			}
			next unless length $val;
			$found{$key} = $val;
			$val =~ s/^\s+//;
			$val =~ s/\s+$//;
			$val =~ s/[\r\n]+\s*(\S)/\n\t$1/g;
			push @headers, "$header: $val";
		}
		unless($found{to} or $::Scratch->{mv_email_enable} =~ /\@/) {
			return
				error_opt($opt, "Refuse to send email message with no recipient.");
		}
		elsif (! $found{to}) {
			$::Scratch->{mv_email_enable} =~ s/\s+/ /g;
			$found{to} = $::Scratch->{mv_email_enable};
			push @headers, "To: $::Scratch->{mv_email_enable}";
		}
	}

	if($opt->{extra}) {
		$opt->{extra} =~ s/^\s+//mg;
		$opt->{extra} =~ s/\s+$//mg;
		push @headers, grep /^\w[-\w]*:/, split /\n/, $opt->{extra};
	}

	$body ||= $setsub->('body');
	unless($body) {
		return error_opt($opt, "Refuse to send email message with no body.");
	}

	$body = format_auto_transmission($body) if ref $body;

	push(@headers, '') if @headers;

	return error_opt("mv_email_enable not set, required.") if $abort;
	if($check and $found{to} ne $Scratch->{mv_email_enable}) {
		return error_opt(
				"mv_email_enable to address (%s) doesn't match enable (%s)",
				$found{to},
				$Scratch->{mv_email_enable},
			);
	}

    SEND: {
		$ok = send_mail(\@headers, $body);
    }

    if (!$ok) {
		close MAIL;
		$body = substr($body, 0, 2000) if length($body) > 2000;
        return error_opt(
					"Unable to send mail using %s\n%s",
					$Vend::Cfg->{SendMailProgram},
					join("\n", @headers, $body),
				);
	}

	delete $Scratch->{mv_email_enable} if $check;
	return if $opt->{hide};
	return join("\n", @headers, $body) if $opt->{show};
    return ($opt->{success} || $ok);
}

# Returns the text of a user entered field named VAR.
sub tag_value {
    my($var,$opt) = @_;
#::logDebug("called value args=" . uneval(\@_));
    my($value);

	local($^W) = 0;
	$::Values->{$var} = $opt->{set} if defined $opt->{set};
	$value = defined $::Values->{$var} ? ($::Values->{$var}) : '';
    if ($value) {
		# Eliminate any Interchange tags
		$value =~ s~<([A-Za-z]*[^>]*\s+[Mm][Vv]\s*=\s*)~&lt;$1~g;
		$value =~ s/\[/&#91;/g;
    }
	if($opt->{filter}) {
		$value = filter_value($opt->{filter}, $value, $var);
		$::Values->{$var} = $value unless $opt->{keep};
	}
	$::Scratch->{$var} = $value if $opt->{scratch};
	return '' if $opt->{hide};
    return $opt->{default} if ! $value and defined $opt->{default};
	$value =~ s/</&lt;/g
		unless $opt->{enable_html};
    return $value;
}

sub esc {
	my $string = shift;
	$string =~ s!(\W)!'%' . sprintf '%02x', ord($1)!eg;
	return $string;
}

# Escapes a scan reliably in three different possible ways
sub escape_scan {
	my ($scan, $ref) = @_;
#::logDebug("escape_scan: scan=$scan");
	if (ref $scan) {
		for(@$scan) {
			my $add = '';
			$_ = "se=$_" unless /[=\n]/;
			$add .= "\nos=0"  unless m{^\s*os=}m;
			$add .= "\nne=0"  unless m{^\s*ne=}m;
			$add .= "\nop=rm" unless m{^\s*op=}m;
			$add .= "\nbs=0"  unless m{^\s*bs=}m;
			$add .= "\nsf=*"  unless m{^\s*sf=}m;
			$add .= "\ncs=0"  unless m{^\s*cs=}m;
			$add .= "\nsg=0"  unless m{^\s*sg=}m;
			$add .= "\nnu=0"  unless m{^\s*nu=}m;
			$_ .= $add;
		}
		$scan = join "\n", @$scan;
		$scan .= "\nco=yes" unless m{^\s*co=}m;
#::logDebug("escape_scan: scan=$scan");
	}

	if($scan =~ /^\s*(?:sq\s*=\s*)?select\s+/im) {
		eval {
			$scan = Vend::Scan::sql_statement($scan, $ref || \%CGI::values)
		};
		if($@) {
			my $msg = errmsg("SQL query failed: %s\nquery was: %s", $@, $scan);
			logError($msg);
			$scan = 'se=BAD_SQL';
		}
	}

	return join '/', 'scan', escape_mv('/', $scan);
}

sub escape_form {
	my $val = shift;

	$val =~ s/^\s+//mg;
	$val =~ s/\s+$//mg;

	## Already escaped, return
	return $val if $val =~ /^\S+=\S+=\S*$/;

	my @args = split /\n+/, $val;

	for(@args) {
		s/^(.*?=)(.+)/$1 . Vend::Util::unhexify($2)/ge;
	}

	for(@args) {
		next if /^[\w=]+$/;
		s!\0!-_NULL_-!g;
		s!([^=]+)=(.*)!esc($1) . '=' . esc($2)!eg
			or (undef $_, next);
	}
	return join $Global::UrlJoiner, grep length($_), @args;
}

sub escape_mv {
	my ($joiner, $scan, $not_scan, $esc) = @_;

	my @args;

	if(index($scan, "\n") != -1) {
		$scan =~ s/^\s+//mg;
		$scan =~ s/\s+$//mg;
		@args = split /\n+/, $scan;
	}
	elsif($scan =~ /&\w\w=/) {
		@args = split /&/, $scan;
	}
	else {
		$scan =~ s!::!__ESLASH__!g;
		@args  = split m:/:, $scan;
	}
	@args = grep $_, @args;
	for(@args) {
		s!/!__SLASH__!g unless defined $not_scan;
		s!\0!-_NULL_-!g;
		m!\w=!
		    or (undef $_, next);
		s!__SLASH__!::!g unless defined $not_scan;
	}
	return join $joiner, grep(defined $_, @args);
}

*form_link = \&tag_area;

PAGELINK: {

my ($urlroutine, $page, $arg, $opt);

sub static_url {
	return $Vend::Cfg->{StaticPath} . "/" . shift;
}

sub resolve_static {
#::logDebug("entering resolve_static...");
	return if ! $Vend::Cookie;
#::logDebug("have cookie...");
	return if ! $Vend::Cfg->{Static};
#::logDebug("are static...");
	my $key = Vend::Util::escape_chars_url($page);
	if($arg) {
		my $tmp = $arg;
		$tmp =~ s:([^\w/]): sprintf '%%%02x', ord($1) :eg;
		$key .= "/$arg";
	}
#::logDebug("checking $key...");

	if(defined $Vend::StaticDBM{$key}) {
#::logDebug("found DBM $key...");
		$page = $Vend::StaticDBM{$key} || "$key$Vend::Cfg->{StaticSuffix}";
	}
	elsif(defined $Vend::Cfg->{StaticPage}{$key}) {
#::logDebug("found StaticPage $key...");
		$page = $Vend::Cfg->{StaticPage}{$key} || "$key$Vend::Cfg->{StaticSuffix}";
	}
	else {
#::logDebug("not found $key...");
		return;
	}
	$urlroutine = \&static_url;
	return;
}

sub tag_page {
    my ($page, $arg, $opt) = @_;

	my $url = tag_area(@_);

	my $extra;
	if($extra = ($opt ||= {})->{extra} || '') {
		$extra =~ s/^(\w+)$/class=$1/;
		$extra = " $extra";
	}
    return qq{<a href="$url"$extra>};
}

# Returns an href which will call up the specified PAGE.

sub tag_area {
    ($page, $arg, $opt) = @_;

	$page = '' if ! defined $page;

	if( $page and $opt->{alias}) {
		my $aloc = $opt->{once} ? 'one_time_path_alias' : 'path_alias';
		$Vend::Session->{$aloc}{$page} = {}
			if not defined $Vend::Session->{path_alias}{$page};
		$Vend::Session->{$aloc}{$page} = $opt->{alias};
	}

	if ($opt->{search}) {
		$page = escape_scan($opt->{search});
	}
	elsif ($page =~ /^[a-z][a-z]+:/) {
		### Javascript or absolute link
		return $page;
	}
	elsif ($page eq 'scan') {
		$page = escape_scan($arg);
		undef $arg;
	}

	$urlroutine = $opt->{secure} ? \&secure_vendUrl : \&vendUrl;

	resolve_static();

	my $anchor = '';
	if($opt->{anchor}) {
		$anchor = '#' . $opt->{anchor};
	}
	return $urlroutine->($page, $arg, undef, $opt) . $anchor;
}

}

# Sets the default shopping cart for display
sub tag_cart {
	$Vend::CurrentCart = shift;
	return '';
}

# Returns the shipping description.

sub tag_shipping_desc {
	my $mode = 	shift;
	$mode = $mode || $::Values->{mv_shipmode} || 'default';
	return '' unless defined $Vend::Cfg->{Shipping_desc}{$mode};
	return errmsg($Vend::Cfg->{Shipping_desc}{$mode});
}

sub tag_calc {
	my($body) = @_;
	my $result;
	if($Vend::NoInterpolate) {
		logGlobal({ level => 'alert' },
					"Attempt to interpolate perl/ITL from RPC, no permissions."
					);
	}

	$Items = $Vend::Items;

	if($MVSAFE::Safe) {
		$result = eval($body);
	}
	else {
		init_calc() if ! $Vend::Calc_initialized;
		$result = $ready_safe->reval($body);
	}

	if ($@) {
		my $msg = $@;
		$Vend::Session->{try}{$Vend::Try} = $msg if $Vend::Try;
		logGlobal({ level => 'debug' }, "Safe: %s\n%s\n" , $msg, $body);
		logError("Safe: %s\n%s\n" , $msg, $body);
		return $MVSAFE::Safe ? '' : 0;
	}
	return $result;
}

sub tag_unless {
	return tag_self_contained_if(@_, 1) if defined $_[4];
	return tag_if(@_, 1);
}

sub tag_self_contained_if {
	my($base, $term, $operator, $comp, $body, $negate) = @_;

	my ($else,$elsif,@addl);
	
	local($^W) = 0;
#::logDebug("self_if: base=$base term=$term op=$operator comp=$comp");
	if ($body =~ s#$QR{condition_begin}##) {
		$comp = $1;
	}
#::logDebug("self_if: base=$base term=$term op=$operator comp=$comp");

	if ( $body =~ /\[[EeTtAaOo][hHLlNnRr][SsEeDd\s]/ ) {
		($body, $elsif, $else, @addl) = split_if($body);
	}

#::logDebug("Additional ops found:\n" . join("\n", @addl) ) if @addl;

	unless(defined $operator || defined $comp) {
		$comp = '';
		undef $operator;
		undef $comp;
	}

	($base =~ s/^\W+// or $base = "!$base") if $negate;

	my $status = conditional ($base, $term, $operator, $comp, @addl);

	my $out;
	if($status) {
		$out = $body;
	}
	elsif ($elsif) {
		$else = '[else]' . $else . '[/else]' if length $else;
		$elsif =~ s#(.*?)$QR{'/elsif'}(.*)#$1${2}[/elsif]#s;
		$out = '[if ' . $elsif . $else . '[/if]';
	}
	elsif (length $else) {
		$out = $else;
	}
	else {
		return '';
	}

	return $out;
}

my %cond_op = (
	eq  => sub { $_[0] eq $_[1] },
	ne  => sub { $_[0] ne $_[1] },
	gt  => sub { $_[0] gt $_[1] },
	ge  => sub { $_[0] ge $_[1] },
	le  => sub { $_[0] le $_[1] },
	lt  => sub { $_[0] lt $_[1] },
   '>'  => sub { $_[0]  > $_[1] },
   '<'  => sub { $_[0]  < $_[1] },
   '>=' => sub { $_[0] >= $_[1] },
   '<=' => sub { $_[0] <= $_[1] },
   '==' => sub { $_[0] == $_[1] },
   '!=' => sub { $_[0] != $_[1] },
   '=~' => sub { 
   				 my $re;
				 $_[1] =~ s:^/(.*)/([imsx]*)\s*$:$1:;
				 $2 and substr($_[1], 0, 0) = "(?$2)";
   				 eval { $re = qr/$_[1]/ };
				 if($@) {
					logError("bad regex %s in if-PREFIX-data", $_[1]);
					return undef;
				 }
				 return $_[0] =~ $re;
				},
   '!~' => sub { 
   				 my $re;
				 $_[1] =~ s:^/(.*)/([imsx]*)\s*$:$1:;
				 $2 and substr($_[1], 0, 0) = "(?$2)";
   				 eval { $re = qr/$_[1]/ };
				 if($@) {
					logError("bad regex %s in if-PREFIX-data", $_[1]);
					return undef;
				 }
				 return $_[0] !~ $re;
				},
);

sub pull_cond {
	my($string, $reverse, $cond, $lhs) = @_;
#::logDebug("pull_cond string='$string' rev='$reverse' cond='$cond' lhs='$lhs'");
	my ($op, $rhs) = split /\s+/, $cond, 2;
	$rhs =~ s/^(["'])(.*)\1$/$2/;
	if(! defined $cond_op{$op} ) {
		logError("bad conditional operator %s in if-PREFIX-data", $op);
		return pull_else($string, $reverse);
	}
	return 	$cond_op{$op}->($lhs, $rhs)
			? pull_if($string, $reverse)
			: pull_else($string, $reverse);
}

sub pull_if {
	return pull_cond(@_) if $_[2];
	my($string, $reverse) = @_;
	return pull_else($string) if $reverse;
	find_matching_else(\$string) if $string =~ s:$QR{has_else}::;
	return $string;
}

sub pull_else {
	return pull_cond(@_) if $_[2];
	my($string, $reverse) = @_;
	return pull_if($string) if $reverse;
	return find_matching_else(\$string) if $string =~ s:$QR{has_else}::;
	return;
}

## ORDER PAGE

my (@Opts);
my (@Flds);
my %Sort = (

	''	=> sub { $_[0] cmp $_[1]				},
	none	=> sub { $_[0] cmp $_[1]				},
	f	=> sub { (lc $_[0]) cmp (lc $_[1])	},
	fr	=> sub { (lc $_[1]) cmp (lc $_[0])	},
    l  => sub {
            my ($a1,$a2) = split /[,.]/, $_[0], 2;
            my ($b1,$b2) = split /[,.]/, $_[1], 2;
            return $a1 <=> $b1 || $a2 <=> $b2;
    },  
    lr  => sub {
            my ($a1,$a2) = split /[,.]/, $_[0], 2;
            my ($b1,$b2) = split /[,.]/, $_[1], 2;
            return $b1 <=> $a1 || $b2 <=> $a2;
    },      
	n	=> sub { $_[0] <=> $_[1]				},
	nr	=> sub { $_[1] <=> $_[0]				},
	r	=> sub { $_[1] cmp $_[0]				},
);

@Sort{qw/rf rl rn/} = @Sort{qw/fr lr nr/};

use vars qw/%Sort_field/;
%Sort_field = %Sort;

sub tag_sort_ary {
    my($opts, $list) = (@_); 
    $opts =~ s/^\s+//; 
    $opts =~ s/\s+$//; 
#::logDebug("tag_sort_ary: opts=$opts list=" . uneval($list));
	my @codes;
	my $key = 0;

	my ($start, $end, $num);
	my $glob_opt = 'none';

    my @opts =  split /\s+/, $opts;
    my @option; my @bases; my @fields;

    for(@opts) {
        my ($base, $fld, $opt) = split /:/, $_;

		if($base =~ /^(\d+)$/) {
			$key = $1;
			$glob_opt = $fld || $opt || 'none';
			next;
		}
		if($base =~ /^([-=+])(\d+)-?(\d*)/) {
			my $op = $1;
			if    ($op eq '-') { $start = $2 }
			elsif ($op eq '+') { $num   = $2 }
			elsif ($op eq '=') {
				$start = $2;
				$end = ($3 || undef);
			}
			next;
		}
		
        push @bases, $base;
        push @fields, $fld;
        push @option, (defined $Vend::Interpolate::Sort_field{$opt} ? $opt : 'none');
    }

	if(defined $end) {
		$num = 1 + $end - $start;
		$num = undef if $num < 1;
 	}

    my $i;
    my $routine = 'sub { ';
	for( $i = 0; $i < @bases; $i++) {
			$routine .= '&{$Vend::Interpolate::Sort_field{"' .
						$option[$i] .
						'"}}(' . "\n";
			$routine .= "tag_data('$bases[$i]','$fields[$i]', \$_[0]->[$key]),\n";
			$routine .= "tag_data('$bases[$i]','$fields[$i]', \$_[1]->[$key]) ) or ";
	}
	$routine .= qq!0 or &{\$Vend::Interpolate::Sort_field{"$glob_opt"}}!;
	$routine .= '($_[0]->[$key],$_[1]->[$key]); }';
#::logDebug("tag_sort_ary routine: $routine\n");

    my $code = eval $routine;  
    die "Bad sort routine\n" if $@;

	#Prime the sort? Prevent variable suicide??
	#&{$Vend::Interpolate::Sort_field{'n'}}('31', '30');

	use locale;
	if($::Scratch->{mv_locale}) {
		POSIX::setlocale(POSIX::LC_COLLATE(),
			$::Scratch->{mv_locale});
	}

	@codes = sort {&$code($a, $b)} @$list;

	if(defined $start and $start > 1) {
		splice(@codes, 0, $start - 1);
	}

	if(defined $num) {
		splice(@codes, $num);
	}
#::logDebug("tag_sort_ary routine returns: " . uneval(\@codes));
	return \@codes;
}

sub tag_sort_hash {
    my($opts, $list) = (@_); 
    $opts =~ s/^\s+//; 
    $opts =~ s/\s+$//; 
#::logDebug("tag_sort_hash: opts=$opts list=" . uneval($list));
	my @codes;
	my $key = 'code';

	my ($start, $end, $num);
	my $glob_opt = 'none';

    my @opts =  split /\s+/, $opts;
    my @option; my @bases; my @fields;

    for(@opts) {

		if(/^(\w+)(:([flnr]+))?$/) {
			$key = $1;
			$glob_opt = $3 || 'none';
			next;
		}
		if(/^([-=+])(\d+)-?(\d*)/) {
			my $op = $1;
			if    ($op eq '-') { $start = $2 }
			elsif ($op eq '+') { $num   = $2 }
			elsif ($op eq '=') {
				$start = $2;
				$end = ($3 || undef);
			}
			next;
		}
        my ($base, $fld, $opt) = split /:/, $_;
		
        push @bases, $base;
        push @fields, $fld;
        push @option, (defined $Vend::Interpolate::Sort_field{$opt} ? $opt : 'none');
    }

	if(defined $end) {
		$num = 1 + $end - $start;
		$num = undef if $num < 1;
 	}

	if (! defined $list->[0]->{$key}) {
		logError("sort key '$key' not defined in list. Skipping sort.");
		return $list;
	}

    my $i;
    my $routine = 'sub { ';
	for( $i = 0; $i < @bases; $i++) {
			$routine .= '&{$Vend::Interpolate::Sort_field{"' .
						$option[$i] .
						'"}}(' . "\n";
			$routine .= "tag_data('$bases[$i]','$fields[$i]', \$_[0]->{$key}),\n";
			$routine .= "tag_data('$bases[$i]','$fields[$i]', \$_[1]->{$key}) ) or ";
	}
	$routine .= qq!0 or &{\$Vend::Interpolate::Sort_field{"$glob_opt"}}!;
	$routine .= '($a->{$key},$_[1]->{$key}); }';

#::logDebug("tag_sort_hash routine: $routine\n");
    my $code = eval $routine;  
    die "Bad sort routine\n" if $@;

	#Prime the sort? Prevent variable suicide??
	#&{$Vend::Interpolate::Sort_field{'n'}}('31', '30');

	use locale;
	if($::Scratch->{mv_locale}) {
		POSIX::setlocale(POSIX::LC_COLLATE(),
			$::Scratch->{mv_locale});
	}

	@codes = sort {&$code($a,$b)} @$list;

	if(defined $start and $start > 1) {
		splice(@codes, 0, $start - 1);
	}

	if(defined $num) {
		splice(@codes, $num);
	}
#::logDebug("tag_sort_hash routine returns: " . uneval(\@codes));
	return \@codes;
}

my %Prev;

sub check_change {
	my($name, $value, $text, $substr) = @_;
	# $value is case-sensitive flag if passed text;
	if(defined $text) {
		$text =~ s:$QR{condition}::;
		$value = $value ? lc $1 : $1;
	}
	$value = substr($value, 0, $substr) if $substr;
	my $prev = $Prev{$name} || undef;
	$Prev{$name} = $value || '';
	if(defined $text) {
		return pull_if($text) if ! defined $prev or $value ne $prev;
		return pull_else($text);
	}
	return 1 unless defined $prev;
	return $value eq $prev ? 0 : 1;
}

sub list_compat {
	my $prefix = shift;
	my $textref = shift;

	$$textref =~ s:\[if[-_]data\s:[if-$prefix-data :gi
		and $$textref =~ s:\[/if[-_]data\]:[/if-$prefix-data]:gi;

	$$textref =~ s:\[if[-_]modifier\s:[if-$prefix-modifier :gi
		and $$textref =~ s:\[/if[-_]modifier\]:[/if-$prefix-modifier]:gi;

	$$textref =~ s:\[if[-_]field\s:[if-$prefix-field :gi
		and $$textref =~ s:\[/if[-_]field\]:[/if-$prefix-field]:gi;

	$$textref =~ s:\[on[-_]change\s:[$prefix-change :gi
		and $$textref =~ s:\[/on[-_]change\s:[/$prefix-change :gi;

	return;
}

sub tag_search_region {
	my($params, $opt, $text) = @_;
	$opt->{search} = $params if $params;
	$opt->{prefix}      = 'item'           if ! defined $opt->{prefix};
	$opt->{list_prefix} = 'search[-_]list' if ! defined $opt->{list_prefix};
# LEGACY
	list_compat($opt->{prefix}, \$text);
# END LEGACY
	return region($opt, $text);
}

sub find_sort {
	my($text) = @_;
	return undef unless defined $$text and $$text =~ s#\[sort(([\s\]])[\000-\377]+)#$1#io;
	my $options = find_close_square($$text);
	$$text = substr( $$text,length($options) + 1 )
				if defined $options;
	$options = interpolate_html($options) if index($options, '[') != -1;
	return $options || '';
}

# Artificial for better variable passing
{
	my( $next_anchor,
		$prev_anchor,
		$page_anchor,
		$border,
		$border_selected,
		$opt,
		$r,
		$chunk,
		$total,
		$current,
		$page,
		$prefix,
		$more_id,
		$session,
		$link_template,
		);

sub more_link_template {
	my ($anchor, $arg, $form_arg) = @_;

	my $url = tag_area("scan/MM=$arg", '', {
	    form => $form_arg,
	    secure => $CGI::secure,
	});

	my $lt = $link_template;
	$lt =~ s/\$URL\$/$url/g;
	$lt =~ s/\$ANCHOR\$/$anchor/g;
	return $lt;
}

sub more_link {
	my($inc, $pa) = @_;
	my ($next, $last, $arg);
	my $list = '';
	$pa =~ s/__PAGE__/$inc/g;
	my $form_arg = "mv_more_ip=1\nmv_nextpage=$page";
	$form_arg .= "\npf=$prefix" if $prefix;
	$form_arg .= "\nmi=$prefix" if $more_id;
	$form_arg .= "\n$opt->{form}" if $opt->{form};
	$next = ($inc-1) * $chunk;
#::logDebug("more_link: inc=$inc current=$current");
	$last = $next + $chunk - 1;
	$last = ($last+1) < $total ? $last : ($total - 1);
	$pa =~ s/__PAGE__/$inc/g;
	$pa =~ s/__MINPAGE__/$next + 1/eg;
	$pa =~ s/__MAXPAGE__/$last + 1/eg;
	if($inc == $current) {
		$pa =~ s/__BORDER__/$border_selected || $border || ''/e;
		$list .= qq|<STRONG>$pa</STRONG> | ;
	}
	else {
		$pa =~ s/__BORDER__/$border/e;
		$arg = "$session:$next:$last:$chunk";
		$list .= more_link_template($pa, $arg, $form_arg) . ' ';
	}
	return $list;
}

sub tag_more_list {
	(
		$next_anchor,
		$prev_anchor,
		$page_anchor,
		$border,
		$border_selected,
		$opt,
		$r,
	) = @_;
#::logDebug("more_list: opt=$opt label=$opt->{label}");
	return undef if ! $opt;
	$q = $opt->{object} || $::Instance->{SearchObject}{$opt->{label}};
	return '' unless $q->{matches} > $q->{mv_matchlimit}
		and $q->{mv_matchlimit} > 0;
	my($arg,$inc,$last,$m);
	my($adder,$pages);
	my($first_anchor,$last_anchor);
	my $next_tag = '';
	my $list = '';
	$session = $q->{mv_cache_key};
	my $first = $q->{mv_first_match} || 0;
	$chunk = $q->{mv_matchlimit};
	$total = $q->{matches};
	my $next = defined $q->{mv_next_pointer}
				? $q->{mv_next_pointer}
				: $first + $chunk;
	$page = $q->{mv_search_page} || $Global::Variable->{MV_PAGE};
	$prefix = $q->{prefix} || '';
	my $form_arg = "mv_more_ip=1\nmv_nextpage=$page";
	$form_arg .= "\npf=$q->{prefix}" if $q->{prefix};
	$form_arg .= "\n$opt->{form}" if $opt->{form};
	if($q->{mv_more_id}) {
		$more_id = $q->{mv_more_id};
		$form_arg .= "\nmi=$more_id";
	}
	else {
		$more_id = undef;
	}

	if($r =~ s:\[border\]($All)\[/border\]::i) {
		$border = $1;
		$border =~ s/\D//g;
	}
	if($r =~ s:\[border[-_]selected\]($All)\[/border[-_]selected\]::i) {
		$border = $1;
		$border =~ s/\D//g;
	}

	if ($r =~ s:\[link[-_]template\]($All)\[/link[-_]template\]::i) {
		$link_template = $1;
	}
	else {
		$link_template = q{<A HREF="$URL$">$ANCHOR$</A>};
	}

	if(! $chunk or $chunk >= $total) {
		return '';
	}

	$border = qq{ BORDER="$border"} if defined $border;
	$border_selected = qq{ BORDER="$border_selected"}
		if defined $border_selected;

	$adder = ($total % $chunk) ? 1 : 0;
	$pages = int($total / $chunk) + $adder;
	$current = int($next / $chunk) || $pages;

	if($first) {
		$first = 0 if $first < 0;

		# First link may appear when prev link is valid
		if($r =~ s:\[first[-_]anchor\]($All)\[/first[-_]anchor\]::i) {
			$first_anchor = $1;
		}
		else {
			$first_anchor = errmsg('First');
		}
		unless ($first_anchor eq 'none') {
			$arg = $session;
			$arg .= ':0:';
			$arg .= $chunk - 1;
			$arg .= ":$chunk";
			$list .= more_link_template($first_anchor, $arg, $form_arg) . ' ';
		}

		unless ($prev_anchor) {
			if($r =~ s:\[prev[-_]anchor\]($All)\[/prev[-_]anchor\]::i) {
				$prev_anchor = $1;
			}
			else {
				$prev_anchor = errmsg('Previous');
			}
		}
		elsif ($prev_anchor ne 'none') {
			$prev_anchor = qq%<IMG SRC="$prev_anchor"$border>%;
		}
		unless ($prev_anchor eq 'none') {
			$arg = $session;
			$arg .= ':';
			$arg .= $first - $chunk;
			$arg .= ':';
			$arg .= $first - 1;
			$arg .= ":$chunk";
			$list .= more_link_template($prev_anchor, $arg, $form_arg) . ' ';
		}

	}
	else {
		$r =~ s:\[(prev|first)[-_]anchor\]$All\[/\1[-_]anchor\]::ig;
	}
	
	if($next) {

		unless ($next_anchor) {
			if($r =~ s:\[next[-_]anchor\]($All)\[/next[-_]anchor\]::i) {
				$next_anchor = $1;
			}
			else {
				$next_anchor = errmsg('Next');
			}
		}
		else {
			$next_anchor = qq%<IMG SRC="$next_anchor"$border>%;
		}
		$last = $next + $chunk - 1;
		$last = $last > ($total - 1) ? $total - 1 : $last;
		$arg = "$session:$next:$last:$chunk";
		$next_tag .= more_link_template($next_anchor, $arg, $form_arg);

 		# Last link can appear when next link is valid
		if($r =~ s:\[last[-_]anchor\]($All)\[/last[-_]anchor\]::i) {
			$last_anchor = $1;
		}
		else {
			$last_anchor = errmsg('Last');
		}
		unless ($last_anchor eq 'none') {
			$last = $total - 1;
			my $last_beg_idx = $total - ($total % $chunk || $chunk);
			$arg = "$session:$last_beg_idx:$last:$chunk";
			$next_tag .= ' ' . more_link_template($last_anchor, $arg, $form_arg);
		}
	}
	else {
		$r =~ s:\[(last|next)[-_]anchor\]$All\[/\1[-_]anchor\]::gi;
	}
	
	unless ($page_anchor) {
		if($r =~ s:\[page[-_]anchor\]($All)\[/page[-_]anchor\]::i) {
			$page_anchor = $1;
		}
		else {
			$page_anchor = '__PAGE__';
		}
	}
	elsif ($page_anchor ne 'none') {
		$page_anchor = qq%<IMG SRC="$page_anchor?__PAGE__"__BORDER__>%;
	}

	$page_anchor =~ s/\$(MIN|MAX)?PAGE\$/__${1}PAGE__/g;

	my $more_string = errmsg('more');
	my ($decade_next, $decade_prev, $decade_div);
	if( $q->{mv_more_decade} or $r =~ m:\[decade[-_]next\]:) {
		$r =~ s:\[decade[-_]next\]($All)\[/decade[-_]next\]::i
			and $decade_next = $1;
		$decade_next = "<SMALL>&#91;$more_string&gt;&gt;&#93;</SMALL>"
			if ! $decade_next;
		$r =~ s:\[decade[-_]prev\]($All)\[/decade[-_]prev\]::i
			and $decade_prev = $1;
		$decade_prev = "<SMALL>&#91;&lt;&lt;$more_string&#93;</SMALL>"
			if ! $decade_prev;
		$decade_div = $q->{mv_more_decade} > 1 ? $q->{mv_more_decade} : 10;
	}

	my ($begin, $end);
	if(defined $decade_div and $pages > $decade_div) {
		if($current > $decade_div) {
			$begin = ( int ($current / $decade_div) * $decade_div ) + 1;
			$list .= " ";
			$list .= more_link($begin - $decade_div, $decade_prev);
		}
		else {
			$begin = 1;
		}
		if($begin + $decade_div <= $pages) {
			$end = $begin + $decade_div;
			$decade_next = more_link($end, $decade_next);
			$end--;
		}
		else {
			$end = $pages;
			undef $decade_next;
		}
#::logDebug("more_list: decade found pages=$pages current=$current begin=$begin end=$end next=$next last=$last decade_div=$decade_div");
	}
	else {
		($begin, $end) = (1, $pages);
		undef $decade_next;
	}
#::logDebug("more_list: pages=$pages current=$current begin=$begin end=$end next=$next last=$last decade_div=$decade_div");

	if ($q->{mv_alpha_list}) {
		for my $record (@{$q->{mv_alpha_list}}) {
			$arg = "$session:$record->[2]:$record->[3]:" . ($record->[3] - $record->[2] + 1);
			my $letters = substr($record->[0], 0, $record->[1]);
			$list .= more_link_template($letters, $arg, $form_arg) . ' ';
		}
	} else {
		foreach $inc ($begin .. $end) {
			last if $page_anchor eq 'none';
			$list .= more_link($inc, $page_anchor);
		}
	}
	$list .= " $decade_next " if defined $decade_next;
	$list .= $next_tag;
	$first = $first + 1;
	$last = $first + $chunk - 1;
	$last = $last > $total ? $total : $last;
	$m = $first . '-' . $last;
	$r =~ s,$QR{more},$list,g;
	$r =~ s,$QR{matches},$m,g;
	$r =~ s,$QR{match_count},$q->{matches},g;

	$r;

}

}

sub sort_cart {
	my($options, $cart) = @_;
	my ($item,$code);
	my %order; my @codes; my @out;
	my $sort_order;
	foreach $item  (@$cart) {
		$code = $item->{code};
		$order{$code} = [] unless defined $order{$code};
		push @{$order{$code}}, $item;
		push @codes, $code;
	}

	$sort_order = tag_sort_hash($options, \@codes);

	foreach $code (@$sort_order) {
		push @out, @{$order{$code}};
	}
	return \@out;
}

# Naming convention
# Ld  Label Data
# B   Begin
# E   End
# D   Data
# I   If
my $LdD = qr{\s+([-\w:#/.]+)\]};
my $LdI = qr{\s+([-\w:#/.]+)$Optr\]($Some)};
my $LdB;
my $LdIB;
my $LdIE;
my $LdExpr;
my $B;
my $E;
my $IB;
my $IE;
my $Prefix;
my $Orig_prefix;

sub tag_labeled_data_row {
	my ($key, $text) = @_;
	my ($row, $table, $tabRE);
	my $done;
	my $prefix;
	if(defined $Prefix) {
		$prefix = $Prefix;
		undef $Prefix;
		$LdB = qr(\[$prefix[-_]data$Spacef)i;
		$LdIB = qr(\[if[-_]$prefix[-_]data(\d*)$Spacef(!?)(?:%20|\s)*)i;
		$LdIE = qr(\[/if[-_]$prefix[-_]data)i;
		$LdExpr = qr{ \[(?:$prefix[-_]data|if[-_]$prefix[-_]data(\d*))
	                \s+ !?\s* ($Codere) \s
					(?!$All\[(?:$prefix[-_]data|if[-_]$prefix[-_]data\1))  }xi;
		%Data_cache = ();
	}
	# Want the last one
#::logDebug(<<EOF);
#tag_labeled_data_row:
#	prefix=$prefix
#	LdB   =$LdB
#	LdIB  =$LdIB
#	LdIE  =$LdIE
#	LdD   =$LdD
#	LdI   =$LdI
#	LdExpr=$LdExpr
#EOF

    while($$text =~ $LdExpr) {
		$table = $2;
		$tabRE = qr/$table/;
		$row = $Data_cache{"$table.$key"}
				|| ( $Data_cache{"$table.$key"}
						= Vend::Data::database_row($table, $key)
					)
				|| {};
		$done = 1;
		$$text =~ s#$LdIB$tabRE$LdI$LdIE\1\]#
					$row->{$3}	? pull_if($5,$2,$4,$row->{$3})
								: pull_else($5,$2,$4,$row->{$3})#ge
			and undef $done;
#::logDebug("after if: table=$table 1=$1 2=$2 3=$3 $$text =~ s#$LdIB $tabRE $LdI $LdIE#");

		$$text =~ s/$LdB$tabRE$LdD/ed($row->{$1})/eg
			and undef $done;
		last if $done;
	}
	return $_;
}

sub random_elements {
	my($ary, $wanted) = @_;
	$wanted = 1 if ! $wanted || $wanted =~ /\D/;
	return undef unless ref $ary;
	my %seen;
	my ($j, @out);
	my $count = scalar @$ary;
	return (0 .. $#$ary) if $count <= $wanted;
	for($j = 0; $j < $wanted; $j++) {
		my $cand = int rand($count);
		redo if $seen{$cand}++;
		push(@out, $cand);
	}
	return (@out);
}

my $opt_select;
my $opt_table;
my $opt_field;
my $opt_value;

sub labeled_list {
    my($opt, $text, $obj) = @_;
	my($count);
	$obj = $opt->{object} if ! $obj;
	return '' if ! $obj;

	my $ary = $obj->{mv_results};
	return if (! $ary or ! ref $ary or ! defined $ary->[0]);
	
	my $save_unsafe = $MVSAFE::Unsafe || '';
	$MVSAFE::Unsafe = 1;

	# This allows left brackets to be output by the data tags
	local($Safe_data);
	$Safe_data = 1 if $opt->{safe_data};

#	if($opt->{prefix} eq 'item') {
#::logDebug("labeled list: opt:\n" . uneval($opt) . "\nobj:" . uneval($obj) . "text:" . substr($text,0,100));
#	}
	$Orig_prefix = $Prefix = $opt->{prefix} || 'item';

	$B  = qr(\[$Prefix)i;
	$E  = qr(\[/$Prefix)i;
	$IB = qr(\[if[-_]$Prefix)i;
	$IE = qr(\[/if[-_]$Prefix)i;

	my $end;
	# List more
	if (	defined $CGI::values{mv_more_matches}
			and     $CGI::values{mv_more_matches} eq 'loop'  )
	{
		undef $CGI::values{mv_more_matches};
		$opt->{fm}	= $CGI::values{mv_next_pointer} + 1;
		$end		= $CGI::values{mv_last_pointer}
			if defined $CGI::values{mv_last_pointer};
		$opt->{ml}	= $CGI::values{mv_matchlimit}
			if defined $CGI::values{mv_matchlimit};
	}
	# get the number to start the increment from
	my $i = 0;
	if (defined $obj->{more_in_progress} and $obj->{mv_first_match}) {
		$i = $obj->{mv_first_match};
	}
	elsif (defined $opt->{random}) {
		@$ary = @$ary[random_elements($ary, $opt->{random})];
		$i = 0; $end = $#$ary;
		undef $obj->{mv_matchlimit};
	}
	elsif (defined $opt->{fm}) {
		$i = $opt->{fm} - 1;
	}

	$count = $obj->{mv_first_match} || $i;
	$count++;
	# Zero the on-change hash
	undef %Prev;

	if(defined $opt->{option}) {
		$opt_value = $opt->{option};
		my $optref = $opt->{cgi} ? (\%CGI::values) : $::Values;

		if($opt_value =~ s/\s*($Codere)::($Codere)\s*//) {
            $opt_table = $1;
            $opt_field = $2;
			$opt_value = lc($optref->{$opt_value}) || undef;
            $opt_select = sub {
                return lc(tag_data($opt_table, $opt_field, shift)) eq $opt_value;
            }
				if $opt_value;
        }
		elsif(defined $optref->{$opt_value} and length $optref->{$opt_value} ) {
			$opt_value = lc($optref->{$opt_value});
			$opt_select = ! $opt->{multiple} 
						  ? sub { return "\L$_[0]" eq $opt_value }
						  : sub { $opt_value =~ /^$_[0](?:\0|$)/i or  
						  		  $opt_value =~ /\0$_[0](?:\0|$)/i
								  };
		}
	}
	else {
		undef $opt_select;
	}

	my $return;
	if($Vend::OnlyProducts) {
		$text =~ s#$B$QR{_field}#[$Prefix-data $Vend::OnlyProducts $1]#g
			and $text =~ s#$E$QR{'/_field'}#[/$Prefix-data]#g;
		$text =~ s,$IB$QR{_field_if_wo},[if-$Prefix-data $1$Vend::OnlyProducts $2],g
			and $text =~ s,$IE$QR{'/_field'},[/if-$Prefix-data],g;
	}
#::logDebug("Past only products.");
	$end =	($obj->{mv_matchlimit} and $obj->{mv_matchlimit} > 0)
			? $i + ($opt->{ml} || $obj->{mv_matchlimit}) - 1
			: $#$ary;
	$end = $#$ary if $#$ary < $end;

# LEGACY
	$text =~ /^\s*\[sort\s+.*/si
		and $opt->{sort} = find_sort(\$text);
# END LEGACY

	my $r;
	if($ary->[0] =~ /HASH/) {
		$ary = tag_sort_hash($opt->{sort}, $ary) if $opt->{sort};
		$r = iterate_hash_list($i, $end, $count, $text, $ary, $opt_select, $opt);
	}
	else {
		my $fa = $obj->{mv_return_fields} || undef;
		my $fh = $obj->{mv_field_hash}    || undef;
		my $fn = $obj->{mv_field_names}   || undef;
		$ary = tag_sort_ary($opt->{sort}, $ary) if $opt->{sort};
		if ($fa and $fn) {
			my $idx = 0;
			$fh = {};
			for(@$fa) {
				$fh->{$fn->[$_]} = $idx++;
			}
		}
		elsif (! $fh and $fn) {
			my $idx = 0;
			$fh = {};
			for(@$fn) {
				$fh->{$_} = $idx++;
			}
		}
#::logDebug("Missing mv_field_hash and/or mv_field_names in Vend::Interpolate::labeled_list") unless ref $fh eq 'HASH';
		$r = iterate_array_list($i, $end, $count, $text, $ary, $opt_select, $fh, $opt);
	}
	$MVSAFE::Unsafe = $save_unsafe;
	return $r;
}

sub tag_attr_list {
	my ($body, $hash, $ucase) = @_;
	if(! ref $hash) {
		$hash = string_to_ref($hash);
		if($@) {
			logDebug("eval error: $@");
		}
		return undef if ! ref $hash;
	}
	if($ucase) {
		$body =~ s!\{([A-Z_][A-Z_]+)\}!$hash->{"\L$1"}!g;
		$body =~ s!\{([A-Z_][A-Z_]+)\?([A-Z_][A-Z_]+)\:([A-Z_][A-Z_]+)\}!
					length($hash->{lc $1}) ? $hash->{lc $2} : $hash->{lc $3}
				  !eg;
		$body =~ s!\{([A-Z_][A-Z_]+)\|($Some)\}!$hash->{lc $1} || $2!eg;
		$body =~ s!\{([A-Z_][A-Z_]+)\s+($Some)\}! $hash->{lc $1} ? $2 : ''!eg;
		1 while $body =~ s!\{([A-Z_][A-Z_]+)\?\}($Some){/\1\?\}! $hash->{lc $1} ? $2 : ''!eg;
		1 while $body =~ s!\{([A-Z_][A-Z_]+)\:\}($Some){/\1\:\}! $hash->{lc $1} ? '' : $2!eg;
		$body =~ s!\{(\w+)\:+(\w+)\:+(.*?)\}! tag_data($1, $2, $3) !eg;
	}
	else {
	$body =~ s!\{($Codere)\}!$hash->{$1}!g;
	$body =~ s!\{($Codere)\?($Codere)\:($Codere)\}!
				length($hash->{$1}) ? $hash->{$2} : $hash->{$3}
			  !eg;
	$body =~ s!\{($Codere)\|($Some)\}!$hash->{$1} || $2!eg;
	$body =~ s!\{($Codere)\s+($Some)\}! $hash->{$1} ? $2 : ''!eg;
	1 while $body =~ s!\{($Codere)\?\}($Some){/\1\?\}! $hash->{$1} ? $2 : ''!eg;
	1 while $body =~ s!\{($Codere)\:\}($Some){/\1\:\}! $hash->{$1} ? '' : $2!eg;
	$body =~ s!\{(\w+)\:+(\w+)\:+(.*?)\}! tag_data($1, $2, $3) !eg;
	}
	return $body;
}

sub tag_address {
	my ($count, $item, $hash, $opt, $body) = @_;
#::logDebug("in ship_address");
	return pull_else($body) if defined $opt->{if} and ! $opt->{if};
	return pull_else($body) if ! $Vend::username || ! $Vend::Session->{logged_in};
#::logDebug("logged in with usernam=$Vend::username");
	
	my $tag = 'address';
	my $attr = 'mv_ad';
	my $nattr = 'mv_an';
	my $pre = '';
	if($opt->{billing}) {
		$tag = 'b_address';
		$attr = 'mv_bd';
		$nattr = 'mv_bn';
		$pre = 'b_';
	}

#	if($item->{$attr} and ! $opt->{set}) {
#		my $pre = $opt->{prefix};
#		$pre =~ s/[-_]/[-_]/g;
#		$body =~ s:\[$pre\]($Some)\[/$pre\]:$item->{$attr}:g;
#		return pull_if($body);
#	}

	my $nick = $opt->{nick} || $opt->{nickname} || $item->{$nattr};

#::logDebug("nick=$nick");

	my $user;
	if(not $user = $Vend::user_object) {
		 $user = new Vend::UserDB username => ($opt->{username} || $Vend::username);
	}
#::logDebug("user=$user");
	! $user and return pull_else($body);

	my $blob = $user->get_hash('SHIPPING')   or return pull_else($body);
#::logDebug("blob=$blob");
	my $addr = $blob->{$nick};

	if (! $addr) {
		%$addr = %{ $::Values };
	}

#::logDebug("addr=" . uneval($addr));

	$addr->{mv_an} = $nick;
	my @nick = sort keys %$blob;
	my $label;
	if($label = $opt->{address_label}) {
		@nick = sort { $blob->{$a}{$label} cmp  $blob->{$a}{$label} } @nick;
		@nick = map { "$_=" . ($blob->{$_}{$label} || $_) } @nick;
		for(@nick) {
			s/,/&#44;/g;
		}
	}
	$opt->{blank} = '--select--' unless $opt->{blank};
	unshift(@nick, "=$opt->{blank}");
	$opt->{address_book} = join ",", @nick
		unless $opt->{address_book};

	my $joiner = get_joiner($opt->{joiner}, '<BR>');
	if(! $opt->{no_address}) {
		my @vals = map { $addr->{$_} }
					grep /^address_?\d*$/ && length($addr->{$_}), keys %$addr;
		$addr->{address} = join $joiner, @vals;
	}

	if($opt->{widget}) {
		$addr->{address_book} = tag_accessories(
									$item->{code},
									undef,
									{
										attribute => $nattr,
										type => $opt->{widget},
										passed => $opt->{address_book},
										form => $opt->{form},
									},
									$item
									);
	}

	if($opt->{set} || ! $item->{$attr}) {
		my $template = '';
		if($::Variable->{MV_SHIP_ADDRESS_TEMPLATE}) {
			$template .= $::Variable->{MV_SHIP_ADDRESS_TEMPLATE};
		}
		else {
			$template .= "{company}\n" if $addr->{"${pre}company"};
			$template .= <<EOF;
{address}
{city}, {state} {zip} 
{country} -- {phone_day}
EOF
		}
		$template =~ s/{(\w+.*?)}/{$pre$1}/g if $pre;
		$addr->{mv_ad} = $item->{$attr} = tag_attr_list($template, $addr);
	}
	else {
		$addr->{mv_ad} = $item->{$attr};
	}

	if($opt->{textarea}) {
		$addr->{textarea} = tag_accessories(
									$item->{code},
									undef,
									{
										attribute => $attr,
										type => 'textarea',
										rows => $opt->{rows} || '4',
										cols => $opt->{cols} || '40',
									},
									$item
									);
	}

	$body =~ s:\[$tag\]($Some)\[/$tag\]:tag_attr_list($1, $addr):eg;
	return pull_if($body);
}

sub tag_object {
	my ($count, $item, $hash, $opt, $body) = @_;
	my $param = delete $hash->{param}
		or return undef;
	my $method;
	my $out = '';
	eval {
		if(not $method = delete $hash->{method}) {
			$out = $item->{$param}->();
		}
		else {
			$out = $item->{$param}->$method();
		}
	};
	return $out;
}

my %Dispatch_hash = (
	address => \&tag_address,
	object  => \&tag_object,
);

sub find_matching_else {
    my($buf) = @_;
    my $out;
	my $canon;

    my $open  = '[else]';
    my $close = '[/else]';
    my $first;
	my $pos;

  	$$buf =~ s{\[else\]}{[else]}igo;
    $first = index($$buf, $open, $pos);
#::logDebug("first=$first");
	return undef if $first < 0;
	my $int     = $first;
	my $begin   = $first;
	$$buf =~ s{\[/else\]}{[/else]}igo
		or $int = -1;

	while($int > -1) {
		$pos   = $begin + 1;
		$begin = index($$buf, $open, $pos);
		$int   = index($$buf, $close, $int + 1);
		last if $int < 1;
		if($begin > $int) {
			$first = $int = $begin;
			$int = $begin;
		}
#::logDebug("pos=$pos int=$int first=$first begin=$begin");
    }
	$first = $begin if $begin > -1;
	substr($$buf, $first) =~ s/(.*)//s;
	$out = $1;
	substr($out, 0, 6) = '';
	return $out;
}

sub tag_dispatch {
	my($tag, $count, $item, $hash, $chunk) = @_;
	$tag = lc $tag;
	$tag =~ tr/-/_/;
	my $full = lc "$Orig_prefix-tag-$tag";
	$full =~ tr/-/_/;
#::logDebug("tag_dispatch: tag=$tag count=$count chunk=$chunk");
	my $attrseq = [];
	my $attrhash = {};
	my $eaten;
	my $this_tag;

	$eaten = Vend::Parse::_find_tag(\$chunk, $attrhash, $attrseq);
	substr($chunk, 0, 1) = '';

	$this_tag = Vend::Parse::find_matching_end($full, \$chunk);
	
	$attrhash->{prefix} = $tag unless $attrhash->{prefix};

	my $out;
	if(defined $Dispatch_hash{$tag}) {
		$out = $Dispatch_hash{$tag}->($count, $item, $hash, $attrhash, $this_tag);
	}
	else {
		$attrhash->{body} = $this_tag unless defined $attrhash->{body};
#::logDebug("calling do_tag tag=$tag this_tag=$this_tag attrhash=" . uneval($attrhash));
		$Tag ||= new Vend::Tags;
		$out = $Tag->$tag($attrhash);
	}
	return $out . $chunk;
}

my $rit = 1;

sub resolve_nested_if {
	my ($where, $what) = @_;
	$where =~ s~\[$what\s+(?!.*\[$what\s)(.*?)\[/$what\]~
				'[' . $what . $rit . " $1" . '[/' . $what . $rit++ . ']'~seg;
#::logDebug("resolved?\n$where\n");
	return $where;
}

use vars qw/%Ary_code/;
%Ary_code = (
	accessories => \&tag_accessories,
	common => \&Vend::Data::product_common,
	description => \&Vend::Data::product_description,
	field => \&Vend::Data::product_field,
	last => \&interpolate_html,
	next => \&interpolate_html,
	options => \&Vend::Options::tag_options,
);

use vars qw/%Hash_code/;
%Hash_code = (
	accessories => \&tag_accessories,
	common => \&Vend::Data::item_common,
	description => \&Vend::Data::item_description,
	field => \&Vend::Data::item_field,
	last => \&interpolate_html,
	next => \&interpolate_html,
	options => \&tag_options,
);

sub map_list_routines {
	my($type, $opt) = @_;

	### This allows mapping of new routines to 
	##    PREFIX-options
	##    PREFIX-accessories
	##    PREFIX-description
	##    PREFIX-common
	##    PREFIX-field
	##    PREFIX-price
	##    PREFIX-tag
	##    PREFIX-last
	##    PREFIX-next

	my $nc;

	my $ac; 
	for $ac ($Global::CodeDef->{$type}, $Vend::Cfg->{CodeDef}{$type}) {
		next unless $ac and $ac->{Routine};
		$nc ||= {};
		for(keys %{$ac->{Routine}}) {
			$nc->{$_} = $ac->{Routine}{$_};
		}
	}

	if($ac = $opt->{maproutine}) {
		$nc ||= {};
		if(! ref($ac) ) {
			$ac =~ s/[\s'",=>\0]+$//;
			$ac =~ s/^[\s'",=>\0]+//;
			$ac = { split /[\s'",=>\0]+/, $ac };
		}
		$ac = {} if ref($ac) ne 'HASH';
		while( my($k,$v) = each %$ac) {
			$nc->{$k} = $Vend::Cfg->{Sub}{$v} || $Global::GlobalSub->{$v}
			  or do {
				  logError("%s: non-existent mapped routine %s.", $type, $_);
					delete $nc->{$_};
			  };
		}
	}
	return $nc;
}

sub iterate_array_list {
	my ($i, $end, $count, $text, $ary, $opt_select, $fh, $opt) = @_;

	my $r = '';
	$opt ||= {};

	my $lim;
	if($lim = $Vend::Cfg->{Limit}{list_text_size} and length($text) > $lim) {
		my $len = length($text);
		my $caller = join "|", caller();
		my $msg = "Large list text encountered,  length=$len, caller=$caller";
		logError($msg);
		return undef if $Vend::Cfg->{Limit}{list_text_overflow} eq 'abort';
	}

	# Optimize for no-match, on-match, etc
	if(! $opt->{iterator} and $text !~ /\[(?:if-)?$Prefix-/) {
		for(; $i <= $end; $i++) {
			$r .= $text;
		}
		return $r;
	}

	my $nc = map_list_routines('ArrayCode', $opt);

	$nc and local(@Ary_code{keys %$nc}) = values %$nc;

	my ($run, $row, $code, $return);
my $once = 0;
#::logDebug("iterating array $i to $end. count=$count opt_select=$opt_select ary=" . uneval($ary));
	if($text =~ m/^$B$QR{_line}\s*$/is) {
		my $i = $1 || 0;
		my $count = scalar values %$fh;
		$count--;
		my (@ary) = sort { $fh->{$a} <=> $fh->{$b} } keys %$fh;
		$r .= join "\t", @ary[$i .. $count];
		$r .= "\n";
	}
	while($text =~ s#$B$QR{_sub}$E$QR{'/_sub'}##i) {
		my $name = $1;
		my $routine = $2;
		## Not necessary?
		## $Vend::Cfg->{Sub}{''} = sub { errmsg('undefined sub') }
		##	unless defined $Vend::Cfg->{Sub}{''};
		$routine = 'sub { ' . $routine . ' }' unless $routine =~ /^\s*sub\s*{/;
		my $sub;
		eval {
			$sub = $ready_safe->reval($routine);
		};
		if($@) {
			logError( errmsg("syntax error on %s-sub %s]: $@", $B, $name) );
			$sub = sub { errmsg('ERROR') };
		}
#::logDebug("sub $name: $sub --> $routine");
		$Vend::Cfg->{Sub}{$name} = $sub;
	}

	my $oexec = { %$opt };

	if($opt->{iterator}) {
		my $sub;
		$sub = $opt->{iterator}          if ref($opt->{iterator}) eq 'CODE';
		$sub ||= $Vend::Cfg->{Sub}{$opt->{iterator}}
				|| $Global::GlobalSub->{$opt->{iterator}};
		if(! $sub) {
			logError(
				"list iterator subroutine '%s' called but not defined. Skipping.",
				$opt->{iterator},
			);
			return '';
		}
		for( ; $i <= $end ; $i++ ) {
			$r .= $sub->($text, $ary->[$i], $oexec);
		}
		return $r;
	}

	1 while $text =~ s{(\[(if[-_]$Prefix[-_][a-zA-Z]+)(?=.*\[\2)\s.*\[/\2\])}
					  {
					  	resolve_nested_if($1, $2)
					  }se;

	# log helpful errors if any unknown field names are
	# used in if-prefix-param or prefix-param tags
	my @field_msg = ('error', "Unknown field name '%s' used in tag %s");
	$run = $text;
	if(! $opt->{ignore_undefined}) {
	$run =~ s#$B$QR{_param}# defined $fh->{$1} ||
		logOnce(@field_msg, $1, "$Orig_prefix-param") #ige;
	$run =~ s#$IB$QR{_param_if}# defined $fh->{$3} ||
		logOnce(@field_msg, $3, "if-$Orig_prefix-param") #ige;
	}

	for( ; $i <= $end ; $i++, $count++ ) {
		$row = $ary->[$i];
		last unless defined $row;
		$code = $row->[0];

#::logDebug("Doing $code substitution, count $count++");
#::logDebug("Doing '" . substr($code, 0, index($code, "\n") + 1) . "' substitution, count $count++");

	    $run = $text;
		$run =~ s#$B$QR{_alternate}$E$QR{'/_alternate'}#
				  $count % ($1 || $::Values->{mv_item_alternate} || 2)
				  							?	pull_else($2)
											:	pull_if($2)#ige;
		1 while $run =~ s#$IB$QR{_param_if}$IE[-_]param\1\]#
				  (defined $fh->{$3} ? $row->[$fh->{$3}] : '')
				  					?	pull_if($5,$2,$4,$row->[$fh->{$3}])
									:	pull_else($5,$2,$4,$row->[$fh->{$3}])#ige;
	    $run =~ s#$B$QR{_param}#defined $fh->{$1} ? ed($row->[$fh->{$1}]) : ''#ige;
		1 while $run =~ s#$IB$QR{_pos_if}$IE[-_]pos\1\]#
				  $row->[$3] 
						?	pull_if($5,$2,$4,$row->[$3])
						:	pull_else($5,$2,$4,$row->[$3])#ige;
	    $run =~ s#$B$QR{_pos}#ed($row->[$1])#ige;
#::logDebug("fh: " . uneval($fh) . uneval($row)) unless $once++;
		1 while $run =~ s#$IB$QR{_field_if}$IE[-_]field\1\]#
				  my $tmp = product_field($3, $code);
				  $tmp	?	pull_if($5,$2,$4,$tmp)
						:	pull_else($5,$2,$4,$tmp)#ige;
		$run =~ s:$B$QR{_line}:join "\t", @{$row}[ ($1 || 0) .. $#$row]:ige;
	    $run =~ s:$B$QR{_increment}:$count:ig;
		$run =~ s:$B$QR{_accessories}:
						$Ary_code{accessories}->($code,$1,{}):ige;
		$run =~ s:$B$QR{_options}:
						$Ary_code{options}->($code,$1):ige;
		$run =~ s:$B$QR{_code}:$code:ig;
		$run =~ s:$B$QR{_description}:ed($Ary_code{description}->($code)):ige;
		$run =~ s:$B$QR{_field}:ed($Ary_code{field}->($1, $code)):ige;
		$run =~ s:$B$QR{_common}:ed($Ary_code{common}->($1, $code)):ige;
		tag_labeled_data_row($code, \$run);
		$run =~ s!$B$QR{_price}!
					currency(product_price($code,$1), $2)!ige;

		1 while $run =~ s!$B$QR{_change}$E$QR{'/_change'}\1\]!
							check_change($1,$3,undef,$2)
											?	pull_if($4)
											:	pull_else($4)!ige;
		$run =~ s#$B$QR{_tag}($Some$E[-_]tag[-_]\1\])#
						tag_dispatch($1,$count, $row, $ary, $2)#ige;
		$run =~ s#$B$QR{_calc}$E$QR{'/_calc'}#tag_calc($1)#ige;
		$run =~ s#$B$QR{_exec}$E$QR{'/_exec'}#
					init_calc() if ! $Vend::Calc_initialized;
					(
						$Vend::Cfg->{Sub}{$1} ||
						$Global::GlobalSub->{$1} ||
						sub { 'ERROR' }
					)->($2,$row,$oexec)
				#ige;
		$run =~ s#$B$QR{_filter}$E$QR{'/_filter'}#filter_value($1,$2)#ige;
		$run =~ s#$B$QR{_last}$E$QR{'/_last'}#
                    my $tmp = $Ary_code{last}->($1);
					$tmp =~ s/^\s+//;
					$tmp =~ s/\s+$//;
                    if($tmp && $tmp < 0) {
                        last;
                    }
                    elsif($tmp) {
                        $return = 1;
                    }
                    '' #ixge;
		$run =~ s#$B$QR{_next}$E$QR{'/_next'}#
                    $Ary_code{next}->($1) != 0 ? next : '' #ixge;
		$run =~ s/<option\s*/<OPTION SELECTED /i
			if $opt_select and $opt_select->($code);

		$r .= $run;
		last if $return;
    }
	return $r;
}

sub iterate_hash_list {
	my($i, $end, $count, $text, $hash, $opt_select, $opt) = @_;

	my $r = '';
	$opt ||= {};

	# Optimize for no-match, on-match, etc
	if(! $opt->{iterator} and $text !~ /\[/) {
		for(; $i <= $end; $i++) {
			$r .= $text;
		}
		return $r;
	}

	my $code_field = $opt->{code_field} || 'mv_sku';
	my ($run, $code, $return, $item);

	my $nc = map_list_routines('HashCode', $opt);

	$nc and local(@Hash_code{keys %$nc}) = values %$nc;

#::logDebug("iterating hash $i to $end. count=$count opt_select=$opt_select hash=" . uneval($hash));
	while($text =~ s#$B$QR{_sub}$E$QR{'/_sub'}##i) {
		my $name = $1;
		my $routine = $2;
		## Not necessary?
		## $Vend::Cfg->{Sub}{''} = sub { errmsg('undefined sub') }
		##	unless defined $Vend::Cfg->{Sub}{''};
		$routine = 'sub { ' . $routine . ' }' unless $routine =~ /^\s*sub\s*{/;
		my $sub;
		eval {
			$sub = $ready_safe->reval($routine);
		};
		if($@) {
			logError( errmsg("syntax error on %s-sub %s]: $@", $B, $name) );
			$sub = sub { errmsg('ERROR') };
		}
		$Vend::Cfg->{Sub}{$name} = $sub;
	}
#::logDebug("subhidden: $opt->{subhidden}");

	my $oexec = { %$opt };

	if($opt->{iterator}) {
		my $sub;
		$sub   = $opt->{iterator}          if ref($opt->{iterator}) eq 'CODE';
		$sub ||= $Vend::Cfg->{Sub}{$opt->{iterator}}
				|| $Global::GlobalSub->{$opt->{iterator}};
		if(! $sub) {
			logError(
				"list iterator subroutine '%s' called but not defined. Skipping.",
				$opt->{iterator},
			);
			return '';
		}

		for( ; $i <= $end ; $i++ ) {
			$r .= $sub->($text, $hash->[$i], $oexec);
		}
		return $r;
	}

	1 while $text =~ s{(\[(if[-_]$Prefix[-_][a-zA-Z]+)(?=.*\[\2)\s.*\[/\2\])}
					  {
					  	resolve_nested_if($1, $2)
					  }se;


	for ( ; $i <= $end; $i++, $count++) {
		$item = $hash->[$i];
		$item->{mv_ip} = $i;
		if($opt->{modular}) {
			if($opt->{master}) {
				next unless $item->{mv_mi} eq $opt->{master};
			}
			if($item->{mv_mp} and $item->{mv_si} and ! $opt->{subitems}) {
#				$r .= <<EOF if $opt->{subhidden};
#<INPUT TYPE="hidden" NAME="quantity$item->{mv_ip}" VALUE="$item->{quantity}">
#EOF
				next;
			}
		}
		$item->{mv_cache_price} = undef;
		$code = $item->{$code_field} || $item->{code};

#::logDebug("Doing $code (variant $item->{code}) substitution, count $count++");

		$run = $text;
		$run =~ s#$B$QR{_alternate}$E$QR{'/_alternate'}#
				  ($i + 1) % ($1 || $::Values->{mv_item_alternate} || 2)
				  							?	pull_else($2)
											:	pull_if($2)#ge;
		tag_labeled_data_row($code,\$run);
		$run =~ s:$B$QR{_line}:join "\t", @{$hash}:ge;
		1 while $run =~ s#$IB$QR{_param_if}$IE[-_]param\1\]#
				  $item->{$3}	?	pull_if($5,$2,$4,$item->{$3})
								:	pull_else($5,$2,$4,$item->{$3})#ige;
		1 while $run =~ s#$IB$QR{_parent_if}$IE[-_]parent\1\]#
				  $item->{$3}	?	pull_if($5,$2,$4,$opt->{$3})
								:	pull_else($5,$2,$4,$opt->{$3})#ige;
		1 while $run =~ s#$IB$QR{_field_if}$IE[-_]field\1\]#
				  my $tmp = item_field($item, $3);
				  $tmp	?	pull_if($5,$2,$4,$tmp)
						:	pull_else($5,$2,$4,$tmp)#ge;
		1 while $run =~ s#$IB$QR{_modifier_if}$IE[-_]modifier\1\]#
				  $item->{$3}	?	pull_if($5,$2,$4,$item->{$3})
								:	pull_else($5,$2,$4,$item->{$3})#ge;
		$run =~ s:$B$QR{_increment}:$i + 1:ge;
		
		$run =~ s:$B$QR{_accessories}:
						$Hash_code{accessories}->($code,$1,{},$item):ge;
		$run =~ s:$B$QR{_options}:
						$Hash_code{options}->($item,$1):ige;
		$run =~ s:$B$QR{_sku}:$code:ig;
		$run =~ s:$B$QR{_code}:$item->{code}:ig;
		$run =~ s:$B$QR{_quantity}:$item->{quantity}:g;
		$run =~ s:$B$QR{_modifier}:ed($item->{$1}):ge;
		$run =~ s:$B$QR{_param}:ed($item->{$1}):ge;
		$run =~ s:$B$QR{_parent}:ed($opt->{$1}):ge;
		$run =~ s:$QR{quantity_name}:quantity$item->{mv_ip}:g;
		$run =~ s:$QR{modifier_name}:$1$item->{mv_ip}:g;
		$run =~ s!$B$QR{_subtotal}!currency(item_subtotal($item),$1)!ge;
		$run =~ s!$B$QR{_discount_subtotal}!
						currency( discount_price(
										$item,item_subtotal($item)
									),
								$1
								)!ge;
		$run =~ s:$B$QR{_code}:$code:g;
		$run =~ s:$B$QR{_field}:ed($Hash_code{field}->($item, $1) || $item->{$1}):ge;
		$run =~ s:$B$QR{_common}:ed($Hash_code{common}->($item, $1) || $item->{$1}):ge;
		$run =~ s:$B$QR{_description}:
							ed($Hash_code{description}->($item) || $item->{description})
							:ge;
		$run =~ s!$B$QR{_price}!currency(item_price($item,$1), $2)!ge;
		$run =~ s!$B$QR{_discount_price}!
					currency(
						discount_price($item, item_price($item,$1), $1 || 1)
						, $2
						)!ge
				or
				$run =~ s!$QR{discount_price}!
							currency(
								discount_price($item, item_price($item,$1), $1 || 1)
								, $2
								)!ge;
		$run =~ s!$B$QR{_difference}!
					currency(
							item_difference(
								$item->{code},
								item_price($item, $item->{quantity}),
								$item->{quantity},
							),
							$2,
					)!ge;
		$run =~ s!$B$QR{_discount}!
					currency(
							item_discount(
								$item->{code},
								item_price($item, $item->{quantity}),
								$item->{quantity},
							),
							$2,
					)!ge;
		1 while $run =~ s!$B$QR{_change}$E$QR{'/_change'}\1\]!
							check_change($1,$3,undef,$2)
											?	pull_if($4)
											:	pull_else($4)!ige;
		$run =~ s#$B$QR{_tag}($All$E[-_]tag[-_]\1\])#
						tag_dispatch($1,$count, $item, $hash, $2)#ige;
		$run =~ s#$B$QR{_calc}$E$QR{'/_calc'}#tag_calc($1)#ige;
		$run =~ s#$B$QR{_exec}$E$QR{'/_exec'}#
					init_calc() if ! $Vend::Calc_initialized;
					(
						$Vend::Cfg->{Sub}{$1} ||
						$Global::GlobalSub->{$1} ||
						sub { 'ERROR' }
					)->($2,$item,$oexec)
				#ige;
		$run =~ s#$B$QR{_filter}$E$QR{'/_filter'}#filter_value($1,$2)#ige;
		$run =~ s#$B$QR{_last}$E$QR{'/_last'}#
                    my $tmp = interpolate_html($1);
                    if($tmp && $tmp < 0) {
                        last;
                    }
                    elsif($tmp) {
                        $return = 1;
                    }
                    '' #xoge;
		$run =~ s#$B$QR{_next}$E$QR{'/_next'}#
                    interpolate_html($1) != 0 ? next : '' #oge;
		$run =~ s/<option\s*/<OPTION SELECTED /i
			if $opt_select and $opt_select->($code);	

		$r .= $run;
#::logDebug("item $code mv_cache_price: $item->{mv_cache_price}");
		delete $item->{mv_cache_price};
		last if $return;
	}

	return $r;
}

sub error_opt {
	my ($opt, @args) = @_;
	return undef unless ref $opt;
	my $msg = errmsg(@args);
	$msg = "$opt->{error_id}: $msg" if $opt->{error_id};
	if($opt->{log_error}) {
		logError($msg);
	}
	return $msg if $opt->{show_error};
	return undef;
}

sub query {
	if(ref $_[0]) {
		unshift @_, '';
	}
	my ($query, $opt, $text) = @_;
	$opt = {} if ! $opt;
	$opt->{prefix} = 'sql' unless $opt->{prefix};
	if($opt->{more} and $Vend::More_in_progress) {
		undef $Vend::More_in_progress;
		return region($opt, $text);
	}
	$opt->{table} = $Vend::Cfg->{ProductFiles}[0]
		unless $opt->{table};
	my $db = $Vend::Database{$opt->{table}} ;
	return $opt->{failure} if ! $db;

	$opt->{query} = $query
		if $query;

	if (! $opt->{wantarray} and ! defined $MVSAFE::Safe) {
		my $result = $db->query($opt, $text);
		return (ref $result) ? '' : $result;
	}
	$db->query($opt, $text);
}

sub html_table {
    my($opt, $ary, $na) = @_;

	if (!$na) {
		$na = [ split /\s+/, $opt->{columns} ];
	}
	if(! ref $ary) {
		$ary =~ s/^\s+//;
		$ary =~ s/\s+$//;
		my $delimiter = quotemeta $opt->{delimiter} || "\t";
		my $splittor = quotemeta $opt->{record_delim} || "\n";
		my (@rows) = split /$splittor/, $ary;
		$na = [ split /$delimiter/, shift @rows ] if $opt->{th};
		$ary = [];
		my $count = scalar @$na || -1;
		for (@rows) {
			push @$ary, [split /$delimiter/, $_, $count];
		}
	}

	my ($tr, $td, $th, $fc, $fr) = @{$opt}{qw/tr td th fc fr/};

	for($tr, $td, $th, $fc, $fr) {
		next unless defined $_;
		s/(.)/ $1/;
	}

	my $r = '';
	$tr = '' if ! defined $tr;
	$td = '' if ! defined $td;
	if(! defined $th || $th and scalar @$na ) {
		$th = '' if ! defined $th;
		$r .= "<TR$tr>";
		for(@$na) {
			$r .= "<TH$th><B>$_</B></TH>";
		}
		$r .= "</TR>\n";
	}
	my $row;
	if($fr) {
		$r .= "<TR$fr>";
		my $val;
		$row = shift @$ary;
		if($fc) {
			$val = (shift @$row) || '&nbsp;';
			$r .= "<TD$fc>$val</TD>";
		}
		foreach (@$row) {
			$val = $_ || '&nbsp;';
			$r .= "<TD$td>$val</TD>";
		}
		$r .= "</TR>\n";
		
	}
	foreach $row (@$ary) {
		$r .= "<TR$tr>";
		my $val;
		if($fc) {
			$val = (shift @$row) || '&nbsp;';
			$r .= "<TD$fc>$val</TD>";
		}
		foreach (@$row) {
			$val = $_ || '&nbsp;';
			$r .= "<TD$td>$val</TD>";
		}
		$r .= "</TR>\n";
	}
	return $r;
}

#
# Tests of above routines
#
#print html_table( {	
#					td => "BGCOLOR=#FFFFFF",
#					},
#[
#	[qw/ data1a	data2a	data3a/],
#	[qw/ data1b	data2b	data3b/],
#	[qw/ data1c	data2c	data3c/],
#],
#[ qw/cell1 cell2 cell3/ ],
#);
#
#print html_table( {	
#					td => "BGCOLOR=#FFFFFF",
#					columns => "cell1 cell2 cell3",
#					}, <<EOF);
#data1a	data2a	data3a
#data1b	data2b	data3b
#data1c	data2c	data3c
#EOF


# SQL
sub tag_sql_list {
    my($text,$ary,$nh,$opt,$na) = @_;
	$opt = {} unless defined $opt;
	$opt->{prefix}      = 'sql' if ! defined $opt->{prefix};
	$opt->{list_prefix} = 'sql[-_]list' if ! defined $opt->{prefix};

	my $object = {
					mv_results => $ary,
					mv_field_hash => $nh,
					mv_return_fields => $na,
					matches => scalar @$ary,
				};

	# Scans the option hash for more search settings if mv_more_alpha
	# is set in [query ...] tag....
	if($opt->{ma}) {
		# Find the sort field and alpha options....
		Vend::Scan::parse_profile_ref($object, $opt);
		# We need to turn the hash reference into a search object
		$object = new Vend::Search (%$object);
		# Delete this so it will meet conditions for creating a more
		delete $object->{mv_matchlimit};
	}

	$opt->{object} = $object;
    return region($opt, $text);
}
# END SQL

# Displays a search page with the special [search-list] tag evaluated.

sub opt_region {
	my $opt = pop @_;
#::logDebug("opt_region called, prefix=$Prefix, text=$_[-1]");
	my $new = { %$opt };
	my $out = iterate_hash_list(@_,[$new]);
	$Prefix = $Orig_prefix;
#::logDebug("opt_region prefix=$Prefix, results=$out");
	return $out;
}

sub region {

	my($opt,$page) = @_;

	my $obj;

	if($opt->{object}) {
		### The caller supplies the object, no search to be done
		#::logDebug("region: object was supplied by caller.");
		$obj = $opt->{object};
	}
	else {
		### We need to run a search to get an object
		#::logDebug("region: no object supplied");
		my $c;
		if($CGI::values{mv_more_matches} || $CGI::values{MM}) {

			### It is a more function, we need to get the parameters
			#::logDebug("more object = $CGI::values{mv_more_matches}");

			find_search_params();
			delete $CGI::values{mv_more_matches};

#::logDebug("more object = " . uneval($c));

		}
		elsif ($opt->{search}) {
			### Explicit search in tag parameter, run just like any
			#::logDebug("opt->search object label=$opt->{label}.");
			if($opt->{more} and $::Instance->{SearchObject}{''}) {
				$obj = $::Instance->{SearchObject}{''};
				#::logDebug("cached search");
			}
			else {
				$c = {	mv_search_immediate => 1,
							mv_search_label => $opt->{label} || 'current',
						};
				my $params = escape_scan($opt->{search});
				Vend::Scan::find_search_params($c, $params);
				#::logDebug("perform_search");
				$obj = perform_search($c);
			}
		}
		else {
			### See if we have a search already done for this label
			#::logDebug("try labeled object label=$opt->{label}.");
			$obj = $::Instance->{SearchObject}{$opt->{label}};
		}

		# If none of the above happen, we need to perform a search
		# based on the passed CGI parameters
		#::logDebug("no found object") if ! $obj;
		if(! $obj) {
			$obj = perform_search();
			$obj = {
						matches => 0,
						mv_search_error => ['No search was found'],
				} if ! $obj;
		}
		finish_search($obj);

		# Label it for future reference
		#::logDebug("labeling as '$opt->{label}'");

		$::Instance->{SearchObject}{$opt->{label}} = $opt->{object} = $obj;
	}
	my $lprefix;
	my $mprefix;
	if(defined $opt->{list_prefix}) {
		$lprefix = $opt->{list_prefix};
		$mprefix = "(?:$opt->{list_prefix}-)?";
	}
	elsif (defined $opt->{prefix}) {
		$lprefix = "(?:$opt->{prefix}-)?list";
		$mprefix = "(?:$opt->{prefix}-)?";
	}
	else {
		$lprefix = "list";
		$mprefix = "";
	}

#::logDebug("region: opt:\n" . uneval($opt) . "\npage:" . substr($page,0,100));

	if($opt->{ml} and ! defined $obj->{mv_matchlimit} ) {
		$obj->{mv_matchlimit} = $opt->{ml};
		$obj->{mv_more_decade} = $opt->{md};
		$obj->{matches} = scalar @{$obj->{mv_results}};
		$obj->{mv_cache_key} = generate_key(substr($page,0,100));
		$obj->{mv_first_match} = $opt->{fm} if $opt->{fm};
		$obj->{mv_search_page} = $opt->{sp} if $opt->{sp};
		$obj->{prefix} = $opt->{prefix} if $opt->{prefix};
		my $out = delete $obj->{mv_results};
		Vend::Search::save_more($obj, $out);
		$obj->{mv_results} = $out;
	}

	$opt->{prefix} = $obj->{prefix} if $obj->{prefix};

	$Orig_prefix = $Prefix = $opt->{prefix} || 'item';

	$B  = qr(\[$Prefix)i;
	$E  = qr(\[/$Prefix)i;
	$IB = qr(\[if[-_]$Prefix)i;
	$IE = qr(\[/if[-_]$Prefix)i;

	my $new;
	$page =~   s!
					\[ ( $mprefix  more[-_]list )  $Optx$Optx$Optx$Optx$Optx \]
						($Some)
					\[/\1\]
				!
					tag_more_list($2,$3,$4,$5,$6,$opt,$7)
				!xige;
	$page =~   s!
					\[ ( $mprefix  on[-_]match )\]
						($Some)
					\[/\1\]
				!
					$obj->{matches} > 0 ? opt_region(0,0,1,$2,$opt) : ''
				!xige;
	$page =~   s!
					\[ ( $mprefix  no[-_]match )\]
						($Some)
					\[/\1\]
				!
					$obj->{matches} > 0 ? '' : opt_region(0,0,1,$2,$opt)
				!xige;
	$page =~ s:\[($lprefix)\]($Some)\[/\1\]:labeled_list($opt,$2,$obj):ige
		or $page = labeled_list($opt,$page,$obj);
#::logDebug("past labeled_list");

    return $page;
}

my $List_it = 1;

sub tag_loop_list {
	my ($list, $opt, $text) = @_;

	my $fn;
	my @rows;

	$opt->{prefix} = 'loop' unless defined $opt->{prefix};
	$opt->{label}  =  "loop" . $List_it++ . $Global::Variable->{MV_PAGE}
						unless defined $opt->{label};

#::logDebug("list is: " . uneval($list) );

	## Thanks to Kaare Rasmussen for this suggestion
	## about passing embedded Perl objects to a list

	# Can pass object.mv_results=$ary object.mv_field_names=$ary
	return region($opt, $text) if $opt->{object};

	# Here we can take the direct results of an op like
	# @set = $db->query() && return \@set;
	# Called with
	#	[loop list=`$Scratch->{ary}`] [loop-code]
	#	[/loop]
	if (ref $list) {
#::logDebug("opt->list in: " . uneval($list) );
		unless (ref $list eq 'ARRAY' and ref $list->[0] eq 'ARRAY') {
			logError("loop was passed invalid list=`...` argument");
			return;
		}
		my ($ary, $fh, $fa) = @$list;
		$opt->{object}{mv_results} = $ary;
		$opt->{object}{matches} = scalar @$ary;
		$opt->{object}{mv_field_names} = $fa if $fa;
		$opt->{object}{mv_field_hash} = $fh if $fh;
		return region($opt, $text);
	}

	my $delim;

	if($opt->{search}) {
#::logDebug("loop resolve search");
		if($opt->{more} and $Vend::More_in_progress) {
			undef $Vend::More_in_progress;
			return region($opt, $text);
		}
		else {
			return region($opt, $text);
		}
	}
	elsif ($opt->{file}) {
#::logDebug("loop resolve file");
		$list = Vend::Util::readfile($opt->{file});
		$opt->{lr} = 1 unless
						defined $opt->{lr}
						or $opt->{quoted};
	}
	elsif ($opt->{extended}) {
		###
		### This returns
		###
		my ($view, $tab, $key) = split /:+/, $opt->{extended}, 3;
		if(! $key) {
			$key = $tab;
			$tab = $view;
			undef $view;
		}
		my $id = $tab;
		$id .= "::$key" if $key;
		my $meta = Vend::Table::Editor::meta_record(
								$id,
								$view,
								$opt->{table},
								$opt->{extended_only},
								);
		if(! $meta) {
			$opt->{object} = {
					matches		=> 1,
					mv_results	=> [],
					mv_field_names => [],
			};
		}
		else {
			$opt->{object} = {
					matches		=> 1,
					mv_results	=> [ $meta ],
			};
		}
		return region($opt, $text);
	}

	if ($fn = $opt->{fn} || $opt->{mv_field_names}) {
		$fn = [ grep /\S/, split /[\s,]+/, $fn ];
	}

	if ($opt->{lr}) {
#::logDebug("loop resolve line");
		$list =~ s/^\s+//;
		$list =~ s/\s+$//;
		if ($list) {
			$delim = $opt->{delimiter} || "\t";
			my $splittor = $opt->{record_delim} || "\n";
			if ($splittor eq "\n") {
				$list =~ s/\r\n/\n/g;
			}

			eval {
				@rows = map { [ split /\Q$delim/o, $_ ] } split /\Q$splittor/, $list;
			};
		}
	}
	elsif($opt->{acclist}) {
#::logDebug("loop resolve acclist");
		$fn = [ qw/option label/ ] unless $fn;
		eval {
			my @items = split /\s*,\s*/, $list;
			for(@items) {
				my ($o, $l) = split /=/, $_;
				$l = $o unless $l;
				push @rows, [ $o, $l ];
			}
		};
#::logDebug("rows:" . uneval(\@rows));
	}
	elsif($opt->{quoted}) {
#::logDebug("loop resolve quoted");
		my @l = Text::ParseWords::shellwords($list);
		produce_range(\@l) if $opt->{ranges};
		eval {
			@rows = map { [$_] } @l;
		};
	}
	else {
#::logDebug("loop resolve default");
		$delim = $opt->{delimiter} || '[,\s]+';
		my @l =  split /$delim/, $list;
		produce_range(\@l) if $opt->{ranges};
		eval {
			@rows = map { [$_] } @l;
		};
	}

	if($@) {
		logError("bad split delimiter in loop list: $@");
#::logDebug("loop resolve error $@");
	}

	# head_skip pulls rows off the top, and uses the last row to
	# set the field names if mv_field_names/fn option was not set
	if ($opt->{head_skip}) {
		my $i = 0;
		my $last_row;
		$last_row = shift(@rows) while $i++ < $opt->{head_skip};
		$fn ||= $last_row;
	}

	$opt->{object} = {
			matches		=> scalar(@rows),
			mv_results	=> \@rows,
			mv_field_names => $fn,
	};
	
#::logDebug("loop object: " . uneval($opt));
	return region($opt, $text);
}

# Tries to display the on-the-fly page if page is missing
sub fly_page {
	my($code, $opt, $page) = @_;

	my $selector;

	return $page if (! $code and $Vend::Flypart eq $Vend::FinalPath);

	$code = $Vend::FinalPath
		unless $code;

	$Vend::Flypart = $code;

	my $base = product_code_exists_ref($code);
#::logDebug("fly_page: code=$code base=$base page=" . substr($page, 0, 100));
	return undef unless $base || $opt->{onfly};

	$base = $Vend::Cfg->{ProductFiles}[0] unless $base;

    if($page) {
		$selector = 'passed in tag';
	}
	elsif(	$Vend::ForceFlypage ) {
		$selector = $Vend::ForceFlypage;
		undef $Vend::ForceFlypage;
	}
	elsif(	$selector = $Vend::Cfg->{PageSelectField}
			and db_column_exists($base,$selector)
		)
	{
			$selector = database_field($base, $code, $selector)
	}

	$selector = find_special_page('flypage')
		unless $selector;
#::logDebug("fly_page: selector=$selector");

	unless (defined $page) {
		unless( allowed_file($selector) ) {
			log_file_violation($selector, 'fly_page');
			return undef;
		}
		$page = readin($selector);
		if (defined $page) {
			vars_and_comments(\$page);
		} else {
			logError("attempt to display code=$code with bad flypage '$selector'");
			return undef;
		}
	}

	# This allows access from embedded Perl
	$Tmp->{flycode} = $code;
# TRACK
	$Vend::Track->view_product($code);
# END TRACK
	
# LEGACY
	list_compat($opt->{prefix}, \$page);
# END LEGACY

	return labeled_list( {}, $page, { mv_results => [[$code]] });
}

sub item_difference {
	my($code,$price,$q) = @_;
	return $price - discount_price($code,$price,$q);
}

sub item_discount {
	my($code,$price,$q) = @_;
	return ($price * $q) - discount_price($code,$price,$q) * $q;
}

sub discount_price {
	my ($item, $price, $quantity) = @_;
	my $extra;
	my $code;

	unless (ref $item) {
		$code = $item;
		$item = { code => $code, quantity => ($quantity || 1) };
	}


	($code, $extra) = ($item->{code}, $item->{mv_discount});

	$Vend::Session->{discount} = {}
		if $extra and ! $Vend::Session->{discount};

	return $price unless $Vend::Session->{discount};

	$quantity = $item->{quantity};

	$Vend::Interpolate::item = $item;
	$Vend::Interpolate::q = $quantity || 1;
	$Vend::Interpolate::s = $price;

	my ($discount, $return);

	for($code, 'ALL_ITEMS') {
		next unless $discount = $Vend::Session->{discount}->{$_};
		$Vend::Interpolate::s = $return = $price;
        $return = $ready_safe->reval($discount);
		if($@) {
			$return = $price;
			next;
		}
        $price = $return;
    }

	if($extra) {
		EXTRA: {
			$return = $ready_safe->reval($extra);
			last EXTRA if $@;
			$price = $return;
		}
	}
	return $price;
}

sub apply_discount {
	my($item) = @_;

	my($formula, $cost);
	my(@formulae);

	# Check for individual item discount
	push(@formulae, $Vend::Session->{discount}->{$item->{code}})
		if defined $Vend::Session->{discount}->{$item->{code}};
	# Check for all item discount
	push(@formulae, $Vend::Session->{discount}->{ALL_ITEMS})
		if defined $Vend::Session->{discount}->{ALL_ITEMS};
	push(@formulae, $item->{mv_discount})
		if defined $item->{mv_discount};

	my $subtotal = item_subtotal($item);

	init_calc() unless $Vend::Calc_initialized;
	# Calculate any formalas found
	foreach $formula (@formulae) {
		next unless $formula;
		$Vend::Interpolate::q = $item->{quantity};
		$Vend::Interpolate::s = $subtotal;
		$Vend::Interpolate::item = $item;
#		$formula =~ s/\$q\b/$item->{quantity}/g; 
#		$formula =~ s/\$s\b/$subtotal/g; 
		$cost = $ready_safe->reval($formula);
		if($@) {
			logError
				"Discount for $item->{code} has bad formula. Not applied.\n$@";
			next;
		}
		$subtotal = $cost;
	}
	$subtotal;
}

my %Ship_remap = ( qw/
							CRITERION   CRIT
							CRITERIA    CRIT
							MAXIMUM     MAX
							MINIMUM     MIN
							PRICE       COST
							QUALIFIER   QUAL
							CODE        PERL
							SUB         PERL
							UPS_TYPE    TABLE
							DESCRIPTION DESC
							ZIP         GEO 
							LOOKUP      TABLE
							DEFAULT_ZIP DEFAULT_GEO 
							SQL         QUERY
					/);

sub make_three {
	my ($zone, $len) = @_;
	$len = 3 if ! $len;
	while ( length($zone) < $len ) {
		$zone = "0$zone";
	}
	return $zone;
}

%Ship_handler = (
		TYPE =>
					sub { 
							my ($v,$k) = @_;
							$$v =~ s/^(.).*/$1/;
							$$v = lc $$v;
							$$k = 'COST';
					}
		,
);

sub read_shipping {
	my ($file, $opt) = @_;
	$opt = {} unless $opt;
    my($code, $desc, $min, $criterion, $max, $cost, $mode);

	if ($file) {
		#nada
	}
	elsif($opt->{add} or $Vend::Cfg->{Variable}{MV_SHIPPING}) {
		$file = "$Vend::Cfg->{ScratchDir}/shipping.asc";
		Vend::Util::writefile(">$file", $opt->{add} || $Vend::Cfg->{Variable}{MV_SHIPPING});
	}
	else {
		$file = $Vend::Cfg->{Special}{'shipping.asc'}
				|| Vend::Util::catfile($Vend::Cfg->{ProductDir},'shipping.asc');
	}

	my @flines = split /\n/, readfile($file);
	if ($Vend::Cfg->{CustomShipping} =~ /^select\s+/i) {
		($Vend::Cfg->{SQL_shipping} = 1, return)
			if $Global::Foreground;
		my $ary;
		my $query = interpolate_html($Vend::Cfg->{CustomShipping});
		eval {
			$ary = query($query, { wantarray => 1} );
		};
		if(! ref $ary) {
			logError("Could not make shipping query %s: %s" ,
						$Vend::Cfg->{CustomShipping},
						$@);
			return undef;
		}
		my $out;
		for(@$ary) {
			push @flines, join "\t", @$_;
		}
	}
	
	$Vend::Cfg->{Shipping_desc} = {}
		if ! $Vend::Cfg->{Shipping_desc};
	my %seen;
	my $append = '00000';
	my @line;
	my $prev = '';
	my $waiting;
	my @shipping;
	my $first;
    for(@flines) {

		# Strip CR, we hope
		s/\s+$//;

		# Handle continued lines
		if(s/\\$//) {
			$prev .= $_;
			next;
		}
		elsif($waiting) {
			if($_ eq $waiting) {
				undef $waiting;
				$_ = $prev;
				$prev = '';
				s/\s+$//;
			}
			else {
				$prev .= "$_\n";
				next;
			}
		}
		elsif($prev) {
			$_ = "$prev$_";
			$prev = '';
		}

		if (s/<<(\w+)$//) {
			$waiting = $1;
			$prev .= $_;
			next;
		}

		next unless /\S/;
		s/\s+$//;
		if(/^[^\s:]+\t/) {
			push (@shipping, [@line]) if @line;
			@line = split(/\t/, $_);
			$Vend::Cfg->{Shipping_desc}->{$line[0]} = $line[1]
				unless $seen{$line[0]}++;
			push @shipping, [@line];
			@line = ();
		}
		elsif(/^(\w+)\s*:\s*(.*)/s) {
			push (@shipping, [@line]) if @line;
			@line = ($1, $2, 'quantity', 0, 999999999, 0);
			$first = 1;
			$Vend::Cfg->{Shipping_desc}->{$line[0]} = $line[1]
				unless $seen{$line[0]}++;
			next;
		}
		elsif(/^\s+min(?:imum)?\s+(\S+)/i) {
			my $min = $1;
			if ($first) {
				undef $first;
				$line[MIN] = $min;
			}
			else {
				push @shipping, [ @line ];
				$line[MIN] = $min;
				if(ref $line[OPT]) {
					my $ref = $line[OPT];
					$line[OPT] = { %$ref };
				}

			}
		}
		else {
			no strict 'refs';
			s/^\s+//;
			my($k, $v) = split /\s+/, $_, 2;
			my $prospect;
			$k = uc $k;
			$k = $Ship_remap{$k}
				if defined $Ship_remap{$k};
			$Ship_handler{$k}->(\$v, \$k, \@line)
				if defined $Ship_handler{$k};
			eval {
				if(defined &{"$k"}) {
						$line[&{"$k"}] = $v;
				}
				else {
					$line[OPT] = {} unless $line[OPT];
					$k = lc $k;
					$line[OPT]->{$k} = $v;
				}
			};
			logError(
				"bad shipping index %s for mode %s in $file",
				$k,
				$line[0],
				) if $@;
		}
	}

	push @shipping, [ @line ]
		if @line;

	if($waiting) {
		logError(
			"Failed to find end-of-line termination '%s' in shipping read",
			$waiting,
		);
	}

	my $row;
	my %zones;
	my %def_opts;
	$def_opts{PriceDivide} = 1 if $Vend::Cfg->{Locale};

	foreach $row (@shipping) {
		my $cost = $row->[COST];
		my $o = get_option_hash($row->[OPT]);
		for(keys %def_opts) {
			$o->{$_} = $def_opts{$_}
				unless defined $o->{$_};
		}
		$row->[OPT] = $o;
		my $zone;
		if ($cost =~ s/^\s*o\s+//) {
			$o = get_option_hash($cost);
			%def_opts = %$o;
		}
		elsif ($zone = $o->{zone} or $cost =~ s/^\s*c\s+(\w+)\s*//) {
			$zone = $1 if ! $zone;
			next if defined $zones{$zone};
			my $ref;
			if ($o->{zone}) {
				$ref = {};
				my @common = qw/
							mult_factor				
							str_length				
							zone_data
							zone_file				
							zone_name				
						/; 
				@{$ref}{@common} = @{$o}{@common};
				$ref->{zone_name} = $zone
					if ! $ref->{zone_name};
			}
			elsif ($cost =~ /^{[\000-\377]+}$/ ) {
				eval { $ref = eval $cost };
			}
			else {
				$ref = {};
				my($name, $file, $length, $multiplier) = split /\s+/, $cost;
				$ref->{zone_name} = $name || undef;
				$ref->{zone_file} = $file if $file;
				$ref->{mult_factor} = $multiplier if defined $multiplier;
				$ref->{str_length} = $length if defined $length;
			}
			if ($@
				or ref($ref) !~ /HASH/
				or ! $ref->{zone_name}) {
				logError(
					"Bad shipping configuration for mode %s, skipping.",
					$row->[MODE]
				);
				$row->[MODE] = 'ERROR';
				next;
			}
			$ref->{zone_key} = $zone;
			$ref->{str_length} = 3 unless defined $ref->{str_length};
			$zones{$zone} = $ref;
		}
    }

	if($Vend::Cfg->{UpsZoneFile} and ! defined $Vend::Cfg->{Shipping_zone}{'u'} ) {
			 $zones{'u'} = {
				zone_file	=> $Vend::Cfg->{UpsZoneFile},
				zone_key	=> 'u',
				zone_name	=> 'UPS',
				};
	}
	UPSZONE: {
		for (keys %zones) {
			my $ref = $zones{$_};
			if (! $ref->{zone_data}) {
				$ref->{zone_file} = Vend::Util::catfile(
											$Vend::Cfg->{ProductDir},
											"$ref->{zone_name}.csv",
										) if ! $ref->{zone_file};
				$ref->{zone_data} =  readfile($ref->{zone_file});
			}
			unless ($ref->{zone_data}) {
				logError( "Bad shipping file for zone '%s', lookup disabled.",
							$ref->{zone_key},
						);
				next;
			}
			my (@zone) = grep /\S/, split /[\r\n]+/, $ref->{zone_data};
			if($zone[0] !~ /\t/) {
				my $len = $ref->{str_length} || 3;
				@zone = grep /\S/, @zone;
				@zone = grep /^[^"]/, @zone;
				$zone[0] =~ s/[^\w,]//g;
				$zone[0] =~ s/^\w+/low,high/;
				@zone = grep /,/, @zone;
				$zone[0] =~	s/\s*,\s*/\t/g;
				for(@zone[1 .. $#zone]) {
					s/^\s*(\w+)\s*,/make_three($1, $len) . ',' . make_three($1, $len) . ','/e;
					s/^\s*(\w+)\s*-\s*(\w+),/make_three($1, $len) . ',' . make_three($2, $len) . ','/e;
					s/\s*,\s*/\t/g;
				}
			}
			$ref->{zone_data} = \@zone;
		}
	}
	for (keys %zones) {
		$Vend::Cfg->{Shipping_zone}{$_} = $zones{$_};
	}
	$Vend::Cfg->{Shipping_line} = []
		if ! $Vend::Cfg->{Shipping_line};
	unshift @{$Vend::Cfg->{Shipping_line}}, @shipping;
	1;
}

*custom_shipping = \&shipping;

# Sets the value of a scratchpad field
sub set_scratch {
	my($var,$val) = @_;
    $::Scratch->{$var} = $val;
	return '';
}

# Sets the value of a temporary scratchpad field
sub set_tmp {
	my($var,$val) = @_;
	push @Vend::TmpScratch, $var;
    $::Scratch->{$var} = $val;
	return '';
}

sub timed_build {
    my $file = shift;
    my $opt = shift;
	my $abort;

	if (defined $opt->{if}) {
		$abort = 1 if ! $opt->{if}; 
	}

	my $saved_file;
	if($opt->{scan}) {
		$saved_file = $Vend::ScanPassed;
		$abort = 1 if ! $saved_file || $file =~ m:MM=:;
	}

	$opt->{login} = 1 if $opt->{auto};

	my $save_scratch;
	if($opt->{new} and $Vend::new_session and !$Vend::Session->{logged_in}) {
#::logDebug("we are new");
		$save_scratch = $::Scratch;
		$Vend::Cookie = 1;
		$Vend::Session->{scratch} = { %{$Vend::Cfg->{ScratchDefault}}, mv_no_session_id => 1, mv_no_count => 1, mv_force_cache => 1 };
		
	}
	else {
		return Vend::Interpolate::interpolate_html($_[0])
			if $abort
			or ( ! $opt->{force}
					and
					(   ! $Vend::Cookie
						or $Vend::BuildingPages
						or ! $opt->{login} && $Vend::Session->{logged_in}
					)
				);
	}
	
	if($opt->{auto}) {
		$opt->{login} =    1 unless defined $opt->{login};
		$opt->{minutes} = 60 unless defined $opt->{minutes};
		$opt->{login} = 1;
		my $dir = "$Vend::Cfg->{ScratchDir}/auto-timed";
		if(! -d $dir) {
			require File::Path;
			File::Path::mkpath($dir);
		}
		$file = "$dir/" . generate_key(@_);
	}

    if($opt->{noframes} and $Vend::Session->{frames}) {
        return '';
    }

	my $secs;
	my $static;
	my $fullfile;
	CHECKDIR: {
		last CHECKDIR if $file;
		my $dir = $Vend::Cfg->{StaticDir};
		$dir = ! -d $dir || ! -w _ ? 'timed' : do { $static = 1; $dir };

		$file = $saved_file || $Vend::Flypart || $Global::Variable->{MV_PAGE};
#::logDebug("static=$file");
		if($saved_file) {
			$file = $saved_file;
			$file =~ s:^scan/::;
			$file = generate_key($file);
			$file = "scan/$file";
		}
		else {
		 	$saved_file = $file = ($Vend::Flypart || $Global::Variable->{MV_PAGE});
		}
		$file .= $Vend::Cfg->{StaticSuffix};
		$fullfile = $file;
		$dir .= "/$1" 
			if $file =~ s:(.*)/::;
		if(! -d $dir) {
			require File::Path;
			File::Path::mkpath($dir);
		}
		$file = Vend::Util::catfile($dir, $file);
	}

#::logDebug("saved=$saved_file");
#::logDebug("file=$file exists=" . -f $file);
	if($opt->{minutes}) {
        $secs = int($opt->{minutes} * 60);
    }
	elsif ($opt->{period}) {
		$secs = Vend::Config::time_to_seconds($opt->{period});
	}

    $file = Vend::Util::escape_chars($file);
    if(! $opt->{auto} and ! allowed_file($file)) {
		log_file_violation($file, 'timed_build');
		return undef;
    }

    if( ! -f $file or $secs && (stat(_))[9] < (time() - $secs) ) {
        my $out = Vend::Interpolate::interpolate_html(shift);
		$opt->{umask} = '22' unless defined $opt->{umask};
        Vend::Util::writefile(">$file", $out, $opt );
# STATICPAGE
		if ($Vend::Cfg->{StaticDBM} and Vend::Session::tie_static_dbm(1) ) {
			if ($opt->{scan}) {
				$saved_file =~ s!=([^/]+)=!=$1%3d!g;
				$saved_file =~ s!=([^/]+)-!=$1%2d!g;
#::logDebug("saved_file=$saved_file");
				$Vend::StaticDBM{$saved_file} = $fullfile;
			}
			else {
				$Vend::StaticDBM{$saved_file} = '';
			}
		}
# END STATICPAGE
		$Vend::Session->{scratch} = $save_scratch if $save_scratch;
        return $out;
    }
	$Vend::Session->{scratch} = $save_scratch if $save_scratch;
	return Vend::Util::readfile($file);
}

sub update {
	my ($func, $opt) = @_;
	if($func eq 'quantity') {
		Vend::Order::update_quantity();
	}
	elsif($func eq 'cart') {
		my $cart;
		if($opt->{name}) {
			$cart = $::Carts->{$opt->{name}};
		}
		else {
			$cart = $Vend::Items;
		}
		return if ! ref $cart;
		Vend::Cart::toss_cart($cart, $opt->{name});
	}
	elsif ($func eq 'process') {
		Vend::Dispatch::do_process();
	}
	elsif ($func eq 'values') {
		Vend::Dispatch::update_user();
	}
	elsif ($func eq 'data') {
		Vend::Data::update_data();
	}
	return;
}

my $Ship_its = 0;

sub push_warning {
	$Vend::Session->{warnings} = [$Vend::Session->{warnings}]
		if ! ref $Vend::Session->{warnings};
	push @{$Vend::Session->{warnings}}, errmsg(@_);
	return;
}

sub shipping {
	my($mode, $opt) = @_;
	return undef unless $mode;
    my $save = $Vend::Items;
	my $qual;
	my $final;

	$Vend::Session->{ship_message} = '' if ! $Ship_its;
	die "Too many levels of shipping recursion ($Ship_its)" 
		if $Ship_its++ > MAX_SHIP_ITERATIONS;
	my @bin;

#::logDebug("Check BEGIN, must get to FINAL. Vend::Items=$Vend::Items main=$::Carts->{main}");
	if ($opt->{cart}) {
		my @carts = grep /\S/, split /[\s,]+/, $opt->{cart};
		for(@carts) {
			next unless $::Carts->{$_};
			push @bin, @{$::Carts->{$_}};
		}
	}
	else {
		@bin = @$Vend::Items;
	}
#::logDebug("doing shipping, mode=$mode bin=" . uneval(\@bin));

	$Vend::Session->{ship_message} = '' if $opt->{reset_message};

	my($field, $code, $i, $total, $cost, $multiplier, $formula, $error_message);

#	my $ref = $Vend::Cfg;
#
#	if(defined $Vend::Cfg->{Shipping_criterion}->{$mode}) {
#		$ref = $Vend::Cfg;
#	}
#	elsif($Vend::Cfg->{Shipping}) {
#		my $locale = 	$::Scratch->{mv_currency}
#						|| $::Scratch->{mv_locale}
#						|| $::Vend::Cfg->{DefaultLocale}
#						|| 'default';
#		$ref = $Vend::Cfg->{Shipping}{$locale};
#		$field = $ref->{$mode};
#	}
#
#	if(defined $ref->{Shipping_code}{$mode}) {
#		$final = tag_perl($opt->{table}, $opt, $Vend::Cfg->{Shipping_code});
#		goto SHIPFORMAT;
#	}

	$@ = 1;

	# Security hole if we don't limit characters
	$mode !~ /[\s,;{}]/ and 
		eval {'what' =~ /$mode/};

	if ($@) {
#::logDebug("Check ERROR, must get to FINAL. Vend::Items=$Vend::Items main=$::Carts->{main}");
		logError("Bad character(s) in shipping mode '$mode', returning 0");
		goto SHIPFORMAT;
	}

	my $row;
	my @lines;
	@lines = grep $_->[0] =~ /^$mode/, @{$Vend::Cfg->{Shipping_line}};
	goto SHIPFORMAT unless @lines;
#::logDebug("shipping lines selected: " . uneval(\@lines));
	my $q;
	if($lines[0][QUERY]) {
		my $q = interpolate_html($lines[0][QUERY]);
		$q =~ s/=\s+?\s*/= '$mode' /g;
		$q =~ s/\s+like\s+?\s*/ LIKE '%$mode%' /ig;
		my $ary = query($q, { wantarray => 1 });
		if(ref $ary) {
			@lines = @$ary;
#::logDebug("shipping lines reselected with SQL: " . uneval(\@lines));
		}
		else {
#::logDebug("shipping lines failed reselect with SQL query '$q'");
		}
	}

	my $o = get_option_hash($lines[0][OPT]) || {};

#::logDebug("shipping opt=" . uneval($o));

	if($o->{limit}) {
		$o->{filter} = '(?i)\s*[1ty]' if ! $o->{filter};
#::logDebug("limiting, filter=$o->{filter} limit=$o->{limit}");
		my $patt = qr{$o->{filter}};
		@bin = grep $_->{$o->{limit}} =~ $patt, @bin;
	}
	$::Carts->{mv_shipping} = \@bin;

	tag_cart('mv_shipping');

#::logDebug("Check 2, must get to FINAL. Vend::Items=" . uneval($Vend::Items) . " main=" . uneval($::Carts->{main}) . " mv_shipping=" . uneval($::Carts->{mv_shipping}));

	if($o->{perl}) {
		$Vend::Interpolate::Shipping   = $lines[0];
		$field = $lines[0][CRIT];
		$field = tag_perl($opt->{tables}, $opt, $field)
			if $field =~ /[^\w:]/;
		$qual  = tag_perl($opt->{tables}, $opt, $o->{qual})
					if $o->{qual};
	}
	elsif ($o->{mml}) {
		$Vend::Interpolate::Shipping   = $lines[0];
		$field = tag_perl($opt->{tables}, $opt, $lines[0][CRIT]);
		$qual =  tag_perl($opt->{tables}, $opt, $o->{qual})
					if $o->{qual};
	}
	elsif($lines[0][CRIT] =~ /[[\s]|__/) {
		($field, $qual) = split /\s+/, interpolate_html($lines[0][CRIT]), 2;
		if($qual =~ /{}/) {
			logError("Bad qualification code '%s', returning 0", $qual);
			goto SHIPFORMAT;
		}
	}
	else {
		$field = $lines[0][CRIT];
	}

	goto SHIPFORMAT unless $field;

	# See if the field needs to be returned by a Interchange function.
	# If a space is encountered, a qualification code
	# will be set up, with any characters after the first space
	# used to determine geography or other qualifier for the mode.
	
	# Uses the quantity on the order form if the field is 'quantity',
	# otherwise goes to the database.
    $total = 0;

	if($field =~ /^[\d.]+$/) {
#::logDebug("Is a number selection");
		$total = $field;
	}
	elsif($field eq 'quantity') {
#::logDebug("quantity selection");
    	foreach $i (0 .. $#$Vend::Items) {
			$total = $total + $Vend::Items->[$i]->{$field};
    	}
	}
	elsif ( index($field, ':') != -1) {
#::logDebug("outboard field selection");
		my ($base, $field) = split /:+/, $field;
		my $db = database_exists_ref($base);
		unless ($db and db_column_exists($db,$field) ) {
			logError("Bad shipping field '$field' or table '$base'. Returning 0");
			goto SHIPFORMAT;
		}
    	foreach $i (0 .. $#$Vend::Items) {
			my $item = $Vend::Items->[$i];
			$total += (database_field($base, $item->{code}, $field) || 0) *
						$item->{quantity};
		}
	}
	else {
#::logDebug("standard field selection");
	    my $use_modifier;

	    if ($::Variable->{MV_SHIP_MODIFIERS}){
			my @pieces = grep {$_ = quotemeta $_} split(/[\s,|]+/,$::Variable->{MV_SHIP_MODIFIERS});
			my $regex = join('|',@pieces);
			$use_modifier = 1 if ($regex && $field =~ /^($regex)$/);
	    }

	    my $col_checked = 0;
	    foreach my $item (@$Vend::Items){
		my $value;
		if ($use_modifier && defined $item->{$field}){
		    $value = $item->{$field};
		}else{
		    unless ($col_checked++ || column_exists $field){
			logError("Custom shipping field '$field' doesn't exist. Returning 0");
			$total = 0;
			goto SHIPFORMAT;
		    }
		    my $base = $item->{mv_ib} || $Vend::Cfg->{ProductFiles}[0];
		    $value = tag_data($base, $field, $item->{code});
		}
		$total += ($value * $item->{quantity});
	    }
	}

	# We will LAST this loop and go to SHIPFORMAT if a match is found
	SHIPIT: 
	foreach $row (@lines) {
#::logDebug("processing mode=$row->[MODE] field=$field total=$total min=$row->[MIN] max=$row->[MAX]");

		next unless  $total <= $row->[MAX] and $total >= $row->[MIN];

		if($qual) {
			next unless
				$row->[CRIT] =~ m{(^|\s)$qual(\s|$)} or
				$row->[CRIT] !~ /\S/;
		}

		$o = get_option_hash($row->[OPT], $o)
			if $row->[OPT];
		# unless field begins with 'x' or 'f', straight cost is returned
		# - otherwise the quantity is multiplied by the cost or a formula
		# is applied
		my $what = $row->[COST];
		if($what !~ /^[a-zA-Z]\w+$/) {
			$what =~ s/^\s+//;
			$what =~ s/[ \t\r]+$//;
		}
		if($what =~ /^(-?(?:\d+(?:\.\d*)?|\.\d+))$/) {
			$final += $1;
			last SHIPIT unless $o->{continue};
		}
		elsif ($what =~ /^f\s*(.*)/i) {
			$formula = $o->{formula} || $1;
			$formula =~ s/\@\@TOTAL\@\\?\@/$total/ig;
			$formula = interpolate_html($formula)
				if $formula =~ /__\w+__|\[\w/;
			$cost = $Vend::Interpolate::ready_safe->reval($formula);
			if($@) {
				$error_message   = errmsg(
								"Shipping mode '%s': bad formula. Returning 0.",
								$mode,
							);
				logError($error_message);
				last SHIPIT;
			}
			$final += $cost;
			last SHIPIT unless $o->{continue};
		}
		elsif ($what =~ /^>>(\w+)/) {
			my $newmode = $1;
			local($opt->{redirect_from});
			$opt->{redirect_from} = $mode;
			return shipping($newmode, $opt);
		}
		elsif ($what eq 'x') {
			$final += ($o->{multiplier} * $total);
			last SHIPIT unless $o->{continue};
		}
		elsif ($what =~ s/^x\s*(-?[\d.]+)\s*$/$1/) {
			$final += ($what * $total);
			last SHIPIT unless $o->{continue};
		}
		elsif ($what =~ s/^([uA-Z])\s*//) {
			my $zselect = $o->{zone} || $1;
			my ($type, $geo, $adder, $mod, $sub);
			($type, $adder) = @{$o}{qw/table adder/};
			$o->{geo} ||= 'zip';
			if(! $type) {
				$what = interpolate_html($what);
				($type, $geo, $adder, $mod, $sub) = split /\s+/, $what, 5;
				$o->{adder}    = $adder;
				$o->{round}    = 1  if $mod =~ /round/;
				$o->{at_least} = $1 if $mod =~ /min\s*([\d.]+)/;
			}
			else {
				$geo = $::Values->{$o->{geo}} || $o->{default_geo};
			}
#::logDebug("ready to tag_ups type=$type geo=$geo total=$total zone=$zselect options=$o");
			$cost = tag_ups($type,$geo,$total,$zselect,$o);
			$final += $cost;
			last SHIPIT unless $o->{continue};
		}
		elsif ($what =~ s/^([im])\s*//) {
			my $select = $1;
			$what =~ s/\@\@TOTAL\@\@/$total/g;
			my ($item, $field, $sum);
			my (@items) = @{$Vend::Items};
			my @fields = split /\s+/, $qual;
			if ($select eq 'm') {
				$sum = { code => $mode, quantity => $total };
			}
			foreach $item (@items) {
				for(@fields) {
					if(s/(.*):+//) {
						$item->{$_} = tag_data($1, $_, $item->{code});
					}
					else {
						$item->{$_} = product_field($_, $item->{code});
					}
					$sum->{$_} += $item->{$_} if defined $sum;
				}
			}
			@items = ($sum) if defined $sum;
			for(@items) {
				$cost = Vend::Data::chain_cost($_, $what);
				if($cost =~ /[A-Za-z]/) {
					$cost = shipping($cost);
				}
				$final += $cost;
			}
			last SHIPIT unless $o->{continue};
		}
		elsif ($what =~ s/^e\s*//) {
			$error_message = $what;
			$error_message =~ s/\@\@TOTAL\@\@/$total/ig;
			$final = 0 unless $final;
			last SHIPIT unless $o->{continue};
		}
		else {
			$error_message = errmsg( "Unknown shipping call '%s'", $what);
			undef $final;
			last SHIPIT;
		}
	}

	if ($final == 0 and $o->{'next'}) {
		return shipping($o->{'next'}, $opt);
	}
	elsif(defined $o->{additional}) {
		my @extra = grep /\S/, split /[\s\0,]+/, $row->[OPT]->{additional};
		for(@extra) {
			$final += shipping($_, {});
		}
	}

#::logDebug("Check 3, must get to FINAL. Vend::Items=$Vend::Items main=$::Carts->{main}");


	SHIPFORMAT: {
		$Vend::Session->{ship_message} .= $error_message
			if defined $error_message;
		undef $::Carts->{mv_shipping};
		$Vend::Items = $save;
#::logDebug("Check FINAL. Vend::Items=$Vend::Items main=$::Carts->{main}");
		last SHIPFORMAT unless defined $final;
#::logDebug("ship options: " . uneval($o) );
		$final /= $Vend::Cfg->{PriceDivide}
			if $o->{PriceDivide} and $Vend::Cfg->{PriceDivide} != 0;
		unless ($o->{free}) {
			return '' if $final == 0;
			$o->{adder} =~ s/\bx\b/$final/g;
			$o->{adder} =~ s/\@\@TOTAL\@\\?\@/$final/g;
			$o->{adder} = $ready_safe->reval($o->{adder});
			$final += $o->{adder} if $o->{adder};
			$final = POSIX::ceil($final) if is_yes($o->{round});
			if($o->{at_least}) {
				$final = $final > $o->{at_least} ? $final : $o->{at_least};
			}
		}
		if($opt->{default}) {
			if(! $opt->{handling}) {
				$::Values->{mv_shipmode} = $mode;
			}
			else {
				$::Values->{mv_handling} = $mode;
			}
			undef $opt->{default};
		}
		return $final unless $opt->{label};
		my $number;
		if($o->{free} and $final == 0) {
			$number = $opt->{free} || $o->{free};
#::logDebug("This is free, mode=$mode number=$number");
		}
		else {
			return $final unless $opt->{label};
#::logDebug("actual options: " . uneval($o));
			$number = Vend::Util::currency( 
											$final,
											$opt->{noformat},
									);
		}

		$opt->{format} ||= '%M=%D (%F)' if $opt->{output_options};
		
		my $label = $opt->{format} || '<OPTION VALUE="%M"%S>%D (%F)';
		my $sel = $::Values->{mv_shipmode} eq $mode;
#::logDebug("label start: $label");
		my %subst = (
						'%' => '%',
						M => $opt->{redirect_from} || $mode,
						T => $total,
						S => $sel ? ' SELECTED' : '',
						C => $sel ? ' CHECKED' : '',
						D => $row->[DESC] || $Vend::Cfg->{Shipping_desc}{$mode},
						L => $row->[MIN],
						H => $row->[MAX],
						O => '$O',
						F => $number,
						N => $final,
						E => defined $error_message ? "(ERROR: $error_message)" : '',
						e => $error_message,
						Q => $qual,
					);
#::logDebug("labeling, subst=" . ::uneval(\%subst));
		$subst{D} = errmsg($subst{D});
		if($opt->{output_options}) {
			for(qw/ D E F f /) {
				next unless $subst{$_};
				$subst{$_} =~ s/,/&#44;/g;
			}
		}
		$label =~ s/(%(.))/exists $subst{$2} ? $subst{$2} : $1/eg;
#::logDebug("label intermediate: $label");
		$label =~ s/(\$O{(.*?)})/$o->{$2}/eg;
#::logDebug("label returning: $label");
		return $label;
	}

	# If we got here, the mode and quantity fit was not found
	$Vend::Session->{ship_message} .=
		"No match found for mode '$mode', quantity '$total', "	.
		($qual ? "qualifier '$qual', " : '')					.
		"returning 0. ";
	return undef;
}

sub taxable_amount {
	my($cart) = @_;
    my($taxable, $i, $code, $item, $tmp, $quantity);

	return subtotal($cart || undef) unless $Vend::Cfg->{NonTaxableField};

	my($save);

    if ($cart) {
        $save = $Vend::Items;
        tag_cart($cart);
    }

    $taxable = 0;

    foreach $i (0 .. $#$Vend::Items) {
		$item =	$Vend::Items->[$i];
		next if is_yes( $item->{mv_nontaxable} );
		next if is_yes( item_field($item, $Vend::Cfg->{NonTaxableField}) );
		$tmp = item_subtotal($item);
		unless (defined $Vend::Session->{discount}) {
			$taxable += $tmp;
		}
		else {
			$taxable += apply_discount($item);
		}
    }

	if (defined $Vend::Session->{discount}->{ENTIRE_ORDER}) {
		$Vend::Interpolate::q = tag_nitems();
		$Vend::Interpolate::s = $taxable;
		my $cost = $Vend::Interpolate::ready_safe->reval(
							 $Vend::Session->{discount}{ENTIRE_ORDER},
						);
		if($@) {
			logError
				"Discount ENTIRE_ORDER has bad formula. Returning normal subtotal.";
			$cost = $taxable;
		}
		$taxable = $cost;
	}

	$Vend::Items = $save if defined $save;

	return $taxable;
}

sub tag_handling {
	my ($mode, $opt) = @_;
	$opt = { noformat => 1, convert => 1 } unless $opt;

	if($opt->{default}) {
		undef $opt->{default}
			if tag_shipping( undef, {handling => 1});
	}

	$opt->{handling} = 1;
	if(! $mode) {
		$mode = $::Values->{mv_handling} || undef;
	}
	return tag_shipping($mode, $opt);
}

sub tag_shipping {
	my($mode, $opt) = @_;
	$opt = { noformat => 1, convert => 1 } unless $opt;
	$Ship_its = 0;
	if(! $mode) {
		$mode = $opt->{handling}
				? ($::Values->{mv_handling})
				: ($::Values->{mv_shipmode} || 'default');
	}
	$Vend::Cfg->{Shipping_line} = [] 
		if $opt->{reset_modes};
	read_shipping(undef, $opt) if $Vend::Cfg->{SQL_shipping};
	read_shipping(undef, $opt) if $opt->{add};
	read_shipping($opt->{file}) if $opt->{file};
	my $out;


	my (@modes) = grep /\S/, split /[\s,\0]+/, $mode;
	if($opt->{default}) {
		undef $opt->{default}
			if tag_shipping($::Values->{mv_shipmode});
	}
	if($opt->{label} || $opt->{widget}) {
		my @out;
		if($opt->{widget}) {
			$opt->{label} = 1;
			$opt->{output_options} = 1;
		}
		for(@modes) {
			push @out, shipping($_, $opt);
		}
		@out = grep /=.+/, @out;
		if($opt->{widget}) {
			my $o = { %$opt };
			$o->{type} = delete $o->{widget};
			$o->{passed} = join ",", @out;
			$o->{name} ||= 'mv_shipmode';
			$o->{value} ||= $::Values->{mv_shipmode};
			$out = Vend::Form::display($o);
		}
		else {
			join "", @out;
		}
	}
	else {
		### If the user has assigned to shipping or handling,
		### we use their value
		if($Vend::Session->{assigned}) {
			my $tag = $opt->{handling} ? 'handling' : 'shipping';
			$out = $Vend::Session->{assigned}{$tag} 
				if defined $Vend::Session->{assigned}{$tag} 
				&& length( $Vend::Session->{assigned}{$tag});
		}
		### If no assignment has been made, we read the shipmodes
		### and use their value
		unless (defined $out) {
			$out = 0;
			for(@modes) {
				$out += shipping($_, $opt) || 0;
			}
		}
		$out = Vend::Util::round_to_frac_digits($out);
		## Conversion would have been done above, force to 0, as
		## found by Frederic Steinfels
		$out = currency($out, $opt->{noformat}, 0, $opt);
	}
	return $out unless $opt->{hide};
	return;
}


sub fly_tax {
	my ($area) = @_;

	if(my $country_check = $::Variable->{TAXCOUNTRY}) {
		$country_check =~ /\b$::Values->{country}\b/
			or return 0;
	}

	if(! $area) {
		my $zone = $Vend::Cfg->{SalesTax};
		while($zone =~ m/(\w+)/g) {
			last if $area = $::Values->{$1};
		}
	}
#::logDebug("flytax area=$area");
	return 0 unless $area;
	my $rates = $::Variable->{TAXRATE};
	my $taxable_shipping = $::Variable->{TAXSHIPPING} || '';
	my $taxable_handling = $::Variable->{TAXHANDLING} || '';
	$rates =~ s/^\s+//;
	$rates =~ s/\s+$//;
	$area =~ s/^\s+//;
	$area =~ s/\s+$//;
	my (@rates) = split /\s*,\s*/, $rates;
	my $rate;
	for(@rates) {
		my ($k,$v) = split /\s*=\s*/, $_, 2;
		next unless "\U$k" eq "\U$area";
		$rate = $v;
		$rate = $rate / 100 if $rate > 1;
		last;
	}
#::logDebug("flytax rate=$rate");
	return 0 unless $rate;
	my $amount = taxable_amount();
#::logDebug("flytax before shipping amount=$amount");
	$amount   += tag_shipping()
		if $taxable_shipping =~ m{(^|[\s,])$area([\s,]|$)}i;
	$amount   += tag_handling()
		if $taxable_handling =~ m{(^|[\s,])$area([\s,]|$)}i;
#::logDebug("flytax amount=$amount return=" . $amount*$rate);
	return $amount * $rate;
}

sub tax_vat {
	my($type, $opt) = @_;
#::logDebug("entering VAT, opts=" . uneval($opt));
	my $cfield = $::Variable->{MV_COUNTRY_FIELD} || 'country';
	my $country = $opt->{country} || $::Values->{$cfield};

	return 0 if ! $country;
	my $ctable   = $opt->{country_table}
				|| $::Variable->{MV_COUNTRY_TABLE}
				|| 'country';
	my $c_taxfield   = $opt->{country_tax_field}
				|| $::Variable->{MV_COUNTRY_TAX_FIELD}
				|| 'tax';
#::logDebug("ctable=$ctable c_taxfield=$c_taxfield country=$country");
	$type ||= tag_data($ctable, $c_taxfield, $country)
		or return 0;
#::logDebug("tax type=$type");
	$type =~ s/^\s+//;
	$type =~ s/\s+$//;

	my @taxes;

	if($type =~ /^(\w+)$/) {
		my $sfield = $1;
		my $state  = $opt->{state} || $::Values->{$sfield};
		return 0 if ! $state;
		my $stable   = $opt->{state_table}
					|| $::Variable->{MV_STATE_TABLE}
					|| 'state';
		my $s_taxfield   = $opt->{state_tax_field}
					|| $::Variable->{MV_STATE_TAX_FIELD}
					|| 'tax';
		my $s_taxtype   = $opt->{tax_type_field} 
					|| $::Variable->{MV_TAX_TYPE_FIELD}
					|| 'tax_name';
		my $db = database_exists_ref($stable)
			or return 0;
		my $addl = '';
		if($opt->{tax_type}) {
			$addl = " AND $s_taxtype = " .
					$db->quote($opt->{tax_type}, $s_taxtype);
		}
		my $q = qq{
						SELECT $s_taxfield FROM $stable
						WHERE  $cfield = '$country'
						AND    $sfield = '$state'
						$addl
					};
#::logDebug("tax state query=$q");
		my $ary;
		eval {
			$ary = $db->query($q);
		};
		if($@) {
			logError("error on state tax query %s", $q);
		}
#::logDebug("query returns " . uneval($ary));
		return 0 unless ref $ary;
		for(@$ary) {
			next unless $_->[0];
			push @taxes, $_->[0];
	}
	}
	else {
		@taxes = $type;
	}

	my $total = 0;
	foreach my $t (@taxes) {
		$t =~ s/^\s+//;
		$t =~ s/\s+$//;
		if ($t =~ /simple:(.*)/) {
			$total += fly_tax($::Values->{$1});
			next;
		}
		elsif ($t =~ /handling:(.*)/) {
			my @modes = grep /\S/, split /[\s,]+/, $1;
			
			my $cost = 0;
			$cost += tag_handling($_) for @modes;
			$total += $cost;
			next;
		}
		my $tax;
#::logDebug("tax type=$t");
		if($t =~ /^(\d+(?:\.\d+)?)\s*(\%)$/) {
			my $rate = $1;
			$rate /= 100 if $2;
			my $amount = Vend::Interpolate::taxable_amount();
			$total += ($rate * $amount);
		}
		else {
			$tax = Vend::Util::get_option_hash($t);
		}
#::logDebug("tax hash=" . uneval($tax));
		my $pfield   = $opt->{tax_category_field}
					|| $::Variable->{MV_TAX_CATEGORY_FIELD}
					|| 'tax_category';
		my @pfield = split /:+/, $pfield;

		for my $item (@$Vend::Items) {
			my $rhash = tag_data($item->{mv_ib}, undef, $item->{code}, { hash => 1});
			my $cat = join ":", @{$rhash}{@pfield};
			my $rate = defined $tax->{$cat} ? $tax->{$cat} : $tax->{default};
#::logDebug("item $item->{code} cat=$cat rate=$rate");
			$rate =~ s/\s*%\s*$// and $rate /= 100;
			next if $rate <= 0;
			my $sub = Vend::Data::item_subtotal($item);
#::logDebug("item $item->{code} subtotal=$sub");
			$total += $sub * $rate;
#::logDebug("tax total=$total");
		}
			
		## Add some tax on shipping if rate for mv_shipping category is set
		if ($tax->{mv_shipping} > 0) {
			my $rate = $tax->{mv_shipping};
			$rate =~ s/\s*%\s*$// and $rate /= 100;
			my $sub = tag_shipping() * $rate;
#::logDebug("applying shipping tax rate of $rate, tax of $sub");
			$total += $sub;
		}

		## Add some tax on handling if rate for mv_handling category is set
		if ($tax->{mv_handling} > 0) {
			my $rate = $tax->{mv_handling};
			$rate =~ s/\s*%\s*$// and $rate /= 100;
			my $sub = tag_handling() * $rate;
#::logDebug("applying handling tax rate of $rate, tax of $sub");
			$total += $sub;
		}

	}
	return $total;
}

# Calculate the sales tax
sub salestax {
	my($cart, $opt) = @_;

	$opt ||= {};

	my($save);
	### If the user has assigned to salestax,
	### we use their value come what may, no rounding
	if($Vend::Session->{assigned}) {
		return $Vend::Session->{assigned}{salestax} 
			if defined $Vend::Session->{assigned}{salestax} 
			&& length( $Vend::Session->{assigned}{salestax});
	}

    if ($cart) {
        $save = $Vend::Items;
        tag_cart($cart);
    }

#::logDebug("salestax entered, cart=$cart");
	my $tax_hash;
	my $cost;
	if($Vend::Cfg->{SalesTax} eq 'multi') {
		$cost = tax_vat($opt->{type}, $opt);
	}
	elsif($Vend::Cfg->{SalesTax} =~ /\[/) {
		$cost = interpolate_html($Vend::Cfg->{SalesTax});
	}
	elsif($Vend::Cfg->{SalesTaxFunction}) {
		$tax_hash = tag_calc($Vend::Cfg->{SalesTaxFunction});
#::logDebug("found custom tax function: " . uneval($tax_hash));
	}
	else {
		$tax_hash = $Vend::Cfg->{SalesTaxTable};
#::logDebug("looking for tax function: " . uneval($tax_hash));
	}

# if we have a cost from previous routines, return it
	if(defined $cost) {
		$Vend::Items = $save if $save;
		return Vend::Util::round_to_frac_digits($cost);
	}

	if(! $tax_hash) {
		$cost = fly_tax();
	}

#::logDebug("got to tax function: " . uneval($tax_hash));
	my $amount = taxable_amount();
	my($r, $code);
	# Make it upper case for state and overseas postal
	# codes, zips don't matter
	my(@code) = map { (uc $::Values->{$_}) || '' }
					split /[,\s]+/, $Vend::Cfg->{SalesTax};
	push(@code, 'DEFAULT');

	$tax_hash = { DEFAULT => } if ! ref($tax_hash) =~ /HASH/;

	if(! defined $tax_hash->{DEFAULT}) {
#::logDebug("Sales tax failed, no tax source, returning 0");
		return 0;
	}

	CHECKSHIPPING: {
		last CHECKSHIPPING unless $Vend::Cfg->{TaxShipping};
		foreach $code (@code) {
			next unless $Vend::Cfg->{TaxShipping} =~ /\b\Q$code\E\b/i;
			$amount += tag_shipping();
			last;
		}
	}

	foreach $code (@code) {
		next unless $code;
		# Trim the zip+4
#::logDebug("salestax: check code '$code'");
		$code =~ s/(\d{5})-\d{4}/$1/;
		next unless defined $tax_hash->{$code};
		my $tax = $tax_hash->{$code};
#::logDebug("salestax: found tax='$tax' for code='$code'");
		if($tax =~ /^-?(?:\d+(?:\.\d*)?|\.\d+)$/) {
			$r = $amount * $tax;
		}
		else {
			$r = Vend::Data::chain_cost(
					{	mv_price	=> $amount, 
						code		=> $code,
						quantity	=> $amount, }, $tax);
		}
#::logDebug("salestax: final tax='$r' for code='$code'");
		last;
	}

	$Vend::Items = $save if defined $save;

	return Vend::Util::round_to_frac_digits($r);
}

# Returns just subtotal of items ordered, with discounts
# applied
sub subtotal {
	my($cart) = @_;

	### If the user has assigned to salestax,
	### we use their value come what may, no rounding
	if($Vend::Session->{assigned}) {
		return $Vend::Session->{assigned}{subtotal}
			if defined $Vend::Session->{assigned}{subtotal} 
			&& length( $Vend::Session->{assigned}{subtotal});
	}

    my($save,$subtotal, $i, $item, $tmp, $cost, $formula);
	if ($cart) {
		$save = $Vend::Items;
		tag_cart($cart);
	}

	levies() unless $Vend::Levying;

	my $discount = defined $Vend::Session->{discount};
    $subtotal = 0;
	$tmp = 0;

    foreach $i (0 .. $#$Vend::Items) {
        $item = $Vend::Items->[$i];
        $tmp = Vend::Data::item_subtotal($item);
        if($discount) {
            $subtotal +=
                apply_discount($item, $tmp);
        }
        else { $subtotal += $tmp }
	}

	if (defined $Vend::Session->{discount}->{ENTIRE_ORDER}) {
		$formula = $Vend::Session->{discount}->{ENTIRE_ORDER};
		$formula =~ s/\$q\b/tag_nitems()/eg; 
		$formula =~ s/\$s\b/$subtotal/g; 
		$cost = $Vend::Interpolate::ready_safe->reval($formula);
		if($@) {
			logError
				"Discount ENTIRE_ORDER has bad formula. Returning normal subtotal.\n$@";
			$cost = $subtotal;
		}
		$subtotal = $cost;
	}
	$Vend::Items = $save if defined $save;
	$Vend::Session->{latest_subtotal} = $subtotal;
    return $subtotal;
}


# Returns the total cost of items ordered.

sub total_cost {
	my($cart) = @_;
    my($total, $i, $save);

	if ($cart) {
		$save = $Vend::Items;
		tag_cart($cart);
	}

	$total = 0;

	if($Vend::Cfg->{Levies}) {
		$total = subtotal();
		$total += levies();
	}
	else {
		my $shipping = 0;
		$shipping += tag_shipping()
			if $::Values->{mv_shipmode};
		$shipping += tag_handling()
			if $::Values->{mv_handling};
		$total += subtotal();
		$total += $shipping;
		$total += salestax();
	}
	$Vend::Items = $save if defined $save;
	$Vend::Session->{latest_total} = $total;
    return $total;
}

sub tag_ups {
	my($type,$zip,$weight,$code,$opt) = @_;
	my(@data);
	my(@fieldnames);
	my($i,$point,$zone);

#::logDebug("tag_ups: type=$type zip=$zip weight=$weight code=$code opt=" . uneval($opt));
	$code = 'u' unless $code;

	unless (defined $Vend::Database{$type}) {
		logError("Shipping lookup called, no database table named '%s'", $type);
		return undef;
	}
	unless (ref $Vend::Cfg->{Shipping_zone}{$code}) {
		logError("Shipping '%s' lookup called, no zone defined", $code);
		return undef;
	}
	my $zref = $Vend::Cfg->{Shipping_zone}{$code};
	
	unless (defined $zref->{zone_data}) {
		logError("$zref->{zone_name} lookup called, zone data not found");
		return undef;
	}

	my $zdata = $zref->{zone_data};
	# UPS doesn't like fractional pounds, rounds up

	# here we can adapt for pounds/kg
	if ($zref->{mult_factor}) {
		$weight = $weight * $zref->{mult_factor};
	}
	$weight = POSIX::ceil($weight);

	$zip = substr($zip, 0, ($zref->{str_length} || 3));

	@fieldnames = split /\t/, $zdata->[0];
	for($i = 2; $i < @fieldnames; $i++) {
		next unless $fieldnames[$i] eq $type;
		$point = $i;
		last;
	}

	unless (defined $point) {
		logError("Zone '$code' lookup failed, type '$type' not found");
		return undef;
	}

	my $eas_point;
	my $eas_zone;
	if($zref->{eas}) {
		for($i = 2; $i < @fieldnames; $i++) {
			next unless $fieldnames[$i] eq $zref->{eas};
			$eas_point = $i;
			last;
		}
	}

	for(@{$zdata}[1..$#{$zdata}]) {
		@data = split /\t/, $_;
		next unless ($zip ge $data[0] and $zip le $data[1]);
		$zone = $data[$point];
		$eas_zone = $data[$eas_point] if defined $eas_point;
		return 0 unless $zone;
		last;
	}

	if (! defined $zone) {
		$Vend::Session->{ship_message} .=
			"No zone found for geo code $zip, type $type. ";
		return undef;
	}
	elsif (!$zone or $zone eq '-') {
		$Vend::Session->{ship_message} .=
			"No $type shipping allowed for geo code $zip.";
		return undef;
	}

	my $cost;
	$cost =  tag_data($type,$zone,$weight);
	$cost += tag_data($type,$zone,$eas_zone)  if defined $eas_point;
	$Vend::Session->{ship_message} .=
								errmsg(
									"Zero cost returned for mode %s, geo code %s.",
									$type,
									$zip,
								)
		unless $cost;
#::logDebug("tag_ups cost: $cost");
	return $cost;
}

sub levy_sum {
	my ($set, $levies, $repos) = @_;

	$set    ||= $Vend::CurrentCart || 'main';
	$levies ||= $Vend::Cfg->{Levies};
	$repos  ||= $Vend::Cfg->{Levy_repository};

	my $icart = $Vend::Session->{carts}{$set} || [];

	my @sums;
	for(@$icart) {
		push @sums, @{$_}{sort keys %$_};
	}
	my $items;
	for(@$levies) {
		next unless $items = $repos->{$_}{check_status};
		push @sums, @{$::Values}{ split /[\s,\0]/, $items };
	}
	return generate_key(@sums);
}

sub levies {
	my($recalc, $set, $opt) = @_;

	my $levies;
	return unless $levies = $Vend::Cfg->{Levies};


	$opt ||= {};
	my $repos = $Vend::Cfg->{Levy_repository};
#::logDebug("Calling levies, recalc=$recalc group=$opt->{group}");

	if(! $repos) {
		logOnce('error', "Levies set but no levies defined! No tax or shipping.");
		return;
	}
	$Vend::Levying = 1;
	$set ||= $Vend::CurrentCart;
	$set ||= 'main';

	$Vend::Session->{levies} ||= {};
	
	my $lcheck = $Vend::Session->{latest_levy} ||= {};
	$lcheck = $lcheck->{$set} ||= {};

	if($Vend::LeviedOnce and ! $recalc and ! $opt->{group} and $lcheck->{sum}) {
		my $newsum = levy_sum($set, $levies, $repos);
#::logDebug("did levy check, new=$newsum old=$lcheck->{sum}");
		if($newsum  eq $lcheck->{sum}) {
			undef $Vend::Levying;
#::logDebug("levy returning cached value");
			return $lcheck->{total};
		}
	}

	my $lcart = $Vend::Session->{levies}{$set} = [];
	
	my $run = 0;
	for my $name (@$levies) {
		my $l = $repos->{$name};
#::logDebug("Levying $name, repos => " . uneval($l));
		if(! $l) {
			logOnce('error', "Levy '%s' called but not defined. Skipping.", $name);
			next;
		}
		if(my $if = $l->{include_if}) {
			if($if =~ /^\w+$/) {
				next unless $::Values->{$if};
			}
			elsif($if =~ /__[A-Z]\w+__|[[a-zA-Z]/) {
				next unless interpolate_html($if);
			}
			else {
				next unless tag_calc($if);
			}
		}
		if(my $if = $l->{exclude_if}) {
			if($if =~ /^\w+$/) {
				next if $::Values->{$if};
			}
			elsif($if =~ /__[A-Z]\w+__|[[a-zA-Z]/) {
				next if interpolate_html($if);
			}
			else {
				next if tag_calc($if);
			}
		}
		my $type = $l->{type} || ($name eq 'salestax' ? 'salestax' : 'shipping');
		my $mode;

		if($l->{mode_from_values}) {
			$mode = $::Values->{$l->{mode_from_values}};
		}
		elsif($l->{mode_from_scratch}) {
			$mode = $::Scratch->{$l->{mode_from_scratch}};
		}

		$mode ||= ($l->{mode} || $name);
		my $group = $l->{group} || $type;
		my $cost = 0;
		my $sort;
		my $desc;
		my $lab_field = $l->{label_value};
		if($type eq 'salestax') {
			my $save;
			$sort = $l->{sort} || '010';
			$lab_field ||= $Vend::Cfg->{SalesTax};
			if($l->{tax_fields}) {
				$save = $Vend::Cfg->{SalesTax};
				$Vend::Cfg->{SalesTax} = $l->{tax_fields};
			}
			elsif ($l->{multi}) {
				$save = $Vend::Cfg->{SalesTax};
				$Vend::Cfg->{SalesTax} = 'multi';
			}
			$cost = salestax(undef, { tax_type => $l->{tax_type} } );
			$l->{description} ||= 'Sales Tax';
			$Vend::Cfg->{SalesTax} = $save if defined $save;
		}
		elsif ($type eq 'shipping' or $type eq 'handling') {
			if(not $sort = $l->{sort}) {
				$sort = $type eq 'handling' ? 100 : 500;
			}
			$cost = shipping($mode);
			$l->{description} = tag_shipping_desc($mode);
		}
		elsif($type eq 'custom') {
			my $sub;
			SUBFIND: {
				$sub = $Vend::Cfg->{Sub}{$mode} || $Global::GlobalSub->{$mode}
					and last SUBFIND;
				eval {
					$sub = $Vend::Cfg->{UserTag}{Routine}{$mode};
				};
				last SUBFIND if ! $@ and $sub;
				eval {
					$sub = $Global::UserTag->{Routine}{$mode};
				};
			}
			if( ref($sub) eq 'CODE') {
				($cost, $desc, $sort) = $sub->($l);
			}
			else {
				logError("No subroutine found for custom levy '%s'", $name);
			}
		}

		$desc = errmsg(
					$l->{description},
					$::Values->{$lab_field},
				);

		my $cost_format;

		my $item = {
							code			=> $name,
							mode			=> $mode,
							sort			=> $sort,
							cost			=> round_to_frac_digits($cost),
							currency		=> currency($cost),
							group			=> $group,
							label			=> $l->{label} || $desc,
							part_number		=> $l->{part_number},
							description		=> $desc,
						};
		if($cost == 0) {
			next unless $l->{keep_if_zero};
			$item->{free} = 1;
			$item->{free_message} = $l->{free_message} || $cost;
		}

		if(my $target = $l->{add_to}) {
			my $found;
			foreach my $lev (@$lcart) {
				next unless $lev->{code} eq $target;
				$lev->{cost} += $item->{cost};
				$lev->{cost} = round_to_frac_digits($lev->{cost});
				$lev->{currency} = currency($lev->{cost});
				$found = 1;
				last;
			}
			unless($found) {
				push @$lcart, $item;
			}
        }
        else {
                push @$lcart, $item;
        }
	}

	@$lcart = sort { $a->{sort} cmp $b->{sort} } @$lcart;

	for(@$lcart) {
		next if $opt->{group} and $opt->{group} ne $_->{group};
		$run += $_->{cost};
	}

	$run = round_to_frac_digits($run);
	if(! $opt->{group}) {
		$lcheck = $Vend::Session->{latest_levy}{$set} = {};
		$lcheck->{sum}   = levy_sum($set, $levies, $repos);
		$lcheck->{total} = $run;
		$Vend::LeviedOnce = 1;
	}

	undef $Vend::Levying;
	return $run;
}
1;
