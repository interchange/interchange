# Vend::Dispatch - Handle Interchange page requests
#
# Copyright (C) 2002-2010 Interchange Development Group
# Copyright (C) 2002 Mike Heins <mike@perusion.net>
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

package Vend::Dispatch;

use vars qw($VERSION);
$VERSION = '1.101.2.3';

use POSIX qw(strftime);
use Vend::Util;
use Vend::Interpolate;
use Vend::Data;
use Vend::Config;
use autouse 'Vend::Error' => qw/get_locale_message interaction_error do_lockout full_dump/;
use Vend::Order;
use Vend::Session;
use Vend::Page;
use Vend::UserDB;
use Vend::CounterFile;
no warnings qw(uninitialized numeric);

# TRACK
use Vend::Track;
# END TRACK

require Exporter;

@ISA = qw(Exporter);

@EXPORT = qw( 

				config_named_catalog
				dispatch
				do_process
				http
				response
				run_macro
				tie_static_dbm
				update_user
				update_values
			);

use strict;

my $H;
sub http {
	return $H;
}

sub response {
	my $possible = shift;
	return if $Vend::Sent;

	if (defined $possible and ! $::Pragma->{download}) {
		push @Vend::Output, (ref $possible ? $possible : \$possible);
	}

	if($::Pragma->{download}) {
		$H->respond(ref $possible ? $possible : \$possible);
	}
	elsif($Vend::MultiOutput) {
		for my $space (keys %Vend::OutPtr) {
			my $things = $Vend::OutPtr{$space} || [];
			for my $ptr (@$things) {
				my $subs = $Vend::OutFilter{$space} || [];
				for my $sub (@$subs) {
					$sub->($Vend::Output[$ptr]);
				}
			}
		}
		for(grep $_, @Vend::Output) {
			$H->respond($_);
		}
	}
	else {
		for(@Vend::Output) {
			Vend::Interpolate::substitute_image($_);
			$H->respond($_);
		}
	}
	@Vend::Output = ();
}

# Parse the mv_click and mv_check special variables
sub parse_click {
	my ($ref, $click, $extra) = @_;
    my($codere) = '[-\w_#/.]+';
	my $params;

#::logDebug("Looking for click $click");
	if($params = $::Scratch->{$click}) {
		# Do nothing, we found the click
#::logDebug("Found scratch click $click = |$params|");
	}
	elsif(defined ($params = $Vend::Cfg->{OrderProfileName}{$click}) ) {
		# Do nothing, we found the click
		$params = $Vend::Cfg->{OrderProfile}[$params];
#::logDebug("Found profile click $click = |$params|");
	}
	elsif(defined ($params = $Global::ProfilesName->{$click}) ) {
		# Do nothing, we found the click
		$params = $Global::Profiles->[$params];
#::logDebug("Found profile click $click = |$params|");
	}
	elsif($params = $::Scratch->{"mv_click $click"}) {
		$::Scratch->{mv_click_arg} = $click;
	}
	elsif($params = $::Scratch->{mv_click}) {
		$::Scratch->{mv_click_arg} = $click;
	}
	else {
#::logDebug("Found NO click $click");
		return 1;
	} # No click processor

	my($var,$val,$parameter);
	$params = interpolate_html($params);
	my(@param) = split /\n+/, $params;

	for(@param) {
		next unless /\S/;
		next if /^\s*#/;
		s/^[\r\s]+//;
		s/[\r\s]+$//;
		$parameter = $_;
		($var,$val) = split /[\s=]+/, $parameter, 2;
		$val =~ s/&#(\d+);/chr($1)/ge;
		$ref->{$var} = $val;
		$extra->{$var} = $val
			if defined $extra;
	}
}

## This is the set of variables we don't want to dump or save in
## sessions for security reasons.
@Global::HideCGI = qw(
						mv_password
						mv_verify
						mv_password_old
						mv_credit_card_number
						mv_credit_card_cvv2
					);

# This is the set of CGI-passed variables to ignore, in other words
# never set in the user session.  If set in the mv_check pass, though,
# they will stick.
%Global::Ignore = qw(
	mv_todo  1
	mv_todo.submit.x  1
	mv_todo.submit.y  1
	mv_todo.return.x  1
	mv_todo.return.y  1
	mv_todo.checkout.x  1
	mv_todo.checkout.y  1
	mv_todo.todo.x  1
	mv_todo.todo.y  1
	mv_todo.map  1
	mv_doit  1
	mv_check  1
	mv_click  1
	mv_nextpage  1
	mv_failpage  1
	mv_password  1
	mv_verify  1
	mv_password_old  1
	mv_successpage  1
	mv_more_ip  1
	mv_credit_card_number  1
	mv_credit_card_cvv2  1
	);


## FILE PERMISSIONS
sub set_file_permissions {
	my($r, $w, $p, $u);

	$r = $Vend::Cfg->{'ReadPermission'};
	if    ($r eq 'user')  { $p = 0400;   $u = 0277; }
	elsif ($r eq 'group') { $p = 0440;   $u = 0227; }
	elsif ($r eq 'world') { $p = 0444;   $u = 0222; }
	else                  { die "Invalid value for ReadPermission\n"; }

	$w = $Vend::Cfg->{'WritePermission'};
	if    ($w eq 'user')  { $p += 0200;  $u &= 0577; }
	elsif ($w eq 'group') { $p += 0220;  $u &= 0557; }
	elsif ($w eq 'world') { $p += 0222;  $u &= 0555; }
	else                  { die "Invalid value for WritePermission\n"; }

	$Vend::Cfg->{'FileCreationMask'} = $p;
	$Vend::Cfg->{'Umask'} = $u;
}

