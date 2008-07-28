# Vend::Interpolate - Interpret Interchange tags
# 
# $Id: Interpolate.pm,v 2.303.2.3 2008-07-28 21:27:03 mheins Exp $
#
# Copyright (C) 2002-2008 Interchange Development Group
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

package Vend::Interpolate;

require Exporter;
@ISA = qw(Exporter);

$VERSION = substr(q$Revision: 2.303.2.3 $, 10);

@EXPORT = qw (

interpolate_html
subtotal
tag_data
tag_attr_list
$Tag
$CGI
$Session
$Values
$Discounts
$Sub
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

use Safe;

my $hole;
BEGIN {
	eval {
		require Safe::Hole;
		$hole = new Safe::Hole;
	};
}

# We generally know when we are testing these things, but be careful
no warnings qw(uninitialized numeric);

use strict;
use Vend::Util;
use Vend::File;
use Vend::Data;
use Vend::Form;
require Vend::Cart;

use HTML::Entities;
use Vend::Server;
use Vend::Scan;
use Vend::Tags;
use Vend::Subs;
use Vend::Document;
use Vend::Parse;
use POSIX qw(ceil strftime LC_CTYPE);

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
							$Discounts
							$Document
							%Db
							$DbSearch
							%Filter
							$Search
							$Carts
							$Config
							%Sql
							$Items
							$Row
							$Scratch
							$Shipping
							$Session
							$Tag
							$Tmp
							$TextSearch
							$Values
							$Variable
							$Sub
						/;
	@Share_routines = qw/
							&tag_data
							&errmsg
							&Log
							&Debug
							&uneval
							&get_option_hash
							&dotted_hash
							&encode_entities
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
		
		Vend::CharSet->utf8_safe_regex_workaround($ready_safe)
		    if $::Variable->{MV_UTF8};

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
		$Sub        = new Vend::Subs;
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
	$CGI_array  = \%CGI::values_array;
	$CGI        = \%CGI::values;
	$Carts      = $::Carts;
	$Discounts	= $::Discounts;
	$Items      = $Vend::Items;
	$Config     = $Vend::Cfg;
	$Scratch    = $::Scratch;
	$Values     = $::Values;
	$Session    = $Vend::Session;
	$Search     = $::Instance->{SearchObject} ||= {};
	$Variable   = $::Variable;
	$Vend::Calc_initialized = 1;
	return;
}

# Define conditional ops
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
   'filter' => sub { 
   				 my ($string, $filter) = @_;
				 my $newval = filter_value($filter, $string);
				 return $string eq $newval ? 1 : 0;
				},
   'length' => sub { 
   				 my ($string, $lenspec) = @_;
				 my ($min,$max) = split /-/, $lenspec;
				 if($min and length($string) < $min) {
				 	return 0;
				 }
				 elsif($max and length($string) > $max) {
				 	return 0;
				 }
				 else {
				 	return 0 unless length($string) > 0;
				 }
				 return 1;
				},
);

my %file_op = (
	A => sub { -A $_[0] },
	B => sub { -B $_[0] },
	d => sub { -d $_[0] },
	e => sub { -e $_[0] },
	f => sub { -f $_[0] },
	g => sub { -g $_[0] },
	l => sub { -l $_[0] },
	M => sub { -M $_[0] },
	r => sub { -r $_[0] },
	s => sub { -s $_[0] },
	T => sub { -T $_[0] },
	u => sub { -u $_[0] },
	w => sub { -w $_[0] },
	x => sub { -x $_[0] },
);


$cond_op{len} = $cond_op{length};

# Regular expression pre-compilation
my %T;
my %QR;

my $All = '[\000-\377]*';
my $Some = '[\000-\377]*?';
my $Codere = '[-\w#/.]+';
my $Coderex = '[-\w:#=/.%]+';
my $Filef = '(?:%20|\s)+([^]]+)';
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
		/_header_param
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
		_header_param
		_include
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
		_modifier_name
		more
		more_list
		no_match
		on_match
		_quantity_name
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
	'_include'		=> qr($T{_include}$Filef\]),
	'_increment'	=> qr($T{_increment}\]),
	'_last'			=> qr($T{_last}\]\s*($Some)\s*),
	'_line'			=> qr($T{_line}$Opt\]),
	'_next'			=> qr($T{_next}\]\s*($Some)\s*),
	'_options'		=> qr($T{_options}($Spacef[^\]]+)?\]),
	'_header_param'	=> qr($T{_header_param}$Mandf$Optr\]),
	'_header_param_if'	=> qr($T{_header_param}(\d*)$Spacef(!?)\s*($Codere)$Optr\]($Some)),
	'_param_if'		=> qr((?:$T{_param}|$T{_modifier})(\d*)$Spacef(!?)\s*($Codere)$Optr\]($Some)),
	'_param'		=> qr((?:$T{_param}|$T{_modifier})$Mandf\]),
	'_parent_if'	=> qr($T{_parent}(\d*)$Spacef(!?)\s*($Codere)$Optr\]($Some)),
	'_parent'		=> qr($T{_parent}$Mandf\]),
	'_pos_if'		=> qr($T{_pos}(\d*)$Spacef(!?)\s*(-?\d+)$Optr\]($Some)),
	'_pos' 			=> qr($T{_pos}$Spacef(-?\d+)\]),
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
	'more'			=> qr($T{more}\]),
	'more_list'		=> qr($T{more_list}$Optx$Optx$Optx$Optx$Optx\]($Some)$T{'/more_list'}),
	'no_match'   	=> qr($T{no_match}\]($Some)$T{'/no_match'}),
	'on_match'   	=> qr($T{on_match}\]($Some)$T{'/on_match'}),
	'_quantity_name'	=> qr($T{_quantity_name}\]),
	'_modifier_name'	=> qr($T{_modifier_name}$Spacef(\w+)\]),
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

	# Translate Interchange tags embedded in HTML comments like <!--[tag ...]-->
	! $::Pragma->{no_html_comment_embed}
	and
		$$html =~ s/<!--+\[/[/g
			and $$html =~ s/\]--+>/]/g;

	return;
}

