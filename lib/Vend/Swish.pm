# Vend::Swish - Search indexes with Swish-e
#
# $Id: Swish.pm,v 1.8 2006-04-10 20:27:37 racke Exp $
#
# Adapted from Vend::Glimpse
#
# Copyright (C) 2002-2006 Interchange Development Group
# Copyright (C) 2002 Mike Heins <mikeh@perusion.net>
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

package Vend::Swish;
require Vend::Search;
@ISA = qw(Vend::Search);

$VERSION = substr(q$Revision: 1.8 $, 10);
use strict;

sub array {
	my ($s, $opt) = @_;
	$s->{mv_list_only} = 1; # makes perform_search only return results array
	return Vend::Scan::perform_search($opt, undef, $s);
}

sub hash {
	my ($s, $opt) = @_;
	$s->{mv_return_reference} = 'HASH';
	$s->{mv_list_only} = 1; # makes perform_search only return results array
	return Vend::Scan::perform_search($opt, undef, $s);
}

sub list {
	my ($s, $opt) = @_;
	$s->{mv_return_reference} = 'LIST';
	$s->{mv_list_only} = 1; # makes perform_search only return results array
	return Vend::Scan::perform_search($opt, undef, $s);
}

my %Default = (
		matches                 => 0,
		mv_head_skip            => 0,
		mv_index_delim          => "\t",
		mv_record_delim         => "\n",
		mv_matchlimit           => 50,
		mv_max_matches          => 2000,
		mv_min_string           => 4,
);


sub init {
	my ($s, $options) = @_;

#::logDebug("initting Swish search, Swish=" . Vend::Util::uneval($Vend::Cfg->{Swish}));
	$Vend::Cfg->{Swish} ||= {};
	@{$s}{keys %Default} = (values %Default);
	$s->{mv_base_directory}     = undef,
	$s->{mv_begin_string}       = [];
	$s->{mv_all_chars}	        = [1];
	$s->{mv_case}               = [];
	$s->{mv_column_op}          = [];
	$s->{mv_negate}             = [];
	$s->{mv_numeric}            = [];
	$s->{mv_orsearch}           = [];
	$s->{mv_searchspec}	        = [];
	$s->{mv_search_group}       = [];
	$s->{mv_search_field}       = [];
	$s->{mv_search_file}        = [];
	push @{$s->{mv_search_file}}, $Vend::Cfg->{Swish}{index}
		if $Vend::Cfg->{Swish}{index};
	$s->{mv_searchspec}         = [];
	$s->{mv_sort_option}        = [];
	$s->{mv_substring_match}    = [];
	$s->{mv_field_names}      = [qw/code score url title filesize mod_date/];
	$s->{mv_return_fields}    = [qw/code score url title filesize mod_date/];
	$s->{swish_cmd} = $Vend::Cfg->{Swish}{command} || '/usr/local/bin/swish-e';
#::logDebug("initting Swish search, swish command=$s->{swish_cmd}");

	for(keys %$options) {
		$s->{$_} = $options->{$_};
	}

	return;
}

sub new {
	my ($class, %options) = @_;
	my $s = new Vend::Search;
	bless $s, $class;
	$s->init(\%options);
	return $s;
}