sub update_values {

	my (@keys) = @_;

	my $set;
	if(@keys) {
		$set = {};
		@{$set}{@keys} = @CGI::values{@keys};
	}
	else {
		$set = \%CGI::values;

		if( $Vend::Cfg->{CreditCardAuto} and $CGI::values{mv_credit_card_number} ) {
			(
				@{$::Values}{
					qw/
							mv_credit_card_valid
							mv_credit_card_info
							mv_credit_card_exp_month
							mv_credit_card_exp_year
							mv_credit_card_exp_all
							mv_credit_card_type
							mv_credit_card_reference
							mv_credit_card_error
					/ }
			) = encrypt_standard_cc(\%CGI::values);
		}	
	}

	my $restrict;
	if($restrict = $Vend::Session->{restrict_html} and ! ref $restrict) {
		$restrict = [ map { lc $_ } split /\s+/, $restrict ];
		$Vend::Session->{restrict_html} = $restrict;
	}

    while (my ($key, $value) = each %$set) {
		# values explicly ignored in configuration
        next if defined $Global::Ignore{$key};
        next if defined $Vend::Cfg->{FormIgnore}{$key};

#LEGACY
		# We add any checkbox ordered items, but don't update -- 
		# we don't want to order them twice
        next if ($key =~ m/^quantity\d+$/);
#END LEGACY

		# Admins should know what they are doing
		if($Vend::admin) {
			$::Values->{$key} = $value;
			next;
		}
		elsif ($restrict and $value =~ /</) {
			# Allow designer to allow only certain HTML tags from trusted users
			# Will go away when current session ends...
			# [ script start character handled in [value ...] ITL tag
			$value = Vend::Interpolate::filter_value(
						'restrict_html',
						$value,
						undef,
						@$restrict,
					);
			$::Values->{$key} = $value;
			next;
		}
		$value =~ tr/<[//d;
		$value =~ s/&lt;//ig;
		$value =~ s/&#91;//g;
        $::Values->{$key} = $value;
    }
}

sub update_user {
	my($key,$value);
    # Update the user-entered fields.

	add_items() if defined $CGI::values{mv_order_item};
	update_values();

	if($CGI::values{mv_check}) {
		my(@checks) = split /\s*[,\0]+\s*/, delete $CGI::values{mv_check};
		my($check);
		foreach $check (@checks) {
				parse_click $::Values, $check, \%CGI::values;	
		}
	}

	check_save if defined $CGI::values{mv_save_session};

}

## DO PROCESS

sub do_click {
	my($click, @clicks);
	do {
		if($CGI::values{mv_click}) {
			@clicks = split /\s*[\0]+\s*/, delete $CGI::values{mv_click};
		}

		if(defined $CGI::values{mv_click_map}) {
			my(@map) = split /\s*[\0]+\s*/, delete $CGI::values{mv_click_map};
			foreach $click (@map) {
				push (@clicks, $click)
					if defined $CGI::values{"mv_click.$click.x"}
					or defined $CGI::values{"$click.x"}
					or $click = $CGI::values{"mv_click_$click"};
			}
		}

		foreach $click (@clicks) {
			parse_click \%CGI::values, $click;
		}
	} while $CGI::values{mv_click};
	return 1;
}

sub do_deliver {
	my $file = $CGI::values{mv_data_file};
	my $mode = $CGI::values{mv_acl_mode} || '';
	if($::Scratch->{mv_deliver} !~ m{(^|\s)$file(\s|$)}
		and 
		! Vend::UserDB::userdb(
							'check_file_acl',
							location => $file,
							mode => $mode,
							)
		)
	{
		$Vend::StatusLine = "Status: 403\nContent-Type: text/html";
		my $msg = get_locale_message(403, <<EOF);
<b>Authorization Required</b>
<p>
This server could not verify that you are authorized to access the document
requested. 
</p>
EOF
		response($msg);
		return 0;
	}

	if (! -f $file) {
		$Vend::StatusLine = "Status: 404\nContent-Type: text/html";
		my $msg = get_locale_message(404, <<EOF, $file);
<b>Not Found</b>
<p>
The requested file %s was not found on this server.
</p>
EOF
		response($msg);
		return 0;
	}

	my $size = -s $CGI::values{mv_data_file};
	$CGI::values{mv_content_type} ||=  'application/octet-stream';
	$Vend::StatusLine = <<EOF;
Content-Type: $CGI::values{mv_content_type}
Content-Length: $size
EOF
	::response(	Vend::Util::readfile ($CGI::values{mv_data_file}) );
	return 0;
}

my %form_action = (

	search	=> \&do_search,
	deliver	=> \&do_deliver,
	submit	=>
				sub {
					update_user();
					update_quantity()
						or return interaction_error("quantities");
					my $ok;
					my($missing,$next,$status,$final,$result_hash);

					# Set shopping cart if necessary
					# Vend::Items is tied, remember!
					$Vend::Items = $CGI::values{mv_cartname}
						if $CGI::values{mv_cartname};

#::logDebug("Default order route=$::Values->{mv_order_route}");
					## Determine the master order route, if routes
					## are not set in CGI values (4.7.x default)
					if(
						$Vend::Cfg->{Route}
						and ! defined $::Values->{mv_order_route}
						)
					{
						my $curr = $Vend::Cfg->{Route};
						my $repos = $Vend::Cfg->{Route_repository};

						if($curr->{master}) {
							# Default route is master

							for(keys %$repos) {
								next unless $curr eq $repos->{$_};
								$::Values->{mv_order_route} = $_;
								last;
							}
						}
						else {
							for(keys %$repos) {
								next unless $repos->{$_}->{master};
								$::Values->{mv_order_route} = $_;
								last;
							}
						}
					}

#::logDebug("Default order route=$::Values->{mv_order_route}");

				  CHECK_ORDER: {

					# If the user sets this later, will be used
					delete $Vend::Session->{mv_order_number};

					if (defined $CGI::values{mv_order_profile}) {
						($status,$final,$missing) =
							check_order($CGI::values{mv_order_profile});
					}
					else {
						$status = $final = 1;
					}
#::logDebug("Profile status status=$status final=$final errors=$missing");

					my $provisional;
					if ($status and defined $::Values->{mv_order_route}) {
						# This checks only route order profiles
#::logDebug("Routing order, pre-check");
						($status, $provisional, $missing)
										= route_order(
												$::Values->{mv_order_route},
												$Vend::Items,
												'check',
											);
					} 

					$final = $provisional if ! $final;

#::logDebug("Routing status status=$status final=$final errors=$missing");
					if($status) {
						$CGI::values{mv_nextpage} = $CGI::values{mv_successpage} 
							if $CGI::values{mv_successpage};
						$CGI::values{mv_nextpage} = $::Values->{mv_orderpage} 
							if ! $CGI::values{mv_nextpage};
					}
					else {
						$CGI::values{mv_nextpage} = $CGI::values{mv_failpage}
							if $CGI::values{mv_failpage};
						$CGI::values{mv_nextpage} = find_special_page('needfield')
							if ! $CGI::values{mv_nextpage};
						undef $final;
					}

					return 1 unless $final;

					my $order_no;
					if (defined $::Values->{mv_order_route}) {
						# $ok will not be defined unless Route "supplant" was set
						# $order_no will come back so we don't issue two of them
#::logDebug("Routing order $::Values->{mv_order_route}");
						($ok, $order_no, $result_hash) = route_order(
											$::Values->{mv_order_route},
											$Vend::Items
											);
						return 1 unless $ok;
					}

					$result_hash = {} unless $result_hash;

# TRACK
                    $Vend::Track->finish_order () if $Vend::Track;
# END TRACK
					# This function (followed down) now does the rudimentary
					# backend ordering with AsciiTrack and the order report.
					# If the "supplant" option was set in order routing it will
					# not be used ($ok would have been defined)


#::logDebug("Order number=$order_no\n");
					$ok = mail_order(undef, $order_no || undef) unless defined $ok;
#::logDebug("Order number=$order_no, result_hash=" . ::uneval($result_hash));

					# Display a receipt if configured

					my $not_displayed = 1;

					if(! $ok) {
						display_special_page(
								find_special_page('failed'),
								errmsg('Error transmitting order(%s): %s', $!, $@),
						);
					}
					elsif (! $result_hash->{no_receipt} ) {
						eval {

							my $receipt = $result_hash->{receipt}
										|| $::Values->{mv_order_receipt}
										|| find_special_page('receipt');
#::logDebug("selected receipt=$receipt");
							display_special_page($receipt);
						};
						$not_displayed = 0;
#::logDebug("not_displayed=$not_displayed");
						if($@) {
							my $msg = $@;
							logError( 
								'Display of receipt on order number %s failed: %s',
								$::Values->{mv_order_number},
								$msg,
							);
						}
					}

					# Remove the items
					@$Vend::Items = ();
#::logDebug("returning order_number=$order_no, not_displayed=$not_displayed");
					return $not_displayed;
				  }
			},
	refresh	=> sub {
					update_quantity()
						or return interaction_error("quantities");
# LEGACY
					$CGI::values{mv_nextpage} = $CGI::values{mv_orderpage}
						if $CGI::values{mv_orderpage};
# END LEGACY
					$CGI::values{mv_nextpage} = $CGI::values{mv_orderpage}
												|| find_special_page('order')
						if ! $CGI::values{mv_nextpage};
					update_user();
					return 1;
				},
	set		=> sub {
					update_user() unless $CGI::values{mv_data_auto_number};
					update_data();
					update_user() if $CGI::values{mv_data_auto_number};
					return 1;
				},
	autoset	=> sub {
					update_data();
					update_user();
					return 1;
				},
	back    => sub { return 1 },
	return	=> sub {
					update_user();
					update_quantity()
						or return interaction_error("quantities");
					return 1;
				},
	cancel	=> sub {
					put_session();
					get_session();
					init_session();
					$CGI::values{mv_nextpage} = find_special_page('canceled')
						if ! $CGI::values{mv_nextpage};
					return 1;
				},
);

$form_action{go} = $form_action{return};

# Process the completed order or search page.

sub do_process {

	# Prevent using keys operation more than once
    my @cgikeys = keys %CGI::values;

    my @multis = grep /^mv\d\d?_/, @cgikeys;

	## Only operates on up to 100 items to prevent "amplification"
	## which could result in DOS attacks
	MULTIS:
	if(@multis) {
		my %hash;
		for(@multis) {
			my $val = delete $CGI::values{$_};
			# Have to handle nulls somehow....
			$val =~ s/\0/::/g;
			m{^mv\d+\d?_(.*)};
			my $idx = $1;
			my $key = $2;
			$hash{$key} ||= [];
			$hash{$key}[$idx] = $val;
		}
		while (my ($k, $v) = each %hash) {
			$CGI::values{$k} = join "\0", @$v;
		}
	}

    my @filters = grep /^[mu][vi]_filter:/, @cgikeys;

	FILTERS: {
		last FILTERS unless @filters;
		foreach my $key (@filters) {
			next unless $key =~ /^ui_|^mv_/;
			my $val = delete $CGI::values{$key};
			$key =~ s/^.._filter://;
			next unless $val;
			if($val =~ /checkbox/) {
				$CGI::values{$key} = $Tag->filter($val, $CGI::values{$key}, $key);
			}
			else {
				next unless defined $CGI::values{$key};
				$CGI::values{$key} = $Tag->filter($val, $CGI::values{$key}, $key);
			}
		}
	}

	if($CGI::values{mv_form_profile}) {
		my ($status) = check_order(
							$CGI::values{mv_form_profile},
							\%CGI::values,
							$CGI::values{mv_individual_profile},
							);
		return 1 if defined $status and ! $status;
	}

    my $orig_todo = $CGI::values{mv_todo};

	do_click();

    my $todo = $CGI::values{mv_todo};

	# Maybe we have an imagemap input, if not, use $doit
	if($orig_todo ne $todo) {
		# Don't mess with it, changed in click
	}
	elsif (defined $CGI::values{'mv_todo.x'}) {
		my $x = $CGI::values{'mv_todo.x'};
		my $y = $CGI::values{'mv_todo.y'};
		my $map = $CGI::values{'mv_todo.map'};
		# Called with action_map and not package id
		# since "autouse" is possibly in force...found
		# by Jeff Carnahan
		$todo = action_map($x,$y,$map);
	}
	elsif( my @todo = grep /^mv_todo\.\w+(?:\.x)?$/, @cgikeys ) {
		# Only one todo!
		for(@todo) {
			delete $CGI::values{$_};
			s/^mv_todo\.(\w+)(?:\.[xy])?$/$1/;
		}
		$todo = shift @todo;
	}

	$todo = $CGI::values{mv_doit} || 'back' if ! $todo;

#::logDebug("todo=$todo after mv_click");

	my ($sub, $status);
	#Now determine the action on the todo
    if (defined $Vend::Cfg->{FormAction}{$todo}) {
		$sub = $Vend::Cfg->{FormAction}{$todo};
	}
    elsif (not $sub = $form_action{$todo} ) {
		unless ($sub = Vend::Util::codedef_routine('FormAction', $todo)) {
		interaction_error("No action passed for processing\n");
		return;
    }
    }
	eval {
		$status = $sub->($todo);
	};
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
		$template = get_locale_message(500, $template, $err);
		$template .= "($err)";
		logError($err);
		response($template);
	}

	if($CGI::values{mv_cleanup}) {
		my(@checks) = split /\s*[,\0]+\s*/, delete $CGI::values{mv_cleanup};
		my($check);
		foreach $check (@checks) {
				parse_click $::Values, $check, \%CGI::values;	
		}
	}

	return $status;
}