sub interpolate_html {
	my ($html, $wantref, $opt) = @_;
	return undef if $Vend::NoInterpolate;
	my ($name, @post);
	my ($bit, %post);

	local($^W);

	my $toplevel;
	if(defined $Vend::PageInit and ! $Vend::PageInit) {
		defined $::Variable->{MV_AUTOLOAD}
			and $html =~ s/^/$::Variable->{MV_AUTOLOAD}/;
		$toplevel = 1;
	}
#::logDebug("opt=" . uneval($opt));

	vars_and_comments(\$html)
		unless $opt and $opt->{onfly};

	$^W = 1 if $::Pragma->{perl_warnings_in_page};

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

sub filter_value {
	my($filter, $value, $tag, @passed_args) = @_;
#::logDebug("filter_value: filter='$filter' value='$value' tag='$tag'");
	my @filters = Text::ParseWords::shellwords($filter); 
	my @args;

	if(! $Vend::Filters_initted++ and my $ref = $Vend::Cfg->{CodeDef}{Filter}) {
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
		if (/^(\d+)([\.\$]?)$/) {
			my $len;
			return $value unless ($len = length($value)) > $1;
			my ($limit, $mod) = ($1, $2);
			unless($mod) {
				substr($value, $limit) = '';
			}
			elsif($mod eq '.') {
				substr($value, $1) = '...';
			}
			elsif($mod eq '$') {
				substr($value, 0, $len - $limit) = '...';
			}
			return $value;
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
		if ( /^words(\d+)(\.?)$/ ) {
			my @str = (split /\s+/, $value);
			if (scalar @str > $1) {
				my $num = $1;
				$value = join(' ', @str[0..--$num]);
				$value .= $2 ? '...' : '';
			}
			next;
		}
		my $sub;
		unless ($sub = $Filter{$_} ||  Vend::Util::codedef_routine('Filter', $_) ) {
			logError ("Unknown filter '%s'", $_);
			next;
		}
		unshift @args, $value, $tag;
		$value = $sub->(@args);
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

	# Only lowercase the first word-characters part of the conditional so that
	# file-T doesn't turn into file-t (which is something different).
	$base =~ s/(\w+)/\L$1/;

	$base =~ s/^!// and $reverse = 1;
	my ($op, $status);
	my $noop;
	$noop = 1, $operator = '' unless defined $operator;

	my $sub;
	my $newcomp;

	if($operator =~ /^([^\s.]+)\.(.+)/) {
		$operator = $1;
		my $tag = $2;
		my $arg;
		if($comp =~ /^\w[-\w]+=/) {
			$arg = get_option_hash($comp);
		}
		else {
			$arg = $comp;
		}

		$Tag ||= new Vend::Tags;
#::logDebug("ready to call tag=$tag with arg=$arg");
		$comp = $Tag->$tag($arg);
	}

	if($sub = $cond_op{$operator}) {
		$noop = 1;
		$newcomp = $comp;
		undef $comp;
		$newcomp =~ s/^(["'])(.*)\1$/$2/s or
			$newcomp =~ s/^qq?([{(])(.*)[})]$/$2/s or
				$newcomp =~ s/^qq?(\S)(.*)\1$/$2/s;
	}

	local($^W) = 0;
	undef $@;
#::logDebug("cond: base=$base term=$term op=$operator comp=$comp newcomp=$newcomp nooop=$noop\n");
#::logDebug (($reverse ? '!' : '') . "cond: base=$base term=$term op=$operator comp=$comp");

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
	elsif($base eq 'scratchd') {
		$op =	qq%$::Scratch->{$term}%;
		$op = "q{$op}" unless defined $noop;
		$op .=	qq%	$operator $comp%
				if defined $comp;
		delete $::Scratch->{$term};
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
	elsif($base =~ /^var(?:iable)?$/) {
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
		my($d,$f,$k) = split /::/, $term, 3;
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
		# Use switch_discount_space to ensure that the hash is set properly.
		switch_discount_space($Vend::DiscountSpaceName)
			unless ref $::Discounts eq 'HASH';
		$op =	qq%$::Discounts->{$term}%;
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
	elsif($base =~ /^file(-([A-Za-z]))?$/) {
		#$op =~ s/[^rwxezfdTsB]//g;
		#$op = substr($op,0,1) || 'f';
		my $fop = $2 || 'f';
		if(! $file_op{$fop}) {
			logError("Unrecognized file test '%s'. Returning false.", $fop);
			$status = 0;
		}
		else {
			$op = $file_op{$fop}->($term);
		}
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
		my @terms = split /::|->|\./, $term;
		eval {
			$op = $Vend::Cfg;
			while(my $t = shift(@terms)) {
				$op = $op->{$t};
			}
		};

		$op = "q{$op}" unless defined $noop;
		$op .=	qq%	$operator $comp%
				if defined $comp;
    }
    elsif($base =~ /^module.version/) {
		eval {
			no strict 'refs';
			$op = ${"${term}::VERSION"};
			$op = "q{$op}" unless defined $noop;
			$op .=	qq%	$operator $comp%
					if defined $comp;
		};
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
	elsif($base eq 'control') {
		$op = 0;
		if (defined $::Scratch->{control_index}
			and defined $::Control->[$Scratch->{control_index}]) {
			$op = qq%$::Control->[$::Scratch->{control_index}]{$term}%;
			$op = "q{$op}"
				unless defined $noop;
			$op .= qq% $operator $comp%
				if defined $comp;
		}
	}
	elsif($base eq 'env') {
		my $env;
		if (my $h = ::http()) {
			$env = $h->{env};
		}
		else {
			$env = \%ENV;
		}
		$op = qq%$env->{$term}%;
		$op = "q{$op}" unless defined $noop;
		$op .= qq% $operator $comp%
			if defined $comp;
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
		
		if($sub) {
			$status = $sub->($op, $newcomp);
			last RUNSAFE;
		}
		elsif ($noop) {
			$status = $op ? 1 : 0;
			last RUNSAFE;
		}

		Vend::CharSet->utf8_safe_regex_workaround($ready_safe)
		    if $::Variable->{MV_UTF8};
		$ready_safe->trap(@{$Global::SafeTrap});
		$ready_safe->untrap(@{$Global::SafeUntrap});
		$status = $ready_safe->reval($op) ? 1 : 0;
		if ($@) {
			logError "Bad if '@_': $@";
			$status = 0;
		}
	}

	$status = $reverse ? ! $status : $status;

	for(@addl) {
		my $chain = /^\[[Aa]/;
		last if ($chain ^ $status);
		$status = ${(new Vend::Parse)->parse($_)->{OUT}} ? 1 : 0;
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
		my $pertinent = Vend::Parse::find_matching_end('elsif', \$elsif);
		unless(defined $pertinent) {
			$pertinent = $elsif;
			$elsif = '';
		}
		$elsif .= '[/elsif]' if $elsif =~ /\S/;
		$out = '[if ' . $pertinent . $elsif . $else . '[/if]';
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
			undef $@;
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
	$max = $::Limit->{option_list} if ! $max;
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
#::logDebug("tag_perl: Attempt to call perl from within Safe.");
		return undef;
	}

#::logDebug("tag_perl: tables=$tables opt=" . uneval($opt) . " body=$body");
#::logDebug("tag_perl initialized=$Vend::Calc_initialized: carts=" . uneval($::Carts));
	if($opt->{subs} or $opt->{arg} =~ /\bsub\b/) {
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
			my $dbh;
			$db = $db->ref();
			if($db->config('type') == 10) {
				my @extra_tabs = $db->_shared_databases();
				push (@tab, @extra_tabs);
				$dbh = $db->dbh();
			} elsif ($db->can('dbh')) {
				$dbh = $db->dbh();
			}

			if($hole) {
				if ($dbh) {
					$Sql{$tab} = $hole->wrap($dbh);
				}
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

	$Tag = $hole->wrap($Tag) if $hole and ! $Vend::TagWrapped++;

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

	$Items = $Vend::Items;

	$body = readfile($opt->{file}) . $body
		if $opt->{file};

	# Skip costly eval of code entirely if perl tag was called with no code,
	# likely used only for the side-effect of opening database handles
	return if $body !~ /\S/;

	$body =~ tr/\r//d if $Global::Windows;

	$MVSAFE::Safe = 1;
	if (
		$opt->{global}
			and
		$Global::AllowGlobal->{$Vend::Cat}
		)
	{
		$MVSAFE::Safe = 0 unless $MVSAFE::Unsafe;
	}

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

	my $msg_type = $opt->{type} || "multipart/mixed";
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
		my $type = $opt->{type} || 'text/plain; charset=US-ASCII';
		my $disposition = $opt->{attach_only}
						? qq{attachment; filename="$desc"}
						: "inline";
		my $encoding = $opt->{transfer_encoding};
		my @headers;
		push @headers, "Content-Type: $type";
		push @headers, "Content-ID: $id";
		push @headers, "Content-Disposition: $disposition";
		push @headers, "Content-Description: $desc";
		push @headers, "Content-Transfer-Encoding: $opt->{transfer_encoding}"
			if $opt->{transfer_encoding};
		my $head = join "\n", @headers;
		$out = <<EndOFmiMe;
--$::Instance->{MIME_BOUNDARY}
$head

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

	unless($opt->{process} and $opt->{process} =~ /\bnostrip\b/i) {
		$data =~ s/\r\n/\n/g;
		$data =~ s/^\s+//;
		$data =~ s/\s+$/\n/;
	}

	my ($delim, $record_delim);
	for(qw/delim record_delim/) {
		next unless defined $opt->{$_};
		$opt->{$_} = $ready_safe->reval(qq{$opt->{$_}});
	}

	if($opt->{type}) {
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
#::logDebug("counter: file=$file start=$opt->{start} sql=$opt->{sql} routine=$opt->{inc_routine} caller=" . scalar(caller()) );
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
			elsif($seq =~ /^\s*SELECT\W/i) {
#::logDebug("found custom SQL SELECT for sequence: $seq");
				my $sth = $dbh->prepare($seq) or die $diemsg;
				$sth->execute or die $diemsg;
				($val) = $sth->fetchrow_array;
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

	for(qw/inc_routine dec_routine/) {
		my $routine = $opt->{$_}
			or next;

		if( ! ref($routine) ) {
			$opt->{$_}   = $Vend::Cfg->{Sub}{$routine};
			$opt->{$_} ||= $Global::GlobalSub->{$routine};
		}
	}

    my $ctr = new Vend::CounterFile
					$file,
					$opt->{start} || undef,
					$opt->{date},
					$opt->{inc_routine},
					$opt->{dec_routine};
    return $ctr->value() if $opt->{value};
    return $ctr->dec() if $opt->{decrement};
    return $ctr->inc();
}

# Returns the text of a user entered field named VAR.
sub tag_value_extended {
    my($var, $opt) = @_;

	my $vspace = $opt->{values_space};
	my $vref;
	if (defined $vspace) {
		if ($vspace eq '') {
			$vref = $Vend::Session->{values};
		}
		else {
			$vref = $Vend::Session->{values_repository}{$vspace} ||= {};
		}
	}
	else {
		$vref = $::Values;
	}

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

	my $val = $CGI::values{$var} || $vref->{$var} || return undef;
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

		unless (Vend::File::allowed_file($file)) {
			Vend::File::log_file_violation($file, 'value-extended');
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
			return $no;
		}
#::logDebug(">$file \$CGI::file{$var}" . uneval($opt)); 
		Vend::Util::writefile(">$file", \$CGI::file{$var}, $opt)
			and return $yes;
		return $no;
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
	local($^W) = 0;

	my $vspace = $opt->{values_space};
	my $vref;
	if (defined $vspace) {
		if ($vspace eq '') {
			$vref = $Vend::Session->{values};
		}
		else {
			$vref = $Vend::Session->{values_repository}{$vspace} ||= {};
		}
	}
	else {
		$vref = $::Values;
	}

	$vref->{$var} = $opt->{set} if defined $opt->{set};

	my $value = defined $vref->{$var} ? $vref->{$var} : '';
	$value =~ s/\[/&#91;/g unless $opt->{enable_itl};
	if($opt->{filter}) {
		$value = filter_value($opt->{filter}, $value, $var);
		$vref->{$var} = $value unless $opt->{keep};
	}
	$::Scratch->{$var} = $value if $opt->{scratch};
	return '' if $opt->{hide};
    return $opt->{default} if ! $value and defined $opt->{default};
	$value =~ s/</&lt;/g unless $opt->{enable_html};
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
		$scan =~ s!::!__SLASH__!g;
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

PAGELINK: {

my ($urlroutine, $page, $arg, $opt);

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

	my $r;

	if ($opt->{search}) {
		$page = escape_scan($opt->{search});
	}
	elsif ($page =~ /^[a-z][a-z]+:/) {
		### Javascript or absolute link
		return $page unless $opt->{form};
		$page =~ s{(\w+://[^/]+)/}{}
			or return $page;
		my $intro = $1;
		my @pieces = split m{/}, $page, 9999;
		$page = pop(@pieces);
		if(! length($page)) {
			$page = pop(@pieces);
			if(! length($page)) {
				$r = $intro;
				$r =~ s{/([^/]+)}{};
				$page = "$1/";
			}
			else {
				$page .= "/";
			}
		}
		$r = join "/", $intro, @pieces unless $r;
		$opt->{add_dot_html} = 0;
		$opt->{no_session} = 1;
		$opt->{secure} = 0;
		$opt->{no_count} = 1;
	}
	elsif ($page eq 'scan') {
		$page = escape_scan($arg);
		undef $arg;
	}

	$urlroutine = $opt->{secure} ? \&secure_vendUrl : \&vendUrl;

	return $urlroutine->($page, $arg, undef, $opt);
}

}

*form_link = \&tag_area;

# Sets the default shopping cart for display
sub tag_cart {
	$Vend::CurrentCart = shift;
	return '';
}

# Sets the discount namespace.
sub switch_discount_space {
	my $dspace = shift || 'main';

	if (! $Vend::Cfg->{DiscountSpacesOn}) {
		$::Discounts
			= $Vend::Session->{discount}
			||= {};
		return $Vend::DiscountSpaceName = 'main';
	}

	my $oldspace = $Vend::DiscountSpaceName || 'main';
#::logDebug("switch_discount_space: called for space '$dspace'; current space is $oldspace.");
	unless ($Vend::Session->{discount} and $Vend::Session->{discount_space}) {
		$::Discounts
			= $Vend::Session->{discount}
			= $Vend::Session->{discount_space}{main}
			||= ($Vend::Session->{discount} || {});
		$Vend::DiscountSpaceName = 'main';
#::logDebug('switch_discount_space: initialized discount space hash.');
	}
	if ($dspace ne $oldspace) {
		$::Discounts
			= $Vend::Session->{discount}
			= $Vend::Session->{discount_space}{$Vend::DiscountSpaceName = $dspace}
			||= {};
#::logDebug("switch_discount_space: changed discount space from '$oldspace' to '$Vend::DiscountSpaceName'");
	}
	else {
		# Make certain the hash is set, in case app programmer manipulated the session directly.
		$::Discounts
			= $Vend::Session->{discount}
			= $Vend::Session->{discount_space}{$Vend::DiscountSpaceName}
			unless ref $::Discounts eq 'HASH';
	}
	return $oldspace;
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

	if($start > 1) {
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

	if($start > 1) {
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
	my $prev = $Prev{$name};
	$Prev{$name} = $value;
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

	$$textref =~ s:\[quantity[-_]name:[$prefix-quantity-name:gi;
	$$textref =~ s:\[modifier[-_]name\s:[$prefix-modifier-name :gi;

	$$textref =~ s:\[if[-_]data\s:[if-$prefix-data :gi
		and $$textref =~ s:\[/if[-_]data\]:[/if-$prefix-data]:gi;

	$$textref =~ s:\[if[-_]modifier\s:[if-$prefix-param :gi
		and $$textref =~ s:\[/if[-_]modifier\]:[/if-$prefix-param]:gi;

	$$textref =~ s:\[if[-_]field\s:[if-$prefix-field :gi
		and $$textref =~ s:\[/if[-_]field\]:[/if-$prefix-field]:gi;

	$$textref =~ s:\[on[-_]change\s:[$prefix-change :gi
		and $$textref =~ s:\[/on[-_]change\s:[/$prefix-change :gi;

	return;
}

sub tag_search_region {
	my($params, $opt, $text) = @_;
	$opt->{search} = $params if $params;
	$opt->{prefix}      ||= 'item';
	$opt->{list_prefix} ||= 'search[-_]list';
# LEGACY
	list_compat($opt->{prefix}, \$text) if $text;
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
		$perm,
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
	$form_arg .= "\n$opt->{form}" if $opt->{form};
	$form_arg .= "\nmi=$more_id" if $more_id;
	$next = ($inc-1) * $chunk;
#::logDebug("more_link: inc=$inc current=$current");
	$last = $next + $chunk - 1;
	$last = ($last+1) < $total ? $last : ($total - 1);
	$pa =~ s/__PAGE__/$inc/g;
	$pa =~ s/__MINPAGE__/$next + 1/eg;
	$pa =~ s/__MAXPAGE__/$last + 1/eg;
	if($inc == $current) {
		$pa =~ s/__BORDER__/$border_selected || $border || ''/e;
		$list .= qq|<strong>$pa</strong> | ;
	}
	else {
		$pa =~ s/__BORDER__/$border/e;
		$arg = "$session:$next:$last:$chunk$perm";
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

	if(my $name = $opt->{more_routine}) {
		my $sub = $Vend::Cfg->{Sub}{$name} || $Global::GlobalSub->{$name};
		return $sub->(@_) if $sub;
	}
#::logDebug("more_list: opt=$opt label=$opt->{label}");
	return undef if ! $opt;
	$q = $opt->{object} || $::Instance->{SearchObject}{$opt->{label}};
	return '' unless $q->{matches} > $q->{mv_matchlimit}
		and $q->{mv_matchlimit} > 0;
	my($arg,$inc,$last,$m);
	my($adder,$pages);
	my($first_anchor,$last_anchor);
	my %hash;


	$session = $q->{mv_cache_key};
	my $first = $q->{mv_first_match} || 0;
	$chunk = $q->{mv_matchlimit};
	$perm = $q->{mv_more_permanent} ? ':1' : '';
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

	my $more_joiner = $opt->{more_link_joiner} || ' ';

	if($r =~ s:\[border\]($All)\[/border\]::i) {
		$border = $1;
		$border =~ s/\D//g;
	}
	if($r =~ s:\[border[-_]selected\]($All)\[/border[-_]selected\]::i) {
		$border = $1;
		$border =~ s/\D//g;
	}

	undef $link_template;
	$r =~ s:\[link[-_]template\]($All)\[/link[-_]template\]::i
		and $link_template = $1;
	$link_template ||= q{<a href="$URL$">$ANCHOR$</a>};

	if(! $chunk or $chunk >= $total) {
		return '';
	}

	$border = qq{ border="$border"} if defined $border;
	$border_selected = qq{ border="$border_selected"}
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
			$arg .= ":$chunk$perm";
			$hash{first_link} = more_link_template($first_anchor, $arg, $form_arg);
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
			$prev_anchor = qq%<img src="$prev_anchor"$border>%;
		}
		unless ($prev_anchor eq 'none') {
			$arg = $session;
			$arg .= ':';
			$arg .= $first - $chunk;
			$arg .= ':';
			$arg .= $first - 1;
			$arg .= ":$chunk$perm";
			$hash{prev_link} = more_link_template($prev_anchor, $arg, $form_arg);
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
			$next_anchor = qq%<img src="$next_anchor"$border>%;
		}
		$last = $next + $chunk - 1;
		$last = $last > ($total - 1) ? $total - 1 : $last;
		$arg = "$session:$next:$last:$chunk$perm";
		$hash{next_link} = more_link_template($next_anchor, $arg, $form_arg);

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
			$arg = "$session:$last_beg_idx:$last:$chunk$perm";
			$hash{last_link} = more_link_template($last_anchor, $arg, $form_arg);
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
		$page_anchor = qq%<img src="$page_anchor?__PAGE__"__BORDER__>%;
	}

	$page_anchor =~ s/\$(MIN|MAX)?PAGE\$/__${1}PAGE__/g;

	my $more_string = errmsg('more');
	my ($decade_next, $decade_prev, $decade_div);
	if( $q->{mv_more_decade} or $r =~ m:\[decade[-_]next\]:) {
		$r =~ s:\[decade[-_]next\]($All)\[/decade[-_]next\]::i
			and $decade_next = $1;
		$decade_next = "<small>&#91;$more_string&gt;&gt;&#93;</small>"
			if ! $decade_next;
		$r =~ s:\[decade[-_]prev\]($All)\[/decade[-_]prev\]::i
			and $decade_prev = $1;
		$decade_prev = "<small>&#91;&lt;&lt;$more_string&#93;</small>"
			if ! $decade_prev;
		$decade_div = $q->{mv_more_decade} > 1 ? $q->{mv_more_decade} : 10;
	}

	my ($begin, $end);
	if(defined $decade_div and $pages > $decade_div) {
		if($current > $decade_div) {
			$begin = ( int ($current / $decade_div) * $decade_div ) + 1;
			$hash{decade_prev} = more_link($begin - $decade_div, $decade_prev);
		}
		else {
			$begin = 1;
		}
		if($begin + $decade_div <= $pages) {
			$end = $begin + $decade_div;
			$hash{decade_next} = more_link($end, $decade_next);
			$end--;
		}
		else {
			$end = $pages;
			delete $hash{$decade_next};
		}
#::logDebug("more_list: decade found pages=$pages current=$current begin=$begin end=$end next=$next last=$last decade_div=$decade_div");
	}
	else {
		($begin, $end) = (1, $pages);
		delete $hash{$decade_next};
	}
#::logDebug("more_list: pages=$pages current=$current begin=$begin end=$end next=$next last=$last decade_div=$decade_div page_anchor=$page_anchor");

	my @more_links;
	if ($q->{mv_alpha_list}) {
		for my $record (@{$q->{mv_alpha_list}}) {
			$arg = "$session:$record->[2]:$record->[3]:" . ($record->[3] - $record->[2] + 1);
			my $letters = substr($record->[0], 0, $record->[1]);
			push @more_links, more_link_template($letters, $arg, $form_arg);
		}
		$hash{more_alpha} = join $more_joiner, @more_links;
	}
	else {
		foreach $inc ($begin .. $end) {
			last if $page_anchor eq 'none';
			push @more_links, more_link($inc, $page_anchor);
		}
		$hash{more_numeric} = join $more_joiner, @more_links;
	}

	$hash{more_list} = join $more_joiner, @more_links;

	$first = $first + 1;
	$last = $first + $chunk - 1;
	$last = $last > $total ? $total : $last;
	$m = $first . '-' . $last;
	$hash{matches} = $m;
	$hash{first_match} = $first;
	$hash{last_match} = $last;
	$hash{decade_first} = $begin;
	$hash{decade_last} = $end;
	$hash{last_page} = $hash{total_pages} = $pages;
	$hash{current_page} = $current;
	$hash{match_count} = $q->{matches};

	if($r =~ /{[A-Z][A-Z_]+[A-Z]}/ and $r !~ $QR{more}) {
		return tag_attr_list($r, \%hash, 1);
	}
	else {
		my $tpl = qq({FIRST_LINK?}{FIRST_LINK} {/FIRST_LINK?}{PREV_LINK?}{PREV_LINK} {/PREV_LINK?}{DECADE_PREV?}{DECADE_PREV} {/DECADE_PREV?}{MORE_LIST}{DECADE_NEXT?} {DECADE_NEXT}{/DECADE_NEXT?}{NEXT_LINK?} {NEXT_LINK}{/NEXT_LINK?}{LAST_LINK?} {LAST_LINK}{/LAST_LINK?});
		$tpl =~ s/\s+$//;
		my $list = tag_attr_list($opt->{more_template} || $tpl, \%hash, 1);
		$r =~ s,$QR{more},$list,g;
		$r =~ s,$QR{matches},$m,g;
		$r =~ s,$QR{match_count},$q->{matches},g;
		return $r;
	}

}

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
	return (0 .. $#$ary) unless $wanted > 0;
	$wanted = 1 if $wanted =~ /\D/;
	return undef unless ref $ary;

	my %seen;
	my ($j, @out);
	my $count = scalar @$ary;
	$wanted = $count if $wanted > $count;
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
	return '' if (! $ary or ! ref $ary or ! defined $ary->[0]);
	
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
	elsif (defined $opt->{random} && !is_no($opt->{random})) {
		$opt->{random} = scalar(@$ary) if $opt->{random} =~ /^[yYtT]/;
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
		my $row_fields = $fa;
		$ary = tag_sort_ary($opt->{sort}, $ary) if $opt->{sort};
		if ($fa and $fn) {
			my $idx = 0;
			$fh = {};
			$row_fields = [];
			@$row_fields = @{$fn}[@$fa];
			for(@$fa) {
				$fh->{$fn->[$_]} = $idx++;
			}
		}
		elsif (! $fh and $fn) {
			my $idx = 0;
			$fh = {};
			$row_fields = $fn;
			for(@$fn) {
				$fh->{$_} = $idx++;
			}
		}
		$opt->{mv_return_fields} = $fa;
#::logDebug("Missing mv_field_hash and/or mv_field_names in Vend::Interpolate::labeled_list") unless ref $fh eq 'HASH';
		# Pass the field arrayref ($row_fields) for support in iterate_array_list of new $Row object...
		$r = iterate_array_list($i, $end, $count, $text, $ary, $opt_select, $fh, $opt, $row_fields);
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
		my $Marker = '[A-Z_]\\w+';
		$body =~ s!\{($Marker)\}!$hash->{"\L$1"}!g;
		$body =~ s!\{($Marker)\?($Marker)\:($Marker)\}!
					length($hash->{lc $1}) ? $hash->{lc $2} : $hash->{lc $3}
				  !eg;
		$body =~ s!\{($Marker)\|($Some)\}!$hash->{lc $1} || $2!eg;
		$body =~ s!\{($Marker)\s+($Some)\}! $hash->{lc $1} ? $2 : ''!eg;
		1 while $body =~ s!\{($Marker)\?\}($Some){/\1\?\}! $hash->{lc $1} ? $2 : ''!eg;
		1 while $body =~ s!\{($Marker)\:\}($Some){/\1\:\}! $hash->{lc $1} ? '' : $2!eg;
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

	my $joiner = get_joiner($opt->{joiner}, "<br$Vend::Xtrailer>");
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
    $first = index($$buf, $open);
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
#::logDebug("calling tag tag=$tag this_tag=$this_tag attrhash=" . uneval($attrhash));
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

sub alternate {
	my ($count, $inc, $end, $page_start, $array_last) = @_;

	if(! length($inc)) {
		$inc ||= $::Values->{mv_item_alternate} || 2;
	}

	return $count % $inc if $inc >= 1;

	my $status;
	if($inc == -1 or $inc eq 'except_last') {
		$status = 1 unless $count - 1 == $end;
	}
	elsif($inc eq '0' or $inc eq 'first_only') {
		$status = 1 if $count == 1 || $count == ($page_start + 1);
	}
	elsif($inc eq 'except_first') {
		$status = 1 unless $count == 1 || $count == ($page_start + 1);
	}
	elsif($inc eq 'last_only') {
		$status = 1 if $count - 1 == $end;
	}
	elsif($inc eq 'absolute_last') {
		$status = 1 if $count == $array_last;
	}
	elsif($inc eq 'absolute_first') {
		$status = 1 if $count == 1;
	}
	return ! $status;
}

sub iterate_array_list {
	my ($i, $end, $count, $text, $ary, $opt_select, $fh, $opt, $fa) = @_;
#::logDebug("passed opt=" . ::uneval($opt));
	my $page_start = $i;
	my $array_last = scalar @{$ary || []};
	my $r = '';
	$opt ||= {};

	# The $Row object needs to be built per-row, so undef it initially.
	$fa ||= [];
	@$fa = sort { $fh->{$a} <=> $fh->{$b} } keys %$fh
		if ! @$fa and ref $fh eq 'HASH';
	undef $Row;

	my $lim;
	if($lim = $::Limit->{list_text_size} and length($text) > $lim) {
		my $len = length($text);
		my $caller = join "|", caller();
		my $msg = "Large list text encountered,  length=$len, caller=$caller";
		logError($msg);
		return undef if $::Limit->{list_text_overflow} eq 'abort';
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

	$text =~ s{
		$B$QR{_include}
	}{
		my $filename = $1;

		$Data_cache{"/$filename"} or do {
		    my $content = Vend::Util::readfile($filename);
		    vars_and_comments(\$content);
		    $Data_cache{"/$filename"} = $content;
		};
	}igex;

	if($text =~ m/^$B$QR{_line}\s*$/is) {
		my $i = $1 || 0;
		my $fa = $opt->{mv_return_fields};
		$r .= join "\t", @$fa[$i .. $#$fa];
		$r .= "\n";
	}
	1 while $text =~ s#$IB$QR{_header_param_if}$IE[-_]header[-_]param\1\]#
			  (defined $opt->{$3} ? $opt->{$3} : '')
				  					?	pull_if($5,$2,$4,$opt->{$3})
									:	pull_else($5,$2,$4,$opt->{$3})#ige;
	$text =~ s#$B$QR{_header_param}#defined $opt->{$1} ? ed($opt->{$1}) : ''#ige;
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
						  alternate($count, $1, $end, $page_start, $array_last)
				  							?	pull_else($2)
											:	pull_if($2)#ige;
		1 while $run =~ s#$IB$QR{_param_if}$IE[-_](?:param|modifier)\1\]#
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
		$run =~ s#$B$QR{_calc}$E$QR{'/_calc'}#
			unless ($Row) {
				$Row = {};
				@{$Row}{@$fa} = @$row;
			}
			tag_calc($1)
			#ige;
		$run =~ s#$B$QR{_exec}$E$QR{'/_exec'}#
					init_calc() if ! $Vend::Calc_initialized;
					(
						$Vend::Cfg->{Sub}{$1} ||
						$Global::GlobalSub->{$1} ||
						sub { logOnce('error', "subroutine $1 missing for PREFIX-exec"); errmsg('ERROR') }
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
                    $Ary_code{next}->($1) != 0 ? (undef $Row, next) : '' #ixge;
		$run =~ s/<option\s*/<option SELECTED /i
			if $opt_select and $opt_select->($code);
		undef $Row;
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
	1 while $text =~ s#$IB$QR{_header_param_if}$IE[-_]header[-_]param\1\]#
			  (defined $opt->{$3} ? $opt->{$3} : '')
				  					?	pull_if($5,$2,$4,$opt->{$3})
									:	pull_else($5,$2,$4,$opt->{$3})#ige;
	$text =~ s#$B$QR{_header_param}#defined $opt->{$1} ? ed($opt->{$1}) : ''#ige;
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

	# undef the $Row object, as it should only be set as needed by [PREFIX-calc]
	undef $Row;

	for ( ; $i <= $end; $i++, $count++) {
		$item = $hash->[$i];
		$item->{mv_ip} = $opt->{reverse} ? ($end - $i) : $i;
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
		$code = '' unless defined $code;

#::logDebug("Doing $code (variant $item->{code}) substitution, count $count++");

		$run = $text;
		$run =~ s#$B$QR{_alternate}$E$QR{'/_alternate'}#
						  alternate($i + 1, $1, $end)
				  							?	pull_else($2)
											:	pull_if($2)#ge;
		tag_labeled_data_row($code,\$run);
		$run =~ s:$B$QR{_line}:join "\t", @{$hash}:ge;
		1 while $run =~ s#$IB$QR{_param_if}$IE[-_](?:param|modifier)\1\]#
				  $item->{$3}	?	pull_if($5,$2,$4,$item->{$3})
								:	pull_else($5,$2,$4,$item->{$3})#ige;
		1 while $run =~ s#$IB$QR{_parent_if}$IE[-_]parent\1\]#
				  $item->{$3}	?	pull_if($5,$2,$4,$opt->{$3})
								:	pull_else($5,$2,$4,$opt->{$3})#ige;
		1 while $run =~ s#$IB$QR{_field_if}$IE[-_]field\1\]#
				  my $tmp = item_field($item, $3);
				  $tmp	?	pull_if($5,$2,$4,$tmp)
						:	pull_else($5,$2,$4,$tmp)#ge;
		$run =~ s:$B$QR{_increment}:$i + 1:ge;
		
		$run =~ s:$B$QR{_accessories}:
						$Hash_code{accessories}->($code,$1,{},$item):ge;
		$run =~ s:$B$QR{_options}:
						$Hash_code{options}->($item,$1):ige;
		$run =~ s:$B$QR{_sku}:$code:ig;
		$run =~ s:$B$QR{_code}:$item->{code}:ig;
		$run =~ s:$B$QR{_quantity}:$item->{quantity}:g;
		$run =~ s:$B$QR{_param}:ed($item->{$1}):ge;
		$run =~ s:$B$QR{_parent}:ed($opt->{$1}):ge;
		$run =~ s:$B$QR{_quantity_name}:quantity$item->{mv_ip}:g;
		$run =~ s:$B$QR{_modifier_name}:$1$item->{mv_ip}:g;
		$run =~ s!$B$QR{_subtotal}!currency(item_subtotal($item),$1)!ge;
		$run =~ s!$B$QR{_discount_subtotal}!
						currency( discount_subtotal($item), $1 )!ge;
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
								$item,
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
		$Row = $item;
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
		$run =~ s/<option\s*/<option SELECTED /i
			if $opt_select and $opt_select->($code);	

		$r .= $run;
		undef $Row;
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

	$opt->{query} =~ s:
			\[\Q$opt->{prefix}\E[_-]quote\](.*?)\[/\Q$opt->{prefix}\E[_-]quote\]
		:
			$db->quote($1)
		:xisge;

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
		$r .= "<tr$tr>";
		for(@$na) {
			$r .= "<th$th><b>$_</b></th>";
		}
		$r .= "</tr>\n";
	}
	my $row;
	if($fr) {
		$r .= "<tr$fr>";
		my $val;
		$row = shift @$ary;
		if($fc) {
			$val = (shift @$row) || '&nbsp;';
			$r .= "<td$fc>$val</td>";
		}
		foreach (@$row) {
			$val = $_ || '&nbsp;';
			$r .= "<td$td>$val</td>";
		}
		$r .= "</tr>\n";
		
	}
	foreach $row (@$ary) {
		$r .= "<tr$tr>";
		my $val;
		if($fc) {
			$val = (shift @$row) || '&nbsp;';
			$r .= "<td$fc>$val</td>";
		}
		foreach (@$row) {
			$val = $_ || '&nbsp;';
			$r .= "<td$td>$val</td>";
		}
		$r .= "</tr>\n";
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
					mv_more_id => $opt->{mv_more_id},
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
	my $new = { %$opt };
	my $out = iterate_hash_list(@_,[$new]);
	$Prefix = $Orig_prefix;
	return $out;
}

sub region {

	my($opt,$page) = @_;

	my $obj;

	if($opt->{object}) {
		### The caller supplies the object, no search to be done
		$obj = $opt->{object};
	}
	else {
		### We need to run a search to get an object
		my $c;
		if($CGI::values{mv_more_matches} || $CGI::values{MM}) {

			### It is a more function, we need to get the parameters
			find_search_params();
			delete $CGI::values{mv_more_matches};
		}
		elsif ($opt->{search}) {
			### Explicit search in tag parameter, run just like any
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
				$c->{mv_no_more} = ! $opt->{more};
				$obj = perform_search($c);
			}
		}
		else {
			### See if we have a search already done for this label
			$obj = $::Instance->{SearchObject}{$opt->{label}};
		}

		# If none of the above happen, we need to perform a search
		# based on the passed CGI parameters
		if(! $obj) {
			$obj = perform_search();
			$obj = {
				matches => 0,
				mv_search_error => [ errmsg('No search was found') ],
			} if ! $obj;
		}
		finish_search($obj);

		# Label it for future reference
		$::Instance->{SearchObject}{$opt->{label}} = $opt->{object} = $obj;
	}

	my $lprefix;
	my $mprefix;
	if($opt->{list_prefix}) {
		$lprefix = $opt->{list_prefix};
		$mprefix = "(?:$opt->{list_prefix}-)?";
	}
	elsif ($opt->{prefix}) {
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
		$obj->{mv_cache_key} = generate_key($opt->{query} || substr($page,0,100));
		$obj->{mv_more_permanent} = $opt->{pm};
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

sub tag_loop_list {
	my ($list, $opt, $text) = @_;

	my $fn;
	my @rows;

	$opt->{prefix} ||= 'loop';
	$opt->{label}  ||= "loop" . ++$::Instance->{List_it} . $Global::Variable->{MV_PAGE};

#::logDebug("list is: " . uneval($list) );

	## Thanks to Kaare Rasmussen for this suggestion
	## about passing embedded Perl objects to a list

	# Can pass object.mv_results=$ary object.mv_field_names=$ary
	if ($opt->{object}) {
		my $obj = $opt->{object};
		# ensure that number of matches is always set
		# so [on-match] / [no-match] works
		$obj->{matches} = scalar(@{$obj->{mv_results}});
		return region($opt, $text);
	}
	
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
		my $obj = $opt->{object} ||= {};
		$obj->{mv_results} = $ary;
		$obj->{matches} = scalar @$ary;
		$obj->{mv_field_names} = $fa if $fa;
		$obj->{mv_field_hash} = $fh if $fh;
		if($opt->{ml}) {
			$obj->{mv_matchlimit} = $opt->{ml};
			$obj->{mv_no_more} = ! $opt->{more};
			$obj->{mv_first_match} = $opt->{mv_first_match} || 0;
			$obj->{mv_next_pointer} = $opt->{mv_first_match} + $opt->{ml};
		}
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
				@rows = map { [ split /\Q$delim/, $_ ] } split /\Q$splittor/, $list;
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

	my ($selector, $subname, $base, $listref);

	return $page if (! $code and $Vend::Flypart eq $Vend::FinalPath);

	$code = $Vend::FinalPath
		unless $code;

	$Vend::Flypart = $code;

	if ($subname = $Vend::Cfg->{SpecialSub}{flypage}) {
		my $sub = $Vend::Cfg->{Sub}{$subname} || $Global::GlobalSub->{$subname}; 
		$listref = $sub->($code);
		$listref = { mv_results => [[$listref]] } unless ref($listref);
		$base = $listref;
	}
	else {
		$base = product_code_exists_ref($code);
		$listref = {mv_results => [[$code]]};
	}
	
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
	$Vend::Track->view_product($code) if $Vend::Track;
# END TRACK
	
	$opt->{prefix} ||= 'item';
# LEGACY
	list_compat($opt->{prefix}, \$page) if $page;
# END LEGACY

	return labeled_list( $opt, $page, $listref);
}

sub item_difference {
	my($code,$price,$q,$item) = @_;
	return $price - discount_price($item || $code,$price,$q);
}

sub item_discount {
	my($code,$price,$q) = @_;
	return ($price * $q) - discount_price($code,$price,$q) * $q;
}

sub discount_subtotal {
	my ($item, $price) = @_;

	unless (ref $item) {
		::logError("Bad call to discount price, item is not reference: %s", $item);
		return 0;
	}

	my $quantity = $item->{quantity} || 1;

	$price ||= item_price($item);
	my $new_price = discount_price($item, $price);
	
	return $new_price * $quantity;
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

	if ($extra and ! $::Discounts) {
		my $dspace = $Vend::DiscountSpaceName ||= 'main';
		$Vend::Session->{discount_space}{main}
			= $Vend::Session->{discount}
			||= {} unless $Vend::Session->{discount_space}{main};
		$::Discounts
			= $Vend::Session->{discount}
			= $Vend::Session->{discount_space}{$dspace}
			||= {} if $Vend::Cfg->{DiscountSpacesOn};
	}

	return $price unless $extra or $::Discounts && %$::Discounts;

	$quantity = $item->{quantity};

	$Vend::Interpolate::item = $item;
	$Vend::Interpolate::q = $quantity || 1;
	$Vend::Interpolate::s = $price;

	my $subtotal = $price * $quantity;

#::logDebug("quantity=$q code=$item->{code} price=$s");

	my ($discount, $return);

	for($code, 'ALL_ITEMS') {
		next unless $discount = $::Discounts->{$_};
		$Vend::Interpolate::s = $return ||= $subtotal;
        $return = $ready_safe->reval($discount);
		if($@) {
			::logError("Bad discount code for %s: %s", $discount);
			$return = $subtotal;
			next;
		}
        $price = $return / $q;
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
	push(@formulae, $::Discounts->{$item->{code}})
		if defined $::Discounts->{$item->{code}};
	# Check for all item discount
	push(@formulae, $::Discounts->{ALL_ITEMS})
		if defined $::Discounts->{ALL_ITEMS};
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

# Stubs for relocated shipping stuff in case of legacy code
*read_shipping = \&Vend::Ship::read_shipping;
*custom_shipping = \&Vend::Ship::shipping;
*tag_shipping_desc = \&Vend::Ship::tag_shipping_desc;
*shipping = \&Vend::Ship::shipping;
*tag_handling = \&Vend::Ship::tag_handling;
*tag_shipping = \&Vend::Ship::tag_shipping;
*tag_ups = \&Vend::Ship::tag_ups;

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

	if ($Vend::LockedOut) {
		$abort = 1;
		delete $opt->{new};
	}
	elsif (defined $opt->{if}) {
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
						or ! $opt->{login} && $Vend::Session->{logged_in}
					)
				);
	}

	local ($Scratch->{mv_no_session_id});
	$Scratch->{mv_no_session_id} = 1;

	if($opt->{auto}) {
		$opt->{minutes} = 60 unless defined $opt->{minutes};
		my $dir = "$Vend::Cfg->{ScratchDir}/auto-timed";
		unless (allowed_file($dir)) {
			log_file_violation($dir, 'timed_build');
			return;
		}
		if(! -d $dir) {
			require File::Path;
			File::Path::mkpath($dir);
		}
		$file = "$dir/" . generate_key(@_);
	}

	my $secs;
	CHECKDIR: {
		last CHECKDIR if Vend::File::file_name_is_absolute($file);
		last CHECKDIR if $file and $file !~ m:/:;
		my $dir;
		if ($file) {
			$dir = '.';
		}
		else {
			$dir = 'timed';
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
			$file .= $Vend::Cfg->{HTMLsuffix};
		}
		$dir .= "/$1" 
			if $file =~ s:(.*)/::;
		unless (allowed_file($dir)) {
			log_file_violation($dir, 'timed_build');
			return;
		}
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


sub taxable_amount {
	my($cart, $dspace) = @_;
    my($taxable, $i, $code, $item, $tmp, $quantity);

	return subtotal($cart || undef, $dspace || undef) unless $Vend::Cfg->{NonTaxableField};

	my($save, $oldspace);

    if ($cart) {
        $save = $Vend::Items;
        tag_cart($cart);
    }

	# Support for discount namespaces.
	$oldspace = switch_discount_space($dspace) if $dspace;

    $taxable = 0;

    foreach $i (0 .. $#$Vend::Items) {
		$item =	$Vend::Items->[$i];
		next if is_yes( $item->{mv_nontaxable} );
		next if is_yes( item_field($item, $Vend::Cfg->{NonTaxableField}) );
		$tmp = item_subtotal($item);
		unless (%$::Discounts) {
			$taxable += $tmp;
		}
		else {
			$taxable += apply_discount($item);
		}
    }

	if (defined $::Discounts->{ENTIRE_ORDER}) {
		$Vend::Interpolate::q = tag_nitems();
		$Vend::Interpolate::s = $taxable;
		my $cost = $Vend::Interpolate::ready_safe->reval(
							 $::Discounts->{ENTIRE_ORDER},
						);
		if($@) {
			logError
				"Discount ENTIRE_ORDER has bad formula. Returning normal subtotal.";
			$cost = $taxable;
		}
		$taxable = $cost;
	}

	$Vend::Items = $save if defined $save;

	# Restore initial discount namespace if appropriate.
	switch_discount_space($oldspace) if defined $oldspace;

	return $taxable;
}



sub fly_tax {
	my ($area, $opt) = @_;

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

	my ($oldcart, $oldspace);
	if ($opt->{cart}) {
		$oldcart = $Vend::Items;
		tag_cart($opt->{cart});
	}
	if ($opt->{discount_space}) {
		$oldspace = switch_discount_space($opt->{discount_space});
	}

	my $amount = taxable_amount();
#::logDebug("flytax before shipping amount=$amount");
	$amount   += tag_shipping()
		if $taxable_shipping =~ m{(^|[\s,])$area([\s,]|$)}i;
	$amount   += tag_handling()
		if $taxable_handling =~ m{(^|[\s,])$area([\s,]|$)}i;

	$Vend::Items = $oldcart if defined $oldcart;
	switch_discount_space($oldspace) if defined $oldspace;

#::logDebug("flytax amount=$amount return=" . $amount*$rate);
	return $amount * $rate;
}

sub percent_rate {
	my $rate = shift;
	$rate =~ s/\s*%\s*$// and $rate /= 100;
	return $rate;
}

sub tax_vat {
	my($type, $opt) = @_;
#::logDebug("entering VAT, opts=" . uneval($opt));
	my $cfield = $::Variable->{MV_COUNTRY_TAX_VAR} || 'country';
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
            $rate = $rate / (1 + $rate) if $Vend::Cfg->{TaxInclusive};
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
			$rate = percent_rate($rate);
			next if $rate <= 0;
			$rate = $rate / (1 + $rate) if $Vend::Cfg->{TaxInclusive};
			my $sub = discount_subtotal($item);
#::logDebug("item $item->{code} subtotal=$sub");
			$total += $sub * $rate;
#::logDebug("tax total=$total");
		}

		my $tax_shipping_rate = 0;

		## Add some tax on shipping ONLY IF TAXABLE ITEMS
		## if rate for mv_shipping_when_taxable category is set
		if ($tax->{mv_shipping_when_taxable} and $total > 0) {
			$tax_shipping_rate += percent_rate($tax->{mv_shipping_when_taxable});
		}

		## Add some tax on shipping if rate for mv_shipping category is set
		if ($tax->{mv_shipping} > 0) {
			$tax_shipping_rate += percent_rate($tax->{mv_shipping});
		}

		if($tax_shipping_rate > 0) {
			my $rate = $tax_shipping_rate;
			$rate =~ s/\s*%\s*$// and $rate /= 100;
			my $sub = tag_shipping() * $rate;
#::logDebug("applying shipping tax rate of $rate, tax of $sub");
			$total += $sub;
		}

		## Add some tax on handling if rate for mv_handling category is set
		if ($tax->{mv_handling} > 0) {
			my $rate = $tax->{mv_handling};
			$rate =~ s/\s*%\s*$// and $rate /= 100;
			$rate = $rate / (1 + $rate) if $Vend::Cfg->{TaxInclusive};
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

	my($save, $oldspace);
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

	$oldspace = switch_discount_space( $opt->{discount_space} ) if $opt->{discount_space};

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
		switch_discount_space($oldspace) if defined $oldspace;
		if($cost < 0 and $::Pragma->{no_negative_tax}) {
			$cost = 0;
		}
		return Vend::Util::round_to_frac_digits($cost);
	}

#::logDebug("got to tax function: " . uneval($tax_hash));
	my $amount = taxable_amount();
	# Restore the original discount namespace if appropriate; no other routines need the discount info.
	switch_discount_space($oldspace) if defined $oldspace;

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

	if($r < 0 and ! $::Pragma->{no_negative_tax}) {
		$r = 0;
	}

	return Vend::Util::round_to_frac_digits($r);
}

# Returns just subtotal of items ordered, with discounts
# applied
sub subtotal {
	my($cart, $dspace) = @_;
	
	### If the user has assigned to salestax,
	### we use their value come what may, no rounding
	if($Vend::Session->{assigned}) {
		return $Vend::Session->{assigned}{subtotal}
			if defined $Vend::Session->{assigned}{subtotal} 
			&& length( $Vend::Session->{assigned}{subtotal});
	}

    my ($save, $subtotal, $i, $item, $tmp, $cost, $formula, $oldspace);
	if ($cart) {
		$save = $Vend::Items;
		tag_cart($cart);
	}

	levies() unless $Vend::Levying;
	
	# Use switch_discount_space unconditionally to guarantee existance of proper discount structures.
	$oldspace = switch_discount_space($dspace || $Vend::DiscountSpaceName);
	
	my $discount = (ref($::Discounts) eq 'HASH' and %$::Discounts);

    $subtotal = 0;
	$tmp = 0;

    foreach $i (0 .. $#$Vend::Items) {
        $item = $Vend::Items->[$i];
        $tmp = Vend::Data::item_subtotal($item);
        if($discount || $item->{mv_discount}) {
            $subtotal +=
                apply_discount($item, $tmp);
        }
        else { $subtotal += $tmp }
	}

	if (defined $::Discounts->{ENTIRE_ORDER}) {
		$formula = $::Discounts->{ENTIRE_ORDER};
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

	# Switch to original discount space if an actual switch occured.
	switch_discount_space($oldspace) if $dspace and defined $oldspace;

    return $subtotal;
}



# Returns the total cost of items ordered.

sub total_cost {
	my ($cart, $dspace) = @_;
    my ($total, $i, $save, $oldspace);

	$oldspace = switch_discount_space($dspace) if $dspace;

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
		$total += salestax()
			unless $Vend::Cfg->{TaxInclusive};
	}
	$Vend::Items = $save if defined $save;
	$Vend::Session->{latest_total} = $total;
	switch_discount_space($oldspace) if defined $oldspace;
    return $total;
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
				my $val = interpolate_html($if);
				$val =~ s/^\s+//;
				$val =~ s/^s+$//;
				next unless $val;
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
				my $val = interpolate_html($if);
				$val =~ s/^\s+//;
				$val =~ s/^s+$//;
				next if $val;
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

			my @modes = split /\0/, $mode;
			for my $m (@modes) {
				$cost += shipping($m);
				if($l->{description}) {
					if($l->{multi_description}) {
						$l->{description} = $l->{multi_description};
					}
					else {
						$l->{description} .= ', ' if $l->{description};
						$l->{description} .= tag_shipping_desc($m);
					}
				}
				else {
					$l->{description} = tag_shipping_desc($m);
				}
			}
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
							type			=> $type,
							sort			=> $sort || $l->{sort},
							cost			=> round_to_frac_digits($cost),
							currency		=> currency($cost),
							group			=> $group,
							inclusive		=> $l->{inclusive},
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
		next if $_->{inclusive};
		next if $_->{type} eq 'salestax' and $Vend::Cfg->{TaxInclusive};
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
