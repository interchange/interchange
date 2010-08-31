# Vend::Parse - Parse Interchange tags
# 
# $Id: Parse.pm,v 2.44 2007-12-19 12:33:44 pajamian Exp $
#
# Copyright (C) 2002-2007 Interchange Development Group
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

package Vend::Parse;
require Vend::Parser;

use Vend::Safe;
use Vend::Util;
use Vend::Interpolate;
use Text::ParseWords;
use Vend::Data qw/product_field/;

require Exporter;

@ISA = qw(Exporter Vend::Parser);

$VERSION = substr(q$Revision: 2.44 $, 10);

@EXPORT = ();
@EXPORT_OK = qw(find_matching_end);

use strict;
no warnings qw(uninitialized numeric);

use vars qw($VERSION);

my($CurrentSearch, $CurrentCode, $CurrentDB, $CurrentWith, $CurrentItem);
my(@SavedSearch, @SavedCode, @SavedDB, @SavedWith, @SavedItem);

my %PosNumber =	( qw!

				bounce           2
				label            1
				if               1
				unless           1
				and              1
				or               1

			! );

my %Order =	(
				bounce			=> [qw( href if )],
				goto			=> [qw( name if)],
				label			=> [qw( name )],
				if				=> [qw( type term op compare )],
				unless			=> [qw( type term op compare )],
				or				=> [qw( type term op compare )],
				and				=> [qw( type term op compare )],
				restrict		=> [qw( enable )],
			);

my %addAttr = (
				qw(
					restrict		1
				)
			);

my %hasEndTag = (

				qw(
					if              1
					unless          1
					restrict		1
				)
			);


my %Implicit = (

			unless =>		{ qw(
								!=		op
								!~		op
								<=		op
								==		op
								=~		op
								>=		op
								eq		op
								gt		op
								lt		op
								ne		op
					   )},
			if =>		{ qw(
								!=		op
								!~		op
								<=		op
								==		op
								=~		op
								>=		op
								eq		op
								gt		op
								lt		op
								ne		op
					   )},

			and =>		{ qw(
								!=		op
								!~		op
								<=		op
								==		op
								=~		op
								>=		op
								eq		op
								gt		op
								lt		op
								ne		op
					   )},

			or =>		{ qw(
								!=		op
								!~		op
								<=		op
								==		op
								=~		op
								>=		op
								eq		op
								gt		op
								lt		op
								ne		op
					   )},

			);

my %PosRoutine = (
				or			=> sub { return &Vend::Interpolate::tag_if(@_, 1) },
				and			=> sub { return &Vend::Interpolate::tag_if(@_, 1) },
				if			=> \&Vend::Interpolate::tag_if,
				unless		=> \&Vend::Interpolate::tag_unless,
			);

my %Special = qw/
				goto	1
				bounce	1
				output 	1
			  /;
my %Routine = (

				output          => sub { return '' },
				bounce          => sub { return '' },
				if				=> \&Vend::Interpolate::tag_self_contained_if,
				unless			=> \&Vend::Interpolate::tag_unless,
				or				=> sub { return &Vend::Interpolate::tag_self_contained_if(@_, 1) },
				and				=> sub { return &Vend::Interpolate::tag_self_contained_if(@_, 1) },
				goto			=> sub { return '' },
				label			=> sub { return '' },

			);

## Put here because we need to call keys %Routine
## Restricts execution of tags by tagname
$Routine{restrict} = sub {
	my ($enable, $opt, $body) = @_;
	my $save = $Vend::Cfg->{AdminSub};

	my $save_restrict = $Vend::restricted;

	$opt->{log} ||= 'all';

	my $default;
	if("\L$opt->{policy}" eq 'allow') {
		# Accept all, deny only ones defined in disable
		$default = undef;
		$opt->{policy} = 'allow';
	}
	else {
		# This is default, deny all except enabled
		$default = 1;
		$opt->{policy} = 'deny';
	}
	my @enable;
	my @disable;
	$enable			and @enable  = split /[\s,\0]+/, $enable;
	$opt->{disable} and @disable = split /[\s,\0]+/, $opt->{disable};

	for(@enable, @disable) {
		$_ = lc $_;
		tr/-/_/;
	}

	my %restrict;
	for(keys %Routine) {
		$restrict{$_} = $default;
	}

	$restrict{$_} = undef for @enable;
	$restrict{$_} = 1     for @disable;
	$restrict{$_} = 1     for keys %$save;

	$Vend::Cfg->{AdminSub} = \%restrict;
	$Vend::restricted = join " ",
			'default=' . $opt->{policy},
			'enable=' . join(",", @enable),
			'disable=' . join(",", @disable),
			'log=' . $opt->{log},
			;
	my $out;
	eval {
		$out = Vend::Interpolate::interpolate_html($body);
	};
	$Vend::restricted = $save_restrict;
	$Vend::Cfg->{AdminSub} = $save;
	return $out;
};

