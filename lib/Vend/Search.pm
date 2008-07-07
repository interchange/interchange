# Vend::Search - Base class for search engines
#
# $Id: Search.pm,v 2.38 2008-07-07 18:15:07 docelic Exp $
#
# Copyright (C) 2002-2008 Interchange Development Group
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

package Vend::Search;

$VERSION = substr(q$Revision: 2.38 $, 10);

use strict;
no warnings qw(uninitialized numeric);

use POSIX qw(LC_CTYPE);

use vars qw($VERSION);

sub new {
	my $class = shift;
	my $s = {@_};
	bless $s, $class;
	return $s;
}

sub get_scalar {
	my $s = shift;
	my @out;
	for (@_) {
		push @out, (ref $s->{$_} ? $s->{$_}[0] : $_[0] || '');
	}
	return @out;
}

sub version {
	$Vend::Search::VERSION;
}

my %maytag = (
	mv_return_fields => sub { 
		my $s = shift;
		my $i;
		while (defined ($i = shift)) {
			next if $s->{mv_return_fields}[$i] =~ /^\d+$/;
			$s->{mv_return_fields}[$i] = 255;
		}
	},
	mv_range_look    => sub { undef shift->{range_look} },
	mv_sort_field    => sub {
		my $s = shift;
		my $i;
		while (defined ($i = shift)) {
#::logDebug("checking sort field $s->{mv_sort_field}[$i]");
			# Assume they know what they are doing
			next if $s->{mv_sort_field}[$i] =~ /^\d+$/;
			if ($s->{mv_sort_field}[$i] =~ s/:([frn]+)$//) {
			  $s->{mv_sort_option}[$i] = $1;
			}
			if(! defined $s->{field_hash}{$s->{mv_sort_field}[$i]})
			{
				splice(@{$s->{mv_sort_field}}, $i, 1);
				splice(@{$s->{mv_sort_option}}, $i, 1);
			}
			else {
				$s->{mv_sort_field}[$i] =
					$s->{field_hash}{$s->{mv_sort_field}[$i]};
			}
		}
	},
	mv_search_field  => sub {
			my $s = shift;
			my $i;
			while (defined ($i = shift)) {
				# Assume they know what they are doing
				next if $s->{mv_search_field}[$i] =~ /^\d+$/;
				next if $s->{mv_search_field}[$i] =~ /[*:]/;
				$s->splice_specs($i);
			}
		},
);

my (@hashable) = (qw/mv_return_fields mv_range_look mv_search_field mv_sort_field/);

sub search_reference {
	my ($s, $ref) = @_;
	my $c = { mv_searchtype => 'ref', label => ref($s), mv_search_file => '__none__' };

	my $ns = $s->{mv_next_search};
	$ns = $::Scratch->{$ns} unless $ns =~ /=/;
	my $params = Vend::Interpolate::escape_scan($ns);
#::logDebug("search_params: $params");
	Vend::Scan::find_search_params($c, $params);

	$c->{mv_return_filtered} = 1;
	$c->{mv_return_fields} = '*';
	$c->{mv_field_names} = $s->{mv_field_names};
	$c->{mv_search_reference} = $ref;
#::logDebug("Ref ready to search: " . ::uneval($c));
	my $o = Vend::Scan::perform_search($c);
	return @{$o->{mv_results} || []};
}

sub hash_fields {
	my ($s, $fn, @laundry) = @_;
	my %fh;
	my $idx = 0;
	for (@$fn) {
		$fh{$_} = $idx++;
	}
	$s->{field_hash} = \%fh;
	my $fa;
	my %wash;
	@laundry = @hashable if ! @laundry;
#::logDebug("washing laundry @laundry");
	foreach $fa (@laundry) {
		next unless defined $s->{$fa};
		my $i = 0;
		for( @{$s->{$fa}} ) {
			if(! defined $fh{$_}) {
				if($_ eq '*') {
					$idx--;
					@{$s->{$fa}} = (0 .. $idx);
					last;
				}
				$wash{$fa} = [] if ! defined $wash{$fa};
				push @{$wash{$fa}}, $i++;
				next;
			}
			$_ = $fh{$_};
			$i++;
		}
	}
	$s->{mv_field_names} = [@$fn] if ! defined $s->{mv_field_names};
	foreach $fa (keys %wash) {
#::logDebug("washing $fa:" . ::uneval($wash{$fa}) );
		$maytag{$fa}->($s, reverse @{$wash{$fa}});
	}
}

sub escape {
    my($s, @text) = @_;
#::logDebug( "unescaped text=" . ::uneval(\@text));
	return @text if ! $s->{mv_all_chars}[0];
	@text = map {quotemeta $_} @text;
#::logDebug( "escaped text=" . ::uneval(\@text));
    return @text;
}

my (@splice) = qw(
	mv_all_chars
	mv_begin_string
	mv_case
	mv_negate
	mv_numeric
	mv_orsearch
	mv_search_group
	mv_search_field
	mv_searchspec
	mv_substring_match
);

sub save_specs {
	my $s = shift;
	return if defined $s->{save_specs};
	return if @{$s->{mv_search_file}} < 2;
	my $ary = [];
	for (@splice) {
#::logDebug("saving $_:" . ::uneval($s->{$_}));
		push @$ary, defined $s->{$_} ? [ @{$s->{$_}} ] : undef;
	}
	$s->{save_specs} = $ary;
	return;
}

