# Server.pm:  listen for cgi requests as a background server
#
# $Id: Server.pm,v 1.7.2.3 2000-11-07 22:41:47 zarko Exp $
#
# Copyright (C) 1996-2000 Akopia, Inc. <info@akopia.com>
#
# This program was originally based on Vend 0.2
# Copyright 1995 by Andrew M. Wilcox <awilcox@world.std.com>
#
# Portions from Vend 0.3
# Copyright 1995 by Andrew M. Wilcox <awilcox@world.std.com>
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
$VERSION = substr(q$Revision: 1.7.2.3 $, 10);

use strict;
use POSIX qw(setsid strftime);
use Vend::Data;
use Vend::Error;
use Vend::Interpolate;
use Vend::Page;
use Vend::Session;
use Vend::Track;
use Vend::Util;
use Fcntl;
use Config;
use Socket;
use File::CounterFile;

sub new {
	my ($class, $fh, $env, $entity) = @_;
	if(@Global::argv > 1) {
		(
			$CGI::script_name,
			$CGI::values{mv_session_id}, 
			$CGI::post_input
		) = @Global::argv;
		map_cgi();
		$Global::FastMode = 1;
		return bless { fh => $fh }, $class;
	}
	populate($env);
	my $http = {
					fh => $fh,
					entity => $entity,
					env => $env,
				};
	map_cgi($http);
	bless $http, $class;
}

my @Map = (
	'authorization' => 'AUTHORIZATION',
	'content_length' => 'CONTENT_LENGTH',
	'content_type' => 'CONTENT_TYPE',
	'content_encoding' => 'HTTP_CONTENT_ENCODING',
	'cookie' => 'HTTP_COOKIE',
	'http_host' => 'HTTP_HOST',
	'path_info' => 'PATH_INFO',
	'path_translated' => 'PATH_TRANSLATED',
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
	'server_port' => 'SERVER_PORT',
	'useragent' => 'HTTP_USER_AGENT',
);

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

sub map_cgi {
	my $h = shift;
	die "REQUEST_METHOD is not defined" unless defined $CGI::request_method
		or @Global::argv;

	if($h) {
		$CGI::user = $CGI::remote_user;
		$CGI::host = $CGI::remote_host || $CGI::remote_addr;

		$CGI::script_path = $CGI::script_name;
		$CGI::script_name = $CGI::server_host . $CGI::script_path
			if $Global::FullUrl;
		if("\U$CGI::request_method" eq 'POST') {
			$CGI::post_input = $h->{'entity'};
		} else {
			$CGI::post_input = $CGI::query_string;
		}
	}
	my $g = $Global::Selector{$CGI::script_name} || undef;
	($::IV, $::VN, $::SV) = defined $g->{VarName}
			? ($g->{IV}, $g->{VN}, $g->{IgnoreMultiple})
			: ($Global::IV, $Global::VN, $Global::IgnoreMultiple);
		
	parse_post();

}

# This is called by parse_multipart
# Doesn't do unhexify
sub store_cgi_kv {
	my ($key, $value) = @_;
	$key = $::IV->{$key} if defined $::IV->{$key};
	if(defined $CGI::values{$key} and ! defined $::SV{$key}) {
		$CGI::values{$key} = "$CGI::values{$key}\0$value";
		push ( @{$CGI::values_array{$key}}, $value)
	} else {
		$CGI::values{$key} = $value;
		$CGI::values_array{$key} = [$value];
	}
}

sub parse_post {
	my(@pairs, $pair, $key, $value);
	undef %CGI::values;
	return unless defined $CGI::post_input;
	if($CGI::content_type =~ /^multipart/i) {
		return parse_multipart() if  $CGI::useragent !~ /MSIE\s+5/i;
		# try and work around an apparent IE5 bug that sends the content type
		# of the next POST after a multipart/form POST as multipart also -
		# even though it's sent as non-multipart data
		# Contributed by Bill Randle
		my ($boundary) = $CGI::content_type =~ /boundary=\"?([^\";]+)\"?/;
		$boundary = "--$boundary";
		return parse_multipart() if $CGI::post_input =~ /^\s*$boundary\s+/;
	}
	@pairs = split(/&/, $CGI::post_input);
	if( defined $pairs[0] and $pairs[0] =~ /^	(\w{8,32})? ; /x)  {
		@CGI::values{qw/ mv_session_id mv_arg mv_pc /}
			= split /;/, $pairs[0], 3;
#::logDebug("found session stuff: $CGI::values{mv_session_id} --> $CGI::values{mv_arg}  --> $CGI::values{mv_pc} ");
		shift @pairs;
	}
	my $redo;
	CGIVAL: {
	  	# This loop semi-duplicated in store_cgi_kv
		foreach $pair (@pairs) {
			($key, $value) = ($pair =~ m/([^=]+)=(.*)/)
				or die "Syntax error in post input:\n$pair\n";

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
			} else {
				$CGI::values{$key} = $value;
				$CGI::values_array{$key} = [$value];
			}
		}
		if(! $redo and "\U$CGI::request_method" eq 'POST') {
			@pairs = split(/&/, $CGI::query_string);
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
	my ($boundary) = $CGI::content_type =~ /boundary=\"?([^\";]+)\"?/;
#::logDebug("got to multipart");
	# Stolen from CGI.pm, thanks Lincoln
	$boundary = "--$boundary"
		unless $CGI::useragent =~ /MSIE 3\.0[12];  Mac/i;
	unless ($CGI::post_input =~ s/^\s*$boundary\s+//) {
		die errmsg("multipart/form-data sent incorrectly\n");
	}

	my @parts;
	@parts = split /\r?\n$boundary/, $CGI::post_input;
	
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
				::logGlobal({}, "unsupported multipart header: \n%s\n", $header);
				next;
			}

			if($filename) {
				$CGI::file{$param} = $data;
				$data = $filename;
			} else {
				$data =~ s/\r?\n$//;
			}
			store_cgi_kv($param, $data);
		}
	}
	return 1;
}