my %attrAlias = (
	 'or'			=> { 
	 						'comp' => 'compare',
	 						'operator' => 'op',
	 						'base' => 'type',
						},
	 'and'			=> { 
	 						'comp' => 'compare',
	 						'operator' => 'op',
	 						'base' => 'type',
						},
	 'unless'			=> { 
	 						'comp' => 'compare',
	 						'condition' => 'compare',
	 						'operator' => 'op',
	 						'base' => 'type',
						},
	 'if'			=> { 
	 						'comp' => 'compare',
	 						'condition' => 'compare',
	 						'operator' => 'op',
	 						'base' => 'type',
						},
);

my %attrDefault = ();

my %Alias = (
	getlocale	=> 'setlocale get=1',
	process_search	=> 'area href=search',
);

my %Interpolate = ();

my %NoReparse = ( qw/
					restrict		1
				/ );

my %Gobble = ( qw/
					timed_build		1
					mvasp			1
				/ );

my $Initialized;

sub global_init {
		add_tags($Global::UserTag);
		my $tag;
		foreach $tag (keys %Routine) {
			$Order{$tag} = []
				if ! defined $Order{$tag};
			next if defined $PosNumber{$tag};
			$PosNumber{$tag} = scalar @{$Order{$tag}};
		}
}

sub new {
    my $class = shift;
	my $opt = shift;
    my $self = new Vend::Parser;

	add_tags($Vend::Cfg->{UserTag})
		unless $Vend::Tags_added++;

    bless $self, $class;

	if($opt) {
		$self->destination('');
	}
	else {
		my $string = '';
		$self->{OUT} = $self->{DEFAULT_OUT} = \$string;
	}
#::logDebug("OUT=$self->{OUT}");

	if (! $Initialized) {
		$Initialized = $self;
		$self->{TOPLEVEL} = 1;
	}

	return $self;
}

sub destination {
	my ($s, $name, $attr) = @_;
	$s->{_outname} ||= [];

	if(! defined $name) {
		pop @{$s->{_outname}};
		$name = pop  @{$s->{_outname}};
	}
	else {
		$name = lc $name;
		push @{$s->{_outname}}, $name;
	}

#::logDebug("destination set to '$name'");
	$name ||= '';

	my $string = '';
	$s->{OUT} = \$string;
	push @Vend::Output, $s->{OUT};

	my $nary = $Vend::OutPtr{$name} ||= [];
	push @$nary, $#Vend::Output;

	return unless $attr;
#::logDebug("destination extended output settings");

	my $fary = $Vend::OutFilter{$name};

	if ($name) {
		$Vend::MultiOutput = 1;
		if(! $Vend::OutFilter{''}) {
			my $ary = [];
			push @$ary, \&Vend::Interpolate::substitute_image
				unless $::Pragma->{no_image_rewrite};
			$Vend::OutFilter{''} = $ary;
		}

		if(! $fary) {
			$fary = $Vend::OutFilter{$name} = [];
			if($attr->{output_filter}) {
				my $filt = $attr->{output_filter};
				push @$fary, sub {
					my $ref = shift;
					$$ref = Vend::Interpolate::filter_value($filt, $$ref);
					return;
				};
			}
			if (! $attr->{no_image_parse} and ! $::Pragma->{no_image_rewrite}) {
				push @$fary, \&Vend::Interpolate::substitute_image;
			}
			if ($attr->{output_extended}) {
				$Vend::OutExtended{$name} = $attr;
			}
		}
	}
	return $s->{OUT};
}

