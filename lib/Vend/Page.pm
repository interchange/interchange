# Vend::Page - Handle Interchange page routing
# 
# $Id: Page.pm,v 2.7 2002-09-01 14:47:19 mheins Exp $
#
# Copyright (C) 1996-2002 Red Hat, Inc. <interchange@redhat.com>
#
# This program was originally based on Vend 0.2 and 0.3
# Copyright 1995 by Andrew M. Wilcox <amw@wilcoxsolutions.com>
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

package Vend::Page;

use Vend::Session;
use Vend::Parse;
use Vend::Data;
use Vend::Interpolate;
use Vend::Scan;
use Vend::Util;

require Exporter;
@ISA = qw(Exporter);
@EXPORT = qw (
				display_special_page
				display_page
				do_page
				do_search
				do_scan
			);

use strict;

use vars qw/$VERSION/;

$VERSION = substr(q$Revision: 2.7 $, 10);

my $wantref = 1;

sub display_special_page {
	my($name, $subject) = @_;
	my($page);

	$name =~ m/[\[<]+/g
		and do {
			::logGlobal(
					"Security violation -- scripting character in page name '%s'.",
					$name,
				);
			$name = 'violation';
		};

	$subject = $subject || 'unspecified error';
	
	$page = readfile($name, $Global::NoAbsolute, 1) || readin($name);

	die ::get_locale_message(412, "Missing special page: %s\n", $name)
		unless defined $page;
	$page =~ s#\[subject\]#$subject#ig;
	return ::response(::interpolate_html($page, 1));
}

# Displays the catalog page NAME.  If the file is not found, displays
# the special page 'missing'.
# 

sub display_page {
	my($name) = @_;
	my($page);

	$name =~ m/[\[<]+/g
		and do {
			::logGlobal(
					"Security violation -- scripting character in page name '%s'.",
					$name,
				);
			$name = 'violation';
			return display_special_page($name);
		};

	$name = $CGI::values{mv_nextpage} unless $name;

	if($Vend::Cfg->{ExtraSecure} and
		$Vend::Cfg->{AlwaysSecure}->{$name}
		and !$CGI::secure) {
		$name = find_special_page('violation');
	}

	$page = readin($name);
# TRACK
	if (defined $page) {
		$Vend::Track->view_page($name);
	}
# END TRACK	
		
	my $opt;
	# Try for on-the-fly if not there
	if(! defined $page) {
		$page = Vend::Interpolate::fly_page($name)
			and $opt->{onfly} = 1;
	}

	# Try one last time for page with index
	if(! defined $page and $Vend::Cfg->{DirectoryIndex}) {
		my $try = $name;
		$try =~ s!/*$!/$Vend::Cfg->{DirectoryIndex}!;
		$page = readin($try);
	}

	if (defined $page) {
		::response(::interpolate_html($page, 1, $opt));
		return 1;
	}
	else {
		HTML::Entities::encode($name, $ESCAPE_CHARS::std);
		display_special_page(find_special_page('missing'), $name);
		return 0;
	}
}


# Display the catalog page NAME.

sub do_page {
	display_page();
}

## DO SEARCH
sub do_search {
	my($c) = \%CGI::values;
	::update_user();

	if ($c->{mv_more_matches}) {
		$Vend::Session->{last_search} = "scan/MM=$c->{mv_more_matches}";
		$c->{mv_more_matches} =~ m/([a-zA-Z0-9])+/;
		$c->{mv_cache_key} = $1;
	}
	else {
		create_last_search($c);
	}

	$c->{mv_cache_key} = generate_key($Vend::Session->{last_search})
			unless defined $c->{mv_cache_key};

	$::Instance->{SearchObject}{''} = perform_search($c);
	$CGI::values{mv_nextpage}	= $::Instance->{SearchObject}{''}->{mv_search_page}
							 	|| find_special_page('search')
		if ! $CGI::values{mv_nextpage};
	return 1;
}

# Do SCAN
# Same as search except path is source of search info
sub do_scan {
	my($path) = @_;
	my ($key,$page);

	my $c = {};
	$Vend::ScanPassed = "scan/$path";
	find_search_params($c,$path);

	if ($c->{mv_more_matches}) {
		$Vend::Session->{last_search} = "scan/MM=$c->{mv_more_matches}";
		$Vend::More_in_progress = 1;
		$c->{mv_more_id} = $CGI::values{mv_more_id} || undef;
		$c->{mv_more_matches} =~ m/([a-zA-Z0-9])+/;
		$c->{mv_cache_key} = $1;
		$CGI::values{mv_nextpage} = $c->{mv_nextpage}
			if ! defined $CGI::values{mv_nextpage};
	}
	else {
		$c->{mv_cache_key} = generate_key(create_last_search($c));
	}

	$::Instance->{SearchObject}{''} = perform_search($c);
	$CGI::values{mv_nextpage} = $::Instance->{SearchObject}{''}->{mv_search_page}
							 	|| find_special_page('search')
		if ! $CGI::values{mv_nextpage};
	return 1;
}

1;
