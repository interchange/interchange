# Vend::Server - Listen for Interchange CGI requests as a background server
#
# $Id: Server.pm,v 2.0.2.13 2003-01-24 05:00:47 jon Exp $
#
# Copyright (C) 1996-2002 Red Hat, Inc. and
# Interchange Development Group, http://www.icdevgroup.org/
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

package Vend::Server;

use vars qw($VERSION);
$VERSION = substr(q$Revision: 2.0.2.13 $, 10);

use POSIX qw(setsid strftime);
use Vend::Util;
use Fcntl;
use Errno qw/:POSIX/;
use Config;
use Socket;
use Symbol;
use strict;

sub new {
    my ($class, $fh, $env, $entity) = @_;
    populate($env);
    my $http = {
					fh => $fh,
					entity => $entity,
					env => $env,
				};
	eval {
		map_cgi($http);
	};
	if($@) {
		my $msg = errmsg("CGI mapping error: %s", $@);
		::logGlobal({ level => 'error' }, $msg);
		return undef;
	}
    bless $http, $class;
}

my @Map =
    (
     'authorization' => 'AUTHORIZATION',
     'content_length' => 'CONTENT_LENGTH',
     'content_type' => 'CONTENT_TYPE',
     'content_encoding' => 'HTTP_CONTENT_ENCODING',
     'cookie' => 'HTTP_COOKIE',
     'http_host' => 'HTTP_HOST',
     'path_info' => 'PATH_INFO',
     'pragma' => 'HTTP_PRAGMA',
     'query_string' => 'QUERY_STRING',
     'referer' => 'HTTP_REFERER',
     'remote_addr' => 'REMOTE_ADDR',
     'remote_host' => 'REMOTE_HOST',
     'remote_user' => 'REMOTE_USER',
     'request_method', => 'REQUEST_METHOD',
     'script_name' => 'SCRIPT_NAME',
     'secure' => 'HTTPS',
     'server_name' => 'SERVER_NAME',
     'server_host' => 'HTTP_HOST',
     'server_port' => 'SERVER_PORT',
     'useragent' => 'HTTP_USER_AGENT',
);

### This is to account for some bad Socket.pm implementations
### which don't set SOMAXCONN, I think SCO is the big one

my $SOMAXCONN;
if(defined &SOMAXCONN) {
	$SOMAXCONN = SOMAXCONN;
}
else {
	$SOMAXCONN = 128;
}

###
###

sub populate {
    my ($cgivar) = @_;

	if($Global::Environment) {
		for(@{$Global::Environment}) {
			$ENV{$_} = $cgivar->{$_} if defined $cgivar->{$_};
		}
	}   

    my @map = @Map;
    my ($field, $cgi);
	no strict 'refs';
    while (($field, $cgi) = splice(@map, 0, 2)) {
        ${"CGI::$field"} = $cgivar->{$cgi} if defined $cgivar->{$cgi};
#::logDebug("CGI::$field=" . ${"CGI::$field"});
    }
}

sub log_http_data {
	return unless $Global::Logging > 4;
	my $ref = shift;
	my @parms = split /\s+/,
	 ($Global::Syslog->{http_items} ||
		q{
			REQUEST_URI
			HTTP_COOKIE
			SERVER_NAME
			REMOTE_ADDR
			HTTP_HOST
			HTTP_USER_AGENT
			REMOTE_USER
		});
	my $string = 'access: ';
	for(@parms) {
		next unless $ref->{env}{$_};
		$string .= " $_=$ref->{env}{$_}";
	}
	::logGlobal( { level => 'info' }, $string);
	return unless $Global::Logging > 5;
	my $ent = $ref->{entity};
	return unless $$ent;
	::logGlobal( { level => 'debug' }, "POST=" . $$ent);
	return;
}

sub map_misc_cgi {
	$CGI::user = $CGI::remote_user;
	$CGI::host = $CGI::remote_host || $CGI::remote_addr;

	$CGI::script_path = $CGI::script_name;
	$CGI::script_name = $CGI::server_host . $CGI::script_path
		if $Global::FullUrl;
}

sub map_cgi {
	my $h = shift;
    die "REQUEST_METHOD is not defined" unless defined $CGI::request_method
		or @Global::argv;

	map_misc_cgi() if $h;

	my $g = $Global::Selector{$CGI::script_name}
		or do {
			my $msg = ::get_locale_message(
						404,
						"Undefined catalog: %s",
						$CGI::script_name,
						);
			my $content_type = $msg =~ /<html/i ? 'text/html' : 'text/plain';
			my $len = length($msg);
			$Vend::StatusLine = <<EOF;
Status: 404 Not found
Content-Type: $content_type
Content-Length: $len
EOF
			respond('', \$msg);
			die($msg);
		};

	($::IV, $::VN, $::SV) = $g->{VarName}
			? ($g->{IV}, $g->{VN}, $g->{IgnoreMultiple})
			: ($Global::IV, $Global::VN, $Global::IgnoreMultiple);

#::logDebug("CGI::query_string=" . $CGI::query_string);
#::logDebug("entity=" . ${$h->{entity}});
	if ("\U$CGI::request_method" eq 'POST') {
		if ($Global::TolerateGet) {
			parse_post(\$CGI::query_string);
			parse_post($h->{entity}, 1);
		}
		else {
			parse_post($h->{entity});
		}
	}
	else {
		 parse_post(\$CGI::query_string);
	}

}

# This is called by parse_multipart
# Doesn't do unhexify
sub store_cgi_kv {
	my ($key, $value) = @_;
	$key = $::IV->{$key} if defined $::IV->{$key};
	if(defined $CGI::values{$key} and ! defined $::SV{$key}) {
		$CGI::values{$key} = "$CGI::values{$key}\0$value";
		push ( @{$CGI::values_array{$key}}, $value)
	}
	else {
		$CGI::values{$key} = $value;
		$CGI::values_array{$key} = [$value];
	}
}

sub parse_post {
	my ($sref, $preserve) = @_;
	my(@pairs, $pair, $key, $value);
	undef %CGI::values unless $preserve;
	return unless length $$sref;
	if ($CGI::content_type =~ /^multipart/i) {
		return parse_multipart($sref) if $CGI::useragent !~ /MSIE\s+5/i;
		# try and work around an apparent IE5 bug that sends the content type
		# of the next POST after a multipart/form POST as multipart also -
		# even though it's sent as non-multipart data
		# Contributed by Bill Randle
		my ($boundary) = $CGI::content_type =~ /boundary=\"?([^\";]+)\"?/;
		$boundary = '--' . quotemeta $boundary;
		return parse_multipart($sref) if $$sref =~ /^\s*$boundary\s+/;
	}
	@pairs = split($Global::UrlSplittor, $$sref);
	if( defined $pairs[0] and $pairs[0] =~ /^	(\w{8,32})? ; /x)  {
		@CGI::values{qw/ mv_session_id mv_arg mv_pc /}
			= split /;/, $pairs[0], 3;
#::logDebug("found session stuff: $CGI::values{mv_session_id} --> $CGI::values{mv_arg}  --> $CGI::values{mv_pc} ");
		shift @pairs;
	}
	elsif ($#pairs == 1 and $pairs[0] !~ /=/) {	# Must be an isindex
		$CGI::values{ISINDEX} = $pairs[0];
		$CGI::values_array{ISINDEX} =  [ split /\+/, $pairs[0] ];
		@pairs = ();
	}
	my $redo;
  CGIVAL: {
  	# This loop semi-duplicated in store_cgi_kv
	foreach $pair (@pairs) {
		($key, $value) = ($pair =~ m/([^=]+)=(.*)/)
			or do {
				if ($Global::TolerateGet) {
					$key = $pair;
					$value = undef;
				}
				elsif($CGI::request_method =~ /^post$/i) {
					die ::errmsg("Syntax error in POST input: %s\n%s", $pair, $$sref);
				}
				else {
					die ::errmsg("Syntax error in GET input: %s\n", $pair);
				}
			};

#::logDebug("incoming --> $key");
		$key = $::IV->{$key} if defined $::IV->{$key};
		$key =~ s/%([0-9a-fA-F][0-9a-fA-F])/chr(hex $1)/ge;
#::logDebug("mapping  --> $key");
		$value =~ tr/+/ /;
		$value =~ s/%([0-9a-fA-F][0-9a-fA-F])/chr(hex $1)/ge;
		# Handle multiple keys
		if(defined $CGI::values{$key} and ! defined $::SV{$key}) {
			$CGI::values{$key} = "$CGI::values{$key}\0$value";
			push ( @{$CGI::values_array{$key}}, $value)
		}
		else {
			$CGI::values{$key} = $value;
			$CGI::values_array{$key} = [$value];
		}
	}
	if (! $redo and "\U$CGI::request_method" eq 'POST') {
		@pairs = split $Global::UrlSplittor, $CGI::query_string;
		if( defined $pairs[0] and $pairs[0] =~ /^	(\w{8,32}) ; /x)  {
			my (@old) = split /;/, $pairs[0], 3;
			$CGI::values{mv_session_id} = $old[0]
				if ! defined $CGI::values{mv_session_id};
			$CGI::values{mv_arg} = $old[1]
				if ! defined $CGI::values{mv_arg};
			$CGI::values{mv_pc} = $old[3]
				if ! defined $CGI::values{mv_pc};
#::logDebug("found session stuff: $CGI::values{mv_session_id} --> $CGI::values{mv_arg}  --> $CGI::values{mv_pc} ");
			shift @pairs;
		}
		$redo = 1;
	}
  } # End CGIVAL
}

