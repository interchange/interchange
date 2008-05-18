# Vend::DbSearch - Search indexes with Interchange
#
# $Id: RefSearch.pm,v 2.11 2007-08-09 13:40:54 pajamian Exp $
#
# Adapted for use with Interchange from Search::TextSearch
#
# Copyright (C) 2002-2007 Interchange Development Group
# Copyright (C) 1996-2002 Red Hat, Inc.
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

package Vend::RefSearch;
require Vend::Search;

@ISA = qw(Vend::Search);

$VERSION = substr(q$Revision: 2.11 $, 10);

use strict;
no warnings qw(uninitialized numeric);

sub array {
	my ($s, $opt) = @_;
	$s->{mv_one_sql_table} = 1;
	$s->{mv_list_only} = 1; # makes perform_search only return results array
	return Vend::Scan::perform_search($opt, undef, $s);
}

sub hash {
	my ($s, $opt) = @_;
	$s->{mv_return_reference} = 'HASH';
	$s->{mv_one_sql_table} = 1;
	$s->{mv_list_only} = 1; # makes perform_search only return results array
	return Vend::Scan::perform_search($opt, undef, $s);
}

sub list {
	my ($s, $opt) = @_;
	$s->{mv_return_reference} = 'LIST';
	$s->{mv_one_sql_table} = 1;
	$s->{mv_list_only} = 1; # makes perform_search only return results array
	return Vend::Scan::perform_search($opt, undef, $s);
}

my %Default = (
	matches                 => 0,
	mv_head_skip            => 0,
	mv_index_delim          => "\t",
	mv_matchlimit           => 50,
	mv_min_string           => 1,
	verbatim_columns        => 1,
);