sub restore_specs {
	my $s = shift;
	return if ! defined $s->{save_specs};
	my $ary = $s->{save_specs};
	my $i;
	for ($i = 0; $i < @splice; $i++) {
		 my $val = $ary->[$i];
#::logDebug("restoring $splice[$i] from $_:" . ::uneval( $s->{$splice[$i]} ));
		 $s->{$splice[$i]} = $val ? [ @{$val} ] : undef;
#::logDebug("restoring $splice[$i] to   $_:" . ::uneval( $val ));
	}
	return;
}

sub splice_specs {
	my ($s, $i) = @_;
	for (@splice) {
		splice(@{$s->{$_}}, $i, 1);
	}
	return;
}

sub dump_coord {
	my $s = shift;
	my $specs = shift;
	my $msg = shift;
	return 
		sprintf "%s coord=%s specs=%s(%s) fields=%s(%s) op=%s(%s) nu=%s(%s) ne=%s(%s)",
			$msg,
            $s->{mv_coordinate},
			scalar @$specs,
			Vend::Util::uneval($specs),
			scalar @{$s->{mv_search_field}},
			Vend::Util::uneval($s->{mv_search_field}),
			scalar @{$s->{mv_column_op}},
			Vend::Util::uneval($s->{mv_column_op}),
			scalar @{$s->{mv_numeric}},
			Vend::Util::uneval($s->{mv_numeric}),
			scalar @{$s->{mv_negate}},
			Vend::Util::uneval($s->{mv_negate}),
			;
}

