# Vend::External - Interchange setup for linking sessions to other programs
# and routines for calling external programs
# 
# $Id: External.pm,v 2.6 2007-08-09 13:40:53 pajamian Exp $
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

package Vend::External;

use strict;

BEGIN {

	if($ENV{EXT_INTERCHANGE_DIR}) {
		$Global::VendRoot = $ENV{EXT_INTERCHANGE_DIR};
		if(-f "$Global::VendRoot/_session_storable") {
			$ENV{MINIVEND_STORABLE} = 1;
		}
	}
}

use Vend::Util;
use Vend::Session;
use Vend::Cart;
use Cwd;
require Data::Dumper;

BEGIN {
	if($ENV{EXT_INTERCHANGE_DIR}) {
		die "No VendRoot specified.\n" unless $Global::VendRoot;
		$Global::RunDir = $ENV{EXT_INTERCHANGE_RUNDIR} || "$Global::VendRoot/etc";
		Vend::Util::setup_escape_chars();
	}
	$Global::ExternalFile = $ENV{EXT_INTERCHANGE_FILE}  || "$Global::RunDir/external.structure";
}

sub check_html {
	my($out) = @_;

	unless($Global::CheckHTML) {
		logError("Can't check HTML: No global CheckHTML defined. Contact admin.", '');
	}

	my $file = POSIX::tmpnam();
	open(CHECK, "|$Global::CheckHTML > $file 2>&1")	or die "Couldn't fork: $!\n";
	print CHECK $$out;
	close CHECK;
	my $begin = "<!-- HTML Check via '$Global::CheckHTML'\n";
	my $end   = "\n-->";
	my $check = readfile($file);
	unlink $file					or die "Couldn't unlink temp file $file: $!\n";
	$$out .= $begin . $check . $end;
	return;
}

1;

package main;

BEGIN {
	if($ENV{EXT_INTERCHANGE_DIR}) {
		sub logDebug {
			warn caller() . ':external_debug: ', Vend::Util::errmsg(@_), "\n";
		}

		sub catalog {
			my $cat = shift or return $Vend::Cat;
			$Vend::Cat = $cat;
		}

		sub session {
			my $id = shift;
			$Vend::Cat ||= $ENV{EXT_INTERCHANGE_CATALOG}
				or die "No Interchange catalog specified\n";
			$Vend::Cfg = $Vend::Global->{Catalogs}{$Vend::Cat}{external_config}
				or die "Catalog $Vend::Cat not found.\n";
			$CGI::remote_addr = $ENV{REMOTE_ADDR};
			if($id =~ /^(\w+):/) {
				$Vend::SessionID = $1;
				$Vend::SessionName = $id;
			}
			else {
				$Vend::SessionID = $id;
				$Vend::SessionName = "${id}:$CGI::remote_addr";
			}
			
			Vend::Session::get_session();
		}

		sub _walk {
			my $ref = shift;
			my $last = pop (@_);

			if($last =~ /->/ and ! scalar(@_)) {
				@_ = split /->/, $last;
				$last = pop @_;
			}

			eval {
				for(@_) {
					$ref = /^\[\d+\]$/ ? $ref->[0] : $ref->{$_};
				}
			};
			if($@) {
				logDebug(caller() . ": problem following structure: " . join("->", @_, $last));
			}
			return $last =~ /^\[\d+\]$/ ? $ref->[$last] : $ref->{$last};
		}

		sub _set_walk {
			my $ref = shift;
			my $value = shift;
			my $last = pop (@_);

			if($last =~ /->/ and ! scalar(@_)) {
				@_ = split /->/, $last;
				$last = pop @_;
			}

			eval {
				for(@_) {
					$ref = /^\[\d+\]$/ ? $ref->[0] : $ref->{$_};
				}
			};
			if($@) {
				logDebug(caller() . ": problem following structure: " . join("->", @_, $last));
			}
			if($last =~ /^\[\d+\]$/) {
				$ref->[$last] = $value;
			}
			else {
				$ref->{$last} = $value;
			}
		}

		sub set_value {
			return _set_walk($Vend::Session, @_);
		}

		sub value {
			return _walk($Vend::Session, @_);
		}

		sub directive {
			return _walk($Vend::Cfg, @_);
		}

		sub session_id {
			return $Vend::SessionID;
		}

		sub session_name {
			return $Vend::SessionName;
		}

		sub remote_addr {
			my $in = shift 
				or return $CGI::remote_addr;
			$CGI::remote_addr = $CGI::host = $in;
		}

		sub write_session {
			Vend::Session::write_session();
		}

		sub init_session {
			Vend::Session::init_session();
			return $Vend::Session;
		}

		sub new_session {
			Vend::Session::new_session();
		}

		sub put_session {
			Vend::Session::put_session();
		}

		*uneval = \&Vend::Util::uneval;
#::logDebug("external file is $Global::ExternalFile");
#::logDebug("storable is $ENV{MINIVEND_STORABLE}, dumper= $ENV{MINIVEND_NO_DUMPER}, signals=$ENV{PERL_SIGNALS}");
		unless(-r $Global::ExternalFile) {
			logDebug "Cannot read  $Global::ExternalFile.";
			die "Cannot read  $Global::ExternalFile.";
		}
#::logDebug("ready to read global");
		$Vend::Global ||= Vend::Util::eval_file($Global::ExternalFile)
			or die "eval_file failed (value=$Vend::Global): $!";
#::logDebug("DID read global");
		#logDebug(uneval($Vend::Global));
	}
}

1;