sub run_in_catalog {
	my ($cat, $job, $itl, $parms) = @_;
	my ($g,$c);

#::logGlobal("running job in cat=$cat");
	$parms ||= {};
	
	$g = $Global::Catalog{$cat};
	unless (defined $g) {
		logGlobal( "Can't find catalog '%s' for jobs group %s" , $cat, $job );
		return undef;
	}

	open_cat($cat);

	logError("Run jobs group=%s pid=$$", $job || 'INTERNAL');

	Vend::Server::set_process_name("job $cat $job");
	
	my $jobscfg = $Vend::Cfg->{Jobs};

	my $dir;
	my @itl;
	if($job) {
		my @jobdirs = ([$jobscfg->{base_directory} || 'etc/jobs', 0]);

		if (is_yes($jobscfg->{use_global}) || is_yes($Global::Jobs->{UseGlobal})) {
			push (@jobdirs, ["$Global::ConfDir/jobs", 1]);
		}

		my $global_dir;
		for my $r (@jobdirs) {
			my $d;
			($d, $global_dir) = @$r;
#::logGlobal("check directory=$d for $job");
			next unless $d;
			next unless -d "$d/$job";
			$dir = "$d/$job";
			last;
		}

		if($dir) {
			my $tmp;
			if ($global_dir) {
				$tmp = $Global::AllowedFileRegex->{$cat};
				$Global::AllowedFileRegex->{$cat} = qr{^$dir};
			}
			
			my @f = glob("$dir/*");
			@f = grep ! -d $_, @f;
			@f = grep $_ !~ /$Vend::Cfg->{HTMLsuffix}$/, @f;
			@f = grep $_ =~ /$jobscfg->{suffix}$/, @f;
			for(@f) {
#::logGlobal("found jobs piece file=$_");
				push @itl, [$_, readfile($_)];
			}

			if ($global_dir) {
				$Global::AllowedFileRegex->{$cat} = $tmp;
			}
		}
	}

	if ($itl) {
		push @itl, ["Passed ITL", $itl];
	}

	my (@out, $errors, $failure);

	# remove bogus session created by logError
	undef $Vend::Session;
	
	if(@itl) {
		# Track job
		my ($trackdb, $trackid);
		
		if ($jobscfg->{trackdb}) {
			if ($trackdb = database_exists_ref($jobscfg->{trackdb})) {
				$trackid = $trackdb->set_slice('', [qw(name begin_run pid)],
											   [$job, Vend::Interpolate::mvtime(undef, {}, '%Y-%m-%d %H:%M'), $$]);
			}
			else {
				::logError ("Invalid jobs tracking database $jobscfg->{trackdb}");
			}
		}

		eval {
			# Run once at beginning
			run_macro($jobscfg->{initialize});

			# initialize or autoload can create session
			# but must handle all aspects
			unless ($Vend::Session) {
				$CGI::values{mv_tmp_session} = 1;
				init_session();
			}

			$CGI::remote_addr ||= 'none';
			$CGI::useragent   ||= 'commandline';

			for(@itl) {
				# Run once at beginning of each job
				run_macro($jobscfg->{autoload});

				push @out, interpolate_html($_->[1]);

				# Run once at end of each job
				run_macro($jobscfg->{autoend});
			}
		};

		if ($@) {
			# job terminated due to an error
			$errors = 1;

			$failure = errmsg('Job terminated with an error: %s', $@);
			logError ("Job group=%s pid=$$ terminated with an error: %s", $job || 'INTERNAL', $@);
			
			# remove flag for this job
			Vend::Server::flag_job($$, $cat, 'furl');
		}
		
		if ($trackid) {
			$trackdb->set_field($trackid, 'end_run',
								Vend::Interpolate::mvtime(undef, {}, '%Y-%m-%d %H:%M'));
		}
	}
	else {
		logError("Empty job=%s", $job);
	}
	my $out = join "", @out;
	my $filter = $jobscfg->{filter} || 'strip';
	$out = Vend::Interpolate::filter_value($filter, $out);
	if ($errors && is_no($jobscfg->{ignore_errors})) {
		$out = join("\n\n", $failure, $out);
	}
	$out .= full_dump() if is_yes($jobscfg->{add_session});

	logError("Finished jobs group=%s pid=$$", $job || 'INTERNAL');
	
	close_cat();

	# don't send email and/or write log entry if job returns
	# no output (in spirit of the cron daemon)
	return unless $out;
	
	if(my $addr = $parms->{email} || $jobscfg->{email}) {
		my $subject = $jobscfg->{subject} || 'Interchange results for job: %s';
		$subject = errmsg($subject, $job);
		my $from = $jobscfg->{from} || $Vend::Cfg->{MailOrderTo};
		Vend::Interpolate::tag_mail($addr,
									{
										from => $from,
										to => $addr,
										subject => $subject,
										reply_to => $jobscfg->{reply_to},
										mailer => "Interchange $::VERSION",
										extra => $jobscfg->{extra_headers},
									    log_error => 1,
									},
									$out,
								);
	}

	if($jobscfg->{log}) {
		logData($jobscfg->{log}, $out);
	}

	return $out;
}