sub init {
	my ($s, $options) = @_;

	# autovivify references of nested data structures we use below, since they
	# don't yet exist at daemon startup time before configuration is done
	$Vend::Cfg->{ProductFiles}[0] or 1;
	$::Variable->{MV_DEFAULT_SEARCH_TABLE} or 1;

	@{$s}{keys %Default} = (values %Default);
	$s->{mv_all_chars}	        = [1];
	
	### This is a bit of a misnomer, for really it is the base table
	### that we will use if no base=table param is specified
	$s->{mv_base_directory}     = $Vend::Cfg->{ProductFiles}[0];
	$s->{mv_begin_string}       = [];
	$s->{mv_case}               = [];
	$s->{mv_column_op}          = [];
	$s->{mv_negate}             = [];
	$s->{mv_numeric}            = [];
	$s->{mv_orsearch}           = [];
	$s->{mv_search_field}       = [];
	$s->{mv_search_file}        =	[ @{
										$::Variable->{MV_DEFAULT_SEARCH_TABLE}
										||	$Vend::Cfg->{ProductFiles}
										} ];
	$s->{mv_search_group}       = [];
	$s->{mv_searchspec}         = [];
	$s->{mv_sort_option}        = [];
	$s->{mv_substring_match}    = [];

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
	my($f,$key,$val);
	my($searchfile,@searchfiles);
	my(@specs);
	my(@pats);

	while (($key,$val) = each %options) {
		$s->{$key} = $val;
	}

	$s->{mv_return_delim} = $s->{mv_index_delim}
		unless defined $s->{mv_return_delim};

#::logDebug("Called RefSearch, object=" . ::uneval($s));
	@specs = @{$s->{mv_searchspec}};

	@pats = $s->spec_check(@specs);

	if ($s->{mv_coordinate}) {
		undef $f;
	}
	elsif ($s->{mv_orsearch}[0]) {
		eval {$f = $s->create_search_or(
									$s->get_scalar(
											qw/mv_case mv_substring_match mv_negate/
											),
										@pats					)};
	}
	else  {	
		eval {$f = $s->create_search_and(
									$s->get_scalar(
											qw/mv_case mv_substring_match mv_negate/
											),
										@pats					)};
	}

	$@  and  return $s->search_error("Function creation: $@");

	$s->save_specs();
#::logDebug("searchfiles=@searchfiles");
	

	### Now we search

	my $target = $s->{mv_search_reference};

#::logDebug("target: " . ::uneval($target));
	if(! ref $target) {
		my $label = $target;
		my $sr = $::Instance->{SearchObject}{$label};
		if(! $sr) {
			return $s->search_error("$label is not a target nor a label referencing a previous search");
		}
		$target= $sr->{mv_results};
		$s->{mv_field_names} ||= $sr->{mv_field_names};
	}

#::logDebug("field names=" . ::uneval($s->{mv_field_names}));
#::logDebug("target now: " . ::uneval($target));
	if(
		ref($target) ne 'ARRAY'
			or
		(defined $target->[0] && ref($target->[0]) ne 'ARRAY')
	  )
	{
		return $s->search_error("Reference for search must be array of arrays");
	}

	if(! $s->{mv_field_names}) {
		if($s->{head_skip}) {
			my @lines = splice(@$target,0,$s->{mv_head_skip});
			$s->{mv_field_names} = pop(@lines);
		}
		else {
			$s->{mv_field_names} = [ 0 .. (@{$target->[0]} - 1) ]
		}
	}

	$s->hash_fields($s->{mv_field_names});
	
	my $prospect;
	eval {
		($limit_sub, $prospect) = $s->get_limit($f);
	};

	$@  and  return $s->search_error("Limit subroutine creation: $@");

	$f = $prospect if $prospect;

	eval {($return_sub, $delayed_return) = $s->get_return()};

	$@  and  return $s->search_error("Return subroutine creation: $@");

	if(! defined $f and defined $limit_sub) {
#::logDebug("no f, limit, dbref=$dbref");
		local($_);
		my $ref;
		for $ref (@$target) {
			next unless $limit_sub->($ref);
			push @out, $return_sub->($ref);
		}
	}
	elsif(defined $limit_sub) {
#::logDebug("f and limit, dbref=$dbref");
		local($_);
		my $ref;
		for $ref (@$target) {
			$_ = join "\t", @$ref;
			next unless &$f();
			next unless $limit_sub->($ref);
			push @out, $return_sub->($ref);
		}
	}
	elsif (!defined $f) {
		return $s->search_error('No search definition');
	}
	else {
#::logDebug("f and no limit, dbref=$dbref");
		local($_);
		my $ref;
		for $ref (@$target) {
#::logDebug("f and no limit, ref=$ref");
			$_ = join "\t", @$ref;
			next unless &$f();
			push @out, $return_sub->($ref);
		}
	}
	$s->restore_specs();

	$s->{matches} = scalar(@out);
#::logDebug("before delayed return: self=" . ::Vend::Util::uneval_it({%$s}));

	if($delayed_return and $s->{matches} > 0) {
		$s->hash_fields($s->{mv_field_names}, qw/mv_sort_field/);
		$s->sort_search_return(\@out);
		$delayed_return = $s->get_return(1);
		@out = map { $delayed_return->($_) } @out;
	}
#::logDebug("after delayed return: self=" . ::Vend::Util::uneval({%$s}));

	if($s->{mv_unique}) {
		my %seen;
		@out = grep ! $seen{$_->[0]}++, @out;
	}

	if($s->{mv_max_matches} > 0) {
		splice @out, $s->{mv_max_matches};
	}

	$s->{matches} = scalar(@out);

	## This is the normal return point unless RefSearch called by program
	## or ITL
	return @out if $s->{mv_return_filtered};

	if ($s->{matches} > $s->{mv_matchlimit} and $s->{mv_matchlimit} > 0) {
		$s->save_more(\@out)
			or ::logError("Error saving matches: $!");
		if ($s->{mv_first_match}) {
			splice(@out,0,$s->{mv_first_match}) if $s->{mv_first_match};
			$s->{mv_next_pointer} = $s->{mv_first_match} + $s->{mv_matchlimit};
			$s->{mv_next_pointer} = 0
				if $s->{mv_next_pointer} > $s->{matches};
		}
		elsif ($s->{mv_start_match}) {
			my $comp = $s->{mv_start_match};
			my $i = -1;
			my $found;
			for(@out) {
				$i++;
				next unless $_->[0] eq $comp;
				$found = $i;
				last;
			}
			if(! $found and $s->{mv_numeric}[0]) {
				for(@out) {
					$i++;
					next unless $_->[0] >= $comp;
					$found = $i;
					last;
				}
			}
			elsif (! $found) {
				for(@out) {
					$i++;
					next unless $_->[0] ge $comp;
					$found = $i;
					last;
				}
			}
			if($found) {
				splice(@out,0,$found);
				$s->{mv_first_match} = $found;
				$s->{mv_next_pointer} = $found + $s->{mv_matchlimit};
				$s->{mv_next_pointer} = 0
					if $s->{mv_next_pointer} > $s->{matches};
			}
		}
		$#out = $s->{mv_matchlimit} - 1;
	}
#::logDebug("after hash fields: self=" . ::Vend::Util::uneval_it({%$s}));
#::logDebug("after delayed return: self=" . ::Vend::Util::uneval_it({%$s}));

	if(! $s->{mv_return_reference}) {
		$s->{mv_results} = \@out;
	}
	elsif($s->{mv_return_reference} eq 'LIST') {
		@out = map { join $s->{mv_return_delim}, @$_ } @out;
		$s->{mv_results} = join $s->{mv_record_delim}, @out;
	}
	else {
		my @names;
		@names = @{ $s->{mv_field_names} }[ @{$s->{mv_return_fields}} ];
		$names[0] eq '0' and $names[0] = 'code';
		my @ary;
		for (@out) {
			my $h = {};
			@{ $h } {@names} = @$_;
			push @ary, $h;
		}
		$s->{mv_results} = \@ary;
	}
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