my %noRearrange = qw//;

my %Documentation;
use vars '%myRefs';

%myRefs = (
     Alias           => \%Alias,
     addAttr         => \%addAttr,
     attrAlias       => \%attrAlias,
     attrDefault     => \%attrDefault,
	 Documentation   => \%Documentation,
	 hasEndTag       => \%hasEndTag,
	 NoReparse       => \%NoReparse,
	 noRearrange     => \%noRearrange,
	 Implicit        => \%Implicit,
	 Interpolate     => \%Interpolate,
	 Order           => \%Order,
	 PosNumber       => \%PosNumber,
	 PosRoutine      => \%PosRoutine,
	 Routine         => \%Routine,
);

my @myRefs = keys %myRefs;

sub do_tag {
	my $tag = shift;
#::logDebug("Parse-do_tag: tag=$tag caller=" . caller() . " args=" . ::uneval_it(\@_) );
	if (defined $Vend::Cfg->{AdminSub}{$tag}) { 

		if($Vend::restricted) {
			die errmsg(
					"Tag '%s' in execution-restricted area: %s",
					$tag,
					$Vend::restricted,
				);
		}
		elsif (! $Vend::admin) {
			die errmsg("Unauthorized for admin tag %s", $tag)
		}

	}

	if (! defined $Routine{$tag} and $Global::AccumulateCode) {
#::logDebug("missing $tag, trying code_from_file");
		if($Alias{$tag}) {
			$tag = $Alias{$tag};
#::logDebug("missing $tag found alias=$tag");
		}
		else {
			$Routine{$tag} = Vend::Config::code_from_file('UserTag', $tag)
				if ! $Routine{$tag};
		}
	}

	if (! defined $Routine{$tag}) {
#::logDebug("missing $tag, but didn't try code_from_file?");
        if (! $Alias{$tag}) {
            ::logError("Tag '$tag' not defined.");
            return undef;
        }
        $tag = $Alias{$tag};
	};

	if($Special{$tag}) {
		my $ref = pop(@_);
		my @args = @$ref{ @{$Order{$tag}} };
		push @args, $ref if $addAttr{$tag};
#::logDebug("Parse-do_tag: args now=" . ::uneval_it(\@args) );
		$Initialized->start($tag, $ref);
		return;
	}
	elsif(
		( ref($_[-1]) && scalar @{$Order{$tag}} > scalar @_ and ! $noRearrange{$tag}) 
	)
	{
		my $text;
		my $ref = pop(@_);
		$text = shift if $hasEndTag{$tag};
		my @args = @$ref{ @{$Order{$tag}} };
		push @args, $ref if $addAttr{$tag};
#::logDebug("Parse-do_tag: args now=" . ::uneval_it(\@args) );
		return &{$Routine{$tag}}(@args, $text || undef);
	}
	else {
#::logDebug("Parse-do_tag tag=$tag: args now=" . ::uneval_it(\@_) );
		return &{$Routine{$tag}}(@_);
	}
}

sub resolve_args {
	my $tag = shift;
#::logDebug("resolving args for $tag, attrAlias = $attrAlias{$tag}");
	if (! defined $Routine{$tag} and $Global::AccumulateCode) {
#::logDebug("missing $tag, trying code_from_file");
		$Routine{$tag} = Vend::Config::code_from_file('UserTag', $tag);
	}

	return @_ unless defined $Routine{$tag};
	my $ref = shift;
	my @list;
	if(defined $attrAlias{$tag}) {
		my ($k, $v);
		while (($k, $v) = each %{$attrAlias{$tag}} ) {
#::logDebug("checking alias $k -> $v");
			next unless defined $ref->{$k};
			$ref->{$v} = $ref->{$k};
		}
	}
	if (defined $attrDefault{$tag}) {
		my ($k, $v);
		while (($k, $v) = each %{$attrDefault{$tag}}) {
			next if defined $ref->{$k};
#::logDebug("using default $k = $v");
			$ref->{$k} = $v;
		}
	}
	@list = @{$ref}{@{$Order{$tag}}};
	push @list, $ref if defined $addAttr{$tag};
	push @list, (shift || (defined $ref->{body} ? $ref->{body} : '')) if $hasEndTag{$tag};
	return @list;
}