sub parse_multipart {
	my $sref = shift;
	my ($boundary) = $CGI::content_type =~ /boundary=\"?([^\";]+)\"?/;
	$boundary = quotemeta $boundary;
#::logDebug("got to multipart");
	# Stolen from CGI.pm, thanks Lincoln
	$boundary = "--$boundary"
		unless $CGI::useragent =~ /MSIE 3\.0[12];  Mac/i;
	unless ($$sref =~ s/^\s*$boundary\s+//) {
		die ::errmsg("multipart/form-data sent incorrectly:\n%s\n", $$sref);
	}

	my @parts;
	@parts = split /\r?\n$boundary/, $$sref;
	
#::logDebug("multipart: " . scalar @parts . " parts");

	DOMULTI: {
		for (@parts) {	
		    last if ! $_ || ($_ =~ /^--(\r?\n)?$/);
			s/^\s+//;
			my($header, $data) = split /\r?\n\r?\n/, $_, 2;
			my $token = '[-\w!\#$%&\'*+.^_\`|{}~]';
			my %header;
			$header =~ s/\r?\n\s+/ /og;           # merge continuation lines
			while ($header=~/($token+):\s+([^\r\n]*)/mgox) {
				my ($field_name,$field_value) = ($1,$2); # avoid taintedness
				$field_name =~ s/\b(\w)/uc($1)/eg; #canonicalize
				$header{$field_name} = $field_value;
			}

#::logDebug("Content-Disposition: " .  $header{'Content-Disposition'});
			my($param)= $header{'Content-Disposition'}=~/ name="?([^\";]*)"?/;

			# Bug:  Netscape doesn't escape quotation marks in file names!!!
			my($filename) = $header{'Content-Disposition'}=~/ filename="?([^\";]*)"?/;
#::logDebug("param='$param' filename='$filename'" );
			if(! $param) {
				::logGlobal({ level => 'debug' }, "unsupported multipart header: \n%s\n", $header);
				next;
			}

			if($filename) {
				$CGI::file{$param} = $data;
				$data = $filename;
			}
			else {
				$data =~ s/\r?\n$//;
			}
			store_cgi_kv($param, $data);
		}
	}
	return 1;
}

sub create_cookie {
	my($domain,$path) = @_;
	my  $out;
	my @jar;
	push @jar, [
				($::Instance->{CookieName} || 'MV_SESSION_ID'),
				defined $::Instance->{ClearCookie} ? '' : $Vend::SessionName,
				$Vend::Expire || undef,
			]
		unless $Vend::CookieID;
	push @jar, ['MV_STATIC', 1] if $Vend::Cfg->{Static};
	push @jar, @{$::Instance->{Cookies}}
		if defined $::Instance->{Cookies};
	$out = '';
	foreach my $cookie (@jar) {
		my ($name, $value, $expire, $d, $p) = @$cookie;
		$d = $domain if ! $d;
		$p = $path   if ! $p;
#::logDebug("create_cookie: name=$name value=$value expire=$expire");
		$value = Vend::Interpolate::esc($value) 
			if $value !~ /^[-\w:.]+$/;
		$out .= "Set-Cookie: $name=$value;";
		$out .= " path=$p;";
		$out .= " domain=" . $d . ";" if $d;
		if (defined $expire or $Vend::Expire) {
			my $expstring;
			if(! $expire) {
				$expire = $Vend::Expire;
			}
			elsif($expire =~ /\s\S+\s/) {
				$expstring = $expire;
			}
			$expstring = strftime "%a, %d-%b-%Y %H:%M:%S GMT ", gmtime($expire)
				unless $expstring;
			$expstring = "expires=$expstring" if $expstring !~ /^\s*expires=/i;
			$expstring =~ s/^\s*/ /;
			$out .= $expstring;
		}
		$out .= "\r\n";
	}
	return $out;
}

sub canon_status {
	local($_);
	$_ = shift;
	s:^\s+::;
	s:\s+$::;
	s:\s*\n\s*:\r\n:g;
	return "$_\r\n";
}

sub respond {
	# $body is now a reference
    my ($s, $body) = @_;
#show_times("begin response send") if $Global::ShowTimes;
	my $status;
	if($Vend::StatusLine) {
		$status = $Vend::StatusLine =~ /(?:^|\n)Status:\s+(.*)/i
				? "$1"
				: "200 OK";
	}

	$$body =~ s/^\s+//
		if ! $Vend::ResponseMade and $Vend::Cfg->{Pragma}{strip_white};

	if(! $s and $Vend::StatusLine) {
		$Vend::StatusLine = "HTTP/1.0 $status\r\n$Vend::StatusLine"
			if defined $Vend::InternalHTTP
				and $Vend::StatusLine !~ m{^HTTP/};
		$Vend::StatusLine .= ($Vend::StatusLine =~ /^Content-Type:/im)
							? '' : "\r\nContent-Type: text/html\r\n";
# TRACK
        $Vend::StatusLine .= "X-Track: " . $Vend::Track->header() . "\r\n"
			if $Vend::Track;
# END TRACK        
        $Vend::StatusLine .= "Pragma: no-cache\r\n"
			if delete $::Scratch->{mv_no_cache};
		print MESSAGE canon_status($Vend::StatusLine);
		print MESSAGE "\r\n";
		print MESSAGE $$body;
		undef $Vend::StatusLine;
		$Vend::ResponseMade = 1;
#show_times("end response send") if $Global::ShowTimes;
		return;
	}

    my $fh = $s->{fh};

# SUNOSDIGITAL
#	 Fix for SunOS, Ultrix, Digital UNIX
#	my($oldfh) = select($fh);
#	$| = 1;
#	select($oldfh);
# END SUNOSDIGITAL

	if($Vend::ResponseMade || $CGI::values{mv_no_header} ) {
		print $fh $$body;
#show_times("end response send") if $Global::ShowTimes;
		return 1;
	}

	if (defined $Vend::InternalHTTP or defined $ENV{MOD_PERL} or $CGI::script_name =~ m:/nph-[^/]+$:) {
# TRACK
		my $save = select $fh;
		$| = 1;
		select $save;
        $Vend::StatusLine .= "X-Track: " . $Vend::Track->header() . "\r\n";
# END TRACK                            
        $Vend::StatusLine .= "Pragma: no-cache\r\n"
			if delete $::Scratch->{mv_no_cache};
		$status = '200 OK' if ! $status;
		if(defined $Vend::StatusLine) {
			$Vend::StatusLine = "HTTP/1.0 $status\r\n$Vend::StatusLine"
				if $Vend::StatusLine !~ m{^HTTP/};
			print $fh canon_status($Vend::StatusLine);
			$Vend::ResponseMade = 1;
			undef $Vend::StatusLine;
		}
		else { print $fh "HTTP/1.0 $status\r\n"; }
	}

	if ( (	! $Vend::CookieID && ! $::Instance->{CookiesSet}
			or defined $Vend::Expire
			or defined $::Instance->{Cookies}
		  )
			and $Vend::Cfg->{Cookies}
		)
	{

		my @domains;
		@domains = ('');
		if ($Vend::Cfg->{CookieDomain}) {
			@domains = split /\s+/, $Vend::Cfg->{CookieDomain};
		}

		my @paths;
		@paths = ('/');
		if($Global::Mall) {
			my $ref = $Global::Catalog{$Vend::Cat};
			@paths = ($ref->{script});
			push (@paths, @{$ref->{alias}}) if defined $ref->{alias};
			if ($Global::FullUrl) {
				# remove domain from script
				for (@paths) { s:^[^/]+/:/: ; }
			}
		}

		my ($d, $p);
		foreach $d (@domains) {
			foreach $p (@paths) {
				print $fh create_cookie($d, $p);
			}
		}
		$::Instance->{CookiesSet} = delete $::Instance->{Cookies};
    }

    if (defined $Vend::StatusLine) {
		print $fh canon_status($Vend::StatusLine);
	}
	elsif(! $Vend::ResponseMade) {        
		print $fh canon_status("Content-Type: text/html");
# TRACK        
        print $fh canon_status("X-Track: " . $Vend::Track->header())
			if $Vend::Track;
# END TRACK
	}
	print $fh canon_status("Pragma: no-cache")
		if delete $::Scratch->{mv_no_cache};

    print $fh "\r\n";
    print $fh $$body;
#show_times("end response send") if $Global::ShowTimes;
    $Vend::ResponseMade = 1;
}

sub _read {
    my ($in, $fh) = @_;
	$fh = \*MESSAGE if ! $fh;
    my ($r);
    
    do {
        $r = sysread($fh, $$in, 512, length($$in));
    } while (!defined $r and $!{eintr});
    die "read: $!" unless defined $r;
    die "read: closed" unless $r > 0;
}

sub _find {
    my ($in, $char) = @_;
    my ($x);

    _read($in) while (($x = index($$in, $char)) == -1);
    my $before = substr($$in, 0, $x);
    substr($$in, 0, $x + 1) = '';
    $before;
}

sub _string {
    my ($in) = @_;
    my $len = _find($in, " ");
    _read($in) while (length($$in) < $len + 1);
    my $str = substr($$in, 0, $len);
    substr($$in, 0, $len + 1) = '';
    $str;
}

my $HTTP_enabled;
my $Remote_addr;
my $Remote_host;
my %CGImap;
my %CGIspecial;