sub spec_check {
  my ($s, @specs) = @_;
  my @pats;
  SPEC_CHECK: {
	last SPEC_CHECK if $s->{mv_return_all};
	# Patch supplied by Don Grodecki
	# Now ignores empty search strings if coordinated search
	my $i = 0;
#::logDebug($s->dump_coord(\@specs, 'BEFORE'));

	if ( $s->{mv_force_coordinate} ) {
		# If coordinated search is forced, ensure 
		# @specs == @{$s->{mv_search_field}}:
		if ( $s->{mv_coordinate} ) {
			my $last = $#{$s->{mv_search_field}};
			my $i;
			for ($i = @specs; $i <= $last; $i++) {
				$specs[$i] = $specs[$#specs];
			}
			$#specs = $last;
		}
	}
	else {
		$s->{mv_coordinate} = ''
			unless $s->{mv_coordinate} and @specs == @{$s->{mv_search_field}};
	}

	my $all_chars = $s->{mv_all_chars}[0];

	while ($i < @specs) {
#::logDebug("i=$i specs=$#specs mv_min_string=$s->{mv_min_string}");
		if($#specs and length($specs[$i]) == 0 and $s->{mv_min_string} != 0) { # should add a switch
			if($s->{mv_coordinate}) {
		        splice(@{$s->{mv_search_group}}, $i, 1);
		        splice(@{$s->{mv_search_field}}, $i, 1);
		        splice(@{$s->{mv_column_op}}, $i, 1);
		        splice(@{$s->{mv_begin_string}}, $i, 1);
		        splice(@{$s->{mv_case}}, $i, 1);
		        splice(@{$s->{mv_numeric}}, $i, 1);
		        splice(@{$s->{mv_all_chars}}, $i, 1);
		        splice(@{$s->{mv_substring_match}}, $i, 1);
		        splice(@{$s->{mv_negate}}, $i, 1);
			}
		    splice(@specs, $i, 1);
		}
		else {
			COLOP: {
				last COLOP unless $s->{mv_coordinate};
#::logDebug("i=$i, begin_string=$s->{mv_begin_string}[$i]");
				$s->{mv_all_chars}[$i] = $all_chars
					if ! defined $s->{mv_all_chars}[$i];
				last COLOP if $s->{mv_search_relate} =~ s/\bor\b/or/ig;
				if(	$s->{mv_column_op}[$i] =~ /([=][~]|rm|em)/ ) {
					$specs[$i] = quotemeta $specs[$i]
						if $s->{mv_all_chars}[$i];
					last COLOP if $s->{mv_begin_string}[$i];
					last COLOP if $s->{mv_column_op}[$i] eq 'em';
					$s->{regex_specs} ||= [];
					$specs[$i] =~ /(.*)/;
					push @{$s->{regex_specs}}, $1
				}
				elsif(	$s->{mv_column_op}[$i] =~ /^(==?|eq)$/ ) {
					$s->{eq_specs} = []
						unless $s->{eq_specs};
					$specs[$i] =~ /(.*)/;
					my $spec = $1;
					push @{$s->{eq_specs}}, $spec;
					last COLOP unless $s->{dbref};
					$spec = $s->{dbref}->quote($spec, $s->{mv_search_field}[$i]);
					$spec = $s->{mv_search_field}[$i] . " = $spec";
					push(@{$s->{eq_specs_sql}}, $spec);
				}
			}
			$i++;
		}
	}

#::logDebug("regex_specs=" . ::uneval($s->{regex_specs}));
#::logDebug("eq_specs_sql=" . ::uneval($s->{eq_specs_sql}));

	if ( ! $s->{mv_exact_match} and ! $s->{mv_coordinate}) {
		my $string = join ' ', @specs;
		eval {
			@specs = Text::ParseWords::shellwords( $string );
		};
		if($@ or ! @specs) {
			$string =~ s/['"]/./g;
			$s->{mv_all_chars}[0] = 0;
			@specs = Text::ParseWords::shellwords( $string );
		}
	}

	@specs = $s->escape(@specs) if ! $s->{mv_coordinate};

	if(! scalar @specs or ! $s->{mv_coordinate}) {
		my $passed;
		my $msg;
		for (@specs) {
			$passed = 1;
		    next if length($_) >= $s->{mv_min_string};
			$msg = ::errmsg(q{Search strings must be at least %s characters. You had '%s' as one of your search strings.}, $s->{mv_min_string}, $_);
			undef $passed;
			last;
		}
		$passed = 1 if ! $s->{mv_min_string};
		if(! defined $passed) {
			$msg = ::errmsg(q{Search strings must be at least %s characters. You had no search string specified.}, $s->{mv_min_string}) if ! $msg;
			return $s->search_error($msg);
		}
	}

	# untaint
	for(@specs) {
		/(.*)/s;
		push @pats, $1;
	}
	$s->{mv_searchspec} = \@pats;
#::logDebug($s->dump_coord(\@specs, 'AFTER '));
	return @pats;

  } # last SPEC_CHECK
  return @pats;
}


sub more_matches {
	my($s) = @_;
	$s->{more_in_progress} = 1;

	my $id;
	if($s->{mv_more_permanent}) {
#::logDebug("Permanent more");
		$id = $s->{mv_cache_key};
	}
	else {
		$id = $s->{mv_more_id} || $s->{mv_session_id};
		$id .= ".$s->{mv_cache_key}";
	}
	
	my $file;
	my $obj;
	eval {
		if($Vend::Cfg->{MoreDB}) {
#::logDebug("more_matches: $id from $Vend::Cfg->{SessionDB}");
			eval {
				my $db = Vend::Util::dbref($Vend::Cfg->{SessionDB});
				$obj = Vend::Util::evalr( $db->field($id,'session') );
			};
			$@ and return $s->search_error(
							"Object saved wrong in session DB for search ID %s.",
							$id,
						);
		}
		else {
			if($s->{mv_more_permanent}) {
				$file = Vend::File::get_filename($id, 2, 1, $Vend::Cfg->{PermanentDir});
			}
			else {
				$file = Vend::File::get_filename($id);
			}

#::logDebug("more_matches: $id from $file");
			eval {
				$obj = Vend::Util::eval_file($file);
			};
			$@ and return $s->search_error(
							"Object saved wrong in %s for search ID %s.",
							$file,
							$id,
						);
		}
	};

	for(qw/mv_cache_key mv_matchlimit /) {
		$obj->{$_} = $s->{$_};
	}
	if($obj->{matches} > ($s->{mv_last_pointer} + 1) ) {
		$obj->{mv_next_pointer} = $s->{mv_last_pointer} + 1;
	}
	else {
		$obj->{mv_next_pointer} = 0;
	}
	$obj->{mv_first_match} = $s->{mv_next_pointer};
	$obj->{more_in_progress} = 1;
#::logDebug("object:" . ::uneval($obj));
	return $obj;
}

sub more_alpha {
	my ($s, $out) = @_;
	my ($sfpos, @letters, @compare, $changed, @pos, $sortkey, $last, @alphaspecs, $i, $l);
	my $alphachars = $s->{mv_more_alpha_chars} || 3;

	# determine position of sort field within results
	for ($i = 0; $i < @{$s->{mv_return_fields}}; $i++) {
		last if $s->{mv_return_fields}->[$i] eq $s->{mv_sort_field}->[0];
	}
	$sfpos = $i;
	
	# add dummy record
	@alphaspecs = (['']);
		
	$last = 0;
	for ($i = 0; $i < @$out; $i++) {
		$sortkey = $out->[$i]->[$sfpos];
		@letters = split(m{}, $sortkey, $alphachars + 1);
		pop(@letters);
		$changed = 0;

		for ($l = 0; $l < $alphachars; $l++) {
			if ($letters[$l] ne $compare[$l]) {				
				$changed = 1;
			}
			next unless $changed;
			$pos[$l] = $i;
			$compare[$l] = $letters[$l];
		}

		if ($pos[0] == $i) {
			# add record if first letter has changed
			push (@alphaspecs, [$sortkey, 1, $i]);
			# add last pointer to previous record
			push (@{$alphaspecs[$last++]}, $i - 1);
		} elsif ($alphachars > 1
				 && $i - $alphaspecs[$last]->[2] >= $s->{mv_matchlimit}) {
			# add record if match limit is exceeded and significant
			# letters are different
			for (my $c = 2; $c <= $alphachars; $c++) {
				if (substr($sortkey, 0, $c)
					ne substr($alphaspecs[$last]->[0],0,$c)) {
					push (@alphaspecs, [$sortkey, $c, $pos[$c - 1]]);
					# add last pointer to previous record
					push (@{$alphaspecs[$last++]}, $pos[$c - 1] - 1);
					last;
				}
			}
		}
			
	}
	# add last pointer to last record
	push (@{$alphaspecs[$last]}, $i - 1);
	# remove dummy record
	shift (@alphaspecs);
	$s->{mv_alpha_list} = \@alphaspecs;
}

# Returns a field weeding function based on the search specification.
# Input is the raw line and the delimiter, output is the fields
# specified in the return_field specification
# If we get a third parameter, $makeref, we need to build a reference
sub get_return {
	my($s, $final, $makeref) = @_;
	my ($return_sub);

	if($makeref) {
		# Avoid the hash key lookup, it is a closure
		my $delim = $s->{mv_index_delim};

		# We will pick out the return fields later if sorting
		# This returns
		if( $s->{mv_sort_field} || $s->{mv_next_search}) {
			return ( 
				sub {
					[ split /$delim/o, shift(@_) ]
				},
				1,
			);
		}
		elsif($s->{mv_return_fields}) {
			my @fields = @{$s->{mv_return_fields}};
			$return_sub = sub {
							return [ (split /$delim/o, shift(@_))[@fields] ]
						};
		}
		else {
			$return_sub = sub {
							$_[0] =~ s/$delim.*//s;
							return [ $_[0] ];
					};
		}
	}
	else {
		# We will pick out the return fields later if sorting
		# This returns
		if(! $final and $s->{mv_sort_field} || $s->{mv_next_search}) {
			return ( sub { [ @{ shift(@_) } ] }, 1);
		}

		if(! $s->{mv_return_fields}) {
			$return_sub = sub {
								return [ $_[0]->[0] ];
						};
		}
		else {
			my @fields = @{$s->{mv_return_fields}};
			$return_sub = sub {
				my $ref = [ @{$_[0]}[@fields] ];
				return $ref;
			};
		}
	}
	return $return_sub;
}

my $TextQuery;

BEGIN {
	eval {
		require Text::Query;
		import Text::Query;
		$TextQuery = 1;
	};
}

sub create_text_query {
	my ($s, $i, $string, $op) = @_;

	if(! $TextQuery) {
		die ::errmsg("No Text::Query module installed, cannot use op=%s", $op);
	}

	$s ||= {};
	$op ||= 'sq';
	my $q;
#::logDebug("query creation called, op=$op");

	my $cs	= ref ($s->{mv_case})
			? $s->{mv_case}[$i]
			: $s->{mv_case};
	my $ac	= ref ($s->{mv_all_chars})
			? $s->{mv_all_chars}[$i]
			: $s->{mv_all_chars};
	my $su	= ref ($s->{mv_substring_match})
			? $s->{mv_substring_match}[$i]
			: $s->{mv_substring_match};

	$string =~ s/(\w)'(s)\b/$1$2/g;
	$string =~ s/(\w)'(\w+)/$1 and $2/g;
	$string =~ s/'//g;
#::logDebug("query creation called, op=$op cs=$cs ac=$ac");
	if($op eq 'aq') {
		$q = new Text::Query($string,
								-parse => 'Text::Query::ParseAdvanced',
                               -solve => 'Text::Query::SolveAdvancedString',
                               -build => 'Text::Query::BuildAdvancedString',
				);
	}
	else {
		$q = new Text::Query($string,
								-parse => 'Text::Query::ParseSimple',
                               -solve => 'Text::Query::SolveSimpleString',
                               -build => 'Text::Query::BuildSimpleString',
				);
	}
	$q->prepare($string,
					-litspace => $s->{mv_exact_match},
					-case => $cs,
					-regexp => ! $ac,
					-whole => ! $su,
				);
#::logDebug("query object called, is: " . ::uneval($q));
	return sub {
		my $str = shift;
#::logDebug("query routine called string=$str");
		$q->matchscalar($str);
    };
}

my %numopmap  = (
				'!=' => [' != '],
				'!~' => [' !~ m{', '}'],
				'<'  => [' < '],
				'<=' => [' <= '],
				'<>' => [' != '],
				'='  => [' == '],
				'==' => [' == '],
				'=~' => [' =~ m{', '}'],
				'>'  => [' > '],
				'>=' => [' >= '],
				'em' => [' =~ m{^', '$}'],
				'eq' => [' == '],
				'ge' => [' >= '],
				'gt' => [' > '],
				'le' => [' <= '],
				'lt' => [' < '],
				'ne' => [' != '],
				'rm' => [' =~ m{', '}'],
				'rn' => [' !~ m{', '}'],
				'like' => [' =~ m{LIKE', '}i'],
				'LIKE' => [' =~ m{LIKE', '}i'],
);
               

my %stropmap  = (
				'!=' => [' ne q{', '}'],
				'!~' => [' !~ m{', '}'],
				'<'  => [' lt q{', '}'],
				'>'  => [' gt q{', '}'],
				'<=' => [' le q{', '}'],
				'<>' => [' ne q{', '}'],
				'='  => [' eq q{', '}'],
				'==' => [' eq q{', '}'],
				'=~' => [' =~ m{', '}'],
				'>=' => [' ge q{', '}'],
				'eq' => [' eq q{', '}'],
				'ge' => [' ge q{', '}'],
				'gt' => [' gt q{', '}'],
				'le' => [' le q{', '}'],
				'lt' => [' lt q{', '}'],
				'ne' => [' ne q{', '}'],
				'em' => [' =~ m{^', '$}i'],
				'rm' => [' =~ m{', '}i'],
				'rn' => [' !~ m{', '}i'],
				'aq' => [\&create_text_query, 'aq'],
				'tq' => [\&create_text_query, 'tq'],
				'like' => [' =~ m{LIKE', '}i'],
				'LIKE' => [' =~ m{LIKE', '}i'],
);
               

sub map_ops {
	my($s, $count) = @_;
	my $c = $s->{mv_column_op} or return ();
	my $i;
	my $op;
	for($i = 0; $i < $count; $i++) {
		next unless $c->[$i];
		$c->[$i] =~ tr/ \t//;
		my $o = $c->[$i];
		$c->[$i] = $s->{mv_numeric}[$i]
				? $numopmap{$o}
				: $stropmap{$o};
		if (ref($c->[$i]) eq 'ARRAY') {
			$c->[$i] = [ @{$c->[$i]} ];
		}
		elsif (!$c->[$i]) {
			my $r;
			$c->[$i] = [$r, $o], next
				if  $r = Vend::Util::codedef_routine('SearchOp',$o);
		}
		if (!$c->[$i]) {
		    $s->search_error("Unknown mv_column_op (%s)",$o);
		}
	}
	@{$s->{mv_column_op}};
}

sub code_join {
	my ($coderef, $num) = @_;
	return $num unless defined $coderef->[$num];
	my $out = ' ( ';
	$out .= join("", @{$coderef->[$num]});
	$out .= ' ) ';
}

sub create_field_hash {
	my $s = shift;
	my $fn = $s->{mv_field_names}
		or return;
	my $fh = {};
	my $idx = 0;
	for(@$fn) {
		$fh->{$idx} = $idx;
		$fh->{$_} = $idx++;
	}
	return $fh;
}

# Returns a screening function based on the search specification.
# The $f is a reference to previously created search function which does
# a pattern match on the line.
# Makeref says we have to build a reference from the supplied text line
sub get_limit {
	my($s, $f, $makeref) = @_;
	my $limit_sub;
	my $range_code = '';
	my $rd = $s->{mv_record_delim} || '\n';
	my $code;
	if($makeref) {
		$code       = "sub {\nmy \$line = [split /$s->{mv_index_delim}/, shift(\@_)];\n";
	}
	else {
		$code       = "sub {\nmy \$line = shift;\n";
	}
	$code .= "my \@fields = \@\$line;\n";

	my $have_hf;
	if ($s->{mv_hide_field}) {
		$s->{mv_field_hash} = create_field_hash($s) 
			unless $s->{mv_field_hash};
		my $hf = $s->{mv_field_hash}{$s->{mv_hide_field}};
		if (defined $hf) {
			$code .= "return if \$fields[$hf];\n";
			$have_hf = 1;
		}
		else {
		 	::logError("Ignoring unknown mv_hide_field specification: $s->{mv_hide_field}");
			delete $s->{mv_hide_field};
		}
	}
		
	my $join_key;
	$join_key = defined $s->{mv_return_fields} ? $s->{mv_return_fields}[0] : 0;
	$join_key = 0 if $join_key eq '*';
	my $sub;
	my $wild_card;
	my @join_fields;
	my $joiner;
	my $ender;
	if($s->{mv_orsearch}[0]) {
		$joiner = '1 if';
		$ender = 'return undef;';
	}
	else {
		$joiner = 'undef unless';
		$ender = 'return 1;';
	}
	#my $joiner = $s->{mv_orsearch}[0] ? '1 if' : 'undef unless';
	#my $ender = $s->{mv_orsearch}[0] ? 'return undef;' : 'return 1;';
	# Here we join data if we are passed a non-numeric field. The array
	# index comes from the end to avoid counting the fields.
	my $k = 0;
	for(@{$s->{mv_search_field}}) {
#::logDebug("join_field $_");
		next unless /[\*:]+/;
		unshift(@join_fields, $_);
		$_ = --$k;
#::logDebug("join_field $_");
	}
	# Add the code to get the join data if it is there
	if(@join_fields) {
		$s->{mv_field_hash} = create_field_hash($s) 
			unless $s->{mv_field_hash};
		$code .= <<EOF;
my \$key = \$line->[$join_key];
EOF
		for(@join_fields) {
			my ($table, $col) = split /:+/, $_, 2;
			if($table) {
				$wild_card = 0;
				$code .= <<EOF;
push \@fields, Vend::Data::database_field('$table', \$key, '$col');
EOF
			}
			elsif ($col =~ tr/:/,/) {
				$col =~ tr/ \t//d;
				my @col = map { $s->{mv_field_hash}{$_} } split /,/, $col;
				@col = grep defined $_, @col;
				$col = join ",", @col;
				next unless $col;
				$wild_card = 1;
				$col =~ s/[^\d,.]//g;
			$code .= <<EOF;
my \$addl = join " ", \@fields[$col];
push \@fields, \$addl;
EOF
			}
			else {
				$wild_card = 1;
				$code .= <<EOF;
my \$addl = join " ", \@fields;
push \@fields, \$addl;
EOF
			}
		}
	}

	my $fields = join ",", @{$s->{mv_search_field}};

	if ( ref $s->{mv_range_look} )  {
		$range_code = <<EOF;
return $joiner \$s->range_check(\$line);
EOF
	}
	if ( $s->{mv_coordinate} ) {
		 undef $f;
		 $ender = '';
		 if($range_code) {
		 	::logError("Range look not compatible with mv_coordinate. Disabling.");
		 }
		 my $callchar = $fields =~ /,/ ? '@' : '$';
		 $code .= <<EOF;
	\@fields = ${callchar}fields[$fields];
EOF
		$code .= <<EOF if $Global::DebugFile and $CGI::values{debug};
   ::logDebug("fields=" . join "|", \@fields);
EOF

		my @specs;
		# For a limiting function, can't if orsearch

		my $field_count = @specs = @{$s->{mv_searchspec}};

		my @cases = @{$s->{mv_case}};
		my @bounds = @{$s->{mv_substring_match}};
		my @ops;
		@ops = $s->map_ops($field_count);
		my @negates =  map { $_ ? 'not ' : ''} @{$s->{mv_negate}};
		my @begin = 	@{$s->{mv_begin_string}};
		my @group = 	@{$s->{mv_search_group}};
#::logDebug("Ops=" .  ::uneval(\@ops));
#::logDebug("Begin=" . join ",", @begin);
#::logDebug("Group=" . join ",", @group);
#::logDebug("Ors=" . join ",", @{$s->{mv_orsearch}});
#::logDebug("Field count=$field_count");
		my @code;
		my $candidate = '';
		my ($i, $start, $term, $like);
		for($i = 0; $i < $field_count; $i++) {
			undef $candidate, undef $f 
				if $begin[$i] or $s->{mv_orsearch}[$i];
			my $subfrag;
			if(! $ops[$i]) {
				$start = '=~ m{';
				$start .=  '^' if $begin[$i];
				if($bounds[$i]) {
					$term = '}';
				}
				else {
					$term = '\b}';
					$start .= '\b' unless $begin[$i];
				}
				$term .= 'i' unless $cases[$i];
				$candidate = 1 if defined $candidate and ! $begin[$i];
			}
			elsif(ref($ops[$i][0]) eq 'CODE') {
					undef $f; undef $candidate;
					my $o = shift(@{$ops[$i]});
					$s->{search_routines} ||= [];
					$s->{search_routines}[$i] = $o->($s, $i, $specs[$i], @{$ops[$i]});
					$subfrag = qq{ \$s->{search_routines}[$i]->(\$fields[$i])};
			}
			else {
				$ops[$i][0] =~ s/m\{$/m{^/ if $begin[$i];
				! $bounds[$i] 
					and $ops[$i][0] =~ s/=~\s+m\{$/=~ m{\\b/
					and $ops[$i][1] = '\b' . $ops[$i][1];
				$start = $ops[$i][0];
#::logDebug("Op now=" .  ::uneval($ops[$i]));
				($term  = $ops[$i][1] || '')
					and $cases[$i]
					and $term =~ s/i$//
					and defined $candidate
					and $candidate = 1;
#::logDebug("Candidate now=$candidate");
			}
			
			if ($start =~ s/LIKE$//) {
				$specs[$i] =~ s/^(%)?([^%]*)(%)?$/$2/;
				# Substitute if only one present
				# test $1
				undef $like;
				if($1 ne $3) {
					$specs[$i] = $1
								? $specs[$i] . '$'
								: '^' . $specs[$i];
					$like = 1;
				}
			}
			if ($i >= $k + $field_count) {
			    undef $candidate if ! $wild_card;
#::logDebug(triggered wild_card: $wild_card");
			    $wild_card = 0;
			}
			if(defined $candidate and ! $like) {
			   undef $f if $candidate;
				$f = "sub { return 1 if $negates[$i]\$_ $start$specs[$i]$term ; return 0}"
			   	if ! defined $f and $start =~ m'=~';
			   undef $candidate if $candidate;
			}
			my $grp = $group[$i] || 0;
			my $frag;
			if($subfrag) {
			   $frag = $subfrag;
			}
			else {
			    $frag = qq{$negates[$i]\$fields[$i] $start$specs[$i]$term};
			}
#::logDebug("Code fragment is q!$frag!");
			 unless ($code[$grp]) {
				 $code[$grp] = [ $frag ];
			 }
			 else {
			 	 my $join = $s->{mv_orsearch}[$i] ? ' or ' : ' and ';
				 push @{$code[$grp]}, "$join$frag";
			 }
		}
#::logDebug("coderef=" . ::uneval_it(\@code));

		undef $f if $s->{mv_search_relate} =~ s/\bor\b/or/ig;
		undef $f unless $s->{regex_specs} or $s->{eq_specs};
		DOLIMIT: {
#::logDebug(::uneval_it({%$s}));
#::logDebug("do_limit.");
			last DOLIMIT if $f;
#::logDebug("do_limit past f.");
			last DOLIMIT if $s->{mv_small_data};
			last DOLIMIT if $s->{eq_specs_sql};
			last DOLIMIT if (grep $_, @{$s->{mv_orsearch}});
			last DOLIMIT if defined $s->{mv_search_relate}
							&& $s->{mv_search_relate} =~ s/\bor\b/or/i;
			my @pats;
#::logDebug("regex_specs=" . ::uneval($s->{regex_specs}));
			for(@{$s->{regex_specs}}) {
				push @pats, $_;
			}
			for(@{$s->{eq_specs}}) {
				push @pats, quotemeta $_;
			}
			if(defined $pats[1]) {
				@pats = sort { length($b) <=> length($a) } @pats;
			}
			elsif(! defined $pats[0]) {
				last DOLIMIT;
			}
			eval {
#::logDebug("filter function going and...");
				$f = $s->create_search_and( 0, 1, 0, @pats);
			};
			undef $f if $@;
		}
		::logDebug("filter function code is: $f")
			if $Global::DebugFile and $CGI::values{debug};
		use locale;
		$f = eval $f if $f and ! ref $f;
		die($@) if $@;
		my $relate;
		if(scalar @code > 1) {
			$relate = 'return ( ';
			if ($s->{mv_search_relate}) {
				$relate .= $s->{mv_search_relate};
				$relate =~ s/([0-9]+)/code_join(\@code,$1)/eg;
			}
			else {
				$relate .= '(';
				$relate .= join ') and (', (map { join "", @$_ } @code);
				$relate .= ')';
			}
			$relate .= ' );';
		}
		elsif (! ref $code[0] ) {
			die("bad limit creation code in coordinated search, probably search group without search specification.");
		}
		else {
			$relate = "return ( " . join("", @{$code[0]}) . " );";
		}
		$code .= $relate;
		$code .= "\n}\n";
		::logDebug("coordinate search code is:\n$code")
			if $Global::DebugFile and $CGI::values{debug};
	}
	elsif ( @{$s->{mv_search_field}} )  {
		if(! $s->{mv_begin_string}[0]) {
#::logDebug("Not begin, sub=$f");
			$sub = $f;
		}
		elsif (! $s->{mv_orsearch}[0] ) {
#::logDebug("Begin, sub creating and");
			$sub = create_search_and(
						$s->{mv_index_delim},		# Passing non-reference first
						$s->{mv_case}[0],	# means beginning of string search
						$s->{mv_substring_match}[0],
						$s->{mv_negate}[0],
						@{$s->{mv_searchspec}});
		}
		else {
#::logDebug("Begin, sub creating or");
			$sub = create_search_or(
						$s->{mv_index_delim},		# Passing non-reference first
						$s->{mv_case}[0],	# means beginning of string search
						$s->{mv_substring_match}[0],
						$s->{mv_negate}[0],
						@{$s->{mv_searchspec}});
		}
		 $code .= $range_code;
		 $code .= <<EOF;
	local(\$_) = join q{$s->{mv_index_delim}}, \@fields[$fields];
	return(1) if &\$sub();
	return undef;
}
EOF
	} 
	# In case range_look only
	elsif ($s->{mv_range_look})  {
		$code .= <<EOF;
	$range_code
	$ender
}
EOF
	}
	elsif ($have_hf) {
		$code .= <<'EOF';
return 1;
}
EOF
	}
	# If there is to be no limit_sub
	else {
		die("no limit and no search") unless defined $f;
		return;
	}
#::logDebug("code is $code");
	use locale;
	if ($::Scratch->{mv_locale}) {
	    POSIX::setlocale(LC_CTYPE, $::Scratch->{mv_locale});
	}
	$limit_sub = eval $code;
	die "Bad code: $@" if $@;
	return ($limit_sub, $f);
}

# Check to see if the fields specified in the range_look array
# meet the criteria
sub range_check {
	my($s,$line) = @_;
	my @fields = @$line[@{$s->{mv_range_look}}];
	my $i = 0;
	for(@fields) {
		no strict 'refs';
		unless(defined $s->{mv_range_alpha}->[$i] and $s->{mv_range_alpha}->[$i]) {
			return 0 unless $_ >= $s->{mv_range_min}->[$i];
			return 0 unless
				(! $s->{mv_range_max}->[$i] or $_ <= $s->{mv_range_max}->[$i]);
		}
		elsif (! $s->{mv_case}) {
			return 0 unless "\L$_" ge (lc $s->{mv_range_min}->[$i]);
			return 0 unless "\L$_" le (lc $s->{mv_range_max}->[$i]);
		}
		else {
			return 0 unless $_ ge $s->{mv_range_min}->[$i];
			return 0 unless $_ le $s->{mv_range_max}->[$i];
		}
		$i++;
	}
	1;
}

sub create_search_and {

	my ($begin, $case, $bound, $negate);

	$begin = shift(@_);
	$begin = ref $begin ? '' : "(?:^|\Q$begin\E)";
	$case = shift(@_) ? '' : 'i';
	$bound = shift(@_) ? '' : '\b';
	$negate = shift(@_) ? '$_ !~ ' : '';

	# We check for no patterns earlier, so we just want true for
	# empty search string
	#die "create_search_and: create_search_and case_sens sub_match patterns" 
	return sub{1}
		unless @_;
	my $pat;

    my $code = <<EOCODE;
sub {
EOCODE

    $code .= <<EOCODE if @_ > 5;
    study;
EOCODE

	my $i = 0;
    for $pat (@_) {
		$pat =~ s/(.*)/$bound$1$bound/
			if $bound;
		$pat =~ s/^(?:\\b)?/$begin/ if $begin;
		$code .= <<EOCODE;
    return 0 unless $negate m{$pat}$case;
EOCODE
		undef $begin;
    } 

    $code .= "\treturn 1;\n}";
#::logDebug("search_and: $code");

	use locale;
    my $func = eval $code;
    die "bad pattern: $@" if $@;

    return $func;
} 

sub create_search_or {
	my ($begin, $case, $bound, $negate);

	$begin = shift(@_);
	$begin = ref $begin ? '' : "(?:^|\Q$begin\E)";

	$case  = shift(@_) ? '' : 'i';
	$bound = shift(@_) ? '' : '\b';
	$negate = shift(@_) ? '$_ !~ ' : '';

	# We check for no patterns earlier, so we just want true for
	# empty search string
	#die "create_search_or: create_search_or case_sens sub_match patterns" 
	return sub{1} unless @_;
	my $pat;

    my $code = <<EOCODE;
sub {
EOCODE

    $code .= <<EOCODE if @_ > 5;
    study;
EOCODE

    for $pat (@_) {
		$pat =~ s/(.*)/$bound$1$bound/
			if $bound;
		$pat =~ s/^(?:\\b)?/$begin/ if $begin;
		$code .= <<EOCODE;
    return 1 if $negate m{$pat}$case;
EOCODE
		undef $begin;
    } 

    $code .= "\treturn 0;\n}\n";

#::logDebug("search_or: $code");

	use locale;
    my $func = eval $code;
    die "bad pattern: $@" if $@;

    return $func;
} 

# Returns an unevaled string with saved 
# global parameters, for putting at beginning
# of more file or hash.
sub save_context {
	my ($s,@save) = @_;
	my $return = {};
	for (@save) {
		$return->{$_} = $s->{$_};
	}
	Vend::Util::uneval_fast($return);
}

sub dump_options {
	my $s = shift;
	eval {require Data::Dumper};
	if(!$@) {
		$Data::Dumper::Indent = 3;
		$Data::Dumper::Terse = 1;
	}
	return Vend::Util::uneval($s);
}

sub search_error {
	my ($s, $msg, @args) = @_;
	$s->{mv_search_error} = [] if ! $s->{mv_search_error};
	$msg = ::errmsg($msg, @args);
	push @{$s->{mv_search_error}}, $msg;
	$s->{matches} = -1;
	::logError ("search error: %s", $msg);
	return undef;
}

sub save_more {
	my($s, $out) = @_;
	return 1 if $s->{mv_no_more};
	return if $MVSAFE::Safe;
	my $file;
	delete $s->{dbref} if defined $s->{dbref};

	my $id;
	my $storedir;

	unless($s->{mv_more_permanent}) {
		$id = $s->{mv_more_id} || $Vend::SessionID;
		$id .= ".$s->{mv_cache_key}";
	}
	else {
		$id = $s->{mv_cache_key};
		$storedir = $Vend::Cfg->{PermanentDir};
	}

	if ($s->{matches} > $s->{mv_matchlimit} and $s->{mv_matchlimit} > 0) {
		$s->{overflow} = 1;
		$s->{mv_next_pointer} = $s->{mv_matchlimit};
	}
	if ($s->{mv_more_alpha}) {
		unless ($s->{mv_sort_field} and @{$s->{mv_sort_field}}) {
			return $s->search_error("mv_sort_field required for mv_more_alpha");
		}
		unless ($s->{mv_return_fields}
				and grep {$_ eq $s->{mv_sort_field}->[0]} @{$s->{mv_return_fields}}) {
					return $s->search_error("mv_sort_field missing in mv_return_fields (required for mv_more_alpha)");
		}
		more_alpha($s,$out);
	}
	
	my $new = { %$s };
	delete $new->{search_routines};
	$new->{mv_results} = $out;

	if($Vend::Cfg->{MoreDB}) {
#::logDebug("save_more: $id to Session DB.");
#::logDebug("save_more:object:" . ::uneval($new));
		my $db = Vend::Util::dbref($Vend::Cfg->{SessionDB});
		$db->set_field($id, 'session', Vend::Util::uneval_fast($new));
	}
	else {
#::logDebug("save_more: $id to $file.");
#::logDebug("save_more:object:" . ::uneval($new));
		if($storedir) {
			$file = Vend::File::get_filename($id,2,1,$storedir); 
		}
		else {
			$file = Vend::File::get_filename($id); 
		}

		eval {
			Vend::Util::uneval_file($new, $file);
		};
	}
	$@ and return $s->search_error("failed to store more matches");
	return 1;
}

my (@Opts);
my (@Flds);

use vars qw/ %Sort_field /;
%Sort_field = (

	none	=> sub { $_[0] cmp $_[1]			},
	f	=> sub { (lc $_[0]) cmp (lc $_[1])	},
	fr	=> sub { (lc $_[1]) cmp (lc $_[0])	},
	n	=> sub { $_[0] <=> $_[1]			},
	nr	=> sub { $_[1] <=> $_[0]			},
	r	=> sub { $_[1] cmp $_[0]			},
	rf	=> sub { (lc $_[1]) cmp (lc $_[0])	},
	rn	=> sub { $_[1] <=> $_[0]			},
);


sub sort_search_return {
    my ($s, $target) = @_;

	@Flds	= @{$s->{mv_sort_field} || []};
	for(@Flds) {
		next if /^\d+$/;
		$_ = $s->{field_hash}{$_}
			 if defined $s->{field_hash}{$_};
		$_ = $s->{mv_field_hash}{$_} || 0;
	}

	return $target unless @Flds;

	@Opts	= @{$s->{mv_sort_option}};

my %Sorter = (

	none	=> sub { $_[0] cmp $_[1]			},
	f	=> sub { (lc $_[0]) cmp (lc $_[1])	},
	fr	=> sub { (lc $_[1]) cmp (lc $_[0])	},
	n	=> sub { $_[0] <=> $_[1]			},
	nr	=> sub { $_[1] <=> $_[0]			},
	r	=> sub { $_[1] cmp $_[0]			},
	rf	=> sub { (lc $_[1]) cmp (lc $_[0])	},
	rn	=> sub { $_[1] <=> $_[0]			},
);

	my $i;
	my $max = 0;
	for($i = 0; $i < @Flds; $i++) {
		$max = $Flds[$i] if $Flds[$i] > $max;
		$Opts[$i] = 'none', next unless $Opts[$i];
		$Opts[$i] = lc $Opts[$i];
		$Opts[$i] = 'none' unless defined $Sort_field{$Opts[$i]};
	}
#::logDebug("sort_search_return: flds='@Flds' opts='@Opts'");

	$max += 2;
	my $f_string = join ",", @Flds;
	my $delim = quotemeta $s->{mv_index_delim};
	my $code = <<EOF;
sub {
	my \@a = \@{\$a}[$f_string];
	my \@b = \@{\$b}[$f_string];
	my \$r;
EOF
#::logDebug("No define of Sort_field") if ! defined $Sort_field{'none'};

	if($MVSAFE::Safe) {
		for($i = 0; $i < @Flds; $i++) {
			$code .= <<EOF;
	\$r = &{\$Sorter{'$Opts[$i]'}}(\$a[$i], \$b[$i]) and return \$r;
EOF
		}
	}
	else {
		for($i = 0; $i < @Flds; $i++) {
			$code .= <<EOF;
	\$r = &{\$Vend::Search::Sort_field{'$Opts[$i]'}}(\$a[$i], \$b[$i]) and return \$r;
EOF
		}
	}

	$code .= "return 0\n}\n";

	my $routine;
	$routine = eval $code;
	die "Bad sort routine:\n$code\n$@" if ! $routine or $@;
eval {

	use locale;
	if($::Scratch->{mv_locale}) {
		POSIX::setlocale(POSIX::LC_COLLATE(),
			$::Scratch->{mv_locale});
	}

};
#::logDebug("Routine is $routine:\n$code");

	# Prime sort routine
	use locale;
	local($^W);

	@$target = sort { &$routine } @$target;
#::logDebug("target is $target: " . Vend::Util::uneval_it($target));

}

1;

__END__