sub add_tags {
	return unless @_;
	my $ref = shift;
	return unless $ref->{Routine} or $ref->{Alias};
	my $area;
	no strict 'refs';
	foreach $area (@myRefs) {
		next unless $ref->{$area};
		if($area eq 'Routine') {
			for (keys %{$ref->{$area}}) {
				$myRefs{$area}->{$_} = $ref->{$area}->{$_};
			}
			next;
		}
		elsif ($area =~ /HTML$/) {
			for (keys %{$ref->{$area}}) {
				$myRefs{$area}->{$_} =
					defined $myRefs{$area}->{$_}
					? $ref->{$area}->{$_} .'|'. $myRefs{$area}->{$_}
					: $ref->{$area}->{$_};
			}
		}
		else {
			Vend::Util::copyref $ref->{$area}, $myRefs{$area};
		}
	}
	for (keys %{$ref->{Routine}}) {
		$Order{$_} = [] if ! $Order{$_};
		next if defined $PosNumber{$_};
		$PosNumber{$_} = scalar @{$Order{$_}};
	}
}

sub eof {
    shift->parse(undef);
}

sub text {
    my($self, $text) = @_;
	${$self->{OUT}} .= $text;
}

my %Monitor = ( qw( tag_ary 1 ) );

sub build_html_tag {
	my ($orig, $attr, $attrseq) = @_;
	$orig =~ s/\s+.*//s;
	for (@$attrseq) {
		$orig .= qq{ \U$_="} ; # syntax color "
		$attr->{$_} =~ s/"/\\"/g;
		$orig .= $attr->{$_};
		$orig .= '"';
	}
	$orig .= ">";
}

my %implicitHTML = (qw/checked CHECKED selected SELECTED/);

sub format_html_attribute {
	my($attr, $val) = @_;
	if(defined $implicitHTML{$attr}) {
		return $implicitHTML{$attr};
	}
	$val =~ s/"/&quot;/g;
	return qq{$attr="$val"};
}

sub resolve_if_unless {
	my $attr = shift;
	if(defined $attr->{'unless'}) {
		return '' if $attr->{'unless'} =~ /^\s*0?\s*$/;
		return '' if ! $attr->{'unless'};
		return 1;
	}
	elsif (defined $attr->{'if'}) {
		return '' if
			($attr->{'if'} and $attr->{'if'} !~ /^\s*0?\s*$/);
		return 1;
	}
	return '';
}

sub goto_buf {
	my ($name, $buf) = @_;
	if(! $name) {
		$$buf = '';
		return;
	}
	$$buf =~ s!.*?\[label\s+(?:name\s*=\s*(?:["'])?)?($name)['"]*\s*\]!!is
		and return;
	$$buf =~ s:.*?</body\s*>::is
		and return;
	$$buf = '';
	return;
	# syntax color "'
}

sub eval_die {
	my $msg = shift;
	$msg =~ s/\(eval\s+\d+/(tag '$Vend::CurrentTag'/;
	die($msg, @_);
}

# syntax color '"

sub start {
    my($self, $tag, $attr, $attrseq, $origtext, $empty_container) = @_;
	$tag =~ tr/-/_/;   # canonical
	$Vend::CurrentTag = $tag = lc $tag;
#::logDebug("start tag=$tag");
	my $buf = \$self->{_buf};

	my($tmpbuf);
	if (defined $Vend::Cfg->{AdminSub}{$tag}) { 

		if($Vend::restricted) {
			my $log = 'all';
			$Vend::restricted =~ /\blog=(\w+)/ and $log = lc $1;
			undef $log if $log eq 'none' or
				($log eq 'once' and $Vend::restricted_err{$origtext}++);
			if ($log) {
				::logError(
					"Restricted tag (%s) attempted during restriction '%s'",
					$origtext,
					$Vend::restricted,
				);
			}
			${$self->{OUT}} .= $origtext;
			return 1;
		}
		elsif (! $Vend::admin) {
			::response(
						get_locale_message (
							403,
							"Unauthorized for admin tag %s",
							$tag,
							)
						);
			return ($self->{ABORT} = 1);
		}

	}

    # $attr is reference to a HASH, $attrseq is reference to an ARRAY
	my $aliasname = '';
	if (! defined $Routine{$tag} and $Global::AccumulateCode) {
		my $newtag;
		if($newtag = $Alias{$tag}) {
			$newtag =~ s/\s+.*//s;
			Vend::Config::code_from_file('UserTag', $newtag)
				unless $Routine{$newtag};
		}
		else {
			Vend::Config::code_from_file('UserTag', $tag);
		}
	}

	unless (defined $Routine{$tag}) {
		if(defined $Alias{$tag}) {
			$aliasname = $tag;
			my $alias = $Alias{$tag};
			$alias =~ tr/-/_/;
			$tag =~ s/_/[-_]/g;
#::logDebug("origtext: $origtext tag=$tag alias=$alias");
			$origtext =~ s/$tag/$alias/i
				or return 0;
			if ($alias =~ /\s/) {
				# keep old behaviour for aliases like
				# process_search => 'area href=search'
				# otherwise we process it like any other tag
				$$buf = $origtext . $$buf;
				return 1;
			}
			$tag = $alias;
		}
		else {
#::logDebug("no alias. origtext: $origtext");
			${$self->{OUT}} .= $origtext;
			return 1;
		}
	}

	my $trib;
	foreach $trib (@$attrseq) {
		# Attribute aliases
		if(defined $attrAlias{$tag} and $attrAlias{$tag}{$trib}) {
			my $new = $attrAlias{$tag}{$trib} ;
			$attr->{$new} = delete $attr->{$trib};
			$trib = $new;
		}
		# Parse tags within tags, only works if the [ is the
		# first character.
		next unless $attr->{$trib} =~ /\[\w+[-\w]*\s*(?s:.)*\]/;

		my $p = new Vend::Parse;
		$p->parse($attr->{$trib});
		$attr->{$trib} = ${$p->{OUT}};
	}

	if (defined $attrDefault{$tag}) {
		my ($k, $v);
		while (($k, $v) = each %{$attrDefault{$tag}}) {
			next if defined $attr->{$k};
#::logDebug("using default $k = $v");
			$attr->{$k} = $v;
		}
	}

	$attr->{enable_html} = 1 if $Vend::Cfg->{Promiscuous};
	$attr->{reparse} = 1
		unless (
			defined $NoReparse{$tag}
			|| defined $attr->{reparse}
			|| $::Pragma->{no_default_reparse}
		);

	my ($routine,@args);

#::logDebug("tag=$tag order=$Order{$tag}");
	# Check for old-style positional tag
	if(!@$attrseq and $origtext =~ s/\[[-\w]+\s+//i) {
			$origtext =~ s/\]$//;
			$attr->{interpolate} = 1 if defined $Interpolate{$tag};
			if(defined $PosNumber{$tag}) {
				if($PosNumber{$tag} > 1) {
					@args = split /\s+/, $origtext, $PosNumber{$tag};
					push(@args, undef) while @args < $PosNumber{$tag};
				}
				elsif ($PosNumber{$tag}) {
					@args = $origtext;
				}
			}
			@{$attr}{ @{ $Order{$tag} } } = @args;
			$routine =  $PosRoutine{$tag} || $Routine{$tag};
	}
	else {
		$routine = $Routine{$tag};
		$attr->{interpolate} = 1
			if  defined $Interpolate{$tag} && ! defined $attr->{interpolate};
		@args = @{$attr}{ @{ $Order{$tag} } };
	}
	$args[scalar @{$Order{$tag}}] = $attr if $addAttr{$tag};

#::logDebug("Interpolate value now='$attr->{interpolate}'") if$Monitor{$tag};


#::logDebug(<<EOF) if $Monitor{$tag};
#tag=$tag
#routine=$routine
#has_end=$hasEndTag{$tag}
#attributes=@args
#interpolate=$attr->{interpolate}
#EOF

	if($Special{$tag}) {
		if($tag eq 'output') {
			$self->destination($attr->{name}, $attr);
			return 1;
		}
		elsif($tag eq 'bounce') {
#::logDebug("bouncing...options=" . ::uneval($attr));
			return 1 if resolve_if_unless($attr);
			if(! $attr->{href} and $attr->{page}) {
				$attr->{href} = Vend::Interpolate::tag_area($attr->{page});
			}

			$attr->{href} = header_data_scrub($attr->{href});

			$Vend::StatusLine = '' if ! $Vend::StatusLine;
			$Vend::StatusLine .= "\n" if $Vend::StatusLine !~ /\n$/;
			$Vend::StatusLine .= <<EOF if $attr->{target};
Window-Target: $attr->{target}
EOF
			$attr->{status} ||= '302 moved';
			$Vend::StatusLine .= <<EOF;
Status: $attr->{status}
Location: $attr->{href}
EOF
#::logDebug("bouncing...status line=\n$Vend::StatusLine");
			$$buf = '';
			$Initialized->{_buf} = '';
			
            my $body = qq{Redirecting to <a href="%s">%s</a>.};
            $body = errmsg($body, $attr->{href}, $attr->{href});
#::logDebug("bouncing...body=$body");
			$::Pragma->{download} = 1;
			::response($body);
			$Vend::Sent = 1;
			$self->{SEND} = 1;
			return 1;
		}
		elsif($tag eq 'goto') {
			return 1 if resolve_if_unless($attr);
			if(! $args[0]) {
				$$buf = '';
				$Initialized->{_buf} = '';
				$self->{ABORT} = 1
					if $attr->{abort};
				return ($self->{SEND} = 1);
			}
			goto_buf($args[0], $buf);
			$self->{ABORT} = 1;
			$self->{SEND} = 1 if ! $$buf;
			return 1;
		}
	}

	local($SIG{__DIE__}) = \&eval_die;

#::logDebug("output attr=$attr->{_output}");
	$self->destination($attr->{_output}) if $attr->{_output};

	if($hasEndTag{$tag}) {
		# Handle embedded tags, but only if interpolate is 
		# defined (always if using old tags)
#::logDebug("look end for $tag, buf=" . length($$buf) );
		$tmpbuf = $empty_container ? '' : find_matching_end($aliasname || $tag, $buf);
#::logDebug("FOUND end for $tag\nBuf " . length($$buf) . ":\n" . $$buf . "\nTmpbuf:\n$tmpbuf\n");
		if ($attr->{interpolate} and !$empty_container) {
			my $p = new Vend::Parse;
			my $tagsave = $Vend::CurrentTag;
			$p->parse($tmpbuf);
			$Vend::CurrentTag = $tagsave;
			$tmpbuf = $p->{ABORT} ? '' : ${$p->{OUT}};
		}
		if ($attr->{'hide'}) {
			$routine->(@args,$tmpbuf);
		}
		elsif($attr->{reparse} ) {
			$$buf = ($routine->(@args,$tmpbuf)) . $$buf;
		}
		else {
			${$self->{OUT}} .= $routine->(@args,$tmpbuf);
		}
	}
	elsif ($attr->{'hide'}) {
		$routine->(@args);
	}
	elsif($attr->{interpolate}) {
		$$buf = $routine->(@args) . $$buf;
	}
	else {
		${$self->{OUT}} .= $routine->(@args);
	}

	$self->{SEND} = $attr->{'send'} || undef;
#::logDebug("Returning from $tag");
	$self->destination() if $attr->{_output};
	return 1;
}

sub end {
    my($self, $tag) = @_;
	my $save = $tag;
	$tag =~ tr/-/_/;   # canonical
	${$self->{OUT}} .= "[/$save]";
}

sub find_html_end {
    my($tag, $buf) = @_;
    my $out;
	my $canon;

    my $open  = "<$tag ";
    my $close = "</$tag>";
	($canon = $tag) =~ s/_/[-_]/g;

    $$buf =~ s!<$canon\s!<$tag !ig;
    $$buf =~ s!</$canon\s*>!</$tag>!ig;
    my $first = index($$buf, $close);
    return undef if $first < 0;
    my $int = index($$buf, $open);
    my $pos = 0;
#::logDebug("find_html_end: tag=$tag open=$open close=$close $first=$first pos=$pos int=$int");
    while( $int > -1 and $int < $first) {
        $pos   = $int + 1;
        $first = index($$buf, $close, $first + 1);
        $int   = index($$buf, $open, $pos);
#::logDebug("find_html_end: tag=$tag open=$open close=$close $first=$first pos=$pos int=$int");
    }
#::logDebug("find_html_end: tag=$tag open=$open close=$close $first=$first pos=$pos int=$int");
	return undef if $first < 0;
    $first += length($close);
#::logDebug("find_html_end (add close): tag=$tag open=$open close=$close $first=$first pos=$pos int=$int");
    $out = substr($$buf, 0, $first);
    substr($$buf, 0, $first) = '';
    return $out;
}

sub find_matching_end {
    my($tag, $buf) = @_;
    my $out;
	my $canon;

    my $open  = "[$tag ";
    my $close = "[/$tag]";
	($canon = $tag) =~ s/_/[-_]/g;

    $$buf =~ s!\[$canon\s![$tag !ig;
	# Syntax color ]
    $$buf =~ s!\[/$canon\]![/$tag]!ig;
    my $first = index($$buf, $close);
    if ($first < 0) {
		if($Gobble{$tag}) {
			$out = $$buf;
			$$buf = '';
			return $out;
		}
		return undef;
	}
    my $int = index($$buf, $open);
    my $pos = 0;
    while( $int > -1 and $int < $first) {
        $pos   = $int + 1;
        $first = index($$buf, $close, $first + 1);
        $int   = index($$buf, $open, $pos);
    }
    $out = substr($$buf, 0, $first);
    $first = $first < 0 ? $first : $first + length($close);
    substr($$buf, 0, $first) = '';
    return $out;
}

# Passed some string that might be HTML-style attributes
# or might be positional parameters, does the right thing
sub _find_tag {
	my ($buf, $attrhash, $attrseq) = (@_);
	return '' if ! $$buf;
	my $old = 0;
	my $eaten = '';
	my %attr;
	my @attrseq;
	while ($$buf =~ s|^(([a-zA-Z][-a-zA-Z0-9._]*)\s*)||) {
		$eaten .= $1;
		my $attr = lc $2;
		$attr =~ tr/-/_/;
		my $val;
		$old = 0;
		# The attribute might take an optional value (first we
		# check for an unquoted value)
		if ($$buf =~ s|(^=\s*([^\"\'\]\s][^\]\s]*)\s*)||) {
			$eaten .= $1;
			$val = $2;
			HTML::Entities::decode($val);
		# or quoted by " or ' 
		} elsif ($$buf =~ s~(^=\s*([\"\'\`\|])(.*?)\2\s*)~~s) {
			$eaten .= $1;
			my $q = $2;
			$val = $3;
			HTML::Entities::decode($val);
			if ($q eq "`") {
				$val = Vend::Interpolate::tag_calc($val);
			}
			else {
				$q eq '|'
			    	and do {
						$val =~ s/^\s+//;
						$val =~ s/\s+$//;
					};
				$val =~ /__[A-Z]\w*[A-Za-z]__|\[.*\]/s
					and do {
						my $p = new Vend::Parse;
						$p->parse($val);
						$val = ${$p->{OUT}};
					};
			}
		# truncated just after the '=' or inside the attribute
		} elsif ($$buf =~ m|^(=\s*)$| or
				 $$buf =~ m|^(=\s*[\"\'].*)|s) {
			$eaten = "$eaten$1";
			last;
		} else {
			# assume attribute with implicit value, which 
			# means in Interchange no value is set and the
			# eaten value is grown. Note that you should
			# never use an implicit tag when setting up an Alias.
			$old = 1;
		}
		next if $old;
		$attrhash->{$attr} = $val;
		push(@attrseq, $attr);
	}
	unshift(@$attrseq, @attrseq);
	return ($eaten);
}

# Implicit tag attributes
# These are deprecated. Please do not document them,
# as they may go away in the future.
sub implicit {
	my($self, $tag, $attr) = @_;
	# 'int' is special in that it doesn't get pushed on @attrseq
	return ('interpolate', 1, 1) if $attr eq 'int';
	return ($attr, undef) unless defined $Implicit{$tag} and $Implicit{$tag}{$attr};
	my $imp = $Implicit{$tag}{$attr};
	return ($attr, $imp) if $imp =~ s/^$attr=//i;
	return ( $Implicit{$tag}{$attr}, $attr );
}

1;
__END__
