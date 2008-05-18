# Vend::SQL_Parser - Interchange SQL parser class
#
# $Id: SQL_Parser.pm,v 2.13 2007-01-30 11:29:51 racke Exp $
#
# Copyright (C) 2003-2007 Interchange Development Group
#
# Based on HTML::Parser
# Copyright 1996 Gisle Aas. All rights reserved.

=head1 NAME

Vend::SQL_Parser - Interchange SQL parser class

=head1 DESCRIPTION

C<Vend::SQL_Parser> will tokenize a SQL query so that it can
be evaluated for an Interchange search spec.

=head1 COPYRIGHT

Copyright 2003-2007 Interchange Development Group
Original SQL::Statement module copyright 1998 Jochen Wiedman.

This library is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

=head1 AUTHORS

Vend::SQL_Parser - Mike Heins <mike@perusion.net>

=cut

package Vend::SQL_Parser;

use strict;

use Vend::Util;
use Text::ParseWords;
use vars qw($VERSION);
no warnings qw(uninitialized numeric);
$VERSION = substr(q$Revision: 2.13 $, 10);

sub new {
	my $class = shift;
	my $statement = shift;
	my $opt = shift;

	my $self = bless { log => 'error' }, $class;

	if($opt) {
		if($opt->{oracle_compatible}) {
			$self->{regex_percent} = '.+';
		}

		for(qw/
					tolerant_like
					case_sensitive
					full_regex
				/)
		{
			next unless defined $opt->{$_};
#::logDebug("$_ defined");
			$self->{$_} = $opt->{$_};
		}
	}

	$statement =~ s/^\s+//;
	$statement =~ s/\s+$//;
	$self->{complete_statement} = $statement;

	$statement =~ s/^(\w+)\s+//
		or die ::errmsg("improper SQL statement: %s", $statement);
	$self->{command} = uc $1;

	if($statement =~ s/\s+limit\s+(\d+(?:\s*,\s*(\d+))?)\s*$//i) {
		$self->{limit_by} = $1;
	}

	if($statement =~ s/\s+order\s+by\s+([^=']+)\s*$//is) {
		$self->{order_by} = $1;
	}

	if($statement =~ s/\s+group\s+by\s+([^=']+)\s*$//is) {
		$self->{group_by} = $1;
	}

	my @things = Text::ParseWords::quotewords('\s+', 1, $statement);

	my @base;
	my @where;
	my $wfound;

	for(@things) {
		if(! $wfound) {
			if(lc($_) eq 'where') {
				$wfound++;
			}
			else {
				push @base, $_;
			}
		}
		else {
			push @where, $_;
		}
	}

	$self->{base_statement} = join " ", @base;
	$self->{where_statement} = join " ", @where;

	return $self;
}

sub errdie {
	my $self = shift;
	my $sub;
	if($self->{log} eq 'debug')     { $sub = \&Vend::Util::logDebug;  }
	elsif($self->{log} eq 'global') { $sub = \&Vend::Util::logGlobal; }
	else                            { $sub = \&Vend::Util::logError;  }

	my $tpl = shift;
	$tpl = "%s: $tpl";
	my $msg = ::errmsg(
				$tpl,
				__PACKAGE__,
				@_,
				);
	$sub->($msg);
	return $msg;
}

sub command {
	return shift->{command};
}

my @stopphrase = (
	'where',
	'order by',
	'group by',
	'having',
	'limit',
);

for(@stopphrase) {
	s/\s+/\\s+/g;
}

my $stopregex = join "|", @stopphrase;

sub tables {
	my $s = shift;
	return @{$s->{tables}} if $s->{tables};
	my @try;
	my @tab;

	my $st = $s->{base_statement};

	if($s->{command} eq 'INSERT') {
		$st =~ s/^\s*into\s+([\w\s,]+)//i;
		my $tab = $1;
		$tab =~ s/\s+$//;
		if($tab =~ s/\s+(values)$//i) {
			$st = "values $st";
		}
		push @try, grep /\S/, split /\s*,\s*/, $tab;
	}
	elsif($s->{command} eq 'SELECT') {
		$st =~ s/(.*?)\s+from\s+//is;
		$s->{raw_columns} = $1;
		my @t = Text::ParseWords::quotewords('\s*,\s*', 0, $st);
		my $last;
		for (@t) {
			$last++ if s/\s+$stopregex\s+.*//is;
			push @try, $_;
			last if $last;
		}
	}
	elsif ($s->{command} eq 'UPDATE') {
		$st =~ s/(\w+(?:\s*,\s*\w+)*)\s+set\s+//is;
		push @try, grep /\S/, split /\s*,\s*/, $1;
	}
	elsif ($s->{command} eq 'DELETE') {
		$st =~ s/^\s*from\s+//is
			or die ::errmsg("Bad syntax: %s", $s->{complete_statement});
		push @try, grep /\S/, split /\s*,\s*/, $st;
	}

	$s->{base_statement} = $st;
	
	my $found;

	for(@try) {
		$found = Vend::SQL_Parser::Table->new( name => $_ );
		push @tab, $found;
	}

	return $s->errdie("No tables found in: %s", $s->{complete_statement})
		unless $found;;

	$s->{tables} = \@tab;
	return @tab;
}

sub limit {
	my $s = shift;
	return $s->{limit} if $s->{limit};

	my $st = $s->{limit_by}
		or return undef;

	$s->{limit} = Vend::SQL_Parser::Limit->new( raw => $st );
}

sub order {
	my $s = shift;
	return @{$s->{order}} if $s->{order};
	my @col;

	my $st = $s->{order_by}
		or do {
			$s->{order} = [];
			return ();
		};

	my $found;

	my @try = split /\s*,\s*/, $st;

	for(@try) {
		$found = Vend::SQL_Parser::Order->new( raw => $_ );
		push @col, $found;
	}

	return $s->errdie("No ORDER BY columns found in: %s", $s->{complete_statement})
		unless $found;;

	$s->{order} = \@col;

	return @col;
}

## BEGIN

my %valid_op  = (
				'<'       => 'lt',
				'<='      => 'le',
				'<>'      => 'ne',
				'='       => 'eq',
				'>'       => 'gt',
				'>='      => 'ge',
				'like'    => 1,
				'in'      => 1,
				'is'      => 'eq',
				'between' => 1,
);

my %not_op  = (
				'<'       => 'ge',
				'<='      => 'gt',
				'<>'      => 'eq',
				'='       => 'ne',
				'>'       => 'le',
				'>='      => 'lt',
);

sub find_param_or_col {
	my $s = shift;
	my $raw = shift;
	my $rhs = shift;

	my $type;
	my $val;
	if($raw =~ /^'(.*)',?$/s) {
		$val = $1;
		$type = 'string';
	}
	elsif($raw =~ /^-?\d+\.?\d*$/) {
		$val = $raw;
		$type = 'number';
	}
	elsif($raw =~ /^(\w+)->(\w+)/) {
		my $space = $1;
		my $sel = $2;
		if($space =~ /^v/) {
			$val = $::Values->{$sel};
		}
		elsif ($space =~ /^s/i) {
			$val = $::Scratch->{$sel};
		}
		elsif ($space =~ /^c/i) {
			$val = $CGI::values{$sel};
		}

		if($val =~ /^-?\d+\.?\d*$/) {
			$type = 'number';
		}
		elsif($rhs) {
			$type = 'string';
		}
		else {
			$type = 'reference';
			$val = lc $val unless $s->{verbatim_fields};
		}
	}
	else {
		$val = $raw;
		$val = lc $val unless $s->{verbatim_fields};
		$type = 'reference';
	}
	return($val, $type);
}

sub where {
	my $s = shift;
#::logDebug("Call where!!");
	return @{$s->{where}} if $s->{where};
	my @try;
	my @col;

	my $st = $s->{where_statement}
		or do {
			$s->{where} = [];
			return ();
		};

	my $found;

	my @things = Text::ParseWords::quotewords('\s+', 1, $st);

#use Data::Dumper;
#$Data::Dumper::Terse = 1;

#::logDebug("things=" . Dumper(\@things));

	my $statement = 0;
	my $extra_statement = 0;
	my @clauses;
	my @stack;
	my $lhs;
	my $op;
	my $rhs;
	my $rhs_type;
	my $rhs_done;
	my $rhs_almost_done;
	my $close;
	my $number;
	my $neg;
	my @out;
	
	my $c;

	while(defined ($_ = shift(@things)) ) {

		if( s/^(\()// ) {
			if($lhs) {
				die "syntax error: paren where op expected"
					unless $op;
				$rhs = [];
			}
			else {
#::logDebug("found left paren");
				push @out, '(';
			}
		}
		if( s/(\))$// ) {
			if(ref($rhs) eq 'ARRAY') {
				$rhs_almost_done = 1;
			}
			elsif($lhs) {
#::logDebug("found right paren");
				$close = ')';
			}
			else {
#::logDebug("found right paren");
				push @out, ')';
			}
		}

		if(s/^(and)$//i) {
			if($lhs) {
				die "syntax error: conditional where op expected"
					unless $op;
			}
			else {
#::logDebug("found and");
				push @out, 'and';
			}
		}
		elsif(s/^(or)$//i) {
			if($lhs) {
				die "syntax error: conditional where op expected"
					unless $op;
			}
			else {
#::logDebug("found or");
				push @out, 'or';
			}
		}

		if(s/^(not)$//i) {
			if($lhs) {
				die "syntax error: negation where rhs expected"
					unless $op and $op eq 'is';
				$neg = 1;
			}
			else {
#::logDebug("found not");
				push @out, 'not';
			}
		}

#::logDebug("evaling '$_'");

		if($rhs_done) {
#::logDebug("rhs is done");
			# do nothing
		}
		elsif(! length($_) ) {
			next;
		}
		elsif(! $lhs) {
#::logDebug("lhs value is=$lhs");
			if(s/^(\w+)([=!<>]+)(.*)/$1/) {
#::logDebug("found merged operator");
				unshift @things, $3 if $3;
				unshift @things, $2;
#::logDebug("found merged operator $things[0]");
			}
			my ($val, $type) = $s->find_param_or_col($_);
			if($type eq 'literal') {
				die "syntax error: literal on left-hand side";
			}
#::logDebug("found lhs=$val");
			$lhs = $val;
		}
		elsif(! $op) {
			if(s/^([=!<>]+)([^=!<>]+)/$1/) {
				$op = $1;
				unshift @things, $2;
#::logDebug("found merged operator and righthand term $things[0]");
			}
			else {
				$op = lc($_);
			}
#::logDebug("found op=$op");
			die "syntax error: unknown op '$op'"
				unless $valid_op{$op};
#::logDebug("op=$op is valid");
			if($op eq 'between' or $op eq 'in') {
				$rhs = [];
			}
		}
		elsif( ref($rhs) eq 'ARRAY') {
			next if $_ eq ',';
#::logDebug("rhs=array, val=$_");
			my ($val, $type) = $s->find_param_or_col($_, 1);
			$rhs_type ||= $type;
			push @$rhs, $val;
			if($op eq 'between' and scalar(@$rhs) == 2) {
				$rhs_done = 1;
			}
#::logDebug("rhs now=" . ::uneval($rhs));
		}
		else {
#::logDebug("rhs=non_array, val=$_");
			($rhs, $rhs_type) = $s->find_param_or_col($_, 1);
			$rhs_done = 1;
#::logDebug("rhs now=" . ::uneval($rhs));
		}

		$rhs_done ||= $rhs_almost_done;

		if($rhs_done) {
			$statement++;
			push @out, $close if $close;
			my $sub = $s->{regex_percent} || '.*';
			if($op eq 'is') {
				$rhs = '' if $rhs eq 'NULL';
			}

			$number = $rhs_type eq 'number' ? 1 : 0;
			if($op eq 'between') {
				push @out, $statement;
				push @stack, ['ac', 1];
				push @stack, ['ne', $neg];
				push @stack, ['nu', $number];
				push @stack, ['op', 'ge'];
				push @stack, ['se', $rhs->[0]];
				push @stack, ['sf', $lhs];
				push @stack, ['sg', $statement];
				push @stack, ['su', 0];
				push @stack, ['cs', 1];

				$extra_statement++;

				push @stack, ['ac', 1];
				push @stack, ['ne', $neg];
				push @stack, ['nu', $number];
				push @stack, ['op', 'le'];
				push @stack, ['se', $rhs->[1]];
				push @stack, ['sf', $lhs];
				push @stack, ['sg', $statement];
				push @stack, ['su', 0];
				push @stack, ['cs', $s->{case_sensitive}];
			}
			elsif($op eq 'in') {
#::logDebug("in rhs=" . ::uneval($rhs));
				my $done_one;
				for(@$rhs) {
					if($done_one++) {
						push @out, 'OR';
					}
					else {
						push @out, '(';
					}
					push @out, $statement;
					push @stack, ['sg', $statement];
					push @stack, ['ac', 1];
					push @stack, ['ne', $neg];
					push @stack, ['nu', $number];
					push @stack, ['op', 'eq'];
					push @stack, ['se', $_];
					push @stack, ['sf', $lhs];
					push @stack, ['su', 0];
					push @stack, ['cs', $s->{case_sensitive}];
					$statement++;
				}
				$statement--;
				push @out, ')';
			}
			elsif($op eq 'like') {

				my $ss = 0;
				unless($s->{full_regex}) {
					$rhs =~ quotemeta($rhs);
					if($s->{tolerant_like}) {
						$rhs =~ s/^([^%])/\%$1/;
						$rhs =~ s/([^%])$/$1\%/;
					}
					$rhs =~ s/%/$sub/g;
					$rhs = "^$rhs\$";
					$ss = 1;
				}
#::logDebug("like rhs=$rhs, tl=$s->{tolerant_like}");
				push @out, $statement;
				push @stack, ['ac', 0];
				push @stack, ['ne', $neg];
				push @stack, ['nu', 0];
				push @stack, ['op', 'rm'];
				push @stack, ['se', $rhs];
				push @stack, ['sf', $lhs];
				push @stack, ['sg', $statement];
				push @stack, ['su', $ss];
				push @stack, ['cs', $s->{case_sensitive}];
			}
			else {
				$op = $valid_op{$op};
				die "Invalid op found!" unless $op;
				push @out, $statement;
				push @stack, ['ac', 1];
				push @stack, ['ne', $neg];
				push @stack, ['nu', $number];
				push @stack, ['op', $op];
				push @stack, ['se', $rhs];
				push @stack, ['sf', $lhs];
				push @stack, ['sg', $statement];
				push @stack, ['su', 0];
				push @stack, ['cs', $s->{case_sensitive}];
			}
			undef $lhs;
			undef $op;
			undef $rhs;
			undef $neg;
			undef $number;
			undef $rhs_done;
			undef $rhs_almost_done;
			undef $close;
		}
	}

	unshift @stack, [ 'co', '1' ];
	if($statement > 1) {
		unshift @stack, ["sr", join(" ", @out)];
	}
	$s->{where} = \@stack;
#::logDebug("stack is ");
#::logDebug(Dumper(\@stack));
	return @stack;
}

=begin test 

#my @ones = (
#	q{val1 < 'd' and (val2 > 'h' or val4 = 'x')},
#	q{prod_group like '%g% Tools%'},
#	q{val2 between ('j','l')},
#	q{val1 < 'd' and val2 > 'h' or val4 = 'x'},
#	q{(val1 < 'd' and val2 > 'h') or val4 = 's'},
#	q{(val1 < 'd' and val2 > 'h') or val4 = 's'},
#);

my @ones = (
	q{val1<'d' and (val2 > 'h' or val4='x')},
);

for(@ones) {
	my $self = { where_statement => $_ };

	where($self);
#::logDebug(Dumper($self));
#::logDebug("\n#### Ended ####\n");
}

=cut 

## END

sub columns {
	my $s = shift;
	return @{$s->{columns}} if $s->{columns};
	$s->tables() unless $s->{tables};
	my @try;
	my @val;
	my @valtype;
	my $params;

	my $st = $s->{base_statement};
	my $col;

	if($s->{command} eq 'INSERT') {
		my $vst = $st;
		$vst =~ s/^into\s+.*?\(/(/is;
		$vst =~ s/^\s+//;
		$vst =~ s/\s+$//;
		
		my @things = Text::ParseWords::quotewords('\s*[=,()]\s*', 1, $vst);
		shift @things while ! length($things[0]);
		pop @things while ! length($things[-1]);

		my $values_start;
		for(@things) {
			if(s/^'(.*)'$//s) {
				push @val, $1;
				push @valtype, 'literal';
				$values_start++;
			}
			elsif ($values_start) {
				push @val, $_;
				push @valtype, 'reference';
			}
			elsif (lc($_) eq 'values') {
#::logDebug("found our values_start");
				$values_start++;
				@try = '*' unless @try;
			}
			else {
				push @try, $_;
			}
		}
#::logDebug("col=" . ::uneval(\@try));
#::logDebug("val=" . ::uneval(\@val));
#::logDebug("valtype=" . ::uneval(\@valtype));
	}
	elsif($s->{command} eq 'SELECT') {
		push @try, split /\s*,\s*/, $s->{raw_columns};
	}
	elsif ($s->{command} eq 'UPDATE') {
		$st =~ s/.*?\s+set\s+//is;
		my @things = Text::ParseWords::quotewords('\s*[=,]\s*', 1, $st);
		for(my $i = 0; $i < @things; $i += 2) {
			push @try, $things[$i];
			my $val = $things[$i + 1];
			if($val =~ s/^'(.*)'$//s) {
				push @val, $1;
				push @valtype, 'literal';
			}
			else {
				push @val, $val;
				push @valtype, 'reference';
			}
		}
#::logDebug("col=" . ::uneval(\@try));
#::logDebug("val=" . ::uneval(\@val));
#::logDebug("valtype=" . ::uneval(\@valtype));
	}
	elsif ($s->{command} eq 'DELETE') {
		$s->{columns} = [];
		$s->{params} = [];
		return;
	}
	
	my @col;
	my @parm;

	my $found;

	for(my $i = 0; $i < @try; $i++) {
		my $col = Vend::SQL_Parser::Column->new(
						raw => $try[$i],
						index => $i,
					);
		push @col, $col;
		$found++;
	}

	for(my $i = 0; $i < @val; $i++) {
		my $parm = Vend::SQL_Parser::Param->new(
						value => $val[$i],
						type => $valtype[$i],
					);
		push @parm, $parm;
	}

	return $s->errdie("No columns found in: %s", $s->{complete_statement})
		unless $found;

	$s->{params} = \@parm;
	$s->{columns} = \@col;

	return @col;
}

sub params {
	my $s = shift;
	return @{$s->{params}} if $s->{params};
	$s->tables() unless $s->{tables};
	$s->columns();
	return @{$s->{params}};
}

sub row_values {
	my $s = shift;
	my @out;
	for($s->params()) {
		push @out, $_->value();
	}
	return @out;
}

sub verbatim_fields {
	my $s = shift;
	my $val = shift;
	if(defined $val) {
		$s->{verbatim_fields} = $val;
	}
#::logDebug("verbatim_fields returning $s->{verbatim_fields}");
	return $s->{verbatim_fields};
}

1;

package Vend::SQL_Parser::Table;

sub name {
	return shift->{name};
}

sub alias {
	return shift->{alias};
}

sub new {
	my $class = shift;
	my $self = { @_ };
	die "No table name!" unless $self->{name};
	$self->{name} =~ s/\s+(?:as\s+)?(.*)//is
		and do {
			$self->{alias} = $1;
			$self->{alias} =~ s/\s+$//;
			$self->{alias} =~ s/^(["'])(.*)\1$/$2/s;
		};
	return bless $self, $class;
}

1;

package Vend::SQL_Parser::Column;

sub setval {
	my $s = shift;
	$s->{value} = shift;
	return $s;
}

sub name {
	return shift->{name};
}

sub distinct {
	my $s = shift;
	return $s->{distinct};
}

sub as {
	return shift->{as};
}

sub new {
	my $class = shift;
	my $self = { @_ };
	die "No column spec!" unless $self->{raw};
	my $raw = $self->{raw};
	my $name;
	if($raw =~ /^(\w+)->(\w+)/) {
		my $space = $1;
		my $sel = $2;
		if($space =~ /^v/) {
			$name = $::Values->{$sel};
		}
		elsif ($space =~ /^s/i) {
			$name = $::Scratch->{$sel};
		}
		elsif ($space =~ /^c/i) {
			$name = $CGI::values{$sel};
		}
	}
	elsif($raw =~ /\s/) {
		if ($raw =~ s/^distinct[\s(]+//i) {
		      $self->{distinct} = 1;
		      # delete last bracket if exists
		      $raw =~ s/[\s\)]+$//i;
		}
		my $title;
		$title = $1 if $raw =~ s/\s+as\s+(.*)//;
		if($title) {
			my $match;
			$title =~ s/^(["']?)(.*)\1$/$2/
				and $match = $1
				and $title =~ s/$match$match/$match/g;
			$self->{as} = $title;
		}
		$name = $raw;
	}
	else {
		$name = $raw;
	}

	if($name !~ /^\w+$/ and $name ne '*') {
		die ::errmsg("Bad column name (from %s): '%s'", $raw, $name);
	}
	$self->{name} = lc $name unless $self->{verbatim_fields};
	return bless $self, $class;
}

1;

package Vend::SQL_Parser::Param;

sub value {
	return shift->{value};
}

sub type {
	return shift->{type};
}

sub new {
	my $class = shift;
	my $self = { @_ };
	my $raw = $self->{value};
	
	if($self->{type} ne 'literal' and $raw =~ /^(\w+)->(\w+)/) {
		my $space = $1;
		my $sel = $2;
		if($space =~ /^v/) {
			$raw = $::Values->{$sel};
		}
		elsif ($space =~ /^s/i) {
			$raw = $::Scratch->{$sel};
		}
		elsif ($space =~ /^c/i) {
			$raw = $CGI::values{$sel};
		}
	    $self->{value} = $raw;
	}
	return bless $self, $class;
}

1;

package Vend::SQL_Parser::Order;

sub column {
	return shift->{name};
}

sub desc {
	return shift->{desc};
}

sub new {
	my $class = shift;
	my $self = { @_ };
	die "No column spec!" unless $self->{raw};
	my $raw = $self->{raw};
	$raw =~ s/\s+desc(ending)?\s*$//i and $self->{desc} = 1;
	my $name;
	if($raw =~ /^(\w+)->(\w+)/) {
		my $space = $1;
		my $sel = $2;
		if($space =~ /^v/) {
			$name = $::Values->{$sel};
		}
		elsif ($space =~ /^s/i) {
			$name = $::Scratch->{$sel};
		}
		elsif ($space =~ /^c/i) {
			$name = $CGI::values{$sel};
		}
	}
	else {
		$name = $raw;
	}

	if($name !~ /^\w+$/) {
		die ::errmsg("Bad column name (from %s): '%s'", $raw, $name);
	}
	$name = lc $name;
	$self->{name} = $name;
	return bless $self, $class;
}

1;

package Vend::SQL_Parser::Limit;

sub limit {
	return shift->{limit};
}

sub offset {
	return shift->{offset};
}

sub new {
	my $class = shift;
	my $self = { @_ };
	die "No limit spec!" unless $self->{raw};

	my @ones = split /\s*,\s*/, $self->{raw};
	
	for(@ones) {
		if(/^(\w+)->(\w+)/) {
			my $space = $1;
			my $sel = $2;
			if($space =~ /^v/) {
				$_ = $::Values->{$sel};
			}
			elsif ($space =~ /^s/i) {
				$_ = $::Scratch->{$sel};
			}
			elsif ($space =~ /^c/i) {
				$_ = $CGI::values{$sel};
			}
		}
	}

	$self->{limit} = $ones[0];
	$self->{offset} = $ones[1] || 0;

	return bless $self, $class;
}

1;
