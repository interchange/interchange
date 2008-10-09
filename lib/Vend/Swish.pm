# Vend::Swish - Search indexes with Swish-e's new SWISH::API
#
# $Id: Swish.pm,v 1.15 2008-10-09 14:43:42 racke Exp $
#
# Adapted from earlier Vend::Swish by Brian Miller <brian@endpoint.com>
#
# Copyright (C) 2005-2008 Interchange Development Group
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
# Software Foundation, Inc., 51 Franklin St, Fifth Floor, Boston,
# MA  02110-1301  USA.

package Vend::Swish;
require Vend::Search;
@ISA = qw(Vend::Search);

$VERSION = substr(q$Revision: 1.15 $, 10);
use strict;

use SWISH::API;

BEGIN {
	eval {
		require SWISH::ParseQuery;
		require SWISH::PhraseHighlight;
		$Vend::Swish::Highlighting = 1;
	};
}
		
# singleton to hold initialization object, 
# search objects are then retrieved through it
# this should improve performance through caching
my $_swish = {};
my $_swish_highlighters = {};

my %Default = (
    matches                 => 0,
    mv_head_skip            => 0,
    mv_index_delim          => "\t",
    mv_record_delim         => "\n",
    mv_matchlimit           => 50,
    mv_max_matches          => 2000,
    mv_min_string           => 1,
);

my %fmap = ( code        => 'swishreccount',
             score       => 'swishrank',
             url         => 'swishdocpath',
             title       => 'swishtitle',
             filesize    => 'swishdocsize',
             mod_date    => 'swishlastmodified',
             description => 'swishdescription',
			 dbfile      => 'swishdbfile',
           );
my %highlight_settings = ( show_words    => 8,
                           occurrences   => 5,
                           max_words     => 100,
                           highlight_on  => '<span class="highlight">',
                           highlight_off => '</span>',
                         );

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

