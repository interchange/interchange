# Track.pm - Interchange User Tracking
#
# $Id: Track.pm,v 1.4 2001-02-22 18:57:53 heins Exp $
#
# Copyright 2000 by Stefan Hornburg <racke@linuxia.de>
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

# TODO
# configuration settings
# check if tracking information is available
# tag to add "view product" tracking information
# support for quantity changes

# DOCUMENTATION
# "DescriptionField" should be set
# flypage should be used

package Vend::Track;
require Exporter;

use vars qw($VERSION);
$VERSION = substr(q$Revision: 1.4 $, 10);

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
					   description => item_description($item)}]);
}

sub user {
	my ($self) = shift;
	push (@{$self->{actions}}, [@_]);
	return;
}

sub finish_order {
	my ($self) = @_;

	push (@{$self->{actions}}, ['ORDER', {}]);
}

sub view_page {
	my ($self, $page) = @_;

	push (@{$self->{actions}}, ['VIEWPAGE', {page => $page}]);
}

sub view_product {
	my ($self, $code) = @_;

	push (@{$self->{actions}}, ['VIEWPROD', {code => $code}]);
}

# HEADER

my %hdrsubs = ('ADDITEM' => sub {my $href = shift; join (',', $href->{'code'}, $href->{'description'});},
			   'ORDER' => sub {my $href = shift; $::Values->{mv_order_number}},
			   'VIEWPAGE' => sub {my $href = shift; $href->{'page'}},
			   'VIEWPROD' => sub {my $href = shift; join (',', $href->{'code'}, $href->{'description'});});

sub header {
	my ($self) = @_;
	my (@hdr, $href);

	push(@hdr, "SESSION=$Vend::SessionID");
	for my $aref (@{$self->{actions}}) {
		$href = $aref->[1];
		if (exists $hdrsubs{$aref->[0]}) {
			push(@hdr, $aref->[0] . '=' . &{$hdrsubs{$aref->[0]}} ($aref->[1]));
		} else {
			push(@hdr, "$aref->[0]=$aref->[1]");
		}
	}
	for(@hdr) {
		s/\n/<CR>/g;
		s/;/<SEMICOLON>/g;
	}
	join('&',@hdr);
}

sub std_log {
	my(@parm) = @_;
	my $now = time();
	my $date = POSIX::strftime('%Y%m%d', localtime($now));

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