sub adjust_cgi {

    my($host);

    die "REQUEST_METHOD is not defined" unless defined $CGI::request_method
		or @Global::argv;

	if ($Global::HostnameLookups && !$CGI::remote_host && $CGI::remote_addr && !$CGI::values{mv_tmp_session}) {
		$CGI::remote_host = gethostbyaddr(Socket::inet_aton($CGI::remote_addr),Socket::AF_INET);
	}

	# The great and really final AOL fix
	#
    $host      = $CGI::remote_host;
    $CGI::ip   = $CGI::remote_addr;

	if($Global::DomainTail and $host) {
		$host =~ /\.([A-Za-z]+)$/;
		my $tld = $1;

		my $level = (defined($Global::CountrySubdomains->{$tld}) && $host =~ $Global::CountrySubdomains->{$tld}) ? 2 : 1;

		$host =~ s/.*?((?:[-A-Za-z0-9]+\.){$level}[A-Za-z]+)$/$1/;
	}
	elsif($Global::IpHead) {
		$host = $Global::IpQuad == 0 ? 'nobody' : '';
		my @ip;
		@ip = split /\./, $CGI::ip;
		$CGI::ip = '';
		$CGI::ip = join ".", @ip[0 .. ($Global::IpQuad - 1)] if $Global::IpQuad;
	}
	#
	# end AOL fix

	# Fix Cobalt/CGIwrap problem
    if($Global::Variable->{CGIWRAP_WORKAROUND}) {
        $CGI::path_info =~ s!^$CGI::script_name!!;
    }

    $CGI::host = $host || $CGI::ip;

    $CGI::user = $CGI::remote_user if $CGI::remote_user;
	undef $CGI::authorization if $CGI::remote_user;

	unless ($Global::FullUrl) {
		$CGI::script_name = $CGI::script_path;
	}
	else {
		if($CGI::server_port eq '80') { $CGI::server_port = ''; }
		else 		{ $CGI::server_port = ":$CGI::server_port"; }
		$CGI::script_name = $CGI::server_name .
							$CGI::server_port .
							$CGI::script_path;
	}
}

