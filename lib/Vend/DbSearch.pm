# Vend/DbSearch.pm:  Search indexes with Perl
#
# $Id: DbSearch.pm,v 1.1 2000-05-26 18:50:37 heins Exp $
#
# ADAPTED FOR USE WITH MINIVEND from Search::TextSearch
#
# Copyright 1996-2000 by Michael J. Heins <mikeh@minivend.com>
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

package Vend::DbSearch;
require Vend::Search;

@ISA = qw(Vend::Search);

$VERSION = substr(q$Revision: 1.1 $, 10);

use Search::Dict;
use strict;

sub array {
	my ($s, $opt) = @_;
	$s->{mv_one_sql_table} = 1;
	$s->{mv_list_only} = 1;
	Vend::Scan::perform_search($opt, undef, $s);
}

sub hash {
	my ($s, $opt) = @_;
	$s->{mv_return_reference} = 'HASH';
	$s->{mv_one_sql_table} = 1;
	$s->{mv_list_only} = 1;
	Vend::Scan::perform_search($opt, undef, $s);
}

sub list {
	my ($s, $opt) = @_;
	$s->{mv_list_only} = 1;
	$s->{mv_return_reference} = 'LIST';
	$s->{mv_one_sql_table} = 1;
	Vend::Scan::perform_search($opt, undef, $s);
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

	@{$s}{keys %Default} = (values %Default);
    $s->{mv_all_chars}	        = [1];
    $s->{mv_base_directory}     = $Vend::Cfg->{ProductFiles}[0];
    $s->{mv_begin_string}       = [];
    $s->{mv_case}               = [];
    $s->{mv_column_op}          = [];
    $s->{mv_negate}             = [];
    $s->{mv_numeric}            = [];
    $s->{mv_orsearch}           = [];
    $s->{mv_search_field}       = [];
    $s->{mv_search_file}        = [@{$Vend::Cfg->{ProductFiles}}];
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

	@searchfiles = @{$s->{mv_search_file}};

	for(@searchfiles) {
		s:.*/::;
		s/\..*//;
	}
#::logDebug ("searching: searchfiles='@searchfiles', obj=" . ::uneval($s));
	my $dbref = $s->{table} || undef;
#::logDebug("before db mapping: self=" . ::Vend::Util::uneval_it({%$s}));

	if( ! $dbref ) {
		$s->{dbref} = $dbref = Vend::Data::database_exists_ref($searchfiles[0]);
	}
	if(! $dbref) {
		return $s->search_error(
			"your search file a valid database reference, was '$searchfiles[0]'."
			);
	}
	$s->{dbref} = $dbref;

	my (@fn) = $dbref->columns();

	@specs = @{$s->{mv_searchspec}};

    if(ref $s->{mv_range_look}) {
        unless( scalar(@{$s->{mv_range_look}}) == scalar(@{$s->{mv_range_min}}) and
                scalar(@{$s->{mv_range_look}}) == scalar(@{$s->{mv_range_max}}) ) {
			$s->{mv_search_warning}
				= "Must have min and max values for range -- aborting range look.";
			undef $s->{mv_range_look};
		}
	}

	@pats = $s->spec_check(@specs);

	if ($s->{mv_coordinate}) {
		undef $f;
	}
	elsif ($s->{mv_return_all}) {
		$f = sub {1};
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

	my $qual;
	if($s->{eq_specs_sql}) {
		$qual = ' WHERE ';
		my $joiner = ' AND ';
		$joiner = ' OR ' if $s->{mv_orsearch}[0];
		$qual .= join $joiner, @{$s->{eq_specs_sql}};
	}

	$s->save_specs();
#::logDebug("searchfiles=@searchfiles");
	foreach $searchfile (@searchfiles) {
		$searchfile =~ s/\..*//;
		my $db;
		if (! $s->{mv_one_sql_table} ) {
			$db = Vend::Data::database_exists_ref($searchfile)
				or ::logError(
							"Attempt to search non-existent database %s",
							$searchfile,
						), next;
			
			$dbref = $s->{dbref} = $db->ref();
			@fn = $dbref->columns();
		}
		$s->hash_fields(\@fn);
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
			while($_ = join "\t", $dbref->each_nokey($qual || undef) ) {
				next unless &$limit_sub($_);
				push @out, &$return_sub($_);
			}
		}
		elsif(defined $limit_sub) {
#::logDebug("f and limit, dbref=$dbref");
			while($_ = join "\t", $dbref->each_nokey($qual || undef) ) {
#::logDebug("cand: $_");
				next unless &$f();
#::logDebug("cand: $_ survived");
				next unless &$limit_sub($_);
#::logDebug("cand: $_ survived again");
				push @out, &$return_sub($_);
			}
		}
		elsif (!defined $f) {
			return $s->search_error('No search definition');
		}
		else {
#::logDebug("f and no limit, dbref=$dbref");
			while($_ = join "\t", $dbref->each_nokey($qual || undef) ) {
				next unless &$f();
				push @out, &$return_sub($_);
			}
		}
		$s->restore_specs();
	}

	$s->{matches} = scalar(@out);
#::logDebug("before delayed return: self=" . ::Vend::Util::uneval_it({%$s}));

	if($delayed_return and $s->{matches} > 0) {
		$s->hash_fields($s->{mv_field_names}, qw/mv_sort_field/);
		$s->sort_search_return(\@out);
		$delayed_return = $s->get_return(1);
		@out = map { $delayed_return->($_) } @out;
	}
#::logDebug("after delayed return: self=" . ::Vend::Util::uneval_it({%$s}));

	if($s->{mv_unique}) {
		my %seen;
		@out = grep ! $seen{$_}++, @out;
		$s->{matches} = scalar(@out);
	}

    if ($s->{matches} > $s->{mv_matchlimit}) {
        $s->save_more(\@out)
            or ::logError("Error saving matches: $!");
		if ($s->{mv_first_match}) {
			splice(@out,0,$s->{mv_first_match}) if $s->{mv_first_match};
			$s->{mv_next_pointer} = $s->{mv_first_match} + $s->{mv_matchlimit};
			$s->{mv_next_pointer} = 0
				if $s->{mv_next_pointer} > $s->{matches};
		}
        $#out = $s->{mv_matchlimit} - 1;
    }
#::logDebug("after hash fields: self=" . ::Vend::Util::uneval_it({%$s}));
#::logDebug("after delayed return: self=" . ::Vend::Util::uneval_it({%$s}));

	if(! $s->{mv_return_reference}) {
		$s->{mv_results} = \@out;
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
	return $s;
}

# Unfortunate hack need for Safe searches
*escape         	= \&Vend::Search::escape;
*spec_check         = \&Vend::Search::spec_check;
*get_scalar         = \&Vend::Search::get_scalar;
*more_matches       = \&Vend::Search::more_matches;
*get_return         = \&Vend::Search::get_return;
*map_ops            = \&Vend::Search::map_ops;
*get_limit          = \&Vend::Search::get_limit;
*saved_params       = \&Vend::Search::saved_params;
*range_check        = \&Vend::Search::range_check;
*create_search_and  = \&Vend::Search::create_search_and;
*create_search_or   = \&Vend::Search::create_search_or;
*save_context       = \&Vend::Search::save_context;
*dump_options       = \&Vend::Search::dump_options;
*save_more          = \&Vend::Search::save_more;
*sort_search_return = \&Vend::Search::sort_search_return;
*get_scalar 		= \&Vend::Search::get_scalar;
*hash_fields 		= \&Vend::Search::hash_fields;
*save_specs 		= \&Vend::Search::save_specs;
*restore_specs 		= \&Vend::Search::restore_specs;
*splice_specs 		= \&Vend::Search::splice_specs;
*search_error 		= \&Vend::Search::search_error;
*save_more 			= \&Vend::Search::save_more;
*sort_search_return = \&Vend::Search::sort_search_return;

1;
__END__