sub search {

	my($s,%options) = @_;

	my(@out);
	my($limit_sub,$return_sub,$delayed_return);
	my($dict_limit,$f,$key,$val);
	my($searchfile, @searchfiles);
	my(@specs);
	my(@pats);

	# map Swish-e auto properties to field names
	my %fmap = qw/
					code	swishreccount
					description swishdescription
					dbfile    swishdbfile
					score	swishrank
					url		swishdocpath
					title	swishtitle
					filesize	swishdocsize
					mod_date	swishlastmodified
				/;
	while (($key,$val) = each %options) {
		$s->{$key} = $val;
	}

	@searchfiles = @{$s->{mv_search_file}};

	for(@searchfiles) {
		$_ = Vend::Util::catfile($s->{mv_base_directory}, $_)
			unless Vend::Util::file_name_is_absolute($_);
	}

#::logDebug("gsearch: self=" . ::Vend::Util::uneval_it({%$s}));
	$s->{mv_return_delim} = $s->{mv_index_delim}
		unless defined $s->{mv_return_delim};

	unless ($s->{swish_cmd} && -x $s->{swish_cmd}) {
		return $s->search_error("Invalid swish command $s->{swish_cmd}");
	}

	@specs = @{$s->{mv_searchspec}};

	@pats = $s->spec_check(@specs);

	my @f;

	for(@{$s->{mv_field_names}}) {
		my $name = $fmap{$_} || $_;
		$name = "<$name>";
		push @f, $name;
	}
	
	my $fmt_string = join $s->{mv_return_delim}, @f;
	
	$fmt_string .= $s->{mv_record_delim} eq "\n" ? '\n' : $s->{mv_record_delim};

	return undef if $s->{matches} == -1;

	# Build swish line
	my @cmd;
	push @cmd, $s->{swish_cmd};
	push @cmd, qq{-x '$fmt_string'};
	push @cmd, "-c $s->{mv_base_directory}"
			if $s->{mv_base_directory};

	if (@searchfiles) {
		push @cmd, "-f " . join(" ", @searchfiles);
	}
	
	push @cmd, "-m $s->{mv_max_matches}" if $s->{mv_max_matches};
	
	local($/) = $s->{mv_record_delim} || "\n";

	$s->save_specs();
	
	my $spec = join ' ', @pats;

	$spec =~ s/[^-\w()"\s\*]+//g
		and $CGI::values{debug}
		and ::logError("Removed unsafe characters from search string");

	if(length($spec) < $s->{mv_min_string}) {
		my $msg = ::errmsg(
					"Swish search string less than minimum %s characters: %s",
					$s->{mv_min_string},
					$spec,
				);
		return $s->search_error($msg);
	}

	push @cmd, qq{-w $spec};

	if(length($spec) < $s->{mv_min_string}) {
		my $msg = ::errmsg (<<EOF, $s->{mv_min_string}, $spec);
Search strings must be at least %s characters.
You had '%s' as the operative characters  of your search strings.
EOF
		return $s->search_error($msg);
	}

	my $cmd = join ' ', @cmd;

	my $cwd = `pwd`;
	chomp($cwd);
#::logDebug("Swish command '$cmd' cwd=$cwd");

	open(SEARCH, "$cmd |")
		or ::logError( "Couldn't fork swish search '$cmd': $!"), next;
	#$s->adjust_delimiter(\*SEARCH) if $s->{mv_delimiter_auto};
	my $line;
	my $field_names;

#::logDebug("search after getting fields: self=" . ::uneval({%$s}));
	my $prospect;

	my $f = sub { 1 };

	eval {
		($limit_sub, $prospect) = $s->get_limit($f, 1);
	};

	$@  and  return $s->search_error("Limit subroutine creation: $@");

	$f = $prospect if $prospect;

	eval {($return_sub, $delayed_return) = $s->get_return(undef, 1)};

	$return_sub = sub { return [ split $s->{mv_index_delim}, shift(@_) ] };

	$@  and  return $s->search_error("Return subroutine creation: $@");

	my $field_names = join "\t", @{$s->{mv_field_names}};
	$field_names =~ s/^\s+//;
	my @laundry = (qw/mv_search_field mv_range_look mv_return_fields/);
	$s->hash_fields(
				[ split /\Q$s->{mv_index_delim}/, $field_names ],
				@laundry,
	);
	undef $field_names;

	if($limit_sub) {
		while(<SEARCH>) {
#::logDebug("swish line, limit_sub: $_");
			next if /^#/;
			last if $_ eq ".\n";
			$limit_sub->($_);
			push @out, $return_sub->($_);
		}
	}
	else {
		while(<SEARCH>) {
#::logDebug("swish line: $_");
			next if /^#/;
			last if $_ eq ".\n";
			push @out, $return_sub->($_);
		}
	}

	if(scalar(@out) == 1 and $out[0][0] =~ s/^err\w*\W+//)  {
		$s->{matches} = -1;
		return $s->search_error($out[0][0]);
	}

	$s->{matches} = scalar(@out);

#::logDebug("gsearch before delayed return: self=" . ::Vend::Util::uneval_it({%$s}));
	if($s->{mv_sort_field} and  @{$s->{mv_sort_field}}) {
		$s->hash_fields($s->{mv_field_names}, qw/mv_sort_field/);
		@out = $s->sort_search_return(\@out);
	}
#::logDebug("after delayed return: self=" . ::Vend::Util::uneval_it({%$s}));

	if($s->{mv_unique}) {
		my %seen;
		@out = grep ! $seen{$_->[0]}++, @out;
		$s->{matches} = scalar(@out);
	}

	if ($s->{matches} > $s->{mv_matchlimit} and $s->{mv_matchlimit} > 0) {
		$s->save_more(\@out)
			or ::logError("Error saving matches: $!");
		if ($s->{mv_first_match}) {
			splice(@out,0,$s->{mv_first_match});
			$s->{mv_next_pointer} = $s->{mv_first_match} + $s->{mv_matchlimit};
			$s->{mv_next_pointer} = 0
				if $s->{mv_next_pointer} > $s->{matches};
		}
		$#out = $s->{mv_matchlimit} - 1;
	}

	if(! $s->{mv_return_reference}) {
		$s->{mv_results} = \@out;
#::logDebug("returning search: " . Vend::Util::uneval($s));
		return $s;
	}
	elsif($s->{mv_return_reference} eq 'LIST') {
		my $col = scalar @{$s->{mv_return_fields}};
		@out = map { join $s->{mv_return_delim}, @$_ } @out;
		$s->{mv_results} = join $s->{mv_record_delim}, @out;
	}
	else {
		my $col = scalar @{$s->{mv_return_fields}};
		my @col;
		my @names;
		@names = @{$s->{mv_field_names}};
		$names[0] eq '0' and $names[0] = 'code';
		my %hash;
		my $key;
		for (@out) {
			@col = split /$s->{mv_return_delim}/, $_, $col;
			$hash{$col[0]} = {};
			@{ $hash{$col[0]} } {@names} = @col;
		}
		$s->{mv_results} = \%hash;
	}
#::logDebug("returning search: " . Vend::Util::uneval($s));
	return $s;
}

# Unfortunate hack need for Safe searches
*create_search_and  = \&Vend::Search::create_search_and;
*create_search_or   = \&Vend::Search::create_search_or;
*dump_options       = \&Vend::Search::dump_options;
*escape             = \&Vend::Search::escape;
*get_limit          = \&Vend::Search::get_limit;
*get_return         = \&Vend::Search::get_return;
*get_scalar         = \&Vend::Search::get_scalar;
*hash_fields        = \&Vend::Search::hash_fields;
*map_ops            = \&Vend::Search::map_ops;
*more_matches       = \&Vend::Search::more_matches;
*range_check        = \&Vend::Search::range_check;
*restore_specs      = \&Vend::Search::restore_specs;
*save_context       = \&Vend::Search::save_context;
*save_more          = \&Vend::Search::save_more;
*save_specs         = \&Vend::Search::save_specs;
*saved_params       = \&Vend::Search::saved_params;
*search_error       = \&Vend::Search::search_error;
*sort_search_return = \&Vend::Search::sort_search_return;
*spec_check         = \&Vend::Search::spec_check;
*splice_specs       = \&Vend::Search::splice_specs;

1;
__END__