BEGIN {
	eval {
		require URI::URL;
		require MIME::Base64;
		$HTTP_enabled = 1;
		%CGImap = ( qw/
				content-length       CONTENT_LENGTH
				content-type         CONTENT_TYPE
                authorization-type   AUTH_TYPE
                authorization        AUTHORIZATION
				cookie               HTTP_COOKIE
                client-hostname      REMOTE_HOST
                client-ip-address    REMOTE_ADDR
                client-ident         REMOTE_IDENT
                content-length       CONTENT_LENGTH
                content-type         CONTENT_TYPE
                cookie               HTTP_COOKIE
                from                 HTTP_FROM
                host                 HTTP_HOST
                https-on             HTTPS
                method               REQUEST_METHOD
                path-info            PATH_INFO
                path-translated      PATH_TRANSLATED
                pragma               HTTP_PRAGMA
                query                QUERY_STRING
                reconfigure          RECONFIGURE_MINIVEND
                referer              HTTP_REFERER
                script               SCRIPT_NAME
                server-host          SERVER_NAME
                server-port          SERVER_PORT
                user-agent           HTTP_USER_AGENT
                content-encoding     HTTP_CONTENT_ENCODING
                content-language     HTTP_CONTENT_LANGUAGE
                content-transfer-encoding HTTP_CONTENT_TRANSFER_ENCODING

					/
		);
		%CGIspecial = ();
	};
										 
}                                    

sub http_log_msg {
	my($status, $env, $request) = @_;
	my(@params);

	# IP, Session, REMOTE_USER (if any) and time
    push @params, ($$env{REMOTE_HOST} || $$env{REMOTE_ADDR});
	push @params, ($$env{SERVER_PORT} || '-');
	push @params, ($$env{REMOTE_USER} || '-');
	push @params, logtime();

	# Catalog name
	push @params, qq{"$request"};

	push @params, $status;

	push @params, '-';
	return join " ", @params;
}

sub http_soap {
	my($fh, $env, $entity) = @_;

	my $in = '';
	die "Need URI::URL for this functionality.\n"
		unless defined $HTTP_enabled;

	my ($real_header, $header, $request, $block);
	my $waiting = 0;
	my $status_line = _find(\$in, "\n");
#::logDebug("status_line: $status_line");
	($$env{REQUEST_METHOD},$request) = split /\s+/, $status_line;
	for(;;) {
        $block = _find(\$in, "\n");
#::logDebug("read: $block");
		$block =~ s/\s+$//;
		if($block eq '') {
			last;
		}
		if ( $block =~ s/^([^:]+):\s*//) {
			$real_header = $1;
			$header = lc $1;
			
			if(defined $CGImap{$header}) {
#::logDebug("setting env{$CGImap{$header}} to: $block");
				$$env{$CGImap{$header}} = $block;
			}
			$$env{$real_header} = $block;
			next;
		}
		else {
			die "HTTP protocol error on '$block':\n$in";
		}
		last;
	}

	if ($$env{CONTENT_LENGTH}) {
		_read(\$in) while length($in) < $$env{CONTENT_LENGTH};
#::logDebug("read entity: $in");
	}
	$in =~ s/\s+$//;
	$$entity = $in;

#::logDebug("exiting loop");
	my $url = new URI::URL $request;

	(undef, $Remote_addr) =
				sockaddr_in(getpeername($fh));
	$$env{REMOTE_HOST} = gethostbyaddr($Remote_addr, AF_INET);
	$Remote_addr = inet_ntoa($Remote_addr);

	$$env{REMOTE_ADDR} = $Remote_addr;

	my (@path) = $url->path_components();
	my $doc;
	my $status = 200;

	shift(@path);
	my $catname = '/'.shift(@path);
	$$env{SESSION_ID} = shift(@path);

#::logDebug("catname is $catname");

	if($Global::Selector{$catname} and $Global::AllowGlobal->{$catname}) {
		if ($$env{AUTHORIZATION}) {
			$$env{REMOTE_USER} =
					Vend::Util::check_authorization( delete $$env{AUTHORIZATION} );
		}
		return undef if ! $$env{REMOTE_USER};
	}

	my $ref;
	if($ref = $Global::Selector{$catname} || $Global::SelectorAlias{$catname}) {
#::logDebug("found catalog $catname");
		$$env{SCRIPT_NAME} = $catname;
	}

	logData("$Global::VendRoot/etc/access_log",
			http_log_msg(
						"SOAP$status",
						$env,
						($$env{REQUEST_METHOD} .  " " .  $request),
						)
		);

	populate($env);
	map_misc_cgi();
	return $ref;
}

sub http_server {
	my($status_line, $in, $argv, $env, $entity) = @_;

	die "Need URI::URL for this functionality.\n"
		unless defined $HTTP_enabled;

	$Vend::InternalHTTP = 1;
	my ($header, $request, $block);
	my $waiting = 0;
	($$env{REQUEST_METHOD},$request) = split /\s+/, $status_line;
	for(;;) {
        $block = _find(\$in, "\n");
#::logDebug("read: $block");
		$block =~ s/\s+$//;
		if($block eq '') {
			last;
		}
		if ( $block =~ s/^([^:]+):\s*//) {
			$header = lc $1;
			if(defined $CGImap{$header}) {
				$$env{$CGImap{$header}} = $block;
			}
			elsif(defined $CGIspecial{$header}) {
				&{$CGIspecial{$header}}($env, $block);
			}
			# else { throw_away() }
			next;
		}
		else {
			die "HTTP protocol error on '$block':\n$in";
		}
		last;
	}

	if ($$env{CONTENT_LENGTH}) {
		_read(\$in) while length($in) < $$env{CONTENT_LENGTH};
	}
	$in =~ s/\s+$//;
	$$entity = $in;

#::logDebug("exiting loop");
	my $url = new URI::URL $request;
	@{$argv} = $url->keywords();

	(undef, $Remote_addr) =
				sockaddr_in(getpeername(MESSAGE));
	$$env{REMOTE_HOST} = gethostbyaddr($Remote_addr, AF_INET);
	$Remote_addr = inet_ntoa($Remote_addr);

	$$env{QUERY_STRING} = $url->equery();
	$$env{REMOTE_ADDR} = $Remote_addr;

	my (@path) = $url->path_components();
	my $path = $url->path();
	if($path =~ m{\.\./}) {
		logGlobal("Attempted breakin using path=$path, will show 404");
		$path =~ s{\.\./}{}g;
	}
	my $doc;
	my $status = 200;

	shift(@path);
	my $catname = shift(@path);

	if ($Global::TcpMap->{$Global::TcpPort} =~ /^\w+/) {
		$catname = $Global::TcpMap->{$Global::TcpPort};
	}
	my $cat = "/$catname";

	if($Global::Selector{$cat} and $Global::AllowGlobal->{$cat}) {
		if ($$env{AUTHORIZATION}) {
			$$env{REMOTE_USER} =
					Vend::Util::check_authorization( delete $$env{AUTHORIZATION} );
		}
		if (! $$env{REMOTE_USER}) {
			$Vend::StatusLine = <<EOF;
HTTP/1.0 401 Unauthorized
WWW-Authenticate: Basic realm="Interchange Admin"
EOF
			$doc = "Requires correct username and password.\n";
			$path = '';
		}
	}

	if($Global::Selector{$cat} || $Global::SelectorAlias{$cat}) {
		$$env{SCRIPT_NAME} = $cat;
		$$env{PATH_INFO} = join "/", '', @path;
	}
	elsif(-f "$Global::VendRoot/doc$path") {
		$Vend::StatusLine = "HTTP/1.0 200 OK";
		$doc = readfile("$Global::VendRoot/doc$path");
	}
	else {
		$status = 404;
		$Vend::StatusLine = "HTTP/1.0 404 Not found";
		$doc = "Not an Interchange catalog or help file.\n";
	}

	if($$env{REQUEST_METHOD} eq 'HEAD') {
		$Vend::StatusLine = "HTTP/1.0 200 OK\nLast-modified: "
			. Vend::Util::logtime;
		$doc = '';
	}

	logData("$Global::VendRoot/etc/access_log",
			http_log_msg(
						$status,
						$env,
						($$env{REQUEST_METHOD} .  " " .  $request),
						)
		);

	if (defined $doc) {
		my $type = Vend::Util::mime_type($path);
		$Vend::StatusLine = '' unless defined $Vend::StatusLine;
		$Vend::StatusLine .= "\r\nContent-type: $type";
		respond(
					'',
					\$doc,
				);
		return;
	}
	return 1;
}

sub read_cgi_data {
    my ($argv, $env, $entity) = @_;
    my ($in, $block, $n, $i, $e, $key, $value);
    $in = '';

    for (;;) {
        $block = _find(\$in, "\n");
		if (($n) = ($block =~ m/^env (\d+)$/)) {
            foreach $i (0 .. $n - 1) {
                $e = _string(\$in);
                if (($key, $value) = ($e =~ m/^([^=]+)=(.*)$/s)) {
                    $$env{$key} = $value;
                }
            }
        }
		elsif ($block =~ m/^end$/) {
            last;
        }
		elsif ($block =~ m/^entity$/) {
            $$entity = _string(\$in);
		}
        elsif ($block =~ m/^[GPH]/) {
           	return http_server($block, $in, @_);
        }
		elsif (($n) = ($block =~ m/^arg (\d+)$/)) {
            $#$argv = $n - 1;
            foreach $i (0 .. $n - 1) {
                $$argv[$i] = _string(\$in);
            }
        }
		else {
			die "Unrecognized block: $block\n";
        }
    }
	if($Vend::OnlyInternalHTTP) {
		my $msg = ::errmsg(
						"attempt to connect from unauthorized host '%s'",
						$Vend::OnlyInternalHTTP,
					);
		::logGlobal({ level => 'alert' }, $msg);
		die "$msg\n";
	}
	return 1;
}