use vars qw/@NoHistory/;

@NoHistory= qw/
					mv_credit_card_number
					mv_credit_card_cvv2
					mv_password
					mv_verify
				/;

sub url_history {
	$Vend::Session->{History} = []
		unless defined $Vend::Session->{History};
	shift @{$Vend::Session->{History}}
		if $#{$Vend::Session->{History}} >= $Vend::Cfg->{History};
	if( $CGI::values{mv_no_cache} ) {
		push (@{$Vend::Session->{History}},  [ 'expired', {} ]);
	}
	else {
		my @save;
		for(@NoHistory) {
			push @save, delete $CGI::values{$_};
		}

		push (@{$Vend::Session->{History}},  [ $CGI::path_info, { %CGI::values } ]);

		for(my $i = 0; $i < @NoHistory; $i++) {
			next unless defined $save[$i];
			$CGI::values{$NoHistory[$i]} = $save[$i];
		}
	}
	return;
}

## DISPATCH

# Parse the invoking URL and dispatch to the handling subroutine.

my %action = (
    process	=> \&do_process,
	ui		=> sub { 
					&UI::Primitive::ui_acl_global();
					&do_process(@_);
				   },
    scan	=> \&do_scan,
    search	=> \&do_search,
    order	=> \&do_order,
    obtain	=> \&do_order,
    silent	=> sub {
						$Vend::StatusLine = "Status: 204 No content";
						my $extra_click = $Vend::FinalPath;
						$extra_click =~ s:/:\0:g;
						$CGI::values{mv_click} =  $CGI::values{mv_click}
											? "$CGI::values{mv_click}\0$extra_click"
											:  $extra_click;
						do_process(@_);
						response('');
						return 0;
					},
);

sub update_global_actions {
	@action{keys %{$Global::ActionMap}} = (values %{$Global::ActionMap})
		if $Global::ActionMap;
	@form_action{keys %{$Global::FormAction}} = (values %{$Global::FormAction})
		if $Global::FormAction;
}

sub open_cat {
	my $cat = shift;

	if($cat) {
		%CGI::values = ();
		if($Global::Catalog{$cat}) {
			$CGI::script_path = $Global::Catalog{$cat}->{script};
			$CGI::script_name = $CGI::script_path;
		}
	}

	unless (defined $Global::Selector{$CGI::script_name}) {
		my $msg = get_locale_message(
						404,
						"Undefined catalog: %s",
						$CGI::script_name || $cat,
						);
		$Vend::StatusLine = <<EOF;
Status: 404 Not Found
Content-Type: text/plain
EOF
		if($H) {
			response($msg);
		}
		logGlobal($msg);
		# No close_cat() necessary
		return;
	}

	if($Global::Foreground) {
		my %hash;
		tie %hash, 'Tie::ShadowHash', $Global::Selector{$CGI::script_name} ;
		$Vend::Cfg = \%hash;
	}
	else {
		$Vend::Cfg = $Global::Selector{$CGI::script_name};
	}

	$Vend::Cat = $Vend::Cfg->{CatalogName};
	$Vend::ReadOnlyCfg = $Global::ReadOnlyCfg{$Vend::Cat};

	my $catref = $Global::Catalog{$Vend::Cat};
	if(! $Global::Foreground and defined $catref->{directive}) {
		no strict 'refs';
		my ($key, $val);
		while ( ($key, $val) = each %{$catref->{directive}}) {
#::logDebug("directive key=$key val=" . ::uneval($val));
			${"Global::$key"} = $val;
		}
	}

	# See if it is a subcatalog
	if (defined $Vend::Cfg->{BaseCatalog}) {
		my $name = $Vend::Cfg->{BaseCatalog};
		my $ref = $Global::Catalog{$name};
		my $c = $Vend::Cfg;
		$Vend::Cfg = $Global::Selector{$ref->{'script'}};
		for(keys %{$c->{Replace}}) {
			undef $Vend::Cfg->{$_};
		}
		copyref $c, $Vend::Cfg;
		if($Vend::Cfg->{Variable}{MV_LANG}) {
			my $loc = $Vend::Cfg->{Variable}{MV_LANG};
			$Vend::Cfg->{Locale} = $Vend::Cfg->{Locale_repository}{$loc}
					if defined $Vend::Cfg->{Locale_repository}{$loc};
		}
	}

	if ($Global::Foreground) {
		my %hash;
		tie %hash, 'Tie::ShadowHash', $Vend::Cfg->{Variable};
		$::Variable = \%hash;
		$::Pragma = { %{ $Vend::Cfg->{Pragma} } };
	}
	else {
		$::Variable = $Vend::Cfg->{Variable};
		$::Pragma = $Vend::Cfg->{Pragma};
	}

	my $mt;
	if($Vend::Cfg->{DeliverImage}
		and $CGI::request_method eq 'GET'
		and $CGI::path_info =~ /\.(\w+)$/
		and $mt = Vend::Util::mime_type($CGI::path_info)
		and $mt =~ m{^image/}
	  )
	{

		my $imgdir = $Vend::Cfg->{ImageDir};
		my $fn = $CGI::path_info;
#::logDebug("deliver image: method=$CGI::request_method type=$mt fn=$fn");
		$fn =~ s:^/+::;
		## Won't resend any images beginning with admin/
		$fn =~ s{^admin/}{};
		if($CGI::secure) {
			 $imgdir = $Vend::Cfg->{ImageDirSecure}
				if $Vend::Cfg->{ImageDirSecure};
		}
		$Vend::tmp_session = 1;
		Vend::Tags->deliver($mt, { location => "$imgdir$fn" } );
		return;
	}

	if (defined $Global::SelectorAlias{$CGI::script_name}) {
		my $real = $Global::SelectorAlias{$CGI::script_name};
		unless (	$CGI::secure                                        or
					$Vend::Cfg->{SecureURL} =~ m{$CGI::script_name$}     and
					$Vend::Cfg->{VendURL}   !~ m{/nph-[^/]+$} 		     and
					$Vend::Cfg->{VendURL}   !~ m{$CGI::script_name$} 		)
		{
			$Vend::Cfg->{VendURL}   =~ s!$real!$CGI::script_name!;
			$Vend::Cfg->{SecureURL} =~ s!$real!$CGI::script_name!;
		}
	}

	if($Global::HitCount and ! $cat) {
		my $ctr = new Vend::CounterFile
					"$Global::ConfDir/hits.$Vend::Cat";
        $ctr->inc();
	}

	if ($Vend::Cfg->{SetGroup}) {
		eval {
			$) = "$Vend::Cfg->{SetGroup} $Vend::Cfg->{SetGroup}";
		};
		if ($@) {
			my $msg = $@;
			logGlobal( "Can't set group to GID %s: %s",
						$Vend::Cfg->{SetGroup}, $msg
					);
			logError("Can't set group to GID %s: %s",
						$Vend::Cfg->{SetGroup}, $msg
					);
		}
	}

	if($Vend::Cfg->{XHTML}) {
		$Vend::Xtrailer = ' /';
		$Vend::Xquote = '"';
	}
	else {
		$Vend::Xtrailer = '';
		$Vend::Xquote = '';
	}

	$::Limit = $Vend::Cfg->{Limit} || {};

	chdir $Vend::Cfg->{VendRoot} 
		or die "Couldn't change to $Vend::Cfg->{VendRoot}: $!\n";
	POSIX::setlocale(POSIX::LC_ALL, $Vend::Cfg->{ExecutionLocale});
	set_file_permissions();
	umask $Vend::Cfg->{Umask};