sub init {
    my ($s, $options) = @_;

#::logDebug("initing Swish search, Swish=" . Vend::Util::uneval($Vend::Cfg->{Swish}));
    $Vend::Cfg->{Swish} ||= {};

    @{$s}{keys %Default} = (values %Default);

    $s->{mv_base_directory}     = $Vend::Cfg->{VendRoot},
    $s->{mv_begin_string}       = [];
    $s->{mv_all_chars}          = [1];
    $s->{mv_case}               = [];
    $s->{mv_column_op}          = [];
    $s->{mv_negate}             = [];
    $s->{mv_numeric}            = [];
    $s->{mv_orsearch}           = [];
    $s->{mv_searchspec}         = [];
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

    for (keys %$options) {
        $s->{$_} = $options->{$_};
    }

    # can create the base Swish object once and run
    # multiple queries off of it
    my @searchfiles = @{$s->{mv_search_file}};
    for (@searchfiles) {
        $_ = Vend::Util::catfile($s->{mv_base_directory}, $_)
            unless Vend::Util::file_name_is_absolute($_);
    }
    my $from_index = join ' ', @searchfiles;
    $s->{'swish_index'} = $from_index;

    unless ($_swish->{$from_index}) {
        $_swish->{$from_index} = new SWISH::API ( $from_index );
        if ($_swish->{$from_index}->Error) {
            die "Can't create swish engine on searchfile(s) @searchfiles: " . $_swish->{$from_index}->ErrorString . "\n";
        }
    }

    if ($Vend::Cfg->{Swish}{highlight_context}) {
        push @{ $s->{mv_field_names} }, 'context';
        push @{ $s->{mv_return_fields} }, 'context';
        $fmap{'context'} = 'swishdescription';

        foreach my $index (@{ $s->{'mv_search_file'} }) {
            my $swish = $_swish->{$from_index};
            my %headers = map { lc $_ => ($swish->HeaderValue( $index, $_ ) || '') } $swish->HeaderNames;

            $_swish_highlighters->{$index} = new SWISH::PhraseHighlight ( \%highlight_settings, \%headers, { swish => $swish } );
        }
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
    my ($s, %options) = @_;

    while (my ($key,$val) = each %options) {
        $s->{$key} = $val;
    }
    $s->{mv_return_delim} = $s->{mv_index_delim}
        unless defined $s->{mv_return_delim};

    my @specs = @{$s->{mv_searchspec}};
    my @pats = $s->spec_check(@specs);

    $s->save_specs();

    my $search_string = join ' ', @pats;
    if (length $search_string < $s->{mv_min_string}) {
        my $msg = ::errmsg(
                    "Swish search string less than minimum %s characters: %s",
                    $s->{mv_min_string},
                    $search_string,
                );
        return $s->search_error($msg);
    }

    my $engine = $_swish->{ $s->{'swish_index'} };

	# check properties first
	my @indexes = $engine->IndexNames();
	my $index_num = @indexes;
	my (%prop_avail, @plist, $prop);
	
	for my $index (@indexes) {
		@plist = $engine->PropertyList($index);
		for $prop (@plist) {
			push (@{$prop_avail{$prop->Name()}}, $index);
		}
	}

	my @sf =  @{ $s->{mv_search_field} };
	
	for my $search_field (@{ $s->{mv_search_field} }) {
		if (exists $prop_avail{$search_field}) {
			$search_string = join (' or ', map {"$search_field=$_"} @pats);
		}
	}
	
	for (@{ $s->{'mv_field_names'} }) {
		unless (exists $fmap{$_}) {
			$fmap{$_} = $_;
		}
		
		$prop = $fmap{$_};
		
		unless (exists $prop_avail{$prop}) {
			return $s->search_error("Unknown property '$prop'");
		}

		unless (@{$prop_avail{$prop}} == $index_num) {
			return $s->search_error("Property '$prop' is missing from some index files");
		}
	}
	
	$search_string = $s->build_search(\@pats);

#::logDebug("Swish search string is $search_string within " . join(', ', @sf));
	
    my $results = $engine->Query( $search_string );
    if ($engine->Error) {
        $s->{matches} = -1;
        return $s->search_error("Can't run swish query: " . $engine->ErrorString);
    }

    # no matches, can return now
    unless ($results->Hits) {
        $s->{matches} = 0;
        return;
    }

    my @out;
	my $date_format = $Vend::Cfg->{Swish}->{date_format} || '%Y-%m-%d %H:%M:%S';
	
    while (my $result = $results->NextResult) {
        my $out_ref = [];
        foreach my $field (@{ $s->{'mv_field_names'} }) {
			my $text = $result->Property( $fmap{$field} );
            if ($field =~ /context/) {
                if ($Vend::Cfg->{'Swish'}{'highlight_context'} and defined $text and $text ne '') {
                    my $index = $result->Property('swishdbfile');

                    my $parsed_query = parse_query( join ' ', $results->ParsedWords( $index ) );
#::logDebug("parsed query: " . Vend::Util::uneval($parsed_query));
        
                    $_swish_highlighters->{$index}->highlight( \$text, $parsed_query->{'swishdefault'}, undef, $result );
                }
                push @$out_ref, $text;
            }
			elsif ($field eq 'mod_date' && $text) {
				push @$out_ref, POSIX::strftime($date_format, localtime($text));
			}
			else {
                push @$out_ref, $text;
            }
        }
        
        push @out, $out_ref;
    }

    {
        my $field_names = join "\t", @{$s->{mv_field_names}};
        $field_names =~ s/^\s+//;
        my @laundry = (qw/mv_search_field mv_range_look mv_return_fields/);
        $s->hash_fields(
                    [ split /\Q$s->{mv_index_delim}/, $field_names ],
                    @laundry,       
        );
    }

    if ($s->{mv_unique}) {
        my %seen;
        @out = grep ! $seen{$_->[0]}++, @out;
    }

    if ($s->{mv_sort_field} and @{$s->{mv_sort_field}}) {
        $s->hash_fields( $s->{mv_field_names}, qw/mv_sort_field/ );
        @out = $s->sort_search_return(\@out);
    }

    $s->{matches} = @out;

    if ($s->{matches} > $s->{mv_matchlimit} and $s->{mv_matchlimit} > 0) {
        $s->save_more(\@out)
            or ::logError("Error saving matches: $!");

        if ($s->{mv_first_match}) {
            splice @out, 0, $s->{mv_first_match};
            $s->{mv_next_pointer} = $s->{mv_first_match} + $s->{mv_matchlimit};
            $s->{mv_next_pointer} = 0
                if $s->{mv_next_pointer} > $s->{matches};
        }
        $#out = $s->{mv_matchlimit} - 1;
    }

    if (! $s->{mv_return_reference}) {
        $s->{mv_results} = \@out;
#::logDebug("returning search: " . Vend::Util::uneval($s));
        return $s;
    }
    elsif ($s->{mv_return_reference} eq 'LIST') {
        my $col = @{ $s->{mv_return_fields} };
        @out = map { join $s->{mv_return_delim}, @$_ } @out;
        $s->{mv_results} = join $s->{mv_record_delim}, @out;
    }
    else {
        my $col = @{ $s->{mv_return_fields} };

        my @names = @{ $s->{mv_field_names} };
        $names[0] eq '0' and $names[0] = 'code';

        my %hash;
        for (@out) {
            my @col = split /$s->{mv_return_delim}/, $_, $col;

            $hash{ $col[0] } = {};
            @{ $hash{$col[0]} } {@names} = @col;
        }
        $s->{mv_results} = \%hash;
    }

#::logDebug("returning search: " . Vend::Util::uneval($s));
    return $s;
}

sub build_search {
	my ($s, $pats) = @_;
	my ($search_string);

	my ($field_count, @ops, @group, @sf);
	
	$field_count =  @{$s->{mv_searchspec}};
	@ops = $s->map_ops($field_count);
	@group = @{$s->{mv_search_group}};
	@sf = @{$s->{mv_search_field}};
	my @su = @{$s->{mv_substring_match}};
	
	my (@specs_by_group, @joiner);
	
	for (my $i = 0; $i < $field_count; $i++) {
		
		# validate $group first
		if (@sf > $i) {
			push (@{$specs_by_group[$group[$i]]}, ["$sf[$i] = $pats->[$i]", $s->{mv_orsearch}->[$i]]);
		} else {
#			if ($su[$i]) {
#				push (@{$specs_by_group[$group[$i]]}, ["*$pats->[$i]", $s->{mv_orsearch}->[$i]]);
#			} else {
				push (@{$specs_by_group[$group[$i]]}, [$pats->[$i], $s->{mv_orsearch}->[$i]]);
#			}
		}
		# record joiner, last one prevails
		$joiner[$group[$i]] = $s->{mv_orsearch}->[$i] ? 'OR' : 'AND';
	}

	my @gall;
	
	for (my $i = 0; $i < @specs_by_group; $i++) {
		my $gsp = $specs_by_group[$i];
		my @gout;
		
		for (my $j = 0; $j < @$gsp; $j++) {
			push (@gout, $gsp->[$j][0]);
			if ($gsp->[$j][1]) {
				push (@gout, 'OR');
			} else {
				push (@gout, 'AND');
			}
		}

		# remove last operator
		pop (@gout);

		$gall[$i] = join (' ', @gout);
	}

	if (@gall > 1) {
		my $i;
		for ($i = 0; $i < @gall - 1; $i++) {
			$search_string .= "($gall[$i]) $joiner[$i] ";
		}
		$search_string .= $gall[$i];
	} else {
		$search_string = $gall[0];
	}

	#::logError ("Search string is: $search_string");
	return $search_string;
}

# Unfortunate hack need for Safe searches
*escape             = \&Vend::Search::escape;
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
*get_scalar         = \&Vend::Search::get_scalar;
*hash_fields        = \&Vend::Search::hash_fields;
*save_specs         = \&Vend::Search::save_specs;
*restore_specs      = \&Vend::Search::restore_specs;
*splice_specs       = \&Vend::Search::splice_specs;
*search_error       = \&Vend::Search::search_error;
*save_more          = \&Vend::Search::save_more;
*sort_search_return = \&Vend::Search::sort_search_return;

1;
__END__