sub connection {
    my (%env, $entity);

  ### This resets all $Vend::variable settings so we start
  ### completely initialized. It only affects the Vend package,
  ### not any Vend::XXX packages.
	reset_vars();

	if($Global::ShowTimes) {
		@Vend::Times = times();
		::logDebug ("begin connection. Summary time set to zero");
	}
    read_cgi_data(\@Global::argv, \%env, \$entity)
    	or return 0;
    show_times('end cgi read') if $Global::ShowTimes;

    my $http = new Vend::Server \*MESSAGE, \%env, \$entity;

	# Can log all CGI inputs
	log_http_data($http) if $Global::Logging;

	show_times("begin dispatch") if $Global::ShowTimes;
    ::dispatch($http) if $http;
	show_times("end connection") if $Global::ShowTimes;
	undef $Vend::Cfg;
}

## Signals

my $Signal_Terminate;
my $Signal_Restart;
my %orig_signal;
my @trapped_signals = qw(INT TERM);


my $ipc;
my $tick;

my %fh_map;
my %vec_map;

my %s_vec_map;
my %s_fh_map;

my %ipc_socket;
my %unix_socket;

use vars qw(
			$Num_servers
			$Page_servers
			%Page_pids
			$SOAP_servers
			%SOAP_pids
			$vector
			$p_vector
			$s_vector
			$ipc_vector
			);
BEGIN {
	$s_vector = '';
}
$Num_servers = 0;
$SOAP_servers = 0;

# might also trap: QUIT

my ($Routine_USR1, $Routine_USR2, $Routine_HUP, $Routine_TERM, $Routine_INT);
my ($Sig_inc, $Sig_dec, $Counter);

unless ($Global::Windows) {
	push @trapped_signals, qw(HUP USR1 USR2);
	$Routine_USR1 = sub { $SIG{USR1} = $Routine_USR1; $Num_servers++};
	$Routine_USR2 = sub { $SIG{USR2} = $Routine_USR2; $Num_servers--};
	$Routine_HUP  = sub { $SIG{HUP} = $Routine_HUP; $Signal_Restart = 1};
}

$Routine_TERM = sub { $SIG{TERM} = $Routine_TERM; $Signal_Terminate = 1 };
$Routine_INT  = sub { $SIG{INT} = $Routine_INT; $Signal_Terminate = 1 };

sub reset_vars {
	package Vend;
	reset 'A-Z';
	reset 'a-z';
	package CGI;
	reset 'A-Z';
	reset 'a-z';
	srand();
#::logDebug("Reset vars");
}

sub reset_per_fork {
	%Vend::Table::DBI::DBI_connect_cache = ();
	%Vend::Table::DBI::DBI_connect_bad = ();
}

sub clean_up_after_fork {
	for(values %Vend::Table::DBI::DBI_connect_cache) {
		next if ! ref $_;
		$_->disconnect();
	}
	%Vend::Table::DBI::DBI_connect_cache = ();
	%Vend::Table::DBI::DBI_connect_bad = ();
}

sub setup_signals {
    @orig_signal{@trapped_signals} =
        map(defined $_ ? $_ : 'DEFAULT', @SIG{@trapped_signals});
    $Signal_Terminate = '';
    $SIG{PIPE} = 'IGNORE';

	if ($Global::Windows) {
		$SIG{INT}  = sub { $Signal_Terminate = 1; };
		$SIG{TERM} = sub { $Signal_Terminate = 1; };
	}
	else  {
		$SIG{INT}  = sub { $Signal_Terminate = 1; };
		$SIG{TERM} = sub { $Signal_Terminate = 1; };
		$SIG{HUP}  = sub { $Signal_Restart = 1; };
		$SIG{USR1} = sub { $Num_servers++; };
		$SIG{USR2} = sub { $Num_servers--; };
	}

	if(! $Global::MaxServers) {
        $Sig_inc = sub { 1 };
        $Sig_dec = sub { 1 };
	}
    else {
        $Sig_inc = sub { kill "USR1", $Vend::MasterProcess; };
        $Sig_dec = sub { kill "USR2", $Vend::MasterProcess; };
    }
}

sub restore_signals {
    @SIG{@trapped_signals} = @orig_signal{@trapped_signals};
}

my $Last_housekeeping = 0;

# Reconfigure any catalogs that have requested it, and 
# check to make sure we haven't too many running servers
sub housekeeping {
	my ($interval) = @_;
	my $now = time;

#::logDebug("called housekeeping");
	return if defined $interval and ($now - $Last_housekeeping < $interval);

#::logDebug("actually doing housekeeping interval=$interval now=$now last=$Last_housekeeping");
	rand();
	$Last_housekeeping = $now;

	my ($c, $num,$reconfig, $restart, @files);
	my @pids;

		if($Global::PreFork) {
			my @bad_pids;
			my (@pids) = sort keys %Page_pids;
			my $count = scalar @pids;
			while ($count > ($Global::StartServers + 1) ) {
#::logDebug("too many pids");
				my ($bad) = shift(@pids);
#::logDebug("scheduling %s for death", $bad);
				push @bad_pids, $bad;
				$count--;
			}

			foreach my $pid (@pids) {
				kill(0, $pid) and next;
#::logDebug("Unresponsive server at PID %s", $pid);
				push @bad_pids, $pid;
			}

			while($count < $Global::StartServers) {
#::logDebug("Spawning page server to reach StartServers");
				start_page(undef,$Global::PreFork,1);
				$count++;
			}
			for my $pid (@bad_pids) {
#::logDebug("Killing excess or unresponsive server at PID %s", $pid);
				if(kill 'TERM', $pid) {
#::logDebug("Server at PID %s terminated OK", $pid);
					# This is OK
				}
				elsif (kill 'TERM', $pid) {
					::logGlobal("page server pid %s required KILL", $pid);
				}
				else {
					::logGlobal("page server pid %s won't die!", $pid);
				}
				delete $Page_pids{$pid};
			}
		}

		opendir(Vend::Server::CHECKRUN, $Global::RunDir)
			or die "opendir $Global::RunDir: $!\n";
		@files = readdir Vend::Server::CHECKRUN;
		closedir(Vend::Server::CHECKRUN)
			or die "closedir $Global::RunDir: $!\n";
		($reconfig) = grep $_ eq 'reconfig', @files;
		($restart) = grep $_ eq 'restart', @files
			if $Signal_Restart || $Global::Windows;
		if($Global::PIDcheck) {
			$Num_servers = 0;
			@pids = grep /^pid\.\d+$/, @files;
		}

		my $respawn;

		if (defined $restart) {
			$Signal_Restart = 0;
			open(Vend::Server::RESTART, "+<$Global::RunDir/restart")
				or die "open $Global::RunDir/restart: $!\n";
			lockfile(\*Vend::Server::RESTART, 1, 1)
				or die "lock $Global::RunDir/restart: $!\n";
			while(<Vend::Server::RESTART>) {
				chomp;
				my ($directive,$value) = split /\s+/, $_, 2;
				if($value =~ /<<(.*)/) {
					my $mark = $1;
					$value = Vend::Config::read_here(\*Vend::Server::RESTART, $mark);
					unless (defined $value) {
						::logGlobal({ level => 'notice'}, <<EOF, $mark);
Global reconfig ERROR
Can't find string terminator "%s" anywhere before EOF.
EOF
						last;
					}
					chomp $value;
				}
				eval {
					if($directive =~ /^\s*(sub)?catalog$/i) {
						::add_catalog("$directive $value");
					}
					elsif(
							$directive =~ /^remove$/i 		and
							$value =~ /catalog\s+(\S+)/i
						)
					{
						::remove_catalog($1);
					}
					else {
						::change_global_directive($directive, $value);
					}
				};
				if($@) {
					::logGlobal({ level => 'notice' }, $@);
					last;
				}
			}
			unlockfile(\*Vend::Server::RESTART)
				or die "unlock $Global::RunDir/restart: $!\n";
			close(Vend::Server::RESTART)
				or die "close $Global::RunDir/restart: $!\n";
			unlink "$Global::RunDir/restart"
				or die "unlink $Global::RunDir/restart: $!\n";
			$respawn = 1;
		}
		if (defined $reconfig) {
			open(Vend::Server::RECONFIG, "+<$Global::RunDir/reconfig")
				or die "open $Global::RunDir/reconfig: $!\n";
			lockfile(\*Vend::Server::RECONFIG, 1, 1)
				or die "lock $Global::RunDir/reconfig: $!\n";
			while(<Vend::Server::RECONFIG>) {
				chomp;
				my ($script_name,$table,$cfile) = split /\s+/, $_, 3;
				my $select = $Global::SelectorAlias{$script_name} || $script_name;
                my $cat = $Global::Selector{$select};
                unless (defined $cat) {
                    ::logGlobal({ level => 'notice' }, "Bad script name '%s' for reconfig." , $script_name );
                    next;
                }

				eval {
					$c = ::config_named_catalog($cat->{CatalogName},
                                    "from running server ($$)", $table, $cfile);
				};

				if (defined $c) {
					$Global::Selector{$select} = $c;
					for(sort keys %Global::SelectorAlias) {
						next unless $Global::SelectorAlias{$_} eq $select;
						$Global::Selector{$_} = $c;
					}
					::logGlobal({ level => 'notice' }, "Reconfig of %s successful.", $c->{CatalogName});
				}
				else {
					::logGlobal({ level => 'warn' },
						 "Error reconfiguring catalog %s from running server (%s)\n%s",
						 $script_name,
						 $$,
						 $@,
						 );
				}
			}
			unlockfile(\*Vend::Server::RECONFIG)
				or die "unlock $Global::RunDir/reconfig: $!\n";
			close(Vend::Server::RECONFIG)
				or die "close $Global::RunDir/reconfig: $!\n";
			unlink "$Global::RunDir/reconfig"
				or die "unlink $Global::RunDir/reconfig: $!\n";
			$respawn = 1;
			
		}

		if($respawn) {
			if($Global::PreFork) {
				# We need to respawn all the servers to pick up the new config
				my @pids = keys %Page_pids;
				for(@pids) {
					::logGlobal(
						{ level => 'info' },
						"respawning page server pid %s to pick up config change",
						$_,
					);
					(kill 'TERM', $_ and delete $Page_pids{$_})
						or ::logGlobal(
								"page server pid %s won't terminate: %s",
								$_,
								$!,
							);
					start_page(undef,$Global::PreFork,1);
				}
			}
			if($Global::SOAP) {
				# We need to respawn all the SOAP servers to pick up the new config
				my @pids = keys %SOAP_pids;
				for(@pids) {
					::logGlobal(
						{ level => 'info' },
						"respawning SOAP server pid %s to pick up config change",
						$_,
					);
					(kill 'TERM', $_ and delete $SOAP_pids{$_})
						or ::logGlobal(
								"SOAP server pid %s won't terminate: %s",
								$_,
								$!,
							);
					start_soap(undef,1);
				}
			}
		}

        for (@pids) {
            $Num_servers++;
            my $fn = "$Global::RunDir/$_";
            ($Num_servers--, next) if ! -f $fn;
            my $runtime = $now - (stat(_))[9];
            next if $runtime < $Global::PIDcheck;
            s/^pid\.//;
            if(kill 9, $_) {
                unlink $fn and $Num_servers--;
                ::logGlobal({ level => 'error' }, "hammered PID %s running %s seconds", $_, $runtime);
            }
            elsif (! kill 0, $_) {
				unlink $fn and $Num_servers--;
                ::logGlobal({ level => 'error' },
					"Spurious PID file for process %s supposedly running %s seconds",
						$_,
						$runtime,
				);
			}
            else {
				unlink $fn and $Num_servers--;
                ::logGlobal({ level => 'crit' },
					"PID %s running %s seconds would not die!",
						$_,
						$runtime,
				);
            }
        }


}

