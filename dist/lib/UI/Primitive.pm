# UI::Primitive - Interchange configuration manager primitives

# $Id: Primitive.pm,v 2.10 2001-11-11 07:15:30 mheins Exp $

# Copyright (C) 1998-2001 Red Hat, Inc. <interchange@redhat.com>

# Author: Michael J. Heins <mheins@redhat.com>
# Former maintainer: Stefan Hornburg <racke@linuxia.de>

# This file is free software; you can redistribute it and/or modify it
# under the terms of the GNU General Public License as published by the
# Free Software Foundation; either version 2, or (at your option) any
# later version.

# This file is distributed in the hope that it will be
# useful, but WITHOUT ANY WARRANTY; without even the implied warranty
# of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# General Public License for more details.

# You should have received a copy of the GNU General Public License
# along with this file; see the file COPYING.  If not, write to the Free
# Software Foundation, 675 Mass Ave, Cambridge, MA 02139, USA.

my($order, $label, %terms) = @_;

package UI::Primitive;

$VERSION = substr(q$Revision: 2.10 $, 10);

$DEBUG = 0;

use vars qw!
	@EXPORT @EXPORT_OK
	$VERSION $DEBUG
	$DECODE_CHARS
	!;

use File::Find;
use File::CounterFile;
use Text::ParseWords;
use Exporter;
use strict;
use Vend::Util qw/errmsg/;
$DECODE_CHARS = qq{&[<"\000-\037\177-\377};

@EXPORT = qw( ui_check_acl ui_acl_enabled meta_record) ;

=head1 NAME

Primitive.pm -- Interchange Configuration Manager Primitives

=head1 SYNOPSIS

display_directive %options;

=head1 DESCRIPTION

The Interchange UI is an interface to configure and administer Interchange catalogs.

=cut

my $ui_safe = new Safe;
$ui_safe->untrap(@{$Global::SafeUntrap});

sub is_super {
	return 1
		if  $Vend::Cfg->{RemoteUser}
		and $Vend::Cfg->{RemoteUser} eq $CGI::remote_user;
	return 0 if ! $Vend::Session->{logged_in};
	return 0 if ! $Vend::username;
	return 0 if $Vend::Cfg->{AdminUserDB} and ! $Vend::admin;
	my $db = Vend::Data::database_exists_ref(
						$Vend::Cfg->{Variable}{UI_ACCESS_TABLE} || 'access'
						);
	return 0 if ! $db;
	$db = $db->ref();
	my $result = $db->field($Vend::username, 'super');
	return $result;
}

sub is_logged {
	return 1
		if  $Vend::Cfg->{RemoteUser}
		and $Vend::Cfg->{RemoteUser} eq $CGI::remote_user;
	return 0 if ! $Vend::Session->{logged_in};
	return 0 unless $Vend::admin or ! $Vend::Cfg->{AdminUserDB};
	return 1;
}

my %wrap_dest;
my $compdb;

sub ui_wrap {
	my $path = shift;
	if($CGI::values{ui_destination}) {
		my $sub = $wrap_dest{$CGI::values{ui_destination}} || return 1;
		return $sub->($path);
	}
	$Vend::Cfg->{VendURL} .= '/ui_wrap';
	$UI::Editing = \&resolve_var;
	$compdb = ::database_exists_ref($::Variable->{UI_COMPONENT_TABLE} ||= 'component');
	$path =~ s:([^/]+)::;
	$Vend::RedoAction = 1;
	my $snoop = $1;
	return $snoop;
}

sub wrap_edit {
	package Vend::Interpolate;
	my $name = shift;
#::logGlobal("entering wrap_edit $name");
	my $ref;
	if ($compdb->record_exists($name)) {
		$ref = $compdb->row_hash($name);
	}
	else {
		return $::Variable->{$name} if ! $::Variable->{$name};
		$ref = { variable => $::Variable->{$name} };
	}
	if ($ref->{variable} =~ s/^(\s*\[)include(\s+)/$1 . 'file' . $2/e) {
		$ref->{variable} = ::interpolate_html($ref->{variable});
	}
	my $edit_link;
	my $url = $Vend::Cfg->{VendURL};
	$url =~ s!/ui_wrap$!$::Variable->{UI_BASE} || $Global::Variable->{UI_BASE} || 'admin'!e;
	$url .= "/";
	if(not $edit_link = $::Variable->{UI_EDIT_LINK}) {
		my $url = Vend::Interpolate::tag_area(
						"$::Variable->{UI_BASE}/compedit",
						$name,
						);
		$url =~ s:/ui_wrap/:/:;
		$edit_link = <<EOF;
<A HREF="$url" target="_blank"><u>edit</u></A>
EOF
		chop $edit_link;
	}
	my $out = <<EOF;
[calc] \$C_stack = [] unless \$C_stack;
		push \@\$C_stack, \$Scratch->{ui_component} || '';
		\$Scratch->{ui_component} = q{$name}; return; [/calc]
EOF
	chop $out;

	for( qw/preedit preamble variable postamble postedit/ ) {
		$out .= $ref->{$_};
	}
	$out .= qq{[calc] \$Scratch->{ui_component} = pop \@\$C_stack; return; [/calc]};
	$out =~ s:\[comment\]\s*\$EDIT_LINK\$\s*\[/comment\]:$edit_link:;
#::logGlobal("returning wrap_edit $out");
	return $out;
}

sub resolve_var {
	my ($name, $ref) = @_;
	if ($compdb) {
		return wrap_edit($name);
	}
	return $ref->{$name} if $ref and defined $ref->{$name};
	return $::Variable->{$name};
}

sub ui_acl_enabled {
	my $try = shift;
	my $table;
	$Global::SuperUserFunction = \&is_super;
	my $default = defined $Global::Variable->{UI_SECURITY_OVERRIDE}
				? $Global::Variable->{UI_SECURITY_OVERRIDE}
				: 0;
	if ($Vend::superuser) {
		return $Vend::UI_entry = { super => 1 };
	}
	$table = $::Variable->{UI_ACCESS_TABLE} || 'access';
	$Vend::WriteDatabase{$table} = 1;
	my $db = Vend::Data::database_exists_ref($table);
	return $default unless $db;
	$db = $db->ref() unless $Vend::Interpolate::Db{$table};
	my $uid = $try || $Vend::username || $CGI::remote_user;
	if(! $uid or ! $db->record_exists($uid) ) {
		return 0;
	}
	my $ref = $db->row_hash($uid)
		or die "Bad database record for $uid.";
	if($ref->{table_control}) {
		$ref->{table_control_ref} = $ui_safe->reval($ref->{table_control});
		ref $ref->{table_control_ref} or delete $ref->{table_control_ref};
	}
	return $ref if $try;
	$Vend::UI_entry = $ref;
}

sub get_ui_table_acl {
	my ($table, $user, $keys) = @_;
	$table = $::Values->{mv_data_table} unless $table;
	my $acl_top;
	if($user and $user ne $Vend::username) {
		if ($Vend::UI_acl{$user}) {
			$acl_top = $Vend::UI_acl{$user};
		}
		else {
			my $ui_table = $::Variable->{UI_ACCESS_TABLE} || 'access';
			my $acl_txt = Vend::Interpolate::tag_data($ui_table, 'table_control', $user);
			return undef unless $acl_txt;
			$acl_top = $ui_safe->reval($acl_txt);
			return undef unless ref($acl_top);
		}
		$Vend::UI_acl{$user} = $acl_top;
		return keys %$acl_top if $keys;
		return $acl_top->{$table};
	}
	else {
		unless ($acl_top = $Vend::UI_entry) {
			return undef unless ref($acl_top = ui_acl_enabled());
		}
	}
	return undef unless defined $acl_top->{table_control_ref};
	return $acl_top->{table_control_ref}{$table};
}

sub ui_acl_grep {
	my ($acl, $name, @entries) = @_;
	my $val;
	my %ok;
	@ok{@entries} = @entries;
	if($val = $acl->{owner_field} and $name eq 'keys') {
		my $u = $Vend::username;
		my $t = $acl->{table}
			or do{
				::logError("no table name with owner_field.");
				return undef;
			};
			for(@entries) {

				my $v = ::tag_data($t, $val, $_);
				$ok{$_} = $v eq $u;
			}
	}
	else {
		if($val = $acl->{"no_$name"}) {
			for(@entries) {
				$ok{$_} = ! ui_check_acl($_, $val);
			}
		}
		if($val = $acl->{"yes_$name"}) {
			for(@entries) {
				$ok{$_} &&= ui_check_acl($_, $val);
			}
		}
	}
	return (grep $ok{$_}, @entries);
}

sub ui_acl_atom {
	my ($acl, $name, $entry) = @_;
	my $val;
	my $status = 1;
	if($val = $acl->{"no_$name"}) {
		$status = ! ui_check_acl($entry, $val);
	}
	if($val = $acl->{"yes_$name"}) {
		$status &&= ui_check_acl($entry, $val);
	}
	return $status;
}

sub ui_extended_acl {
	my ($item, $string) = @_;
	$string = " $string ";
	my ($name, $sub) = split /=/, $item, 2;
	return 0 if $string =~ /[\s,]!$name(?:[,\s])/;
	return 1 if $string =~ /[\s,]$name(?:[,\s])/;
	my (@subs) = split //, $sub;
	for(@subs) {
		return 0 if $string =~ /[\s,]!$name=[^,\s]*$sub/;
		return 0 unless $string =~ /[\s,]$name=[^,\s]*$sub/;
	}
	return 1;
}

sub ui_check_acl {
	my ($item, $string) = @_;
	return ui_extended_acl(@_) if $item =~ /=/;
	$string = " $string ";
	return 0 if $string =~ /[\s,]!$item[=,\s]/;
	return 1 if $string =~ /[\s,]$item[=,\s]/;
	return '';
}

sub ui_acl_global {
	my $record = ui_acl_enabled();
	# First we see if we have ACL enforcement enabled
	# If you don't, then people can do anything!
	unless (ref $record) {
		$::Scratch->{mv_data_enable} = $record;
		return;
	}
	my $enable = delete $::Scratch->{mv_data_enable} || 1;
	my $CGI = \%CGI::values;
	my $Tag = new Vend::Tags;
	$CGI->{mv_todo} = $CGI->{mv_doit}
		if ! $CGI->{mv_todo};
	if( $Tag->if_mm('super')) {
		$::Scratch->{mv_data_enable} = $enable;
		return;
	}

    if( $CGI->{mv_todo} eq 'set' ) {
		undef $::Scratch->{mv_data_enable};
		my $mml_enable = $Tag->if_mm('functions', 'mml');
		my $html_enable = ! $Tag->if_mm('functions', 'no_html');
		my $target = $CGI->{mv_data_table};
		$Vend::WriteDatabase{$target} = 1;
		my $db = Vend::Data::database_exists_ref($target);
		if(! $db) {
			$::Scratch->{ui_failure} = "Table $target doesn't exist";
			return;
		}

		my $keyname = $CGI->{mv_data_key};
		if ($CGI->{mv_auto_export}
			and $Tag->if_mm('!tables', undef, { table => "$target=x" }, 1) ) {
			$::Scratch->{ui_failure} = "Unauthorized to export table $target";
			$CGI->{mv_todo} = 'return';
			return;
		}
		if ($Tag->if_mm('!tables', undef, { table => "$target=e" }, 1) ) {
			$::Scratch->{ui_failure} = "Unauthorized to edit table $target";
			$CGI->{mv_todo} = 'return';
			return;
		}

		my @codes = grep /\S/, split /\0/, $CGI->{$keyname};
		for(@codes) {
			unless( $db->record_exists($_) ) {
				next if $Tag->if_mm('tables', undef, { table => "$target=c" }, 1);
				$::Scratch->{ui_failure} = "Unauthorized to insert to table $target";
				$CGI->{mv_todo} = 'return';
				return;
			}
			next if $Tag->if_mm('keys', $_, { table => $target }, 1);
			$CGI->{mv_todo} = 'return';
			$::Scratch->{ui_failure} = errmsg("Unauthorized for key %s", $_);
 			return;
  		}

		my @fields = grep /\S/, split /[,\s\0]+/, $CGI->{mv_data_fields};
		push @fields, $CGI->{mv_blob_field}
			if $CGI->{mv_blob_field};

		for(@fields) {
			$CGI->{$_} =~ s/\[/&#91;/g unless $mml_enable;
			$CGI->{$_} =~ s/\</&lt;/g unless $html_enable;
			next if $Tag->if_mm('columns', $_, { table => $target }, 1);
			$CGI->{mv_todo} = 'return';
			$::Scratch->{ui_failure} = errmsg("Unauthorized for key %s", $_);
 			return;
  		}

 		$::Scratch->{mv_data_enable} = $enable;
	}
	elsif ($CGI->{mv_todo} eq 'deliver') {
		if($Tag->if_mm('files', $CGI->{mv_data_file}, {}, 1 ) ) {
			$::Scratch->{mv_deliver} = $CGI->{mv_data_file};
		}
		else {
			$::Scratch->{ui_failure} = errmsg(
										"Unauthorized for file %s",
										$CGI->{mv_data_file},
										);
		}
	}
    return;

}

sub list_keys {
	my $table = shift;
	my $opt = shift;
	$table = $::Values->{mv_data_table}
		unless $table;
	my @keys;
	my $record;
	if(! ($record = $Vend::UI_entry) ) {
		$record =  ui_acl_enabled();
	}

	my $acl;
	my $keys;
	if($record) {
		$acl = get_ui_table_acl($table);
		if($acl and $acl->{yes_keys}) {
			@keys = grep /\S/, split /\s+/, $acl->{yes_keys};
		}
	}
	unless (@keys) {
		my $db = Vend::Data::database_exists_ref($table);
		return '' unless $db;
		$db = $db->ref() unless $Vend::Interpolate::Db{$table};
		my $keyname = $db->config('KEY');
		if($db->config('LARGE')) {
			return ::errmsg('--not listed, too large--');
		}
		my $query = "select $keyname from $table order by $keyname";
		$keys = $db->query(
						{
							query => $query,
							ml => $::Variable->{UI_ACCESS_KEY_LIMIT} || 500,
							st => 'db',
						}
					);
		if(defined $keys) {
			@keys = map {$_->[0]} @$keys;
		}
		else {
			my $k;
			while (($k) = $db->each_record()) {
				push(@keys, $k);
			}
			if( $db->numeric($db->config('KEY')) ) {
				@keys = sort { $a <=> $b } @keys;
			}
			else {
				@keys = sort @keys;
			}
		}
	}
	if($acl) {
		@keys = UI::Primitive::ui_acl_grep( $acl, 'keys', @keys);
	}
	my $joiner = $opt->{joiner} || "\n";
	return join($joiner, @keys);
}

sub list_tables {
	my $opt = shift;
	my @dbs;
	my $d = $Vend::Cfg->{Database};
	@dbs = sort keys %$d;
	my @outdb;
	my $record =  ui_acl_enabled();
	undef $record
		unless ref($record)
			   and $record->{yes_tables} || $record->{no_tables};

	for(@dbs) {
		next if $::Values->{ui_tables_to_hide} =~ /\b$_\b/;
		if($record) {
			next if $record->{no_tables}
				and ui_check_acl($_, $record->{no_tables});
			next if $record->{yes_tables}
				and ! ui_check_acl($_, $record->{yes_tables});
		}
		push @outdb, $_;
	}

	@dbs = $opt->{nohide} ? (@dbs) : (@outdb);
	$opt->{joiner} = " " if ! $opt->{joiner};
	
	my $string = join $opt->{joiner}, grep /\S/, @dbs;
	if(defined $::Values->{mv_data_table}) {
		return $string unless $d->{$::Values->{mv_data_table}};
		my $size = -s $Vend::Cfg->{ProductDir} .
						"/" .  $d->{$::Values->{mv_data_table}}{'file'};
		$size = 3_000_000 if $size < 1;
		$::Values->{ui_too_large} = $size > 100_000 ? 1 : '';
		$::Values->{ui_way_too_large} = $size > 2_000_000 ? 1 : '';
		local($_) = $::Values->{mv_data_table};
		$::Values->{ui_rotate_spread} = $::Values->{ui_tables_to_rotate} =~ /\b$_\b/;
	}
	return $string;
}

sub list_images {
	my ($base, $suf) = @_;
	return undef unless -d $base;
#::logDebug("passed suf=$suf");
	$suf = '\.(GIF|gif|JPG|JPEG|jpg|jpeg|png|PNG)'
		unless $suf;
	my @names;
	my $regex;
	eval {
		$regex = qr{$suf$}o;
	};
	return undef if $@;
	my $wanted = sub {
					return undef unless -f $_;
					return undef unless $_ =~ $regex;
					my $n = $File::Find::name;
					$n =~ s:^$base/?::;
					push(@names, $n);
				};
	find($wanted, $base);
	return sort @names;
}

sub list_glob {
	my($spec, $prefix) = @_;
	my $globspec = $spec;
	if($prefix) {
		$globspec =~ s:^\s+::;
		$globspec =~ s:\s+$::;
		$globspec =~ s:^:$prefix:;
		$globspec =~ s:\s+: $prefix:g;
	}
	my @files = glob($globspec);
	if($prefix) {
		@files = map { s:^$prefix::; $_ } @files;
	}
	return @files;
}

sub list_pages {
	my ($keep, $suf, $base) = @_;
	$suf = $Vend::Cfg->{StaticSuffix} if ! $suf;
	$base = Vend::Util::catfile($Vend::Cfg->{VendRoot}, $base) if $base;
	$base = $Vend::Cfg->{PageDir} if ! $base;
	my @names;
	my $wanted = sub {
					return undef unless -f $_;
					return undef unless /$suf$/;
					my $n = $File::Find::name;
					$n =~ s:^$base/?::;
					$n =~ s/$suf$// unless $keep;
					push(@names, $n);
				};
	find($wanted, $base);
	return sort @names;
}

my %Break = (
				'variable'   => 1,
				'subroutine' => 1,

);

my %Format_routine;

sub rotate {
	my($base, $options) = @_;

	unless ($base) {
		::logError( errmsg("%s: called rotate without file.", caller() ) );
		return undef;
	}

	if(! $options) {
		$options = {};
	}
	elsif (! ref $options) {
		$options = {Motion => 'unsave'};
	}


	my $dir = '.';

	if( $options->{Directory} ) {
		$dir = $options->{Directory};
	}

	if ($base =~ s:(.*)/:: ) {
		$dir .= "/$1";
	}

	my $motion = $options->{Motion} || 'save';


	$dir =~ s:/+$::;

	if("\L$motion" eq 'save' and ! -f "$dir/$base+") {
			require File::Copy;
			File::Copy::copy("$dir/$base", "$dir/$base+")
				or die "copy $dir/$base to $dir/$base+: $!\n";
	}

	opendir(forwardDIR, $dir) || die "opendir $dir: $!\n";
	my @files;
	@files = grep /^$base/, readdir forwardDIR;
	my @forward;
	my @backward;
	my $add = '-';

	if("\L$motion" eq 'save') {
		@backward = grep s:^($base\++):$dir/$1:, @files;
		@forward = grep s:^($base-+):$dir/$1:, @files;
	}
	elsif("\L$motion" eq 'unsave') {
		return 0 unless -f "$dir/$base-";
		@forward = grep s:^($base\++):$dir/$1:, @files;
		@backward = grep s:^($base-+):$dir/$1:, @files;
		$add = '+';
	}
	else { 
		die "Bad motion: $motion";
	}

	$base = "$dir/$base";


	my $base_exists = -f $base;
	push @forward, $base if $base_exists;

	for(reverse sort @forward) {
		next unless -f $_;
		rename $_, $_ . $add or die "rename $_ => $_+: $!\n";
	}

	#return 1 unless $base_exists && @backward;

	@backward = sort @backward;

	unshift @backward, $base;
	my $i;
	for($i = 0; $i < $#backward; $i++) {
		rename $backward[$i+1], $backward[$i]
			or die "rename $backward[$i+1] => $backward[$i]: $!\n";
	}

	if($options->{Touch}) {
		my $now = time();
		utime $now, $now, $base;
	}
	return 1;
}

my @t = localtime();

my (@years) = ( $t[5] + 1899 .. $t[5] + 1910 );
my (@months);
my (@days);

for(1 .. 12) {
	$t[4] = $_ - 1;
	$t[5] = 1;
	push @months, [sprintf("%02d", $_), POSIX::strftime("%B", @t)];
}

for(1 .. 31) {
	push @days, [sprintf("%02d", $_), $_];
}

sub round_to_fifteen {
	my $val = shift;
#::logDebug("round_to_fifteen val in=$val");
	$val = substr($val, 0, 4);
	$val = "0$val" if length($val) == 3;
	return '0000' if length($val) < 4;
	if($val !~ /(00|15|30|45)$/) {
		my $hr = substr($val, 0, 2);
		$hr =~ s/^0//;
		my $min = substr($val, 2, 2);
		$min =~ s/^0//;
		if($min > 45 and $hr < 23) {
			$hr++;
			$min = 0;
		}
		elsif($min > 30) {
			$min = 45;
		}
		elsif($min > 15) {
			$min = 30;
		}
		elsif($min > 0) {
			$min = 15;
		}
		elsif ($hr == 23) {
			$min = 45;
		}
		else {
			$min = 0;
		}
		$val = sprintf('%02d%02d', $hr, $min);
	}
#::logDebug("round_to_fifteen val out=$val");
	return $val;
}

sub date_widget {
	my($name, $val, $time) = @_;
	if($val =~ /\D/) {
		$val = Vend::Interpolate::filter_value('date_change', $val);
	}
	my $now;
	if($time and $time =~ /([-+])(\d+)/) {
		my $sign = $1;
		my $adjust = $2;
		$adjust *= 3600;
		$now = time;
		$now += $sign eq '+' ? $adjust : -$adjust;
	}

	@t = localtime($now || time);
	if (not $val) {
		$t[2]++ if $t[2] < 23;
		$val = POSIX::strftime("%Y%m%d%H00", @t);
	}
	my $sel = 0;
	my $out = qq{<SELECT NAME="$name">};
	my $o;
	for(@months) {
		$o = qq{<OPTION VALUE="$_->[0]">} . errmsg($_->[1]) . '</OPTION>';
		($out .= $o, next) unless ! $sel and $val;
		$o =~ s/>/ SELECTED>/ && $sel++
			if substr($val, 4, 2) eq $_->[0];
		$out .= $o;
	}
	$sel = 0;
	$out .= qq{</SELECT>};
	$out .= qq{<INPUT TYPE=hidden NAME="$name" VALUE="/">};
	$out .= qq{<SELECT NAME="$name">};
	for(@days) {
		$o = qq{<OPTION VALUE="$_->[0]">$_->[1]} . '</OPTION>';
		($out .= $o, next) unless ! $sel and $val;
		$o =~ s/>/ SELECTED>/ && $sel++
			if substr($val, 6, 2) eq $_->[0];
		$out .= $o;
	}
	$sel = 0;
	$out .= qq{</SELECT>};
	$out .= qq{<INPUT TYPE=hidden NAME="$name" VALUE="/">};
	$out .= qq{<SELECT NAME="$name">};
	if($::Variable->{UI_DATE_BEGIN}) {
		my $cy = $t[5] + 1900;
		my $by = $::Variable->{UI_DATE_BEGIN};
		my $ey = $::Variable->{UI_DATE_END} || ($cy + 10);
		if($by < 100) {
			$by = $cy - abs($by);
		}
		if($ey < 100) {
			$ey += $cy;
		}
		@years = ($by .. $ey);
	}
	for(@years) {
		$o = qq{<OPTION>$_} . '</OPTION>';
		($out .= $o, next) unless ! $sel and $val;
		$o =~ s/>/ SELECTED>/ && $sel++
			if substr($val, 0, 4) eq $_;
		$out .= $o;
	}
	$out .= qq{</SELECT>};
	return $out unless $time;

	$val =~ s/^\d{8}//;
	$val =~ s/\D+//g;
	$val = round_to_fifteen($val);
	$out .= qq{<INPUT TYPE=hidden NAME="$name" VALUE=":">};
	$out .= qq{<SELECT NAME="$name">};
	
	my $ampm = $time =~ /pm/ ? 1 : 0;
	my $mod = '';
	undef $sel;
	my %special = qw/ 0 midnight 12 noon /;
	
	$ampm =1;
	for my $hr ( 0 .. 23) {
		for my $min ( 0,15,30,45 ) {
			my $disp_hour = $hr;
			if($ampm) {
				if( $hr < 12) {
					$mod = 'am';
				}
				else {
					$mod = 'pm';
					$disp_hour = $hr - 12 unless $hr == 12;
				}
				$mod = errmsg($mod);
				$mod = " $mod";
			}
			if($special{$hr} and $min == 0) {
				$disp_hour = errmsg($special{$hr});
			}
			elsif($ampm) {
				$disp_hour = sprintf("%2d:%02d%s", $disp_hour, $min, $mod);
			}
			else {
				$disp_hour = sprintf("%02d:%02d", $hr, $min);
			}
			my $time = sprintf "%02d%02d", $hr, $min;
			$o = sprintf qq{<OPTION VALUE="%s">%s}, $time, $disp_hour;
			($out .= $o, next) unless ! $sel and $val;
#::logDebug("prospect=$time actual=$val");
			$o =~ s/>/ SELECTED>/ && $sel++
				if $val eq $time;
			$out .= $o;
		}
	}
	$out .= "</SELECT>";
	return $out;
}

sub option_widget_box {
	my ($name, $val, $lab, $default, $width) = @_;
	my $half = int($width / 2);
	my $sel = $default ? ' SELECTED' : '';
	$val =~ s/"/&quot;/g;
	$lab =~ s/"/&quot;/g;
	$width = 10 if ! $width;
	return qq{<TR><TD><SMALL><INPUT TYPE=text NAME="$name" VALUE="$val" SIZE=$half></SMALL></TD><TD><SMALL><INPUT TYPE=text NAME="$name" VALUE="$lab" SIZE=$width></SMALL></TD><TD><SMALL><SMALL><SELECT NAME="$name"><OPTION value="0">no<OPTION value="1"$sel>default*</SELECT></SMALL></SMALL></TD></TR>};
}

sub option_widget {
	my($name, $val, $opt) = @_;
	$opt = {} if ! ref $opt;
	my $width = $opt->{width} || 16;
	$val = Vend::Interpolate::filter_value('option_format', $val);
	my @opts = split /\s*,\s*/, $val;
	my $out = "<TABLE CELLPADDING=0 CELLSPACING=0><TR><TH><SMALL>Value</SMALL></TH><TH ALIGN=LEFT COLSPAN=2><SMALL>Label</SMALL></TH></TR>";
	my $done;
	for(@opts) {
		my ($v,$l) = split /\s*=\s*/, $_, 2;
		next unless $l || length($v);
		$done++;
		my $default;
		($l =~ s/\*$// or ! $l && $v =~ s/\*$//)
			and $default = 1;
		$out .= option_widget_box($name, $v, $l, $default, $width);
	}
	while($done++ < 3) {
		$out .= option_widget_box($name, '', '', '', $width);
	}
	$out .= option_widget_box($name, '', '', '', $width);
	$out .= option_widget_box($name, '', '', '', $width);
	$out .= "</TABLE>";
}

sub uploadhelper_widget {
	# $column, $value, $record->{outboard}, $record->{width}
    my ($name, $val, $path, $size) = @_;
	
	$path =~ s:^/+::;
	my $view_url;
	$size = qq{ SIZE="$size"} if $size > 0;
	my $out = '';
    if ($val) {
		if($path) {
			my $base = $::Variable->{UI_BASE} || 'admin';
			my $view_url = Vend::Interpolate::tag_area("$base/do_view", "$path/$val");
			$out .= qq{<A HREF="$view_url">};
		}
		$out .= $val;
		$out .= "</A>" if $path;
		$out .= qq{&nbsp;<INPUT TYPE=file NAME="$name" VALUE="$val">
<INPUT TYPE=hidden NAME="ui_upload_file_path:$name" VALUE="$path">
<INPUT TYPE=hidden NAME="$name" VALUE="$val">};      
    }
	else {
        $out = qq{<INPUT TYPE=hidden NAME="ui_upload_file_path:$name" VALUE="$path">
<INPUT TYPE=file NAME="$name"$size>};
    }
	return $out;
}

sub imagehelper_widget {
    my ($name, $val, $path, $imagebase, $size) = @_;
	
	Vend::Interpolate::vars_and_comments(\$path);
	Vend::Interpolate::vars_and_comments(\$imagebase);
	if ($imagebase ||= '') {
		$imagebase =~ s/^\s+//;
		$imagebase =~ s:[\s/]*$:/:;
	}

	my $of_widget;
	if($path =~ s!/\*(?:\.([^/]+))?$!!) {
		my $spec = $1;
		my @files = list_images($path, $spec);
		unshift(@files, "=(none)");
		my $passed = join ",", map { s/,/&#44;/g; $_} @files;
		my $opt = {
			type => 'select',
			default => $val,
			attribute => 'mv_data_file_oldfile',
			passed => $passed,
		};
		$of_widget = Vend::Interpolate::tag_accessories(
				undef, undef, $opt, { 'mv_data_file_oldfile' => $val } );
	}
	else {
		$of_widget = qq{<INPUT TYPE=hidden NAME=mv_data_file_oldfile VALUE="$val">};
	}
	$size = qq{ SIZE="$size"} if $size > 0;
    if ($val) {
        qq{<A HREF="$imagebase$path/$val">$val</A>&nbsp;<INPUT TYPE=hidden NAME=mv_data_file_field VALUE="$name">
<INPUT TYPE=hidden NAME=mv_data_file_path VALUE="$path">$of_widget<INPUT TYPE=file NAME="$name" VALUE="$val">};      
    } else {
        qq{<INPUT TYPE=hidden NAME=mv_data_file_field VALUE="$name">
<INPUT TYPE=hidden NAME=mv_data_file_path VALUE="$path">$of_widget<INPUT TYPE=file NAME="$name"$size>};
    }
}

sub meta_record {
	my ($item, $view, $mtable) = @_;
	return undef unless $item;
	$mtable ||= $::Variable->{UI_META_TABLE} || 'mv_metadata',
	my $mdb = Vend::Data::database_exists_ref($mtable)
		or return undef;
	my $record;
	if($view) {
		$record = $mdb->row_hash("${view}::$item");
	}
	$record = $mdb->row_hash($item) if ! $record;

	return undef if ! $record;

	# Get additional settings from extended field, which is a serialized
	# hash
	my $hash;
	if($record->{extended}) {
		$hash = Vend::Util::get_option_hash($record->{extended});
		if(ref $hash eq 'HASH') {
			@$record{keys %$hash} = values %$hash;
		}
		else {
			undef $hash;
		}
	}

	# Allow view settings to be placed in the extended area
	if($view and $hash and $hash->{view}) {
		my $view_hash = $record->{view}{$view};
		ref $view_hash
			and @$record{keys %$view_hash} = values %$view_hash;
	}
#::logDebug("return meta_record=" . ::uneval($record) );
	return $record;
}

my $base_entry_value;

sub meta_display {
	my ($table,$column,$key,$value,$meta_db,$query,$o) = @_;

	my $metakey;
	$meta_db = $::Variable->{UI_META_TABLE} || 'mv_metadata' if ! $meta_db;
	$o = {} if ! ref $o;
	my $meta = Vend::Data::database_exists_ref($meta_db)
		or return undef;
	$meta = $meta->ref();
	if($column eq $meta->config('KEY')) {
		if($o->{arbitrary} and $value !~ /::.+::/) {
			$base_entry_value = ($value =~ /^[^:]+::(\w+)$/)
								? $1
								: $value;
		}
		else {
			$base_entry_value = $value =~ /::/ ? $table : $value;
		}
	}

	my (@tries) = "${table}::$column";
	unshift @tries, "${table}::${column}::$key"
		if $key;

	my $view;
	if($view = $o->{arbitrary}) {
		unshift @tries, "$o->{arbitrary}::${table}::${column}";
		unshift @tries, "$o->{arbitrary}::${table}::${column}::$key" if $key;
	}

	my $sess = $Vend::Session->{mv_metadata} || {};

	push @tries, { type => $o->{type} }
		if $o->{type} || $o->{label};

#::logDebug("calling meta_display with type=$o->{type}");
	for $metakey (@tries) {
		my $record;
		unless ( $record = $sess->{$metakey} and ref $record ) {
			if(ref $metakey) {
				$record = $metakey;
				undef $metakey;
			}
			else {
				next unless $meta->record_exists($metakey);
				$record = $meta->row_hash($metakey);
			}
		}
		if($query) {
			return $record->{query};
		}
		my $opt;

		# Get additional settings from extended field, which is a serialized
		# hash
		my $hash;
		if($record->{extended}) {
			$hash = Vend::Util::get_option_hash($record->{extended});
			if(ref $hash) {
				@$record{keys %$hash} = values %$hash;
			}
			else {
				undef $hash;
			}
		}

		# Allow view settings to be placed in the extended area
		if($view and $hash and $hash->{view}) {
			my $view_hash = $record->{view}{$view};
			ref $view_hash
				and @$record{keys %$view_hash} = values %$view_hash;
		}

		## Here we allow override with the display tag, even with views and
		## extended
		my @override = grep defined $o->{$_},
						qw/
							append
							attribute
							db
							field
							filter
							height
							help
							help_url
							label
							lookup
							lookup_exclude
							name
							options
							outboard
							passed
							pre_filter
							prepend
							type
							width
							/;
		for(@override) {
			$record->{$_} = $o->{$_};
		}

		$record->{name} ||= $column;

		if($record->{options} and $record->{options} =~ /^[\w:]+$/) {
#::logDebug("checking options");
			PASS: {
				my $passed = $record->{options};

				if($passed eq 'tables') {
					$record->{passed} = "=--none--," . list_tables({ joiner => ',' });
				}
				elsif($passed eq 'filters') {
					$record->{passed} = $Vend::Interpolate::Tag->filters(1),
				}
				elsif($passed =~ /^columns(::(\w*))?\s*$/) {
					my $total = $1;
					my $tname = $2 || $record->{db} || $table;
#::logDebug("columns options, total=$total tname=$tname");
					$tname = $base_entry_value if $total eq '::';
					my $db = $Vend::Database{$tname};
					$record->{passed} = join (',', "=--none--", $db->columns())
						if $db;
				}
				elsif($passed =~ /^keys(::(\w+))?\s*$/) {
					my $tname = $2 || $record->{db} || $table;
					$record->{passed} = "=--none--," . list_keys($tname, { joiner => ',' });
				}
			}
		}
		if($record->{pre_filter}) {
			$value = Vend::Interpolate::filter_value($record->{pre_filter}, $value);
		}
		if($record->{lookup}) {
			my $fld = $record->{field} || $record->{lookup};
			my $key = $record->{lookup};
			LOOK: {
				my $dbname = $record->{db} || $table;
				my $db = Vend::Data::database_exists_ref($dbname);
				last LOOK unless $db;
				my $flds = $key eq $fld ? $key : "$key, $fld";
				my $query = "select DISTINCT $flds FROM $dbname ORDER BY $fld";
				my $ary = $db->query(
						{
							query => $query,
							ml => $::Variable->{UI_ACCESS_KEY_LIMIT} || 500,
							st => 'db',
						}
					);
				last LOOK unless ref($ary);
				if(! scalar @$ary) {
					push @$ary, ["=--no current values--"];
				}
				undef $record->{type} unless $record->{type} =~ /multi|combo/;
				my $sub;
				if($record->{lookup_exclude}) {
					eval {
						$sub = sub { $_[0] !~ m{$record->{lookup_exclude}} };
					};
					if ($@) {
						::logError(errmsg(
										"Bad lookup pattern m{%s}: %s",
										$record->{exclude},
										$@,
									));
						$sub = \&CORE::length;
					}
				}
				$sub = sub { length(@_) } if ! $sub;
				$record->{passed} = join ",", grep $sub->($_),
									map
										{ $_->[1] =~ s/,/&#44;/g; $_->[0] . "=" . $_->[1]}
									@$ary;
				if($record->{options}) {
					$record->{passed} =
						join ",", $record->{options}, $record->{passed};
				}
				$record->{passed} = "=--no current values--"
					if ! $record->{passed};
			}
		}
		elsif ($record->{type} eq 'yesno') {
			$record->{passed}  = '=' . ::errmsg('No');
			$record->{passed} .= ',1=' . ::errmsg('Yes');
			$o->{type} = 'select' unless $o->{type} =~ /radio/;
		}
		elsif ($record->{type} eq 'noyes') {
			$record->{passed}  = '1=' . ::errmsg('No');
			$record->{passed} .= ',=' . ::errmsg('Yes');
			$o->{type} = 'select' unless $o->{type} =~ /radio/;
		}
		elsif ($record->{type} =~ s/^custom\s+//s) {
			my $wid = lc $record->{type};
			$wid =~ tr/-/_/;
			my $w;
			$record->{attribute} ||= $column;
			$record->{table}     ||= $meta_db;
			$record->{rows}      ||= $record->{height};
			$record->{cols}      ||= $record->{width};
			$record->{field}     ||= 'options';
			$record->{name}      ||= $column;
			$record->{outboard}  ||= $metakey;
			my $Tag = new Vend::Tags;
			eval {
				$w = $Tag->$wid($record->{name}, $value, $record, $o);
			};
			if($@) {
				::logError("error using custom widget %s: %s", $wid, $@);
			}
			return $w unless $o->{template};
			return ($w, $record->{label}, $record->{help}, $record->{help_url});
		}
		elsif ($record->{type} eq 'option_format') {
			my $w = option_widget($record->{name}, $value);
			$w .= qq{<INPUT TYPE=hidden NAME="ui_filter:$record->{name}" VALUE="option_format">};
			return $w unless $o->{template};
			return ($w, $record->{label}, $record->{help}, $record->{help_url});
		}
		elsif ($record->{type} eq 'date') {
			my $w = date_widget($record->{name}, $value);
			$w .= qq{<INPUT TYPE=hidden NAME="ui_filter:$record->{name}" VALUE="date_change">};
			return $w unless $o->{template};
			return ($w, $record->{label}, $record->{help}, $record->{help_url});
		}
		elsif ($record->{type} =~ /^date_?time/) {
			my $w = date_widget($record->{name}, $value, $record->{type});
			$w .= qq{<INPUT TYPE=hidden NAME="ui_filter:$record->{name}" VALUE="date_change">};
			return $w unless $o->{template};
			return ($w, $record->{label}, $record->{help}, $record->{help_url});
		}
		elsif ($record->{type} eq 'imagedir') {
			my $dir = $record->{'outboard'} || $column;
			my $suf;
			if($record->{options}) {
				$suf = $record->{options};;
				if($suf !~ /[\.|]/) {
					my @types = grep /\S/, split /[,\s\0]+/, $suf;
					$suf = '\.(' . join("|", @types) . ')';
				}
			}
			my @files = list_images($dir, $suf);
			$record->{type} = 'combo';
			$record->{passed} = join ",",
									map { s/,/&#44;/g; $_} @files;
		}
		elsif ($record->{type} eq 'imagehelper') {
            my $w = imagehelper_widget(	
							$record->{name},
							$value,
							$record->{outboard},
							$record->{prepend},
							$record->{width},
							);
			return $w unless $o->{template};
			return ($w, $record->{label}, $record->{help}, $record->{help_url});
        }
		elsif ($record->{type} eq 'uploadhelper') {
            my $w = uploadhelper_widget(	
							$record->{name},
							$value,
							$record->{outboard},
							$record->{width},
							);
			return $w unless $o->{template};
			return ($w, $record->{label}, $record->{help}, $record->{help_url});
        }

		for(qw/append prepend/) {
			next unless $record->{$_};
			$record->{$_} = Vend::Util::resolve_links($record->{$_});
			$record->{$_} =~ s/_UI_VALUE_/$value/g;
			$record->{$_} =~ /_UI_URL_VALUE_/
				and do {
					my $tmp = $value;
					$tmp =~ s/(\W)/sprintf '%%%02x', ord($1)/eg;
					$record->{$_} =~ s/_UI_URL_VALUE_/$tmp/g;
				};
			$record->{$_} =~ s/_UI_TABLE_/$table/g;
			$record->{$_} =~ s/_UI_COLUMN_/$column/g;
			$record->{$_} =~ s/_UI_KEY_/$key/g;
		}
		if($record->{height}) {
			if($record->{type} =~ /multi/i) {
				$record->{type} = "MULTIPLE SIZE=$record->{height}";
			}
			elsif ($record->{type} =~ /textarea/i) {
				my $width = $record->{width} || 80;
				$record->{type} =~ s/textarea/textarea_$record->{height}_$width/;
			}
		}
		elsif ($record->{width}) {
			if($record->{type} =~ /textarea/) {
				$record->{type} = "textarea_2_" . $record->{width};
			}
			elsif($record->{type} =~ /text/) {
				$record->{type} = "text_$record->{width}";
			}
			elsif($record->{type} =~ /radio|check/) {
				$record->{type} =~ s/(left|right)[\s_]*\d*/$1 $record->{width}/;
			}
		}

		if(! $o->{type} and ! $record->{type}) {
			$o->{type} = 'text' unless $record->{passed};
		}
		$opt = {
			attribute	=> ($record->{'attribute'}	|| $column),
			table		=> ($record->{'db'}			|| $meta_db),
			rows 		=> ($o->{rows} || $record->{height}),
			cols 		=> ($o->{cols} || $record->{width}),
			column		=> ($record->{'field'}		|| 'options'),
			name		=> ($o->{'name'} || $record->{'name'} || $column),
			outboard	=> ($record->{'outboard'}	|| $metakey),
			passed		=> ($record->{'passed'}		|| undef),
			type		=> ($o->{type} || $record->{'type'}		|| undef),
			prepend		=> ($record->{'prepend'}	|| undef),
			append		=> ($record->{'append'}		|| undef),
			extra		=> ($o->{'extra'} || $record->{extra} || undef),
		};
		my $w = Vend::Interpolate::tag_accessories(
				undef, undef, $opt, { $column => $value } );
		my $filter;
		if($filter = ($o->{filter} || $record->{filter})) {
			$w .= qq{<INPUT TYPE=hidden NAME="ui_filter:$opt->{name}" VALUE="};
			$w .= $filter;
			$w .= '">';
		}
		return $w unless $o->{template};
		return ($w, $record->{label}, $record->{help}, $record->{help_url});
	}
	return undef;
}

1;

__END__