sub create_cookie {
	my($domain,$path) = @_;
	my ($name, $value, $out, $expire, $cookie);
	my @jar;
	@jar = ['MV_SESSION_ID', $Vend::SessionName, $Vend::Expire || undef];
	push @jar, ['MV_STATIC', 1] if $Vend::Cfg->{Static};
	push @jar, @{$::Instance->{Cookies}}
		if defined $::Instance->{Cookies};
	$out = '';
	foreach $cookie (@jar) {
		($name, $value, $expire) = @$cookie;
#::logDebug("create_cookie: name=$name value=$value expire=$expire");
		$value = Vend::Interpolate::esc($value) 
			if $value !~ /^[-\w:.]+$/;
		$out .= "Set-Cookie: $name=$value;";
		$out .= " path=$path;";
		$out .= " domain=" . $domain . ";" if $domain;
		if(defined $expire or $Vend::Expire) {
			$expire = $Vend::Expire unless defined $expire;
			$out .= " expires=" .
						strftime "%a, %d-%b-%y %H:%M:%S GMT ", gmtime($expire);
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
	s:\s*\n:\r\n:mg;
	return "$_\r\n";
}

sub respond {
	# $body is now a reference
	my ($s, $body) = @_;

	my $status;
	if($Vend::StatusLine) {
		$status = $Vend::StatusLine =~ /(?:^|\n)Status:\s+(.*)/i
				? "$1"
				: "200 OK";
	}
	if(! $s and $Vend::StatusLine) {
		$Vend::StatusLine = "HTTP/1.0 $status\r\n$Vend::StatusLine"
			if defined $Vend::InternalHTTP
				and $Vend::StatusLine !~ m{^HTTP/};
		$Vend::StatusLine .= ($Vend::StatusLine =~ /^Content-Type:/im)
							? '' : "\r\nContent-Type: text/html\r\n";
# TRACK
		$Vend::StatusLine .= "X-Track: " . $Vend::Track->header() . "\r\n";
# END TRACK
		$Vend::StatusLine .= "Pragma: no-cache\r\n"
			if delete $::Scratch->{mv_no_cache};
		print Vend::Server::MESSAGE canon_status($Vend::StatusLine);
		print Vend::Server::MESSAGE "\r\n";
		print Vend::Server::MESSAGE $$body;
		undef $Vend::StatusLine;
		$Vend::ResponseMade = 1;
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
		return 1;
	}

	if(defined $Vend::InternalHTTP or defined $ENV{MOD_PERL} or $CGI::script_name =~ m:/nph-[^/]+$:) {
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
		} else {
			print $fh "HTTP/1.0 $status\r\n";
		}
	}

	if( (	! $CGI::cookie && ! $::Instance->{CookiesSet}
			or defined $Vend::Expire
			or defined $::Instance->{Cookies}
		  )
			and $Vend::Cfg->{Cookies}
		)
	{
		my @domains;
		@domains = ('');
		if($Vend::Cfg->{CookieDomain}) {
			@domains = split /\s+/, $Vend::Cfg->{CookieDomain};
		}

		my @paths;
		@paths = ('/');
		if($Global::Mall) {
			my $ref = $Global::Catalog{$Vend::Cfg->{CatalogName}};
			@paths = ($ref->{'script'});
			push (@paths, @{$ref->{'alias'}}) if defined $ref->{'alias'};
			if($Global::FullUrl) {
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

	if(defined $Vend::StatusLine) {
		print $fh canon_status($Vend::StatusLine);
	} elsif(! $Vend::ResponseMade) {        
		print $fh canon_status("Content-Type: text/html");
# TRACK        
		print $fh canon_status("X-Track: " . $Vend::Track->header() . "\r\n");
# END TRACK
	}

	print $fh "\r\n";
	print $fh $$body;
	$Vend::ResponseMade = 1;
}

sub read_entity_body {
	my ($s) = @_;
	$s->{entity};
}

sub _read {
	my ($in) = @_;
	my ($r);

	do {
		$r = sysread(Vend::Server::MESSAGE, $$in, 512, length($$in));
	} while (!defined $r and $! =~ m/^Interrupted/);
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
my %MIME_type;

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

		%MIME_type = (qw|
							jpg		image/jpeg
							gif		image/gif
							JPG		image/jpeg
							GIF		image/gif
							JPEG	image/jpeg
							jpeg	image/jpeg
							htm		text/html
							html	text/html
						|
		);
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
		if( $block =~ s/^([^:]+):\s*//) {
			$header = lc $1;
			if(defined $CGImap{$header}) {
				$$env{$CGImap{$header}} = $block;
			} elsif(defined $CGIspecial{$header}) {
				&{$CGIspecial{$header}}($env, $block);
#			} else {
#				throw_away();
			}
			next;
		} else {
			die "HTTP protocol error on '$block':\n$in";
		}
		last;
	}

	if($$env{CONTENT_LENGTH}) {
		_read(\$in) while length($in) < $$env{CONTENT_LENGTH};
	}
	$in =~ s/\s+$//;
	$$entity = $in;

#::logDebug("exiting loop");
	my $url = new URI::URL $request;
	@{$argv} = $url->keywords();

	(undef, $Remote_addr) =
				sockaddr_in(getpeername(Vend::Server::MESSAGE));
	$$env{REMOTE_HOST} = gethostbyaddr($Remote_addr, AF_INET);
	$Remote_addr = inet_ntoa($Remote_addr);

	$$env{QUERY_STRING} = $url->equery();
	$$env{REMOTE_ADDR} = $Remote_addr;

	my (@path) = $url->path_components();
	my $path = $url->path();
	my $doc;
	my $status = 200;

	shift(@path);
	my $cat = "/" . shift(@path);

	if($Global::TcpMap->{$Global::TcpPort} =~ /^\w+/) {
		$cat = $Global::TcpMap->{$Global::TcpPort};
		$cat = "/$cat" unless index($cat, '/') == 0;
	}

	if($cat eq '/mv_admin') {
#::logDebug("found mv_admin");
		if($$env{AUTHORIZATION}) {
			$$env{REMOTE_USER} =
					Vend::Util::check_authorization( delete $$env{AUTHORIZATION} );
		}
		if(! $$env{REMOTE_USER}) {
			$Vend::StatusLine = <<EOF;
HTTP/1.0 401 Unauthorized
WWW-Authenticate: Basic realm="Interchange Admin"
EOF
			$doc = "Requires correct username and password.\n";
			$path = '';
		}
	}

	if($Global::Selector{$cat} || $Global::SelectorAlias{$cat}) {
#::logDebug("found direct catalog $cat");
		$$env{SCRIPT_NAME} = $cat;
		$$env{PATH_INFO} = join "/", '', @path;
	} elsif(-f "$Global::VendRoot/doc$path") {
#::logDebug("found doc file");
		$Vend::StatusLine = "HTTP/1.0 200 OK";
		$doc = readfile("$Global::VendRoot/doc$path");
	} else {
#::logDebug("not found");
		$status = 404;
		$Vend::StatusLine = "HTTP/1.0 404 Not found";
		$doc = "$path not a Interchange catalog or help file.\n";
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

	if(defined $doc) {
		$path =~ /\.([^.]+)$/;
		$Vend::StatusLine = '' unless defined $Vend::StatusLine;
		$Vend::StatusLine .= "\r\nContent-type: " . ($MIME_type{$1} || "text/plain");
		respond(
					'',
					\$doc,
				);
		return;
	}
	return 1;
}

sub read_cgi_data {
	my($argv, $env, $entity) = @_;
	my($in, $block, $n, $i, $e, $key, $value);
	$in = '';

	for (;;) {
		$block = _find(\$in, "\n");
		if($block =~ m/^[GPH]/) {
			return http_server($block, $in, @_);
		} elsif($block =~ s/^ipc ([-\w]+)$//) {
			my $cat = $1;
		} elsif(($n) = ($block =~ m/^arg (\d+)$/)) {
			$#$argv = $n - 1;
			foreach $i (0 .. $n - 1) {
				$$argv[$i] = _string(\$in);
			}
		} elsif(($n) = ($block =~ m/^env (\d+)$/)) {
			foreach $i (0 .. $n - 1) {
				$e = _string(\$in);
				if(($key, $value) = ($e =~ m/^([^=]+)=(.*)$/s)) {
					$$env{$key} = $value;
				}
			}
		} elsif($block =~ m/^entity$/) {
			$$entity = _string(\$in);
		} elsif($block =~ m/^end$/) {
			last;
		} else {
			die "Unrecognized block: $block\n";
		}
	}
	if($Vend::OnlyInternalHTTP) {
		my $msg = errmsg(
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
	my $http;
#::logDebug ("begin connection: " . (join " ", times()) . "\n");
	read_cgi_data(\@Global::argv, \%env, \$entity)
		or return 0;
	$http = new Vend::Server \*Vend::Server::MESSAGE, \%env, $entity;
#::logGlobal ("begin dispatch: " . (join " ", times()) . "\n");
	dispatch($http);
#::logDebug ("end connection: " . (join " ", times()) . "\n");
	undef $Vend::ResponseMade;
	undef $Vend::InternalHTTP;
}

## Signals

my $Signal_Terminate;
my $Signal_Debug;
my $Signal_Restart;
my %orig_signal;
my @trapped_signals = qw(INT TERM);
$Vend::Server::Num_servers = 0;

# might also trap: QUIT

my ($Routine_USR1, $Routine_USR2, $Routine_HUP, $Routine_TERM, $Routine_INT);
my ($Sig_inc, $Sig_dec, $Counter);

unless ($Global::Windows) {
	push @trapped_signals, qw(HUP USR1 USR2);
	$Routine_USR1 = sub { $SIG{USR1} = $Routine_USR1; $Vend::Server::Num_servers++};
	$Routine_USR2 = sub { $SIG{USR2} = $Routine_USR2; $Vend::Server::Num_servers--};
	$Routine_HUP  = sub { $SIG{HUP} = $Routine_HUP; $Signal_Restart = 1};
}

$Routine_TERM = sub { $SIG{TERM} = $Routine_TERM; $Signal_Terminate = 1 };
$Routine_INT  = sub { $SIG{INT} = $Routine_INT; $Signal_Terminate = 1 };

sub setup_signals {
	@orig_signal{@trapped_signals} =
		map(defined $_ ? $_ : 'DEFAULT', @SIG{@trapped_signals});
	$Signal_Terminate = $Signal_Debug = '';
	$SIG{PIPE} = 'IGNORE';

	if($Global::Windows) {
		$SIG{INT}  = sub { $Signal_Terminate = 1; };
		$SIG{TERM} = sub { $Signal_Terminate = 1; };
	} else  {
		$SIG{INT}  = sub { $Signal_Terminate = 1; };
		$SIG{TERM} = sub { $Signal_Terminate = 1; };
		$SIG{HUP}  = sub { $Signal_Restart = 1; };
		$SIG{USR1} = sub { $Vend::Server::Num_servers++; };
		$SIG{USR2} = sub { $Vend::Server::Num_servers--; };
	}

	if(! $Global::MaxServers) {
		$Sig_inc = sub { 1 };
		$Sig_dec = sub { 1 };
	} else {
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
	my ($tick) = @_;
	my $now = time;
	rand();

	return if defined $tick and ($now - $Last_housekeeping < $tick);

	$Last_housekeeping = $now;

	my ($c, $num,$reconfig, $restart, @files);
	my @pids;

	opendir(Vend::Server::CHECKRUN, $Global::ConfDir)
		or die "opendir $Global::ConfDir: $!\n";
	@files = readdir Vend::Server::CHECKRUN;
	closedir(Vend::Server::CHECKRUN)
		or die "closedir $Global::ConfDir: $!\n";
	($reconfig) = grep $_ eq 'reconfig', @files;
	($restart) = grep $_ eq 'restart', @files
		if $Signal_Restart || $Global::Windows;
	if($Global::PIDcheck) {
		$Vend::Server::Num_servers = 0;
		@pids = grep /^pid\.\d+$/, @files;
	}
	#scalar grep($_ eq 'stop_the_server', @files) and exit;
	if(defined $restart) {
		$Signal_Restart = 0;
		open(Vend::Server::RESTART, "+<$Global::ConfDir/restart")
			or die "open $Global::ConfDir/restart: $!\n";
		lockfile(\*Vend::Server::RESTART, 1, 1)
			or die "lock $Global::ConfDir/restart: $!\n";
		while(<Vend::Server::RESTART>) {
			chomp;
			my ($directive,$value) = split /\s+/, $_, 2;
			if($value =~ /<<(.*)/) {
				my $mark = $1;
				$value = Vend::Config::read_here(\*Vend::Server::RESTART, $mark);
				unless (defined $value) {
					::logGlobal({}, <<EOF, $mark);
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
				} elsif(
						$directive =~ /^remove$/i 		and
						$value =~ /catalog\s+(\S+)/i
					)
				{
					::remove_catalog($1);
				} else {
					::change_global_directive($directive, $value);
				}
			};
			if($@) {
				::logGlobal({}, $@);
				last;
			}
		}
		unlockfile(\*Vend::Server::RESTART)
			or die "unlock $Global::ConfDir/restart: $!\n";
		close(Vend::Server::RESTART)
			or die "close $Global::ConfDir/restart: $!\n";
		unlink "$Global::ConfDir/restart"
			or die "unlink $Global::ConfDir/restart: $!\n";
	}
	if(defined $reconfig) {
		open(Vend::Server::RECONFIG, "+<$Global::ConfDir/reconfig")
			or die "open $Global::ConfDir/reconfig: $!\n";
		lockfile(\*Vend::Server::RECONFIG, 1, 1)
			or die "lock $Global::ConfDir/reconfig: $!\n";
		while(<Vend::Server::RECONFIG>) {
			chomp;
			my ($script_name,$build) = split /\s+/, $_;
			my $select = $Global::SelectorAlias{$script_name} || $script_name;
			my $cat = $Global::Selector{$select};
			unless (defined $cat) {
				::logGlobal({}, "Bad script name '%s' for reconfig." , $script_name );
				next;
			}
			$c = ::config_named_catalog($cat->{CatalogName},
				"from running server ($$)", $build);
			if(defined $c) {
				$Global::Selector{$select} = $c;
				for(sort keys %Global::SelectorAlias) {
					next unless $Global::SelectorAlias{$_} eq $select;
					$Global::Selector{$_} = $c;
				}
				::logGlobal({}, "Reconfig of %s successful.", $c->{CatalogName});
			} else {
				::logGlobal({},
					 "Error reconfiguring catalog %s from running server (%s)\n%s",
					 $script_name,
					 $$,
					 $@,
					 );
			}
		}
		unlockfile(\*Vend::Server::RECONFIG)
			or die "unlock $Global::ConfDir/reconfig: $!\n";
		close(Vend::Server::RECONFIG)
			or die "close $Global::ConfDir/reconfig: $!\n";
		unlink "$Global::ConfDir/reconfig"
			or die "unlink $Global::ConfDir/reconfig: $!\n";
	}
	for (@pids) {
		$Vend::Server::Num_servers++;
		my $fn = "$Global::ConfDir/$_";
		($Vend::Server::Num_servers--, next) if ! -f $fn;
		my $runtime = $now - (stat(_))[9];
		next if $runtime < $Global::PIDcheck;
		s/^pid\.//;
		if(kill 9, $_) {
			unlink $fn and $Vend::Server::Num_servers--;
			::logGlobal({}, "hammered PID %s running %s seconds", $_, $runtime);
		} elsif(! kill 0, $_) {
			unlink $fn and $Vend::Server::Num_servers--;
			::logGlobal({},
				"Spurious PID file for process %s supposedly running %s seconds",
					$_,
					$runtime,
			);
		} else {
			unlink $fn and $Vend::Server::Num_servers--;
			::logGlobal({},
				"PID %s running %s seconds would not die!",
					$_,
					$runtime,
			);
		}
	}
}

# The servers for both are now combined
# Can have both INET and UNIX on same system
sub server_both {
	my ($socket_filename) = @_;
	my ($n, $rin, $rout, $pid, $tick);

	$Vend::MasterProcess = $$;

	$tick        = $Global::HouseKeeping || 60;

	setup_signals();

	my ($host, $port);
	if($Global::Inet_Mode) {
		$host = $Global::TcpHost || '127.0.0.1';
		my @hosts;
		$Global::TcpHost =~ s/\./\\./g;
		$Global::TcpHost =~ s/\*/\\S+/g;
		@hosts = grep /\S/, split /\s+/, $Global::TcpHost;
		$Global::TcpHost = join "|", @hosts;
		::logGlobal({}, "Accepting connections from %s", $Global::TcpHost);
	}

	my $proto = getprotobyname('tcp');

#::logDebug("Starting server socket file='$socket_filename' tcpport=$port hosts='$host'\n");
	unlink $socket_filename;

	my $vector = '';
	my $spawn;

	my $so_max;
	if(defined &SOMAXCONN) {
		$so_max = SOMAXCONN;
	} else {
		$so_max = 128;
	}

	unlink "$Global::ConfDir/mode.inet", "$Global::ConfDir/mode.unix";

	if($Global::Unix_Mode) {
		socket(Vend::Server::USOCKET, AF_UNIX, SOCK_STREAM, 0) || die "socket: $!";

		setsockopt(Vend::Server::USOCKET, SOL_SOCKET, SO_REUSEADDR, pack("l", 1));

		bind(Vend::Server::USOCKET, pack("S", AF_UNIX) . $socket_filename . chr(0))
			or die "Could not bind (open as a socket) '$socket_filename':\n$!\n";
		listen(Vend::Server::USOCKET,$so_max) or die "listen: $!";

		$rin = '';
		vec($rin, fileno(Vend::Server::USOCKET), 1) = 1;
		$vector |= $rin;
		open(Vend::Server::INET_MODE_INDICATOR, ">$Global::ConfDir/mode.unix")
			or die "creat $Global::ConfDir/mode.unix: $!";
		close(Vend::Server::INET_MODE_INDICATOR);

		chmod $Global::SocketPerms, $socket_filename;
		if($Global::SocketPerms & 077) {
			::logGlobal({},
							"ALERT: %s socket permissions are insecure; are you sure you want permssions %o?",
							$Global::SocketFile,
							$Global::SocketPerms,
						);
		}
	}

	use Symbol;
	my %fh_map;
	my %vec_map;
	my $made_at_least_one;

	my @types;
	push (@types, 'INET') if $Global::Inet_Mode;
	push (@types, 'UNIX') if $Global::Unix_Mode;
	my $server_type = join(" and ", @types);
	::logGlobal({}, "START server (%s) (%s)" , $$, $server_type );

	if($Global::Inet_Mode) {

	  foreach $port (keys %{$Global::TcpMap}) {
		my $fh = gensym();
		my $bind_addr;
		my $bind_ip;
#::logDebug("starting to parse port $port, fh created: $fh");
		if($port =~ s/^([-\w.]+):(\d+)$/$2/) {
			$bind_ip  = $1;
			$bind_addr = inet_aton($bind_ip);
		} else {
			$bind_ip  = '0.0.0.0';
			$bind_addr = INADDR_ANY;
		}
#::logDebug("Trying to run server on ip=$bind_ip port=$port");
	    if(! $bind_addr) {
			::logGlobal({},
					"Could not bind to IP address %s on port %s: %s",
					$bind_ip,
					$port,
					$!,
				  );
			next;
		}
		eval {
			socket($fh, PF_INET, SOCK_STREAM, $proto)
					|| die "socket: $!";
			setsockopt($fh, SOL_SOCKET, SO_REUSEADDR, pack("l", 1))
					|| die "setsockopt: $!";
			bind($fh, sockaddr_in($port, $bind_addr))
					|| die "bind: $!";
			listen($fh,$so_max)
					|| die "listen: $!";
			$made_at_least_one = 1;
		};


		if(! $@) {
			$rin = '';
			vec($rin, fileno($fh), 1) = 1;
			$vector |= $rin;
			$vec_map{"$bind_ip:$port"} = fileno($fh);
			$fh_map{"$bind_ip:$port"} = $fh;
		} else {
		  ::logGlobal({},
					"INET mode server failed to start on port %s: %s",
					$port,
					$@,
				  );
		}
		next if $made_at_least_one;
		open(Vend::Server::INET_MODE_INDICATOR, ">$Global::ConfDir/mode.inet")
			or die "creat $Global::ConfDir/mode.inet: $!";
		close(Vend::Server::INET_MODE_INDICATOR);
	  }
	}

	if(! $made_at_least_one and $Global::Inet_Mode) {
		my $msg;
		if($Global::Unix_Mode) {
			$msg = errmsg("Continuing in UNIX MODE ONLY" );
			::logGlobal($msg);
			print "$msg\n";
		} else {
			$msg = errmsg( "No sockets -- INTERCHANGE SERVER TERMINATING\a" );
			::logGlobal( {level => 'alert'}, $msg );
			print "$msg\n";
			exit 1;
		}
	}

	my $no_fork;
	if($Global::Windows or $Global::DEBUG ) {
		$no_fork = 1;
		$Vend::Foreground = 1;
		::logGlobal("Running in foreground, OS=$^O, debug=$Global::DEBUG\n");
	} else {
		close(STDIN);
		close(STDOUT);
		close(STDERR);

		if($Global::DebugFile) {
			open(Vend::DEBUG, ">>$Global::DebugFile");
			select Vend::DEBUG;
			$| =1;
			print "Start DEBUG at " . localtime() . "\n";
		} elsif(!$Global::DEBUG) {
			# May as well turn warnings off, not going anywhere
			$^W = 0;
			open (Vend::DEBUG, ">/dev/null") unless $Global::Windows;
		}

		open(STDOUT, ">&Vend::DEBUG");
		select(STDOUT);
		$| = 1;
		open(STDERR, ">&Vend::DEBUG");
		select(STDERR); $| = 1; select(STDOUT);
		$Vend::Foreground = 0;
	}


	for (;;) {
		eval {
			$rin = $vector;
			undef $spawn;
			$n = select($rout = $rin, undef, undef, $tick);

			undef $Vend::Cfg;

			if($n == -1) {
				if($! =~ m/^Interrupted/) {
					if($Signal_Terminate) {
						last;
					}
				} else {
					my $msg = $!;
					$msg = errmsg("error '%s' from select." , $msg );
					::logGlobal({}, $msg );
					die "$msg\n";
				}
			} elsif($Global::Unix_Mode && vec($rout, fileno(Vend::Server::USOCKET), 1)) {
				undef $Vend::OnlyInternalHTTP;
				my $ok = accept(Vend::Server::MESSAGE, Vend::Server::USOCKET);
				die "accept: $!" unless defined $ok;
				$spawn = 1;
			} elsif($n == 0) {
				undef $spawn;
				housekeeping();
			} elsif($Global::Inet_Mode) {
				my ($ok, $p, $v);
				while (($p, $v) = each %vec_map) {
					next unless vec($rout, $v, 1);
					$Global::TcpPort = $p;
					$ok = accept(Vend::Server::MESSAGE, $fh_map{$p});
				}
#::logDebug("port $Global::TcpPort");
				die "accept: $!" unless defined $ok;
				my $connector;
				(undef, $ok) = sockaddr_in($ok);
				CHECKHOST: {
					undef $Vend::OnlyInternalHTTP;
					$connector = inet_ntoa($ok);
					last CHECKHOST if $connector =~ /$Global::TcpHost/;
					my $dns_name;
					(undef, $dns_name) = gethostbyaddr($ok, AF_INET);
					$dns_name = "UNRESOLVED_NAME" if ! $dns_name;
					last CHECKHOST if $dns_name =~ /$Global::TcpHost/;
					$Vend::OnlyInternalHTTP = "$dns_name/$connector";
				}
				$spawn = 1;
			} else {
				die "Why did select return with $n? Can we even get here?";
			}
		};
		::logGlobal({}, "Died in select, retrying: %s", $@) if $@;

		eval {
			SPAWN: {
				last SPAWN unless defined $spawn;
#::logDebug #("Spawning connection, " .  ($no_fork ? 'no fork, ' : 'forked, ') .  scalar localtime() . "\n");
				if(defined $no_fork) {
					$Vend::NoFork = {};
					$::Instance = {};
					connection();
					undef $Vend::NoFork;
					undef $::Instance;
				} elsif(! defined ($pid = fork) ) {
					my $msg = errmsg("Can't fork: %s", $!);
					::logGlobal({}, $msg );
					die ("$msg\n");
				} elsif(! $pid) {
					#fork again
					unless ($pid = fork) {

						$::Instance = {};
						eval { 
							touch_pid() if $Global::PIDcheck;
							&$Sig_inc;
							connection();
						};
						if($@) {
							my $msg = $@;
							::logGlobal({}, "Runtime error: %s" , $msg);
							logError("Runtime error: %s", $msg)
								if defined $Vend::Cfg->{ErrorFile};
						}

						undef $::Instance;
						select(undef,undef,undef,0.050) until getppid == 1;
						if($Global::PIDcheck) {
							unlink_pid() and &$Sig_dec;
						} else {
							&$Sig_dec;
						}
						exit(0);
					}
					exit(0);
				}
				close Vend::Server::MESSAGE;
				last SPAWN if $no_fork;
				wait;
			}
		};

		# clean up dies during spawn
		if($@) {
			::logGlobal({}, "Died in server spawn: %s", $@ ) if $@;

			# Below only happens with Windows or foreground debugs.
			# Prevent corruption of changed $Vend::Cfg entries
			# (only VendURL/SecureURL at this point).
			if($Vend::Save and $Vend::Cfg) {
				::copyref($Vend::Save, $Vend::Cfg);
				undef $Vend::Save;
			}
			undef $Vend::Cfg;
		}

		last if $Signal_Terminate || $Signal_Debug;

		eval {
			for(;;) {
				housekeeping($tick);
				last if ! $Global::MaxServers or $Vend::Server::Num_servers < $Global::MaxServers;
				select(undef,undef,undef,0.100);
				last if $Signal_Terminate || $Signal_Debug;
			}
		};
		::logGlobal({}, "Died in housekeeping, retry: %s", $@ ) if $@;
	}

	restore_signals();

	if($Signal_Terminate) {
	       	::logGlobal({}, "STOP server (%s) on signal TERM", $$ );
	       	return 'terminate';
	}

	return '';
}

sub touch_pid {
	open(TEMPPID, ">>$Global::ConfDir/pid.$$") 
		or die "creat PID file $$: $!\n";
	lockfile(\*TEMPPID, 1, 0)
		or die "PID $$ conflict: can't lock\n";
}

sub unlink_pid {
	close(TEMPPID);
	unlink("$Global::ConfDir/pid.$$");
	1;
}

sub grab_pid {
	my $ok = lockfile(\*Vend::Server::Pid, 1, 0);
	if(not $ok) {
		chomp(my $pid = <Vend::Server::Pid>);
		return $pid;
	}
	{
		no strict 'subs';
		truncate(Vend::Server::Pid, 0) or die "Couldn't truncate pid file: $!\n";
	}
	print Vend::Server::Pid $$, "\n";
	return 0;
}



sub open_pid {
	open(Vend::Server::Pid, "+>>$Global::PIDfile")
		or die "Couldn't open '$Global::PIDfile': $!\n";
	seek(Vend::Server::Pid, 0, 0);
	my $o = select(Vend::Server::Pid);
	$| = 1;
	{
		no strict 'refs';
		select($o);
	}
}

sub run_server {
	my $next;
	my $pid;
	
	open_pid();

	unless($Global::Inet_Mode || $Global::Unix_Mode || $Global::Windows) {
		$Global::Inet_Mode = $Global::Unix_Mode = 1;
	} elsif( $Global::Windows ) {
		$Global::Inet_Mode = 1;
	}

	my @types;
	push (@types, 'INET') if $Global::Inet_Mode;
	push (@types, 'UNIX') if $Global::Unix_Mode;
	my $server_type = join(" and ", @types);
	::logGlobal({}, "START server (%s) (%s)" , $$, $server_type );

	if($Global::Windows) {
		$pid = grab_pid();
		if($pid) {
			print errmsg(
				"The Interchange server is already running (process id %s)\n",
				$pid,
				);
			exit 1;
		}

		print errmsg("Interchange server started (%s) (%s)\n", $$, $server_type);
		$next = server_both($Global::SocketFile);
	} else {
		fcntl(Vend::Server::Pid, F_SETFD, 0)
			or die "Can't fcntl close-on-exec flag for '$Global::PIDfile': $!\n";
		my ($pid1, $pid2);
		if($pid1 = fork) {
			# parent
			wait;
			sleep 2;
			exit 0;
		} elsif(not defined $pid1) {
			# fork error
			print "Can't fork: $!\n";
			exit 1;
		} else {
			# child 1
			if($pid2 = fork) {
				# still child 1
				exit 0;
			} elsif(not defined $pid2) {
				print "child 1 can't fork: $!\n";
				exit 1;
			} else {
				# child 2
				sleep 1 until getppid == 1;

				$pid = grab_pid();
				if($pid) {
					print errmsg(
						"The Interchange server is already running (process id %s)\n",
						$pid,
						);
					exit 1;
				}
				print errmsg(
						"Interchange server started in %s mode(s) (process id %s)\n",
						$server_type,
						$$,
					 ) unless $Vend::Quiet;

				setsid();

				fcntl(Vend::Server::Pid, F_SETFD, 1)
					or die "Can't fcntl close-on-exec flag for '$Global::PIDfile': $!\n";

				$next = server_both($Global::SocketFile);

				unlockfile(\*Vend::Server::Pid);
				opendir(CONFDIR, $Global::ConfDir) 
					or die "Couldn't open directory $Global::ConfDir: $!\n";
				my @running = grep /^mvrunning/, readdir CONFDIR;
				for(@running) {
					unlink "$Global::ConfDir/$_" or die
						"Couldn't unlink status file $Global::ConfDir/$_: $!\n";
				}
				unlink $Global::PIDfile;
				exit 0;
			}
		}
	}                
}

## FILE PERMISSIONS

sub set_file_permissions {
	my($r, $w, $p, $u);

	$r = $Vend::Cfg->{'ReadPermission'};
	if($r eq 'user') {
		$p = 0400;   $u = 0277;
	} elsif($r eq 'group') {
		$p = 0440;   $u = 0227;
	} elsif($r eq 'world') {
		$p = 0444;   $u = 0222;
	} else {
		die "Invalid value for ReadPermission\n";
	}

	$w = $Vend::Cfg->{'WritePermission'};
	if($w eq 'user') {
		$p += 0200;  $u &= 0577;
	} elsif($w eq 'group') {
		$p += 0220;  $u &= 0557;
	} elsif($w eq 'world') {
		$p += 0222;  $u &= 0555;
	} else {
		die "Invalid value for WritePermission\n";
	}

	$Vend::Cfg->{'FileCreationMask'} = $p;
	$Vend::Cfg->{'Umask'} = $u;
}

## 

sub adjust_cgi {
	my($host);

	die "REQUEST_METHOD is not defined" unless defined $CGI::request_method
		or @Global::argv;

	# The great and really final AOL fix
	#
	$host      = $CGI::remote_host;
	$CGI::ip   = $CGI::remote_addr;

	if($Global::DomainTail and $host) {
		$host =~ s/.*?([-A-Za-z0-9]+\.[A-Za-z]+)$/$1/;
	} elsif($Global::IpHead) {
		$host = $Global::IpQuad == 0 ? 'nobody' : '';
		my @ip;
		@ip = split /\./, $CGI::ip;
		$CGI::ip = '';
		$CGI::ip = join ".", @ip[0 .. ($Global::IpQuad - 1)] if $Global::IpQuad;
	}
	#
	# end AOL fix

	$CGI::host = $host || $CGI::ip;

	if($CGI::remote_user) {
		$CGI::user = $CGI::remote_user;
		undef $CGI::authorization;
	}
	$Vend::Cookie = $CGI::cookie;

	unless ($Global::FullUrl) {
		$CGI::script_name = $CGI::script_path;
	} else {
		if($CGI::server_port eq '80') {
			$CGI::server_port = '';
		} else {
			$CGI::server_port = ":$CGI::server_port";
		}
		$CGI::script_name = $CGI::server_name .
					$CGI::server_port .
					$CGI::script_path;
	}
}

sub url_history {
	$Vend::Session->{History} = []
		unless defined $Vend::Session->{History};
	shift @{$Vend::Session->{History}}
		if $#{$Vend::Session->{History}} >= $Vend::Cfg->{History};
	if($CGI::pragma =~ /\bno-cache\b/ || $CGI::values{mv_no_cache}) {
		push (@{$Vend::Session->{History}},  [ 'expired', {} ]);
	} else {
		push (@{$Vend::Session->{History}},  [ $CGI::path_info, \%CGI::values ]);
	}
	return;
}

## DISPATCH

# Parse the invoking URL and dispatch to the handling subroutine.

my %action = (
	process	=> \&::do_process,
	ui_wrap => \&UI::Primitive::ui_wrap,
	ui=> sub { 
			&UI::Primitive::ui_acl_global();
			\&::do_process(@_);
		 },
	minimate=> sub { 
			&MiniMate::CfgMgr::mm_acl_global;
			\&::do_process(@_);
		       },
	scan	=> \&do_scan,
	search	=> \&do_search,
	order	=> \&::do_order,
	obtain	=> \&::do_order,
);

my $H;
sub http {
	return $H;
}

sub response {
	my($output) = @_;
	return 1 if $Vend::BuildingPages;
	my $out = ref $output ? $output : \$output;
	if(defined $Vend::CheckHTML) {
		require Vend::External;
		Vend::External::check_html($out);
	}
	$H->respond($out);
}

sub dispatch {
	my($http) = @_;
	$H = $http;
	if($Vend::Foreground) {
		Vend::Interpolate::reset_calc();
	}
#::logDebug ("begin dispatch: " . (join " ", times()) . "\n");
#::logDebug ("begin dispatch, locale LC_CTYPE: " . POSIX::setlocale(POSIX::LC_CTYPE()) . "\n");

	adjust_cgi();

	my($sessionid);
	my(@path);
	my($g, $action);

	unless (defined $Global::Selector{$CGI::script_name}) {
		my $msg = ::get_locale_message(
						403,
						"Undefined catalog: %s",
						$CGI::script_name,
						);
		$Vend::StatusLine = <<EOF;
Status: 404 Not Found
Content-Type: text/plain
EOF
		response($msg);
		logGlobal($msg);
		return;
	}
	$Vend::Cfg = $Global::Selector{$CGI::script_name};

## Uncomment this to get global directive setting on a per-catalog basis
## Probably only useful for:
##
##   DebugFile
##   DisplayErrors
##   DomainTail
##   ErrorLog
##   FullUrl
##   GlobalSub
##   HitCount
##   IpHead
##   IpQuad
##   Locale
##   LockoutCommand
##   NoAbsolute
##   SafeUntrap
##   UserTag
##   Variable

	my $catref = $Global::Catalog{$Vend::Cfg->{CatalogName}};
	if(! $Vend::Foreground and defined $catref->{directive}) {
		no strict 'refs';
		my ($key, $val);
		while ( ($key, $val) = each %{$catref->{directive}}) {
#::logDebug("directive key=$key val=" . ::uneval($val));
			${"Global::$key"} = $val;
		}
	}

	# See if it is a subcatalog
	if(defined $Vend::Cfg->{BaseCatalog}) {
		my $name = $Vend::Cfg->{BaseCatalog};
		my $ref = $Global::Catalog{$name};
		my $c = $Vend::Cfg;
		$Vend::Cfg = $Global::Selector{$ref->{'script'}};
		for(keys %{$c->{Replace}}) {
			undef $Vend::Cfg->{$_};
		}
		::copyref($c, $Vend::Cfg);
		if($Vend::Cfg->{Variable}{MV_LANG}) {
			my $loc = $Vend::Cfg->{Variable}{MV_LANG};
			$Vend::Cfg->{Locale} = $Vend::Cfg->{Locale_repository}{$loc}
					if defined $Vend::Cfg->{Locale_repository}{$loc};
		}
		$Vend::Cfg->{StaticPage} = {}
			unless $Vend::Cfg->{Static};
	}
	$::Variable = $Vend::Cfg->{Variable};


	if(defined $Global::SelectorAlias{$CGI::script_name}
		and ! defined $Vend::InternalHTTP                 )
	{
		my $real = $Global::SelectorAlias{$CGI::script_name};
		if(defined $Vend::NoFork) {
			$Vend::Save = {} unless $Vend::Save;
			$Vend::Save->{VendURL}   = $Vend::Cfg->{VendURL};
			$Vend::Save->{SecureURL} = $Vend::Cfg->{SecureURL};
		}
		unless ($CGI::secure                                        or
			$Vend::Cfg->{SecureURL} =~ m{$CGI::script_name$}    and
			$Vend::Cfg->{VendURL}   !~ m{/nph-[^/]+$} 	    and
			$Vend::Cfg->{VendURL}   !~ m{$CGI::script_name$} )
		{
			$Vend::Cfg->{VendURL}   =~ s!$real!$CGI::script_name!;
			$Vend::Cfg->{SecureURL} =~ s!$real!$CGI::script_name!;
		}
	} elsif($Vend::InternalHTTP) {
		$Vend::Cfg->{VendURL} = "http://" .
					$CGI::http_host .
					$CGI::script_path;
		$Vend::Cfg->{ImageDir} = $Vend::Cfg->{ImageDirInternal}
			if  $Vend::Cfg->{ImageDirInternal};
	}

	if($Global::HitCount) {
		my $ctr = new File::CounterFile
			"$Global::ConfDir/hits.$Vend::Cfg->{CatalogName}";
		$ctr->inc();
	}

	if($Vend::Cfg->{SetGroup}) {
		eval {
			$) = "$Vend::Cfg->{SetGroup} $Vend::Cfg->{SetGroup}";
		};
		if($@) {
			my $msg = $@;
			logGlobal( "Can't set group to GID %s: %s",
					$Vend::Cfg->{SetGroup}, $msg
				 );
			logError("Can't set group to GID %s: %s",
					$Vend::Cfg->{SetGroup}, $msg
				 );
		}
	}

	chdir $Vend::Cfg->{VendRoot} 
		or die "Couldn't change to $Vend::Cfg->{VendRoot}: $!\n";
	set_file_permissions();
# STATICPAGE
	::tie_static_dbm() if $Vend::Cfg->{StaticDBM};
# END STATICPAGE
	umask $Vend::Cfg->{Umask};
	::open_database();

	$CGI::user = Vend::Util::check_authorization($CGI::authorization)
		if defined $CGI::authorization;

	my $from_cookie;
	$sessionid = $CGI::values{mv_session_id} || undef;
	$Vend::OnlyProducts = defined $Vend::Cfg->{ProductFiles}->[1]
					  ? undef
					  : $Vend::Cfg->{ProductFiles}->[0];

	if(defined $CGI::cookie and
		 $CGI::cookie =~ /\bMV_SESSION_ID=(\w{8,32})
								[:_] (
								 # An IP ADDRESS
								 (\d{1,3}\.
								  \d{1,3}\.
								  \d{1,3}\.
								  \d{1,3})
								|
								 # A user name or domain
								 ([A-Za-z0-9][-\@A-Za-z.0-9]+)
								)?\b/x)
	{
		$sessionid = $1
			unless defined $CGI::values{mv_pc} and $CGI::values{mv_pc} eq 'RESET';
		$CGI::cookiehost = $3 || undef;
		$CGI::cookieuser = $4 || undef;
		$from_cookie = 1;
	}

	$CGI::host = 'nobody' if $Vend::Cfg->{WideOpen};

	if(! $sessionid) {
		my $id = $::Variable->{MV_SESSION_ID};
		$sessionid = $CGI::values{$id} if $CGI::values{$id};
		if(! $sessionid and $Vend::Cfg->{FallbackIP}) {
			$sessionid = ::generate_key($CGI::remote_addr . $CGI::useragent);
		}
	} elsif($sessionid !~ /^\w+$/) {
		my $msg = ::get_locale_message(
						403,
						"Unauthorized for that session %s. Logged.",
						$sessionid,
						);
		$Vend::StatusLine = <<EOF;
Status: 403 Unauthorized
Content-Type: text/plain
EOF
		response($msg);
		logGlobal($msg);
		return;
	}

# DEBUG
#::logDebug ("session='$sessionid' cookie='$CGI::cookie' chost='$CGI::cookiehost'");
# END DEBUG

	RESOLVEID: {
		if($sessionid) {
			$Vend::SessionID = $sessionid;
			$Vend::SessionName = ::session_name();
			# if not it will return false and a new session has been created.
			# The IP address will be counted for robot_resolution
			if(! ::get_session()) {
				::retire_id($sessionid);
				last RESOLVEID;
			}
			my $now = time;
			if(! $from_cookie) {
				if( ::is_retired($sessionid) ) {
					::new_session();
					last RESOLVEID;
				}
				my $compare_host = $CGI::secure
							? ($Vend::Session->{shost})
							: ($Vend::Session->{ohost});

				if(! $compare_host) {
					::new_session() unless $CGI::secure;
					$Vend::Session->{shost} = $CGI::secure;
				} elsif($compare_host ne $CGI::remote_addr) {
					::new_session();
				}
			}
			if($now - $Vend::Session->{'time'} > $Vend::Cfg->{SessionExpire}) {
				::retire_id($sessionid);
				::new_session();
				last RESOLVEID;
			} elsif($Vend::Cfg->{RobotLimit}) {
				if($now - $Vend::Session->{'time'} > 30) {
					$Vend::Session->{accesses} = 0;
				} else {
					$Vend::Session->{accesses}++;
					if($Vend::Session->{'accesses'} > $Vend::Cfg->{RobotLimit}) {
						my $msg = ::errmsg(
							"WARNING: POSSIBLE BAD ROBOT. %s accesses with no 30 second pause.",
							$Vend::Session->{accesses},
						);
						::do_lockout($msg);
					}
				}
			}
		} else {
			if($Vend::Cfg->{RobotLimit}) {
				if(Vend::Session::count_ip() > $Vend::Cfg->{RobotLimit}) {
					my $msg;
					# Here they can get it back if they pass expiration time
					my $wait = $Global::Variable->{MV_ROBOT_EXPIRE} || 86400;
					$wait /= 3600;
					$msg = ::errmsg(<<EOF, $wait); 
Too many new ID assignments for this IP address. Please wait at least %d hours
before trying again. Only waiting that period will allow access. Terminating.
EOF
					$msg = ::get_locale_message(403, $msg);
					::do_lockout($msg);
					$Vend::StatusLine = <<EOF;
Status: 403 Forbidden
Content-Type: text/plain
EOF
						response($msg);
						return;
				}
			}
			::new_session();
		}
	}

#::logDebug("session name='$Vend::SessionName'\n");
::logError("session id='$Vend::SessionID'");

	$Vend::Interpolate::Calc_initialized = 0;
	$CGI::values{mv_session_id} = $Vend::Session->{id} = $Vend::SessionID;

	if($Vend::Cfg->{CookieLogin}) {
		COOKIELOGIN: {
			last COOKIELOGIN if $Vend::Session->{logged_in};
			last COOKIELOGIN if defined $CGI::values{mv_username};
			last COOKIELOGIN unless
				$CGI::values{mv_username} = Vend::Util::read_cookie('MV_USERNAME');
			my $password;
			last COOKIELOGIN unless
				$password = Vend::Util::read_cookie('MV_PASSWORD');
			$CGI::values{mv_password} = $password;
			local(%SIG);
			undef $SIG{__DIE__};
			eval {
				Vend::UserDB::userdb('login');
			};
			if($@) {
				$Vend::Session->{failure} .= $@;
			}
		}
	}

	$Vend::Session->{'arg'} = $Vend::Argument = ($CGI::values{mv_arg} || undef);
#::logDebug("arg is $Vend::Session->{arg}");
	if($CGI::values{mv_pc} and $CGI::values{mv_pc} =~ /[A-Za-z]/) {
		$Vend::Session->{'source'} =	$CGI::values{mv_pc} eq 'RESET'
						? ''
						: $CGI::values{mv_pc};
	}

	$Vend::Session->{'user'} = $CGI::user;
::logError("username='$Vend::Session->{username}'");
::logError("loggedin='".$Vend::Session->{logged_in}."'");

	undef $Vend::Cookie if 
		$Vend::Session->{logged_in} && ! $Vend::Cfg->{StaticLogged};

	$CGI::pragma = 'no-cache'
		if delete $::Scratch->{mv_no_cache};

	$Vend::FinalPath = $Vend::Session->{last_url} = $CGI::path_info;
	if(defined $Vend::Session->{one_time_path_alias}{$Vend::FinalPath}) {
		$CGI::path_info =
		$Vend::FinalPath =
		delete $Vend::Session->{one_time_path_alias}{$Vend::FinalPath};
	} elsif( defined $Vend::Session->{path_alias}{$Vend::FinalPath}	) {
		$CGI::path_info =
		$Vend::FinalPath =
		$Vend::Session->{path_alias}{$Vend::FinalPath};
	}
	url_history($Vend::FinalPath) if $Vend::Cfg->{History};

# TRACK
	$Vend::Track = new Vend::Track();
# END TRACK

	if($Vend::Cfg->{DisplayErrors} and $Global::DisplayErrors) {
		$SIG{"__DIE__"} = sub {
					my $msg = shift;
					response( <<EOF);
<HTML><HEAD><TITLE>Fatal Interchange Error</TITLE></HEAD><BODY>
<H1>FATAL error</H1>
<PRE>$msg</PRE>
</BODY></HTML>
EOF
					exit 0;
				      };
	}

# LEGACY
	ROUTINES: {
		last ROUTINES unless index($Vend::FinalPath, '/process/') == 0;
		while ($Vend::FinalPath =~ s:/process/(locale|language|currency)/([^/]*)/:/process/:) {
			$::Scratch->{"mv_$1"} = $2;
		}
		$Vend::FinalPath =~ s:/process/page/:/:;
	}
	my $locale;
	if($locale = $::Scratch->{mv_language}) {
		$Global::Variable->{LANG}
			= $::Variable->{LANG} = $locale;
	}

	if($Vend::Cfg->{Locale}								and
		$locale = $::Scratch->{mv_locale}	and
		defined $Vend::Cfg->{Locale_repository}->{$locale}
		)
	{ 
		$Global::Variable->{LANG}
				= $::Variable->{LANG}
				= $::Scratch->{mv_language}
				= $locale
			 if ! $::Scratch->{mv_language};
		Vend::Util::setlocale(	$locale,
								($::Scratch->{mv_currency} || undef),
								{ persist => 1 }
							);
	}
# END LEGACY

	my $macro;
	if($macro = $Vend::Cfg->{Autoload}) {
		if($macro =~ /\[\w+/) {
			::interpolate_html($macro);
		} elsif($macro =~ /^\w+$/) {
			my $sub = $Vend::Cfg->{Sub}{$macro} || $Global::GlobalSub->{$macro};
			$sub->();
		}
	}

	if($macro = $Vend::Cfg->{Filter}) {
		for(keys %$macro) {
			Vend::Interpolate::input_filter_do($_, { 'op' => $macro->{$_} } );
		}
	}

	if(
		defined $Vend::Session->{Filter} and
		$macro = $Vend::Session->{Filter}
		)
	{
		for(keys %$macro) {
			Vend::Interpolate::input_filter_do($_, $macro->{$_});
		}
	}

	if(
		defined $Vend::Session->{Autoload} and
		$macro = $Vend::Session->{Autoload}
		)
	{
		if(ref $macro) {
			for (@$macro) {
				::interpolate_html($_);
			}
		} else {
			::interpolate_html($macro);
		}
	}

	# If the cgi-bin program was invoked with no extra path info,
	# just display the catalog page.
	if(! $Vend::FinalPath || $Vend::FinalPath =~ m:^/+$:) {
		$Vend::FinalPath = ::find_special_page('catalog');
	}

	$Vend::FinalPath =~ s:^/+::;
	$Vend::FinalPath =~ s/(\.html?)$//;
	$Vend::Session->{extension} = $1 || '';
#::logDebug("path=$Vend::FinalPath");

	DOACTION: {
		@path = split('/', $Vend::FinalPath, 2);
		if(defined $CGI::values{mv_action}) {
			$CGI::values{mv_todo} = $CGI::values{mv_action}
				if ! defined $CGI::values{mv_todo}
				and ! defined $CGI::values{mv_doit};
			if($path[0] eq 'ui_wrap') {
				$Vend::Action = 'ui_wrap';
				delete $CGI::values{mv_action};
				shift(@path);
				$CGI::values{mv_nextpage} = $path[0]
					if ! defined $CGI::values{mv_nextpage};
				$path[0] = "process/$path[0]";
			} else {
				$Vend::Action = 'process';
				$CGI::values{mv_nextpage} = $Vend::FinalPath
					if ! defined $CGI::values{mv_nextpage};
			}
		} else {
			$Vend::Action = shift @path;
		}

#::logGlobal("action=$Vend::Action path=$Vend::FinalPath");
::logError ("action=$Vend::Action path=$Vend::FinalPath");
		my ($sub, $status);
		Vend::Interpolate::reset_calc();
		if(defined $Vend::Cfg->{ActionMap}{$Vend::Action}) {
			$sub = $Vend::Cfg->{ActionMap}{$Vend::Action};
			Vend::Interpolate::init_calc();
			$CGI::values{mv_nextpage} = $Vend::FinalPath
				if ! defined $CGI::values{mv_nextpage};
			new Vend::Parse;
		} elsif( defined ($sub = $action{$Vend::Action}) )  {
			Vend::Interpolate::init_calc();
			$Vend::FinalPath = join "", @path;
		}

		eval {
			if(defined $sub) {
#::logDebug("found sub");
				$status = $sub->($Vend::FinalPath);
			} else {
				$status = 1;
			}
		};
		(undef $Vend::RedoAction, redo DOACTION) if $Vend::RedoAction;

		if($@) {
			undef $status;
			my $err = $@;
			my $template = <<EOF;
Sorry, there was an error in processing this form action. Please 
report the error or try again later.
EOF
			$template .= "\n\nError: %s\n"
				if $Global::DisplayErrors && $Vend::Cfg->{DisplayErrors}
				;
			$template = ::get_locale_message(500, $template, $err);
			$template .= "($err)";
			response($template);
		}

		$CGI::values{mv_nextpage} = $Vend::FinalPath
			if ! defined $CGI::values{mv_nextpage};

		::do_page() if $status;

#::logDebug ("end dispatch: " . (join " ", times()) . "\n");

		if(my $macro = $Vend::Cfg->{AutoEnd}) {
			if($macro =~ /\[\w+/) {
				::interpolate_html($macro);
			} elsif($macro =~ /^\w+$/) {
				$sub = $Vend::Cfg->{Sub}{$macro} || $Global::GlobalSub->{$macro};
				$sub->();
			}
		}
	}

# TRACK
	$Vend::Track->filetrack();
# END TRACK

::logError("havsession=$Vend::HaveSession");
	::put_session() if $Vend::HaveSession;
	::close_database();

	undef $H;
	if($Vend::Save) {
		::copyref($Vend::Save, $Vend::Cfg);
		undef $Vend::Save;
	}
	undef $Vend::Cfg;

# DEBUG
#::logDebug ("closed all: " .  join " ", times() . "\n");
# END DEBUG

	return 1;
}

1;
__END__