sub server_start_message {
	my ($fmt, $reverse) = @_;
	$fmt = 'START server (%s) (%s)' unless $fmt; 
	my @types;
	push (@types, 'INET') if $Global::Inet_Mode;
	push (@types, 'UNIX') if $Global::Unix_Mode;
	push (@types, 'SOAP') if $Global::SOAP;
	my $server_type = join(" and ", @types);
	my @args = $reverse ? ($server_type, $$) : ($$, $server_type);
	return ::errmsg ($fmt , @args );
}

sub map_unix_socket {
	my ($vec, $vec_map, $fh_map, @files) = @_;

	my @made;

	foreach my $sockfn (@files) {
		my $fh = gensym();

#::logDebug("starting to parse file socket $sockfn, fh created: $fh");

		eval {
			socket($fh, AF_UNIX, SOCK_STREAM, 0) || die "socket: $!";

			setsockopt($fh, SOL_SOCKET, SO_REUSEADDR, pack("l", 1));

			bind($fh, pack("S", AF_UNIX) . $sockfn . chr(0))
				or die "Could not bind (open as a socket) '$sockfn':\n$!\n";
			listen($fh,$SOMAXCONN) or die "listen: $!";
		};

		if($@) {
			::logGlobal({ level => 'error' }, 
					"Could not bind to UNIX socket file %s: %s",
					$sockfn,
					$!,
				  );
			next;
		}

#::logDebug("made socket $sockfn");
		my $rin = '';
		vec($rin, fileno($fh), 1) = 1;
		$$vec |= $rin;
		$vec_map->{$sockfn} = fileno($fh);
		$fh_map->{$sockfn} = $fh;
		push @made, $sockfn;
	}
	return @made;
}

sub map_inet_socket {
	my ($vec, $vec_map, $fh_map, @ports) = @_;

	my $proto = getprotobyname('tcp');
	my @made;

	for(@ports) {
		my $fh = gensym();
		my $bind_addr;
		my $bind_port;
		my $bind_ip;
#::logDebug("starting to parse port $_, fh created: $fh");
		if (/^([-\w.]+):(\d+)$/) {
			$bind_ip  = $1;
			$bind_port = $2;
			$bind_addr = inet_aton($bind_ip);
		}
		elsif (/^\d+$/) {
			$bind_ip  = '0.0.0.0';
			$bind_addr = INADDR_ANY;
			$bind_port = $_;
		}
		else {
			::logGlobal({ level => 'error' }, 
					"Unrecognized port type '%s'",
					$bind_port,
					$!,
				  );
		}
#::logDebug("Trying to run server on ip=$bind_ip port=$bind_port");
		if(! $bind_addr) {
			::logGlobal({ level => 'error' }, 
					"Could not bind to IP address %s on port %s: %s",
					$bind_ip,
					$bind_port,
					$!,
				  );
			return undef;
		}
		eval {
			socket($fh, PF_INET, SOCK_STREAM, $proto)
					|| die "socket: $!";
			setsockopt($fh, SOL_SOCKET, SO_REUSEADDR, pack("l", 1))
					|| die "setsockopt: $!";
			bind($fh, sockaddr_in($bind_port, $bind_addr))
					|| die "bind: $!";
			listen($fh,$SOMAXCONN)
					|| die "listen: $!";
		};

		if ($@) {
		  ::logGlobal({ level => 'error' },
					"INET mode server failed to start on port %s: %s",
					$bind_port,
					$@,
				  );
		  next;
		}

		my $rin = '';
		vec($rin, fileno($fh), 1) = 1;
		$$vec |= $rin;
		my $port_ptr = "$bind_ip:$bind_port"; 
		$vec_map->{$port_ptr} = fileno($fh);
		$fh_map->{$port_ptr} = $fh;
		push @made, $port_ptr;
#::logDebug( "Made port $bind_ip:$bind_port\n");
	}
	return @made;
}

sub create_host_pattern {
		my $host = shift;
		my @hosts = grep /\S/, split /[,\s\|]+/, $host;
		for (@hosts) {
			s/\./\\./g;
			s/\*/[-\\w.]+/g;
		}
		return join "|", @hosts;
}

sub unlink_sockets {
	my @to_unlink;
	for (@_) {
		if(ref($_)) {
			push @to_unlink, @$_;
		}
		else {
			push @to_unlink, $_;
		}
	}
	
	for(@to_unlink) {
		unlink $_ if -S $_;
		if(-S $_) {
			unlink $_ 
				or 
				::logGlobal(
					{level => 'error'},
					"Socket file %s cannot be unlinked: %s",
					$_,
					$!,
				);
		}
		elsif(-e _) {
			::logGlobal(
				{level => 'error'},
				"Socket file %s exists and is not a socket, possible error",
				$_,
			);
		}
	}
}

sub start_page {

	my ($do_message, $no_fork, $number) = @_;
#::logDebug("starting soap");

	$number = $Global::StartServers if ! $number; 
	if ($number > 50) {
		  die ::errmsg(
		   "Ridiculously large number of StartServers: %s",
		   $number,
		   );
	}
	for (1 .. $number) {
		my $pid;
		if(! defined ($pid = fork) ) {
			my $msg = ::errmsg("Can't fork: %s", $!);
			::logGlobal({ level => 'crit' },  $msg );
			die ("$msg\n");
		}
		elsif (! $pid) {
			unless( $pid = fork ) {
				$Global::Foreground = 1 if $no_fork;

				if($do_message) {
					::logGlobal(
						{ level => 'info'},
						server_start_message(
							"Interchange page server started (process id %s)",
						 ),
					 ) unless $Vend::Quiet;
				}

				send_ipc("register page $$");

				my $next;
				$::Instance = {};

				reset_per_fork();
				eval { 
					$next = server_page($no_fork);
				};
				if ($@) {
					my $msg = ::errmsg("Server spawn error: %s", $@);
					::logGlobal({ level => 'error' }, $msg);
					logError($msg)
						if defined $Vend::Cfg->{ErrorFile};
				}

				clean_up_after_fork();
				send_ipc("respawn page $$")		if $next;
				
				undef $::Instance;
				exit(0);
			}
			exit(0);
		}
		wait;
	}
	return 1;
}

sub start_soap {

	my $do_message = shift;
	my $number = shift;
#::logDebug("starting soap");

	$number = $Global::SOAP_StartServers if ! $number; 
	if ($number > 50) {
		  die ::errmsg(
		   "Ridiculously large number of SOAP_StartServers: %s",
		   $number,
		   );
	}
	for (1 .. $number) {
		my $pid;
		if(! defined ($pid = fork) ) {
			my $msg = ::errmsg("Can't fork: %s", $!);
			::logGlobal({ level => 'crit' },  $msg );
			die ("$msg\n");
		}
		elsif (! $pid) {
			unless( $pid = fork ) {
				close(STDOUT);
				close(STDERR);
				close(STDIN);
				if ($Global::DebugFile) {
					open(Vend::DEBUG, ">>$Global::DebugFile.soap");
					select Vend::DEBUG;
					$| =1;
					print "Start DEBUG at " . localtime() . "\n";
				}
				elsif (!$Global::DEBUG) {
					# May as well turn warnings off, not going anywhere
					$^W = 0;
					open (Vend::DEBUG, ">/dev/null") unless $Global::Windows;
				}

				open(STDOUT, ">&Vend::DEBUG");
				select(STDOUT);
				$| = 1;
				open(STDERR, ">&Vend::DEBUG");
				select(STDERR); $| = 1; select(STDOUT);

				$Global::Foreground = 1;

				if($do_message) {
					::logGlobal(
						{ level => 'info'},
						server_start_message(
							"Interchange SOAP server started (process id %s)",
						 ),
					 ) unless $Vend::Quiet;
				}

				send_ipc("register soap $$");

				reset_per_fork();
				my $next;
				$::Instance = {};
				eval { 
					$next = server_soap(@_);
				};
				if ($@) {
					my $msg = $@;
					::logGlobal({ level => 'error' }, "Runtime error: %s" , $msg);
					logError("Runtime error: %s", $msg)
						if defined $Vend::Cfg->{ErrorFile};
				}

				clean_up_after_fork();
				send_ipc("respawn soap $$")		if $next;
				
				undef $::Instance;
				exit(0);
			}
			exit(0);
		}
		wait;
	}
	return 1;
}

