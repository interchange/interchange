# Vend::ModPerl - Run Interchange inside Apache and mod_perl
#
# $Id: ModPerl.pm,v 2.9 2007-08-09 13:40:53 pajamian Exp $
#
# Copyright (C) 2002-2007 Interchange Development Group
# Copyright (C) 2002 Red Hat, Inc.
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along
# with this program; if not, write to the Free Software Foundation, Inc.,
# 51 Franklin St, Fifth Floor, Boston, MA  02110-1301  USA.

package Vend::ModPerl;

$VERSION = substr(q$Revision: 2.9 $, 10);

use Apache::Constants qw(:common);
use Apache::Request ();
use Apache::URI ();
use Apache::Server ();
use Vend::Server;
use Vend::Util;

use strict;


sub handler {
	my $r = shift;

	unless ($Global::mod_perl) {
		$r->log_error("Interchange can't serve pages because there were problems during startup inside mod_perl");
		return SERVER_ERROR;
	}

	@Global::argv = ();
	Vend::Server::reset_vars();

	if($Global::ShowTimes) {
		@Vend::Times = times();
		::logDebug("begin connection. Summary time set to zero");
	}

	$::Instance = {};
	my (%env, $entity);
	%env = %ENV;

	my $path = $r->parsed_uri->path;
	# URI currently must look like /prefix/catalogname/page...
	# should allow customized path prefixes
	$path =~ s{^(/[^/]+/[^/]+)}{};
	$env{SCRIPT_NAME} = $1;
	$env{PATH_INFO} = $path;

	# not handling MV3-style requests or TolerateGet compatibility yet
	my $apr = Apache::Request->new($r);
	for my $k ($apr->param) {
		if (my $upload = $apr->upload($k)) {
			my $fh = $upload->fh;
			$CGI::file{$k} = join('', <$fh>);
			#::logDebug("Vend::ModPerl: cgi param $k is an upload file of length " . length($CGI::file{$k}));
		}
		for my $v ($apr->param($k)) {
			Vend::Server::store_cgi_kv($k, $v);
		}
	}

	select STDERR;
	$| = 1;
	undef *STDOUT;
	tie *OUT, 'Apache';
	my $http = new Vend::Server \*OUT, \%env, \$entity;
	return NOT_FOUND unless $http;

	# Can log all CGI inputs
	log_http_data($http) if $Global::Logging;

	show_times("begin dispatch") if $Global::ShowTimes;
	::dispatch($http);
	show_times("end connection") if $Global::ShowTimes;
	undef $::Instance;
	undef $Vend::Cfg;
	return OK;
}

my $pidh;
sub child_start {
	return unless $Global::mod_perl;

	$Global::Foreground = 1;
	Vend::Server::reset_per_fork();

	# first child writes correct Apache master daemon pid and locks pidfile
	unless ($pidh) {
		$pidh = Vend::Server::open_pid($Global::PIDfile);
		Vend::Server::grab_pid($pidh);
		close $pidh;
		$pidh = 1;
	}
	return;
}

sub child_end {
	return unless $Global::mod_perl;
	Vend::Server::clean_up_after_fork();
	return;
}


1;
