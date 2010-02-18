# Vend::Page - Handle Interchange page routing
# 
# $Id: Page.pm,v 2.26 2008-04-15 19:37:57 racke Exp $
#
# Copyright (C) 2002-2008 Interchange Development Group
# Copyright (C) 1996-2002 Red Hat, Inc.
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
# Software Foundation, Inc., 51 Franklin St, Fifth Floor, Boston,
# MA  02110-1301  USA.

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

$VERSION = substr(q$Revision: 2.26 $, 10);

my $wantref = 1;

sub display_special_page {
	my($name, $subject) = @_;
	my($page);

	undef $Vend::write_redirect;

	$name =~ m/[\[<]|[\@_]_[A-Z]\w+_[\@_]|\@\@[A-Z]\w+\@\@/
		and do {
			::logGlobal(
					"Security violation -- scripting character in page name '%s'.",
					$name,
				);
			$name = find_special_page('violation');
			1 while $subject =~ s/[\@_]_/_/g;
		};

	$subject ||= 'unspecified error';

	my $noname = $name;
	$noname =~ s:^\.\./::;
	
	$page = readfile($noname, $Global::NoAbsolute, 1) || readin($name);

	die ::get_locale_message(412, qq{Missing special page "%s" for subject "%s"\n}, $name, $subject)
		unless defined $page;
	$page =~ s#\[subject\]#$subject#ig;
	$Global::Variable->{MV_SUBJECT} = $subject;
	$Vend::PageInit = 0;
	interpolate_html($page, 1);
	::response();
}

# Displays the catalog page NAME.  If the file is not found, displays
# the special page 'missing'.
# 

sub display_page {
	my($name, $opt) = @_;
	my($page);

	$name ||= $CGI::values{mv_nextpage};

	$name =~ m/[\[<]|[\@_]_[A-Z]\w+_[\@_]|\@\@[A-Z]\w+\@\@/
		and do {
			::logGlobal(
					"Security violation -- scripting character in page name '%s'.",
					$name,
				);
			$name = find_special_page('violation');
			return display_special_page($name);
		};

	if($Vend::Cfg->{ExtraSecure} and
		$Vend::Cfg->{AlwaysSecure}->{$name}
		and !$CGI::secure) {
		$name = find_special_page('violation');
	}

	$page = $Vend::VirtualPage || readin($name);
# TRACK
	if (defined $page && $Vend::Track) {
		$Vend::Track->view_page($name);
	}
# END TRACK	
		
	my $inth_opt;
	# Try for on-the-fly if not there
	if(! defined $page) {
		$page = Vend::Interpolate::fly_page($name)
			and $inth_opt->{onfly} = 1;
	}

	# Try one last time for page with index
	if(! defined $page and $Vend::Cfg->{DirectoryIndex}) {
		my $try = $name;
		$try =~ s!/*$!/$Vend::Cfg->{DirectoryIndex}!;
		$page = readin($try);
	}

	if (defined $page) {
		$Vend::PageInit = 0;
		if ($opt->{return}) {
			return ::interpolate_html($page, 1, $inth_opt);
		} else {
			::interpolate_html($page, 1, $inth_opt);
		}
		::response();
		return 1;
	}
	else {
		my $handled;
		my $newpage;
		if(my $subname = $Vend::Cfg->{SpecialSub}{missing}) {
			my $sub = $Vend::Cfg->{Sub}{$subname} || $Global::GlobalSub->{$subname};
			($handled, $newpage) = $sub->($name)
				if $sub;
		}
		if($handled) {
			return display_page($newpage) if $newpage;
			return 0;
		}
		HTML::Entities::encode($name, $ESCAPE_CHARS::std);
		display_special_page(find_special_page('missing'), $name);
		return 0;
	}
}


# Display the catalog page NAME.

sub do_page {
	display_page();
}

sub _check_search_file {
	my ($c) = @_;
	my $f;

	if ($c->{mv_search_file}) {
		my(@files) = grep /\S/, split /\s*[,\0]\s*/, $c->{mv_search_file}, -1;
		for $f (@files) {
			unless (grep { $f eq $_ } @{$Vend::Cfg->{AllowRemoteSearch}}) {
				::logGlobal("Security violation, trying to remote search '%s', doesn't match '%s'",
					$f, join ',' => @{$Vend::Cfg->{AllowRemoteSearch}});
				die "Security violation";
			}
		}
	}
}

## DO SEARCH
sub do_search {
	my($c) = @_;
	::update_user();

	# If search parameters not passed in via function, then safely pull them from
	# the CGI values.
	if (!is_hash($c)) {
		$c = find_search_params(\%CGI::values);
		_check_search_file($c);
	}

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

	my $retval = perform_search($c);
	
	if (ref($retval)) {
		$::Instance->{SearchObject}{''} = $retval;
		$CGI::values{mv_nextpage}	= $retval->{mv_search_page}
			|| find_special_page('search')
				if ! $CGI::values{mv_nextpage};
	}
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

	_check_search_file($c);

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

sub output_test {
	my ($tag) = @_;
	my $ary;
	return '' unless $ary = $Vend::OutPtr{lc $tag};
	for(@$ary) {
		next unless $Vend::Output[$_];
		next unless length(${$Vend::Output[$_]});
		return 1;
	}
	return '';
}

sub output_cat {
	my ($tag) = @_;
	my $ary;
	return '' unless $ary = $Vend::OutPtr{lc $tag};
	my $out = '';
	for(@$ary) {
		next unless $Vend::Output[$_];
		$out .= ${$Vend::Output[$_]};
		undef $Vend::Output[$_];
	}
	$out =~ s/^\s+// if $::Pragma->{strip_white};
	return $out;
}

sub output_ary {
	my ($tag) = @_;
	my $ary;
	return '' unless $ary = $Vend::OutPtr{lc $tag};
	my @out;
	for(@$ary) {
		next unless $Vend::Output[$_];
		push @out, ${$Vend::Output[$_]};
		undef $Vend::Output[$_];
	}
	return \@out;
}

sub output_rest {
	my ($tag) = @_;
	my $out = '';
	for(@$Vend::Output) {
		next unless $_;
		$out .= ${$Vend::Output[$_]};
		undef $Vend::Output[$_];
	}
	return $out;
}

sub templatize {
	my ($template) = @_;
	$template ||= $Vend::Cfg->{PageTemplate} || '{:REST}';
#::logDebug("Templatizing, template length=" . length($template));
	my $body = $template;

	$body =~ s!\{\{\@([A-Z][A-Z_0-9]*[A-Z0-9])\}\}(.*?)\{\{/\@\1\}\}!
					my $tag = lc $1;
					my $ary;
					return '' unless $ary = $Vend::OutPtr{$tag};
					my $tpl = $2;
					my $out = '';
					for(@$ary) {
						my $ref = $Vend::Output[$_]
							or next;
						my $chunk = $tpl;
						$chunk =~ s/\{$tag\}/$$ref/;
						undef $Vend::Output[$_];
						$out .= $chunk;
					}
					$out;
				!sge;
	1 while $body =~ s!\{\{([A-Z][A-Z_0-9]*[A-Z0-9])\?\}\}(.*?)\{\{/\1\?\}\}! output_test(lc $1) ? $2 : ''!egs;
	1 while $body =~ s!\{\{([A-Z][A-Z_0-9]*[A-Z0-9])\:\}\}(.*?)\{\{/\1\:\}\}! output_test(lc $1) ? '' : $2!egs;
	$body =~ s!\{\{([A-Z][A-Z_0-9]*[A-Z0-9])\}\}!output_cat($1)!eg;
	$body =~ s!\{\{:DEFAULT\}\}!output_cat('')!e;
	$body =~ s!\{\{:REST\}\}!output_rest('')!e;
	@Vend::Output = (\$body);
}

1;