sub server_page {

	my ($no_fork) = @_;

	my $c = 0;
	my $cycle;
	my $rin;
	my $rout;
	my $pid;
	my $spawn;
	my $handled = 0;
	
	$Global::Foreground ||= $no_fork;

    for (;;) {

	  my $n;
	  $c++;
	  my ($ok, $p, $v);
	  my $i = 0;
	  $c++;
	  eval {
		$rin = $p_vector;
		
my $pretty_vector = unpack('b*', $rin);

		undef $spawn;
		do {
			$n = select($rout = $rin, undef, undef, $tick);
		} while $n == -1 && $!{EINTR} && ! $Signal_Terminate;

#::logDebug("pid=$$ cycle=$c handled=$handled tick=$tick vector=$pretty_vector n=$n num_servers=$Num_servers");
        if ($n == -1) {
			last if $Signal_Terminate;
			my $msg = $!;
			$msg = ::errmsg("error '%s' from select, n=$n." , $msg );
			die "$msg";
        }
		elsif($n == 0) {
			undef $spawn;
			#indiv_housekeeping();
			next;
		}
        else {

            my ($ok, $p, $v);
			while (($p, $v) = each %vec_map) {
#::logDebug("PAGE trying p=$p v=$v vec=" . vec($rout,$v,1) . " pid=$$ c=$c i=" . $i++ );
        		next unless vec($rout, $v, 1);
#::logDebug("PAGE accepting p=$p v=$v pid=$$ c=$c i=" . $i++);
				$Global::TcpPort = $p;
				$ok = accept(MESSAGE, $fh_map{$p});
				last;
			}

#::logDebug("PAGE port $Global::TcpPort handled=$handled n=$n v=$v error=$! p=$p unix=$unix_socket{$p} ipc=$ipc_socket{$p} pid=$$ c=$c i=" . $i++);

			unless (defined $ok) {
#::logDebug("PAGE redo accept on error=$! n=$n v=$v p=$p unix=$unix_socket{$p} pid=$$ c=$c i=" . $i++);
				redo;
				#die ("accept: $! ok=$ok pid=$$ n=$n c=$c i=" . $i++);
			}

			CHECKHOST: {
				undef $Global::OnlyInternalHTTP;
				last CHECKHOST if $unix_socket{$p};
				my $connector;
				(undef, $ok) = sockaddr_in($ok);
				$connector = inet_ntoa($ok);
				last CHECKHOST if $connector =~ /$Global::TcpHost/;
				my $dns_name;
				(undef, $dns_name) = gethostbyaddr($ok, AF_INET);
				$dns_name = "UNRESOLVED_NAME" if ! $dns_name;
				last CHECKHOST if $dns_name =~ /$Global::TcpHost/;
				$Global::OnlyInternalHTTP = "$dns_name/$connector";
			}
			$spawn = 1;
		}
	  };

	  if($@) {
	  	my $msg = $@;
		$msg =~ s/\s+$//;
#::logDebug("Died in select, retrying: $msg");
	    ::logGlobal({ level => 'error' },  "Died in select, retrying: %s", $msg);
	  }

#::logDebug ("Past connect, spawn=$spawn");

	  eval {
		SPAWN: {
			last SPAWN unless defined $spawn;
#::logDebug ("Spawning connection, " .  ($no_fork ? 'no fork, ' : 'forked, ') .  scalar localtime());
			if($no_fork) {
				### Careful, returns after MaxRequests or terminate signal
				$::Instance = {};
				$handled++;
#::logDebug("begin non-forked ::connection()");
				connection();
#::logDebug("end non-forked ::connection()");
				undef $::Instance;
			}
			elsif(! defined ($pid = fork) ) {
				my $msg = ::errmsg("Can't fork: %s", $!);
				::logGlobal({ level => 'crit' },  $msg );
				die ("$msg\n");
			}
			elsif (! $pid) {
				#fork again
				unless ($pid = fork) {
#::logDebug("forked connection");
					$::Instance = {};
					eval { 
						touch_pid() if $Global::PIDcheck;
						&$Sig_inc;
						connection();
					};
					if ($@) {
						my $msg = $@;
						::logGlobal({ level => 'error' }, "Runtime error: %s" , $msg);
						logError("Runtime error: %s", $msg)
							if defined $Vend::Cfg->{ErrorFile};
					}

					undef $::Instance;
					select(undef,undef,undef,0.050) until getppid == 1;
					&$Sig_dec and unlink_pid();
					exit(0);
				}
				exit(0);
			}
			close MESSAGE;
			last SPAWN if $no_fork;
			wait;
		}
	  };

		# clean up dies during spawn
		if ($@) {
			my $msg = $@;
			::logGlobal({ level => 'error' }, "Died in server spawn: %s", $msg );

			Vend::Session::close_session();
			$Vend::Cfg = { } if ! $Vend::Cfg;

			my $content;
			if($content = ::get_locale_message(500, '', $msg)) {
				print MESSAGE canon_status("Content-type: text/html");
				print MESSAGE $content;
			}

			close MESSAGE;

		}

		return 1
			if $no_fork
			and $Global::MaxRequestsPerChild
			and $handled >= $Global::MaxRequestsPerChild;

		return if $Signal_Terminate;

    }
}

sub server_soap {
#::logDebug("Entering soap server program");
	my $rin;
	my $rout;

	my $c = 0;
	my $handled = 0;
my $pretty_vector = unpack('b*', $s_vector);
#::logDebug("SOAP server $$ begun, vector=$pretty_vector servers=$SOAP_servers");
    for (;;) {

	  my $n;
	  $c++;
	  my ($ok, $p, $v);
	  eval {
		$rin = $s_vector;

		do {
			$n = select($rout = $rin, undef, undef, $tick);
		} while $n == -1 && $!{EINTR} && ! $Signal_Terminate;

        if ($n == -1) {
			last if $!{EINTR} and $Signal_Terminate;
			my $msg = $!;
			$msg = ::errmsg("error '%s' from select, n=%s.", $msg, $n );
			die "$msg";
        }
		elsif($n == 0) {
			#soap_housekeeping();
			next;
		}
        else {
			while (($p, $v) = each %s_vec_map) {
        		next unless vec($rout, $v, 1);
				$Global::TcpPort = $p;
				$ok = accept(MESSAGE, $s_fh_map{$p});
				last;
			}



	  };

	  last if $Signal_Terminate;

	  if($@) {
	  	my $msg = $@;
		$msg =~ s/\s+$//;
#::logDebug("SOAP died in select, retrying: $msg");
	    ::logGlobal({ level => 'error' },  "SOAP died in select, retrying: %s", $msg);
	  }

	  unless (defined $ok) {
#::logDebug("redo accept on error=$! n=$n p=$p unix=$unix_socket{$p} pid=$$ c=$c");
		  redo;
	  }


	  eval {
			my $connector;
			my $dns_name;

			CHECKHOST: {
				last CHECKHOST if $unix_socket{$p};
				(undef, $ok) = sockaddr_in($ok);
				$connector = inet_ntoa($ok);
				last CHECKHOST if $connector =~ /$Global::TcpHost/;
				(undef, $dns_name) = gethostbyaddr($ok, AF_INET);
				$dns_name = $connector if ! $dns_name;
				last CHECKHOST if $dns_name =~ /$Global::TcpHost/;
				$Global::OnlyInternalHTTP = "$dns_name/$connector";
			}

			$handled++;
			my %env;
			my $entity;
			
			reset_vars();

			$Vend::OnlyInternalHTTP = $Global::OnlyInternalHTTP;

			$Vend::Cfg = http_soap(\*MESSAGE, \%env, \$entity);
			$Vend::Cat = $Vend::Cfg->{CatalogName};

			my $result;
			my $error;
			if(! $Vend::Cfg) {
#::logDebug("we have no catalog");
				$result = Vend::SOAP::Transport::Server
					->new( error => 'Catalog not found' )
					->dispatch_to('', 'Vend::SOAP::Error')
					->handle();
			}
			elsif(! $Vend::Cfg->{SOAP}) {
#::logDebug("we have no SOAP enable");
				$result = Vend::SOAP::Transport::Server
					->new( error => 'SOAP not enabled' )
					->dispatch_to('', 'Vend::SOAP::Error')
					->handle();
			}
			else {
#::logDebug("we have our SOAP enable, entity is $entity");
				($Vend::SessionID, $CGI::cookiehost) = split /:/, $env{SESSION_ID};
#::logDebug("Received ID=$Vend::SessionID, host='$CGI::cookiehost'");
				$Vend::NoInterpolate = 1
					unless $Vend::Cfg->{SOAP_Enable}->{interpolate};
				$result = Vend::SOAP::Transport::Server
					->new( in => $entity )
					->dispatch_to('', 'Vend::SOAP')
					->handle;
			}

			unless ($Vend::StatusLine =~ m{^HTTP/}) {
				my $status = $Vend::StatusLine =~ /(?:^|\n)Status:\s+(.*)/i
					? "$1" : "200 OK";
				$Vend::StatusLine = "HTTP/1.0 $status\r\n" . $Vend::StatusLine;
			}
			$Vend::StatusLine .= "\r\nContent-Type: text/xml\r\n"
				unless $Vend::StatusLine =~ /^Content-Type:/im;

			print MESSAGE canon_status($Vend::StatusLine);
			print MESSAGE $result;
			undef $Vend::StatusLine;
			$Vend::ResponseMade = 1;
			close MESSAGE;
#::logDebug("SOAP port=$p n=$n unix=$unix_socket{$p} pid=$$ c=$c time=" . join '|', times);
		}
	  };	

	  if($@) {
	  	my $msg = $@;
		$msg =~ s/\s+$//;
#::logDebug("SOAP died in processing: $msg");
	    ::logGlobal({ level => 'error' },  "SOAP died in processing: %s", $msg);
		close MESSAGE;
	  }

	  return if $Signal_Terminate;
	  return 1 if $handled > ($Global::SOAP_MaxRequests || 10);
	  ::put_session() if $Vend::HaveSession;
	  undef $Vend::Session;
	  undef $Vend::HaveSession;
    }

}

