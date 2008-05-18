# Vend::Glimpse - Search indexes with Glimpse
#
# $Id: Glimpse.pm,v 2.16 2007-08-09 13:40:53 pajamian Exp $
#
# Adapted for use with Interchange from Search::Glimpse
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

package Vend::Glimpse;
require Vend::Search;
@ISA = qw(Vend::Search);

$VERSION = substr(q$Revision: 2.16 $, 10);
use strict;
use Vend::File;
use Vend::Util;


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

	@{$s}{keys %Default} = (values %Default);
	$s->{mv_base_directory}     = $Vend::Cfg->{ProductDir} || 'products',
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
	$s->{mv_searchspec}         = [];
	$s->{mv_sort_option}        = [];
	$s->{mv_substring_match}    = [];
	$s->{mv_field_file}         = $::Variable->{MV_DEFAULT_SEARCH_FILE}[0];
	$s->{glimpse_cmd} = $Vend::Cfg->{Glimpse} || 'glimpse';

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

	while (($key,$val) = each %options) {
		$s->{$key} = $val;
	}

	@searchfiles = @{$s->{mv_search_file}};

	for(@searchfiles) {
		$_ = Vend::Util::catfile($s->{mv_base_directory}, $_)
			unless Vend::Util::file_name_is_absolute($_);
	}

	unless ($s->{mv_no_hide} or $s->{mv_hide_field}) {
		my $dbref = $s->{table} || undef;
		if (! $dbref) {
			my $table = $s->{mv_field_file};
			$table =~ s:.*/::;
			$table =~ s/\..*//;
			$dbref = Vend::Data::database_exists_ref($table);
		}
		if ($dbref) {
			my $hf = $dbref->config('HIDE_FIELD');
			$s->{mv_hide_field} = $hf if defined $hf;
#::logDebug("mv_hide_field=$hf");
		}
	}