#show_times("end cgi and config mapping") if $Global::ShowTimes;
	open_database();

	if (my $subname = $Vend::Cfg->{SpecialSub}{request_init}) {
#::logDebug(errmsg("running subroutine '%s' for %s", $subname, 'request_init'));
		my $sub = $Vend::Cfg->{Sub}{$subname} || $Global::GlobalSub->{$subname};
		my $status;
		eval {
			$status = $sub->();
		};

		if($@) {
			::logError("Error running %s subroutine %s: %s", 'request_init', $subname, $@);
		}
	}

#show_times("end open_database") if $Global::ShowTimes;
	return 1;
}

sub close_cat {
	put_session() if $Vend::HaveSession;
	close_session() if $Vend::SessionOpen;
	close_database();
}

sub run_macro {
	my $macro = shift
		or return;
	my $content_ref = shift;

	my @mac;
	if(ref $macro eq 'ARRAY') {
		@mac = @$macro;
	}
	elsif ($macro =~ /^[-\s\w,]+$/) {
		@mac = grep /\S/, split /[\s,]+/, $macro;
	}
	else {
		push @mac, $macro;
	}

	for my $m (@mac) {
		if ($m =~ /^\w+$/) {
			my $sub = $Vend::Cfg->{Sub}{$m} || $Global::GlobalSub->{$m}
				or do {
					my $call = join(',', caller());

					my $msg = errmsg("Unknown macro '%s' from %s.", $m, $call);
					if($Vend::Cfg->{CatalogName}) {
						logError($msg);
					}
					else {
						logGlobal($msg);
					}
					next;
				};
			$sub->($content_ref);
		}
		elsif($m =~ /^\w+-\w+$/) {
			Vend::Interpolate::tag_profile($m);
		}
		else {
			interpolate_html($m);
		}
	}
}