sub process_ipc {
	my $fh = shift;
#::logDebug("pid $$: processing ipc response $fh");
	my $thing = <$fh>;
#::logDebug("pid $$: thing is $thing");
	if($thing =~ /^\d+$/) {
		close $fh;
		$Num_servers--;
	}
	elsif ($thing =~ /^register page (\d+)/) {
		$Page_pids{$1} = 1;
#::logDebug("registered Page pid $1");
		$Page_servers++;
	}
	elsif ($thing =~ /^respawn page (\d+)/) {
		delete $Page_pids{$1};
#::logDebug("deleted Page pid $1");
		$Page_servers--;
		start_page(undef,$Global::PreFork,1);
	}
	elsif ($thing =~ /^register soap (\d+)/) {
		$SOAP_pids{$1} = 1;
#::logDebug("registered SOAP pid $1");
		$SOAP_servers++;
	}
	elsif ($thing =~ /^respawn soap (\d+)/) {
		delete $SOAP_pids{$1};
#::logDebug("deleted SOAP pid $1");
		$SOAP_servers--;
		start_soap(undef, 1);
	}
	elsif($thing =~ /^\d+$/) {
		close $fh;
		$Num_servers++;
	}
	return;
}

sub send_ipc {
	my $msg = shift;
	socket(SOCK, PF_UNIX, SOCK_STREAM, 0)	or die "socket: $!\n";

	my $ok;

	do {
	   $ok = connect(SOCK, sockaddr_un($Global::IPCsocket));
	} while ( ! defined $ok and ! $!{EINTR});

	print SOCK $msg;
#::logDebug("pid $$: sent ipc $msg");
	close SOCK;
}

# The servers for both are now combined
# Can have both INET and UNIX on same system
sub server_both {
    my ($socket_filename) = @_;
    my ($n, $rin, $rout, $pid);

	$Vend::MasterProcess = $$;

	$tick        = $Global::HouseKeeping || 60;

    setup_signals();

#::logDebug("Starting server socket file='$socket_filename' hosts='$host'\n");

	my $spawn;

	for (qw/mode.inet mode.unix mode.soap/) {
		unlink "$Global::RunDir/$_";
	}

	# We always unlink our file-based sockets
	unlink_sockets($Global::SocketFile);
	if($Global::IPCsocket) {
#::logDebug("Creating IPC socket $Global::IPCsocket");
		unlink_sockets($Global::IPCsocket);
		## This is a scalar, not an array like Global::SocketFile
		($ipc) = map_unix_socket(\$vector, \%vec_map, \%fh_map, $Global::IPCsocket );
		$ipc_socket{$ipc} = $ipc;
		$unix_socket{$ipc} = $ipc;
		$ipc_vector = $vector;
		
	}

	# Make UNIX-domain sockets if applicable. The sockets are mapped into the
	# vector map and file handle map, socket permissions are set, etc.  The
	# socket labels are marked with %unix_socket so that INET-specific
	# processing like determining IP address are not done.
	if($Global::Unix_Mode) {
		my @made =
			map_unix_socket(\$vector, \%vec_map, \%fh_map, @$Global::SocketFile);
		if (scalar @made) {
			@unix_socket{@made} = @made;
			open(UNIX_MODE_INDICATOR, ">$Global::RunDir/mode.unix")
				or die "create $Global::RunDir/mode.unix: $!";
			print UNIX_MODE_INDICATOR join " ", @made;
			close(UNIX_MODE_INDICATOR);
			# So that other apps can read if appropriate
			chmod $Global::SocketPerms, "$Global::RunDir/mode.unix";
		}
		else { # The error condition
			my $msg;
			if ($Global::Inet_Mode) {
				$msg = errmsg("Failed to make any UNIX sockets, continuing in INET MODE ONLY" );
				::logGlobal({ level => 'warn' }, $msg);
				print "$msg\n";
				undef $Global::Unix_Mode;
			}
			else {
				$msg = errmsg( "No sockets -- INTERCHANGE SERVER TERMINATING\a" );
				::logGlobal( {level => 'alert'}, $msg );
				print "$msg\n";
				exit 1;
			}
		}
		
		for(@made) {
			chmod $Global::SocketPerms, $_;
			if($Global::SocketPerms & 033) {
				::logGlobal( {
					level => 'warn' },
					"ALERT: %s socket permissions are insecure; are you sure you want permissions %o?",
					$_,
					$Global::SocketPerms,
				);
			}
		}
	}

	# Make SOAP-IPC sockets if applicable. The sockets are mapped into a
	# separate vector map and file handle map. The require of the SOAP
	# module is done here so that memory footprint will not be greater
	# if SOAP is not used.

	if($Global::SOAP) {
		eval {
			require Vend::SOAP;
		};
		if($@) {
			::logGlobal( {
				level => 'warn' },
				"SOAP enabled, but Vend::SOAP will not load: %s",
				$@,
			);
		}
		else {
			my @made;
			my @unix_soap = grep m{/}, @{$Global::SOAP_Socket};
			my @inet_soap = grep $_ !~ m{/}, @{$Global::SOAP_Socket};
			if(@unix_soap) {
				unlink_sockets(@unix_soap);
				push @made,
					map_unix_socket(\$s_vector, \%s_vec_map, \%s_fh_map, @unix_soap);
				chmod $Global::SOAP_Perms, @made;
				@unix_socket{@made} = @made;
			}
			if(@inet_soap) {
				push @made,
					map_inet_socket(\$s_vector, \%s_vec_map, \%s_fh_map, @inet_soap);
			}
		}
	}

	# Make INET-domain sockets if applicable. The sockets are added into
	# $vector for select(,,,) monitoring, and mapped into the vector map and
	# file handle map.
	if($Global::Inet_Mode) {
		$Global::TcpHost = create_host_pattern($Global::TcpHost);
		::logGlobal(
				{ level => 'info' },
				"Accepting connections from %s",
				$Global::TcpHost,
				);
		my @made =
			map_inet_socket(\$vector, \%vec_map, \%fh_map, keys %{$Global::TcpMap});
		if (! scalar @made) {
			my $msg;
			if ($Global::Unix_Mode) {
				$msg = errmsg("Continuing in UNIX MODE ONLY" );
				::logGlobal({ level => 'warn' }, $msg);
				print "$msg\n";
				undef $Global::Inet_Mode;
			}
			else {
				$msg = errmsg( "No sockets -- INTERCHANGE SERVER TERMINATING\a" );
				::logGlobal( {level => 'alert'}, $msg );
				print "$msg\n";
				exit 1;
			}
		}
		else {
			open(INET_MODE_INDICATOR, ">$Global::RunDir/mode.inet")
				or die "create $Global::RunDir/mode.inet: $!";
			print INET_MODE_INDICATOR join " ", @made;
			close(INET_MODE_INDICATOR);
			# So that other apps can read if appropriate
			chmod $Global::SocketPerms, "$Global::RunDir/mode.inet";
		}
	}

	::logGlobal({ level => 'info' }, server_start_message() );

	my $no_fork;
	if($Global::Windows or $Global::DEBUG ) {
		$no_fork = 1;
		$Global::Foreground = 1;
		::logGlobal({ level => 'info' }, "Running in foreground, OS=$^O, debug=$Global::DEBUG\n");
	}
	else {
		close(STDIN);
		close(STDOUT);
		close(STDERR);

		if ($Global::DebugFile) {
			open(Vend::DEBUG, ">>$Global::DebugFile");
			select Vend::DEBUG;
			$| =1;
			print "Start DEBUG at " . localtime() . "\n";
		}
		elsif (!$Global::DEBUG) {
			# May as well turn warnings off, not going anywhere
			$^W = 0;
			open (Vend::DEBUG, ">/dev/null") unless $Global::Windows;
		}

		open(STDOUT, ">&Vend::DEBUG");
		select(STDOUT);
		$| = 1;
		open(STDERR, ">&Vend::DEBUG");
		select(STDERR); $| = 1; select(STDOUT);
#::logDebug("s_vector=" . unpack('b*', $s_vector));
		if($s_vector) {
			start_soap(1);
		}
	}

	my $master_ipc = 0;
	if($Global::StartServers) {
		$master_ipc = 1;
		$p_vector = $vector ^ $ipc_vector;
		start_page(1,$Global::PreFork);
	}

	my $c = 0;
	my $only_ipc = $master_ipc;
	my $checked_soap;
	my $cycle;
    for (;;) {

	  my $i = 0;
	  $c++;
	  eval {
        if($only_ipc) {
			$rin = $ipc_vector;
			$cycle = 0.100;
		}
		else {
			$rin = $vector;
			$cycle = $tick;
		}
my $pretty_vector = unpack('b*', $rin);
		undef $spawn;
		undef $checked_soap;
		do {
			$n = select($rout = $rin, undef, undef, $cycle);
		} while $n == -1 && $!{EINTR} && ! $Signal_Terminate;

		undef $Vend::Cfg;

#::logDebug("cycle=$c tick=$cycle vector=$pretty_vector n=$n num_servers=$Num_servers");
        if ($n == -1) {
			last if $Signal_Terminate;
			my $msg = $!;
			$msg = ::errmsg("error '%s' from select, n=%s." , $msg, $n);
			die "$msg";
        }
		elsif($n == 0) {
			# Do nothing, timed out
		}
        else {

            my ($ok, $p, $v);
			while (($p, $v) = each %vec_map) {
#::logDebug("trying p=$p v=$v vec=" . vec($rout,$v,1) . " pid=$$ c=$c i=" . $i++ );
        		next unless vec($rout, $v, 1);
#::logDebug("accepting p=$p v=$v pid=$$ c=$c i=" . $i++);
				$Global::TcpPort = $p;
				$ok = accept(MESSAGE, $fh_map{$p});
				last;
			}

#::logDebug("port $Global::TcpPort n=$n v=$v error=$! p=$p unix=$unix_socket{$p} ipc=$ipc_socket{$p} pid=$$ c=$c i=" . $i++);

			unless (defined $ok) {
#::logDebug("redo accept on error=$! n=$n v=$v p=$p unix=$unix_socket{$p} pid=$$ c=$c i=" . $i++);
				redo;
				#die ("accept: $! ok=$ok pid=$$ n=$n c=$c i=" . $i++);
			}

			if ($ipc_socket{$p}) {
				process_ipc(\*MESSAGE);
				$only_ipc = 1;
			}

			CHECKHOST: {
				undef $Vend::OnlyInternalHTTP;
				last CHECKHOST if $unix_socket{$p};
				my $connector;
				(undef, $ok) = sockaddr_in($ok);
				$connector = inet_ntoa($ok);
				last CHECKHOST if $connector =~ /$Global::TcpHost/;
				my $dns_name;
				(undef, $dns_name) = gethostbyaddr($ok, AF_INET);
				$dns_name = "UNRESOLVED_NAME" if ! $dns_name;
				last CHECKHOST if $dns_name =~ /$Global::TcpHost/;
				$Vend::OnlyInternalHTTP = "$dns_name/$connector";
			}
			$spawn = 1 unless $only_ipc;
		}
	  };

	  if($@) {
	  	my $msg = $@;
		$msg =~ s/\s+$//;
#::logDebug("Died in select, retrying: $msg");
	    ::logGlobal({ level => 'error' },  "Died in select, retrying: %s", $msg);
	  }

	  eval {
		SPAWN: {
			last SPAWN unless defined $spawn;
#::logDebug("Spawning connection, " .  ($no_fork ? 'no fork, ' : 'forked, ') .  scalar localtime() . "\n");
			if(defined $no_fork) {
				$::Instance = {};
				connection();
				undef $::Instance;
			}
			elsif(! defined ($pid = fork) ) {
				my $msg = ::errmsg("Can't fork: %s", $!);
				::logGlobal({ level => 'crit' },  $msg );
				die ("$msg\n");
			}
			elsif (! $pid) {
				#fork again
				unless ($pid = fork) {

					reset_per_fork();
					$::Instance = {};
					eval { 
						touch_pid() if $Global::PIDcheck;
						&$Sig_inc;
						connection();
					};
					if ($@) {
						my $msg = $@;
						::logGlobal({ level => 'error' }, "Runtime error: %s" , $msg);
						logError("Runtime error: %s", $msg)
							if defined $Vend::Cfg->{ErrorFile};
					}
					clean_up_after_fork();

					undef $::Instance;
					select(undef,undef,undef,0.050) until getppid == 1;
					if ($Global::IPCsocket) {
						&$Sig_dec and unlink_pid();
					}
					elsif ($Global::PIDcheck) {
						unlink_pid() and &$Sig_dec;
					}
					else {
						&$Sig_dec;
					}
					exit(0);
				}
				exit(0);
			}
			close MESSAGE;
			last SPAWN if $no_fork;
			wait;
		}
	  };

		# clean up dies during spawn
		if ($@) {
			my $msg = $@;
			::logGlobal({ level => 'error' }, "Died in server spawn: %s", $msg );

			Vend::Session::close_session();
			$Vend::Cfg = { } if ! $Vend::Cfg;

			my $content;
			if($content = ::get_locale_message(500, '', $msg)) {
				print MESSAGE canon_status("Content-type: text/html");
				print MESSAGE $content;
			}

			close MESSAGE;
		}

		last if $Signal_Terminate;
	  	$only_ipc = $master_ipc;

	  eval {
		    housekeeping($tick);
		    if ($Global::MaxServers and $Num_servers > $Global::MaxServers) {
			   $only_ipc = $ipc;
			}
			if( $rin = $s_vector and select($rin, undef, undef, 0) >= 1 ) {
				start_soap(undef,1)
					unless $SOAP_servers > $Global::SOAP_MaxServers;
			}
	  };
	  ::logGlobal({ level => 'crit' }, "Died in housekeeping, retry: %s", $@ ) if $@;
    }

    restore_signals();

   	if ($Signal_Terminate) {
       	::logGlobal({ level => 'info' }, "STOP server (%s) on signal TERM", $$ );
#::logDebug("SOAP pids: " . ::uneval(\%SOAP_pids));
		my @pids = keys %SOAP_pids;
		if(@pids) {
			::logGlobal(
				{ level => 'info' },
				"STOP SOAP servers (%s) on signal TERM",
				join ",", keys %SOAP_pids,
			);
			kill 'TERM', @pids;
		}
		@pids = keys %Page_pids;
		if(@pids) {
			::logGlobal(
				{ level => 'info' },
				"STOP page servers (%s) on signal TERM",
				join ",", keys %Page_pids,
			);
			kill 'TERM', @pids;
		}
   	}

    return '';
}