#::logDebug("gsearch: self=" . ::Vend::Util::uneval_it({%$s}));
	$s->{mv_return_delim} = $s->{mv_index_delim}
		unless defined $s->{mv_return_delim};

	return $s->search_error("Search with glimpse, no glimpse configured.")
		if ! $s->{glimpse_cmd};

	@specs = @{$s->{mv_searchspec}};

	@pats = $s->spec_check(@specs);

	return undef if $s->{matches} == -1;

	# Build glimpse line
	my @cmd;
	push @cmd, $s->{glimpse_cmd};
	push @cmd, "-H $s->{mv_base_directory}"
			unless $s->{glimpse_cmd} =~ /\s+-H/;

	if ($s->{mv_spelling_errors}) {
		$s->{mv_spelling_errors} = int  $s->{mv_spelling_errors};
		push @cmd, '-' . $s->{mv_spelling_errors};
	}

	push @cmd, "-i" unless $s->{mv_case} and $s->{mv_case}[0];
	push @cmd, "-h" unless $s->{mv_return_file_name};
	push @cmd, "-y -L $s->{mv_max_matches}:0:$s->{mv_max_matches}";
	push(@cmd, "-F '$s->{mv_search_file}[0]'")
		if defined $s->{mv_search_file}[0];

	push @cmd, '-w' unless @{$s->{mv_substring_match}};
	push(@cmd, '-O -X') if $s->{mv_return_file_name};
	
	if($s->{mv_return_file_name}) { 
		push @cmd, "-d 'NeVAiRbE'";
	}
	elsif (! $s->{mv_record_delim} or $s->{mv_record_delim} eq "\n") { 
		 #intentionally empty 
	}
	elsif ($s->{mv_record_delim} =~ /^\n+(.*)/) {
		#This doesn't handle two newlines, unfortunately
		push @cmd, "-d '^$1'";
	}
	else {
		$s->{mv_record_delim} =~ s/'/\\'/g; 
		push @cmd, "-d '$s->{mv_record_delim}'";
	}

	if($s->{regex_specs}) {
		@pats = @{$s->{regex_specs}};
	}

	my $joiner = $s->{mv_orsearch}[0] ? ',' : ';';

	if ($s->{mv_coordinate}) {
		undef $f;
	}
	elsif ($s->{mv_return_all}) {
		return $s->search_error("mv_return_all not valid for Glimpse.");
	}
	elsif ($s->{mv_orsearch}[0]) {
		# Put mv_min_string in instead of mv_substring_match to avoid
		# \b in search function
		eval {$f = $s->create_search_or(
									$s->get_scalar(
											qw/mv_case mv_min_string mv_negate/
											),
										@pats					)};
	}
	else  {	
		# Put mv_min_string in instead of mv_substring_match to avoid
		# \b in search function
		eval {$f = $s->create_search_and(
									$s->get_scalar(
											qw/mv_case mv_min_string mv_negate/
											),
										@pats					)};
	}

	$@  and  return $s->search_error("Function creation: $@");
	local($/) = $s->{mv_record_delim} || "\n";

	$s->save_specs();
	
	my $spec = join $joiner, @pats;
	$spec =~ s/'/./g;

	if(length($spec) < $s->{mv_min_string}) {
		my $msg = errmsg(
					"Glimpse search string less than minimum %s characters: %s",
					$s->{mv_min_string},
					$spec,
				);
		return $s->search_error($msg);
	}

	push @cmd, "'$spec'";

	$joiner = $spec;
	$joiner =~ s/['";,]//g;
	if(length($joiner) < $s->{mv_min_string}) {
		my $msg = ::errmsg (<<EOF, $s->{mv_min_string}, $joiner);
Search strings must be at least %s characters.
You had '%s' as the operative characters  of your search strings.
EOF
		return $s->search_error($msg);
	}

	my $cmd = join ' ', @cmd;

#::logDebug("Glimpse command '$cmd'");

	GLIMPSE: {

		open(Vend::Glimpse::SEARCH, "$cmd |")
			or ::logError( "Couldn't fork glimpse search '$cmd': $!"), next;
		#$s->adjust_delimiter(\*SEARCH) if $s->{mv_delimiter_auto};
		my $line;
		my $field_names;

		# Get field names only if no sort (will throw it off) or
		# not already defined
		if($s->{mv_field_file}) {
			allowed_file($s->{mv_field_file})
				or return $s->search_error("can't open fields file");
			$s->{mv_field_file} =
					::catfile($Vend::Cfg->{ProductDir}, $s->{mv_field_file})
				unless ::file_name_is_absolute($s->{mv_field_file});
			open(FF, "< $s->{mv_field_file}")
				or return $s->search_error("can't open fields file");
			chomp($field_names = <FF>);
		}
		if($field_names) {
			$field_names =~ s/^\s+//;
			my @laundry = (qw/mv_search_field mv_range_look mv_return_fields/);
			$s->hash_fields(
						[ split /\Q$s->{mv_index_delim}/, $field_names ],
						@laundry,
			);
			undef $field_names;
		}

#::logDebug("search after getting fields: self=" . ::uneval({%$s}));
		my $prospect;

		eval {
			($limit_sub, $prospect) = $s->get_limit($f, 1);
		};

		$@  and  return $s->search_error("Limit subroutine creation: $@");

		$f = $prospect if $prospect;

		eval {($return_sub, $delayed_return) = $s->get_return(undef, 1)};

		$@  and  return $s->search_error("Return subroutine creation: $@");

		if(! defined $f and defined $limit_sub) {
#::logDebug("no f, limit");
			while(<Vend::Glimpse::SEARCH>) {
				next unless &$limit_sub($_);
				(push @out, $_ and last)
					if $s->{mv_return_file_name};
				push @out, &$return_sub($_);
			}
		}
		elsif(defined $limit_sub) {
#::logDebug("f, limit");
#::logDebug("record_delim: |$s->{mv_record_delim}|, delim=|$/|");
			while(<Vend::Glimpse::SEARCH>) {
#::logDebug("in line: $_");
				next unless &$f();
#::logDebug("match line f: $_");
				next unless &$limit_sub($_);
#::logDebug("match line limit: $_");
				(push @out, $_ and last)
					if $s->{mv_return_file_name};
				push @out, &$return_sub($_);
			}
		}
		elsif (!defined $f) {
#::logDebug("no f, no limit");
			return $s->search_error('No search definition');
		}
		else {
#::logDebug("f, no limit");
			while(<Vend::Glimpse::SEARCH>) {
				next unless &$f();
				(push @out, $_ and last)
					if $s->{mv_return_file_name};
				push @out, &$return_sub($_);
			}
		}
#::logDebug("gsearch before closing search: self=" . ::Vend::Util::uneval_it({%$s}));
		close Vend::Glimpse::SEARCH;
		$s->restore_specs();
	}

	$s->{matches} = scalar(@out);

#::logDebug("gsearch before delayed return: self=" . ::Vend::Util::uneval_it({%$s}));
	if($delayed_return and $s->{matches} > 0) {
		$s->hash_fields($s->{mv_field_names}, qw/mv_sort_field/);
#::logDebug("gsearch after hash fields: self=" . ::Vend::Util::uneval_it({%$s}));
		$s->sort_search_return(\@out);
		$delayed_return = $s->get_return(1);
		@out = map { $delayed_return->($_) } @out;
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
		return $s;
	}
	elsif($s->{mv_return_reference} eq 'LIST') {
		my $col = scalar @{$s->{mv_return_fields}};
		@out = map { join $s->{mv_return_delim}, @$_ } @out;
		$s->{mv_results} = join $s->{mv_record_delim}, @out;
	}
	elsif($s->{mv_return_reference} eq 'HASH') {
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
