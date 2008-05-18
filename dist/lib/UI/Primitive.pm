# UI::Primitive - Interchange configuration manager primitives

# $Id: Primitive.pm,v 2.28 2008-04-10 22:26:12 docelic Exp $

# Copyright (C) 2002-2007 Interchange Development Group
# Copyright (C) 1998-2002 Red Hat, Inc.

# Authors:
# Michael J. Heins <mikeh@perusion.net>
# Stefan Hornburg <racke@linuxia.de>

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

$VERSION = substr(q$Revision: 2.28 $, 10);

$DEBUG = 0;

use vars qw!
	@EXPORT @EXPORT_OK
	$VERSION $DEBUG
	$DECODE_CHARS
	!;

use File::Find;
use Exporter;
use strict;
no warnings qw(uninitialized numeric);
use Vend::Util qw/errmsg/;
$DECODE_CHARS = qq{&[<"\000-\037\177-\377};

@EXPORT = qw(
		list_glob
		list_images
		list_pages
		ui_acl_enabled
		ui_check_acl
	);

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
		$regex = qr{$suf$};
	};
	return undef if $@;
	my $wanted = sub {
					return undef unless -f $_;
					return undef unless $_ =~ $regex;
					my $n = $File::Find::name;
					$n =~ s:^$base/?::;
					push(@names, $n);
				};
	find($wanted, $base . '/');
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
	$suf = $Vend::Cfg->{HTMLsuffix} if ! $suf;
	$base = Vend::Util::catfile($Vend::Cfg->{VendRoot}, $base) if $base;
	$base ||= $Vend::Cfg->{PageDir};
	my @names;
	$suf = quotemeta($suf);
#::logDebug("Finding, ext=$suf base=$base");
	my $wanted = sub {
					return undef unless -f $_;
					return undef unless /$suf$/;
					my $n = $File::Find::name;
					$n =~ s:^$base/?::;
					$n =~ s/$suf$// unless $keep;
					push(@names, $n);
				};
	find($wanted, $base);
#::logDebug("Found files: " . join (",", @names));
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

	$options->{max} = 10 if ! defined $options->{max};

	$dir =~ s:/+$::;

	if("\L$motion" eq 'save' and ! -f "$dir/$base+") {
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

	if (@forward > $options->{max}) {
		$#forward = $options->{max};
	}

	for(reverse sort @forward) {
		next unless -f $_;
		rename $_, $_ . $add or die "rename $_ => $_+: $!\n";
	}

	#return 1 unless $base_exists && @backward;

	@backward = sort @backward;

	unshift @backward, $base;

	if (@backward > $options->{max}) {
		$#backward = $options->{max};
	}

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

1;

__END__

