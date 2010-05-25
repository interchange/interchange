# Vend::Track - Interchange User Tracking
#
# $Id: Track.pm,v 2.4 2007-03-30 11:39:46 pajamian Exp $
#
# Copyright (C) 2000-2007 by Stefan Hornburg <racke@linuxia.de>
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

# TODO
# configuration settings
# check if tracking information is available
# tag to add "view product" tracking information
# support for quantity changes
# consider other carts

# DOCUMENTATION
# "CategoryField" should be set
# "DescriptionField" should be set
# flypage should be used

package Vend::Track;
require Exporter;

use vars qw($VERSION);
$VERSION = substr(q$Revision: 2.4 $, 10);

@ISA = qw(Exporter);

use strict;
use Vend::Data;

sub new {
	my $proto = shift;
	my $class = ref ($proto) || $proto;
	my $self = {actions => []};

	bless ($self, $class);
}

# ACTIONS

sub add_item {
	my ($self,$cart,$item) = @_;

	push (@{$self->{actions}},
		  ['ADDITEM', {code => $item->{'code'},
					   description => item_description($item),
					   category => item_category($item)
					  }]);
}

sub user {
	my ($self) = shift;
	push (@{$self->{actions}}, [@_]);
	return;
}

sub finish_order {
	my ($self) = @_;
	my (@items, $item, $itemout);
	
	foreach my $item (@{$::Carts->{'main'}}) {
		$itemout = {code => $item->{'code'},
					description => item_description($item),
					category => item_category($item),
					quantity => $item->{'quantity'},
					price => item_price($item)
					};
		push (@items, $itemout);
	}
		
	push (@{$self->{actions}}, ['ORDER', {}],
		  ['ORDERINFO', {total => Vend::Interpolate::total_cost (),
					 payment => '',
					 shipmode => Vend::Interpolate::tag_shipping_desc (),
					 items => \@items
					}]);
}

sub view_page {
	my ($self, $page) = @_;
	my @params;

	if (exists $Vend::Cfg->{TrackPageParam}->{$page}) {
		for (split /,/, $Vend::Cfg->{TrackPageParam}->{$page}) {
			next if $_ eq 'mv_credit_card_number' || $_ eq 'mv_credit_card_cvv2';
			if ($CGI::values{$_} =~ /\S/) {
				push(@params, "$_=$CGI::values{$_}");
			}
		}
	}
	push (@{$self->{actions}}, ['VIEWPAGE', {page => $page, params => \@params}]);
}

sub view_product {
	my ($self, $code) = @_;

	push (@{$self->{actions}},
		  ['VIEWPROD', {code => $code,
						description => product_description($code),
						category => product_category($code)
					   }]);
}

# HEADER

my %hdrsubs = ('ADDITEM' => sub {my $href = shift; join (',', $href->{'code'}, $href->{'description'});},
			   'ORDER' => sub {my $href = shift; $::Values->{mv_order_number}},
			   'ORDERINFO' => sub {my $href = shift;
							   join ('/',
									 join ("\t", $href->{'total'}, $href->{'payment'}, $href->{'shipmode'}),
									 map {join ("\t", $_->{'code'},
											   $_->{'description'},
											   $_->{'category'},
											   $_->{'quantity'},
											   $_->{'price'})}
									 @{$href->{'items'}});},
			   'VIEWPAGE' => sub {my $href = shift; join ("\t", $href->{'page'}, @{$href->{'params'}})},
			   'VIEWPROD' => sub {my $href = shift; join ("\t", $href->{'code'}, $href->{'description'}, $href->{'category'});});

sub header {
	my ($self) = @_;
	my @hdr = ("SESSION=$Vend::SessionID");
	for my $aref (@{$self->{actions}}) {
		my ($k, $v) = @$aref;
		if (exists $hdrsubs{$k}) {
			$v = $hdrsubs{$k}->($v);
		}
		push @hdr, "$k=$v";
	}
	for(@hdr) {
		s/\n/<LF>/g;
		s/\r/<CR>/g;
	}
	my $value = join '&', @hdr;

	# arbitrarily limit header value sizes to keep entire header under about 1 kB
	# to avoid internal server error by Apache, found by Brian Miller <brian@endpoint.com>
	# and reported at http://www.icdevgroup.org/pipermail/interchange-users/2010-May/051990.html
	my $max_length = 900;
	if (length($value) > $max_length) {
		$value = substr($value, 0, $max_length);
		::logDebug("truncating header longer than $max_length characters in Vend::Track");
	}

	return $value;
}

sub std_log {
	my(@parm) = @_;
	my $now = time();
	my ($fmt, $date);

	$fmt = $Vend::Cfg->{TrackDateFormat} || '%Y%m%d';
	$date = POSIX::strftime($fmt, localtime($now));

	::logData(
		$Vend::Cfg->{TrackFile},
				$date,
				$Vend::SessionName,
				$Vend::Session->{username},
				($CGI::remote_host || $CGI::remote_addr),
				$now,
				$Vend::Session->{source},
				join('&', @parm),
	);
	return;
}

sub filetrack {
	return unless $Vend::Cfg->{TrackFile};
	my ($self) = @_;
	my (@hdr, $href);

	for my $aref (@{$self->{actions}}) {
		$href = $aref->[1];
		if (exists $hdrsubs{$aref->[0]}) {
			push(@hdr, $aref->[0] . '=' . &{$hdrsubs{$aref->[0]}} ($aref->[1]));
		}
		else {
			push(@hdr, "$aref->[0]=$aref->[1]");
		}
	}
	return std_log(@hdr) unless $Vend::Cfg->{TrackSub};
	$Vend::Cfg->{TrackSub}->(@hdr);
}