sub touch_pid {
	open(TEMPPID, ">>$Global::RunDir/pid.$$") 
		or die "create PID file $$: $!\n";
	lockfile(\*TEMPPID, 1, 0)
		or die "PID $$ conflict: can't lock\n";
}

sub unlink_pid {
	close(TEMPPID);
	unlink("$Global::RunDir/pid.$$");
	1;
}

sub grab_pid {
	my $fh = shift
		or return;
    my $ok = lockfile($fh, 1, 0);
    if (not $ok) {
        chomp(my $pid = <$fh>);
        return $pid;
    }
    {
        no strict 'subs';
        truncate($fh, 0) or die "Couldn't truncate pid file: $!\n";
    }
    print $fh $$, "\n";
    return 0;
}



sub open_pid {
	my $fn = shift || $Global::PIDfile;
	my $fh = gensym();
    open($fh, "+>>$fn")
        or die ::errmsg("Couldn't open '%s': %s\n", $fn, $!);
    seek($fh, 0, 0);
    my $o = select($fh);
    $| = 1;
	select($o);
	return $fh;
}

sub run_server {
    my $next;
	
    my $pidh = open_pid($Global::PIDfile);

	unless($Global::Inet_Mode || $Global::Unix_Mode || $Global::Windows) {
		$Global::Inet_Mode = $Global::Unix_Mode = 1;
	}
	elsif ( $Global::Windows ) {
		$Global::Inet_Mode = 1;
	}

	::logGlobal({ level => 'info' }, server_start_message());

	if($Global::PreFork || $Global::DEBUG || $Global::Windows) {
		eval {
			require Tie::ShadowHash;
		};
		if($@) {
			my $reason;
			if($Global::PreFork)	{ $reason = 'in PreFork mode' }
			elsif($Global::DEBUG)	{ $reason = 'in DEBUG mode' }
			elsif($Global::Windows)	{ $reason = 'under Windows' }
			die ::errmsg("Running $reason requires Tie::ShadowHash module.") . "\n";
		}
	}

    if ($Global::Windows || $Global::DEBUG) {
        my $running = grab_pid($pidh);
        if ($running) {
			print errmsg(
				"The Interchange server is already running (process id %s)\n",
				$running,
				);
			exit 1;
        }

        print server_start_message("Interchange server started (%s) (%s)\n");
		$next = server_both();
    }
    else {

        fcntl($pidh, F_SETFD, 0)
            or die ::errmsg(
					"Can't fcntl close-on-exec flag for '%s': %s\n",
					$Global::PIDfile, $!,
					);
        my ($pid1, $pid2);
        if ($pid1 = fork) {
            # parent
            wait;
			sleep 2;
            exit 0;
        }
        elsif (not defined $pid1) {
            # fork error
            print "Can't fork: $!\n";
            exit 1;
        }
        else {
            # child 1
            if ($pid2 = fork) {
                # still child 1
                exit 0;
            }
            elsif (not defined $pid2) {
                print "child 1 can't fork: $!\n";
                exit 1;
            }
            else {
                # child 2
                sleep 1 until getppid == 1;

                my $running = grab_pid($pidh);
                if ($running) {
                    print errmsg(
						"The Interchange server is already running (process id %s)\n",
						$running,
						);
                    exit 1;
                }
                print server_start_message(
						"Interchange server started in %s mode(s) (process id %s)\n",
						1,
					 ) unless $Vend::Quiet;

                setsid();

                fcntl($pidh, F_SETFD, 1)
                    or die "Can't fcntl close-on-exec flag for '$Global::PIDfile': $!\n";

				$next = server_both();

				unlockfile($pidh);
				opendir(RUNDIR, $Global::RunDir) 
					or die "Couldn't open directory $Global::RunDir: $!\n";
				unlink $Global::PIDfile;
                exit 0;
            }
        }
    }
}

1;
__END__