sub dispatch {
	my($http) = @_;
	$H = $http;

	adjust_cgi();

	## If returns false then was a 404 no catalog or a delivered image
	open_cat() or return 1;

	Vend::Server::set_process_name("$Vend::Cat $CGI::host");

	run_macro($Vend::Cfg->{Preload});

	$CGI::user = Vend::Util::check_authorization($CGI::authorization)
		if defined $CGI::authorization;

	my($sessionid, $seed);

	$sessionid = $CGI::values{mv_session_id} || undef
		and $sessionid =~ s/\0.*//s;

	$::Instance->{CookieName} = $Vend::Cfg->{CookieName};

	if($CGI::values{mv_tmp_session}) {
#::logDebug("setting tmp_session");
		$Vend::tmp_session = $Vend::new_session = 1;
		$sessionid = 'nsession';
		$Vend::Cookie = 1;
		$Vend::Cfg->{ScratchDefault}{mv_no_count} = 1;
		$Vend::Cfg->{ScratchDefault}{mv_no_session_id} = 1;
	}
	elsif ($sessionid and $CGI::values{mv_force_session}) {
		# do nothing
	}
	elsif ($::Instance->{CookieName} and defined $CGI::cookie) {
		$CGI::cookie =~ m{$::Instance->{CookieName}=($Vend::Cfg->{CookiePattern})};
		$seed = $sessionid = $1;
		$::Instance->{ExternalCookie} = $sessionid || 1;
		$Vend::CookieID = $Vend::Cookie = 1;
	}
	elsif (defined $CGI::cookie and
		 $CGI::cookie =~ /\bMV_SESSION_ID=(\w{8,32})
								[:_] (
									(	\d{1,3}\.   # An IP ADDRESS
										\d{1,3}\.
										\d{1,3}\.
										\d{1,3})
									# A user name or domain
									|	([A-Za-z0-9][-\@A-Za-z.0-9]+) )?
									\b/x)
	{
		$sessionid = $1
			unless defined $CGI::values{mv_pc} and $CGI::values{mv_pc} eq 'RESET';
		$CGI::cookiehost = $3;
		$CGI::cookieuser = $4;
		$Vend::CookieID = $Vend::Cookie = 1;
    }

	Vend::Server::set_process_name("$Vend::Cat $CGI::host $sessionid");

	$::Instance->{CookieName} = 'MV_SESSION_ID' if ! $::Instance->{CookieName};

	$CGI::host = 'nobody' if $Vend::Cfg->{WideOpen};

	if(! $sessionid) {
		if(my $id = $::Variable->{MV_SESSION_ID}) {
			$sessionid = $CGI::values{$id} if $CGI::values{$id};
		}

		if(! $sessionid and $CGI::redirect_status and $Vend::Cfg->{RedirectCache}) {
			$Vend::tmp_session = $Vend::new_session = 1;
			$sessionid = 'nsession';
			$Vend::Cookie = 1;
			$Vend::Cfg->{ScratchDefault}{mv_no_count} = 1;
			$Vend::Cfg->{ScratchDefault}{mv_no_session_id} = 1;
			$Vend::write_redirect = 1;
		}

		if (! $sessionid and $Vend::Cfg->{FallbackIP}) {
			$sessionid = generate_key($CGI::remote_addr . $CGI::useragent);
		}

	}
	elsif (! $::Instance->{ExternalCookie} and $sessionid !~ /^\w+$/) {
		my $msg = get_locale_message(
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
		close_cat();
		return;
	}

# DEBUG
#::logDebug ("session='$sessionid' cookie='$CGI::cookie' chost='$CGI::cookiehost'");
# END DEBUG

RESOLVEID: {
    if ($sessionid) {
		$Vend::SessionID = $sessionid;
    	$Vend::SessionName = session_name();
		if($Vend::tmp_session) {
			$Vend::Session = {};
			init_session;
			last RESOLVEID;
		}
		# get_session will return a value if a session is read,
		# if not it will return false and a new session has been created.
		# The IP address will be counted for robot_resolution
		if(! get_session($seed) and ! $::Instance->{ExternalCookie}) {
			retire_id($sessionid);
			last RESOLVEID;
		}
		my $now = time;
		if(! $Vend::CookieID) {
			if( is_retired($sessionid) ) {
				new_session();
				last RESOLVEID;
			}
			my $compare_host	= $CGI::secure
								? ($Vend::Session->{shost})
								: ($Vend::Session->{ohost});

			if($Vend::Cfg->{WideOpen}) {
				# do nothing, no host checking
			}
			elsif(! $compare_host) {
				if ($CGI::secure) {
				    $Vend::Session->{shost} = $CGI::remote_addr;
				}
				else {
				    new_session($seed);
				    init_session();
				}
			}
			elsif ($compare_host ne $CGI::remote_addr) {
				new_session($seed);
				init_session();
			}
		}
		if ($now - $Vend::Session->{'time'} > $Vend::Cfg->{SessionExpire}) {
			if($::Instance->{ExternalCookie}) {
				init_session();
			}
			else {
				retire_id($sessionid);
				new_session();
			}
			last RESOLVEID;
		}
		elsif($Vend::Cfg->{RobotLimit}) {
			if ($now - $Vend::Session->{'time'} > ($::Limit->{lockout_reset_seconds} || 30) ) {
				$Vend::Session->{accesses} = 0;
			}
			else {
				$Vend::Session->{accesses}++;
#::logDebug("accesses=$Vend::Session->{accesses} admin=$Vend::admin");
				if($Vend::Session->{accesses} > $Vend::Cfg->{RobotLimit}
					and ! $Vend::admin
					)
				{
					do_lockout();
				}
			}
		}
	} else {
	    if (Vend::Session::count_ip() && !do_lockout()) {
		my $msg;
		# Here they can get it back if they pass expiration time
		my $wait = $::Limit->{robot_expire} || 1;
		$wait *= 24;
		$msg = errmsg(<<EOF, $wait); 
Too many new ID assignments for this IP address. Please wait at least %d hours
before trying again. Only waiting that period will allow access. Terminating.
EOF
		$msg = get_locale_message(403, $msg);

		::logError('Too many IDs, %d hour wait enforced.', $wait);

		$Vend::StatusLine = <<EOF;
Status: 403 Forbidden
Content-Type: text/plain
EOF
		response($msg);
		close_cat();
		return;
	    }
	    new_session();
	}

}

#::logDebug("session name='$Vend::SessionName'\n");

	$Vend::Calc_initialized = 0;
	$CGI::values{mv_session_id} = $Vend::Session->{id} = $Vend::SessionID;

	if($Vend::admin and my $subname = $Vend::Cfg->{SpecialSub}{admin_init}) {
		my $sub = $Vend::Cfg->{Sub}{$subname} || $Global::GlobalSub->{$subname};
		eval {
			$sub->();
		};

		if($@) {
			::logError("Error running %s subroutine %s: %s", 'admin_init', $subname, $@);
		}
	}

	if(my $vspace = $CGI::values{mv_values_space}) {
		$::Values = $Vend::Session->{values_repository}{$vspace} ||= {};
		$Vend::ValuesSpace = $vspace;
	}

	$Vend::Session->{'arg'} = $Vend::Argument = ($CGI::values{mv_arg} || undef);

	my $new_source;
	if ($CGI::values{mv_pc} and $CGI::values{mv_pc} =~ /\D/) {
		$new_source = $Vend::Session->{source} = $CGI::values{mv_pc} eq 'RESET'
											   ? ''
											   : $CGI::values{mv_pc};
	}
	elsif($CGI::values{mv_source}) {
		$new_source = $Vend::Session->{source} = $CGI::values{mv_source};
	}
	if ($new_source and $CGI::request_method eq 'GET' and $Vend::Cfg->{BounceReferrals}) {
		my $path = $CGI::path_info;
		$path =~ s:^/::;
		my $form =
			join '',
			map { "$_=$CGI::values{$_}\n" }
			grep !/^mv_(?:pc|source)$/,
			sort keys %CGI::values;
		my $url = vendUrl($path eq '' ? $Vend::Cfg->{DirectoryIndex} : $path, undef, undef, { form => $form, match_security => 1 });
		$url = header_data_scrub($url);
		my $msg = get_locale_message(
			301,
			"Redirected to %s.",
			$url,
		);
		$Vend::StatusLine = <<EOF;
Status: 301 Moved
Location: $url
Content-Type: text/plain

Redirecting to $url
EOF
		response($msg);
#::logDebug("bouncing to $url");
		close_cat();
		return;
	}

	$Vend::Session->{'user'} = $CGI::user;

	Vend::Server::set_process_name("$Vend::Cat $CGI::host $sessionid " . $Vend::Session->{username} || '-');

	$CGI::pragma = 'no-cache'
		if delete $::Scratch->{mv_no_cache};
#show_times("end session get") if $Global::ShowTimes;

	$Vend::FinalPath = $Vend::Session->{last_url} = $CGI::path_info;

	if( defined $Vend::Session->{path_alias}{$Vend::FinalPath}	) {
		$CGI::path_info
					= $Vend::FinalPath
					= $Vend::Session->{path_alias}{$Vend::FinalPath};
		delete $Vend::Session->{path_alias}{$Vend::FinalPath}
			if delete $Vend::Session->{one_time_path_alias}{$Vend::FinalPath};
	}

	url_history($Vend::FinalPath) if $Vend::Cfg->{History};

	Vend::Server::set_process_name("$Vend::Cat $CGI::host $sessionid " . ($Vend::Session->{username} || '-') . " $Vend::FinalPath");

# TRACK
	$Vend::Track = Vend::Track->new
		if ($Vend::Cfg->{UserTrack} or $Vend::Cfg->{TrackFile})
			and not ($Vend::admin and ! $::Variable->{MV_TRACK_ADMIN});
# END TRACK

	if($Vend::Cfg->{DisplayErrors} and $Global::DisplayErrors) {
		$SIG{"__DIE__"} = sub {
							my $msg = shift;
							put_session() if $Vend::HaveSession;
							my $content = get_locale_message(500, <<EOF, $msg);
<html><head><title>Fatal Interchange Error</title></head><body>
<h1>FATAL error</h1>
<pre>%s</pre>
</body></html>
EOF
							response(\$content);
							exit 0;
		};
	}

	# Do it here so we can use autoloads and such
	Vend::Interpolate::reset_calc() if $Global::Foreground;
	Vend::Interpolate::init_calc();
	new Vend::Tags;
# LEGACY
	ROUTINES: {
		last ROUTINES unless index($Vend::FinalPath, "/$Vend::Cfg->{ProcessPage}/") == 0;
		while ($Vend::FinalPath =~ s{/$Vend::Cfg->{ProcessPage}/(locale|language|currency)/([^/]*)/}{/$Vend::Cfg->{ProcessPage}/}) {
			$::Scratch->{"mv_$1"} = $2;
		}
		$Vend::FinalPath =~ s{/$Vend::Cfg->{ProcessPage}/page/}{/};
	}

	if(my $locale = $::Scratch->{mv_language}) {
		$Global::Variable->{LANG}
			= $::Variable->{LANG} = $locale;
	}
# END LEGACY

	for my $routine (@{$Vend::Cfg->{DispatchRoutines}}) {
		$routine->();
	}

#show_times("end dispatch routines (Autoload, etc.)") if $Global::ShowTimes;

	for my $macro ( $Vend::Cfg->{Filter}, $Vend::Session->{Filter}) {
		next unless $macro;
		if (ref($macro) ne 'HASH') {
			logError("Bad CGI filter '%s'", $macro);
			next;
		}
		for(keys %$macro) {
			Vend::Interpolate::input_filter_do($_, { op => $macro->{$_} } );
		}
	}

	## Here we initialize new features
	if(my $ary = $Vend::Cfg->{Init}) {
		undef $Vend::Cfg->{Init};
		for(@$ary) {
			my ($source, $touch) = @$_;
			next if -f $touch;
			open INITOUT, "> $touch"
				or do {
					::logError(
						"Unable to open init file %s for feature init", $touch,
						);
					next;
				};
			my $out;
			eval {
				$out = Vend::Interpolate::interpolate_html(
									Vend::Util::readfile($source)
						  );
			};
			if($@) {
				$out .= $@;
			}
			print INITOUT errmsg(
							"Results of init at %s: ",
							POSIX::strftime("%Y-%m-%d %H:%M:%S", localtime()),
							);
			print INITOUT $out;
			close INITOUT;
		}
	}

	run_macro($Vend::Session->{Autoload});
#show_times("end session Autoload macro") if $Global::ShowTimes;

    # If the cgi-bin program was invoked with no extra path info,
    # just display the catalog page.
    if (! $Vend::FinalPath || $Vend::FinalPath =~ m:^/+$:) {
#::logDebug("request_uri=$CGI::request_uri script_path=$CGI::script_path");
        if($CGI::request_uri !~ /^$CGI::script_path/) {
            $Vend::FinalPath = $CGI::request_uri;
            # remove any trailing query string
            $Vend::FinalPath =~ s/\?.*//;
#::logDebug("FinalPath now $CGI::request_uri");
        }
        else {
            $Vend::FinalPath = find_special_page('catalog');
        }
    }

	if($CGI::put_ref and my $act = $Vend::Cfg->{Special}{put_handler} ) {
		$Vend::FinalPath =~ s:^/*:$act/:;
	}

	$Vend::FinalPath =~ s:^/+::;
	$Vend::FinalPath =~ s/(\.html?)$//
		and $Vend::Extension = $1;
	$Vend::Session->{extension} = $1 || '';

	my $record;
	my $adb;

	if(ref $Vend::Session->{alias_table}) {
		$record = $Vend::Session->{alias_table}{$Vend::FinalPath};
		$Vend::Cfg->{AliasTable} ||= 'alias';
	}

	if(
		$Vend::Cfg->{AliasTable}
			and
		$record 
			or 
		(
			$adb = database_exists_ref($Vend::Cfg->{AliasTable})
			  and 
			$record = $adb->row_hash($Vend::FinalPath)
		)
	 )
	{
		$Vend::FinalPath = $record->{real_page};

		# This prevents filesystem access when we never want it
		# If base page is not passed we allow normal resolution
		$record->{base_page}
			and $Vend::ForceFlypage = $record->{base_page};

		my $ref;

		## Here we populate CGI variables if desired
		## Explicitly passed variables override this
		if(
			$record->{base_control}
				and
			$ref = get_option_hash($record->{base_control})
		  )
		{
			for(keys %$ref) {
				next if defined $CGI::values{$_};
				$CGI::values{$_} = $ref->{$_};
			}
		}

	}

#::logDebug("path=$Vend::FinalPath mv_action=$CGI::values{mv_action}");

  DOACTION: {
	if (defined $CGI::values{mv_action}) {
		$CGI::values{mv_todo} = $CGI::values{mv_action}
			if ! defined $CGI::values{mv_todo}
			and ! defined $CGI::values{mv_doit};
		$Vend::Action = $CGI->{mv_ui} ? 'ui' : 'process';
		$CGI::values{mv_nextpage} = $Vend::FinalPath
			if ! defined $CGI::values{mv_nextpage};
	}
	else {
		($Vend::Action) = $Vend::FinalPath =~ m{\A([^/]*)};
	}

#::logGlobal("action=$Vend::Action path=$Vend::FinalPath");
	my ($sub, $status);
	if(defined $Vend::Cfg->{ActionMap}{$Vend::Action}) {
		$sub = $Vend::Cfg->{ActionMap}{$Vend::Action};
		$CGI::values{mv_nextpage} = $Vend::FinalPath
			if ! defined $CGI::values{mv_nextpage};
		new Vend::Parse;
	}
	else {
		$sub = $action{$Vend::Action};
	}

#show_times("end path/action resolve") if $Global::ShowTimes;

	eval {
		if(defined $sub) {
			$status = $sub->($Vend::FinalPath);
#show_times("end action") if $Global::ShowTimes;
		}
		else {
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
		$template = get_locale_message(500, $template, $err);
		$template .= "($err)";
		undef $Vend::write_redirect;
		response($template);
	}

	$CGI::values{mv_nextpage} = $Vend::FinalPath
		if ! defined $CGI::values{mv_nextpage};

	do_page() if $status;
#show_times("end page display") if $Global::ShowTimes;

	for my $routine (@{$Vend::Cfg->{CleanupRoutines}}) {
		$routine->();
	}
  }

# TRACK
	$Vend::Track->filetrack() if $Vend::Track;
# END TRACK

	close_cat();

	Vend::Server::set_process_name('done');

	undef $H;

#show_times("end dispatch cleanup") if $Global::ShowTimes;

	return 1;
}

1;
__END__

