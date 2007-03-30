# SOAP::Transport - Handle Interchange SOAP connections
#
# $Id: Transport.pm,v 2.3 2007-03-30 11:39:54 pajamian Exp $
#
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

# ======================================================================
#
# Copyright (C) 2000-2001 Paul Kulchenko (paulclinger@yahoo.com)
# SOAP::Lite is free software; you can redistribute it
# and/or modify it under the same terms as Perl itself.
#
# ======================================================================

package Vend::SOAP::Transport;

use strict;
use vars qw($VERSION);
$VERSION = substr(q$Revision: 2.3 $, 10);

# ======================================================================

package Vend::SOAP::Transport::Server;

use strict;
use Carp ();
use SOAP::Lite;
use vars qw(@ISA);
@ISA = qw(SOAP::Server);

sub new {
  my $self = shift;
#::logDebug(__PACKAGE__ . " new called, args=" . ::uneval(\@_));
    
	unless (ref $self) {
		my $class = ref($self) || $self;
		$self = $class->SUPER::new(@_);
#::logDebug(__PACKAGE__ . " new done, self=" . ::uneval($self));
	}

	return $self;
}

sub BEGIN {
  no strict 'refs';
  my @modes = qw(in error session no_database);
  for my $method (@modes) {
    my $field = '_' . $method;
    *$method = sub {
	  my $self = shift;
      return $self->{$field} unless @_;
      my $val = shift;
      $self->{$field} = $val;
      return $self;
    }
  }
}

if(defined \&::errmsg) {
	*errmsg = \&::errmsg;
}
else {
	*errmsg = sub { return sprintf(@_) };
}

sub handle {
  my $self = shift->new;

  undef $Tmp::Autoloaded;
#::logDebug("handler called, begin transaction\n");

  if($self->error) {
  	die ::errmsg($self->error);
  }
  my $in = $self->in
  	or die ::errmsg("Nothing in");

#::logDebug(__PACKAGE__ . " meat is: $in");

  my $result = $self->SUPER::handle($in);
#::logDebug(__PACKAGE__ . " result is: $result");
#::logDebug("handler ends\n");
  return $result;
}

sub DESTROY {
	my $self = shift;
	return unless $self->{_IC_initialized};
	::put_session();
	::close_database() unless $self->no_database;
}

# ======================================================================

1;

__END__

=head1 NAME

SOAP::Transport::IO - Server side IO support for SOAP::Lite

=head1 SYNOPSIS

  use SOAP::Transport::IO;

  SOAP::Transport::IO::Server

    # you may specify as parameters for new():
    # -> new( in => 'in_file_name' [, out => 'out_file_name'] )
    # -> new( in => IN_HANDLE      [, out => OUT_HANDLE] )
    # -> new( in => *IN_HANDLE     [, out => *OUT_HANDLE] )
    # -> new( in => \*IN_HANDLE    [, out => \*OUT_HANDLE] )
  
    # -- OR --
    # any combinations
    # -> new( in => *STDIN, out => 'out_file_name' )
    # -> new( in => 'in_file_name', => \*OUT_HANDLE )
  
    # -- OR --
    # use in() and/or out() methods
    # -> in( *STDIN ) -> out( *STDOUT )
  
    # -- OR --
    # use default (when nothing specified):
    #      in => *STDIN, out => *STDOUT
  
    # don't forget, if you want to accept parameters from command line
    # \*HANDLER will be understood literally, so this syntax won't work 
    # and server will complain
  
    -> new(@ARGV)
  
    # specify path to My/Examples.pm here
    -> dispatch_to('/Your/Path/To/Deployed/Modules', 'Module::Name', 'Module::method') 
    -> handle
  ;

=head1 DESCRIPTION

=head1 COPYRIGHT

Copyright (C) 2000-2001 Paul Kulchenko. All rights reserved.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHOR

Paul Kulchenko (paulclinger@yahoo.com)

=cut
