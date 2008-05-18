package Business::UPS;

use LWP::Simple;
use strict;
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK);
require 5.003;

require Exporter;

@ISA = qw(Exporter AutoLoader);
# Items to export into callers namespace by default. Note: do not export
# names by default without a very good reason. Use EXPORT_OK instead.
# Do not simply export all your public functions/methods/constants.
@EXPORT = qw(
	     getUPS
	     UPStrack
);


# Preloaded methods go here.

#	Copyright 1998 Mark Solomon <msolomon@seva.net> (See GNU GPL)
#	Started 01/07/1998 Mark Solomon 
#

$VERSION = do { my @r = (q$Revision: 2.0 $ =~ /\d+/g); sprintf "%d."."%02d" x $#r, @r }; # must be all one line, for MakeMaker

sub getUPS {

    my ($product, $origin, $dest, $weight, $country , $length,
	$width, $height, $oversized, $cod) = @_;
    
    my $ups_cgi = 'http://www.ups.com/using/services/rave/qcostcgi.cgi';
    my $workString = "?";
    $workString .= "accept_UPS_license_agreement=yes&";
    $workString .= "10_action=3&";
    $workString .= "13_product=" . $product . "&";
    $workString .= "15_origPostal=" . $origin . "&";
    $workString .= "19_destPostal=" . $dest . "&";
    $workString .= "23_weight=" . $weight;
    $workString .= "&22_destCountry=" . $country if $country;
    $workString .= "&25_length=" . $length if $length;
    $workString .= "&26_width=" . $width if $width;
    $workString .= "&27_height=" . $height if $height;
    $workString .= "&30_cod=" . $cod if $cod;
    $workString .= "&29_oversized=1" if $oversized;
    $workString .= "&30_cod=1" if $cod;
    $workString = "${ups_cgi}${workString}";
    
    my @ret = split( '%', get($workString) );
    
    if (! $ret[5]) {
	# Error
	return (undef,undef,$ret[1]);
    }
    else {
	# Good results
	my $total_shipping = $ret[10];
	my $ups_zone = $ret[6];
	return ($total_shipping,$ups_zone,undef);
    }
}


#
#	UPStrack sub added 2/27/1998
#


sub UPStrack {
    my ($tracking_number) = shift;
    my %retValue = {};		# Will hold return values
    $tracking_number || Error("No number to track in UPStrack()");

    my $raw_data = get("http://wwwapps.ups.com/tracking/tracking.cgi?tracknum=$tracking_number") || Error("Cannot get data from UPS");
    $raw_data =~ tr/\r//d;

    my @raw_data = split "\n", $raw_data;

    # These are the splitting keys
    my $scan_sep = 'Scanning Information';
    my $notice_sep = 'Notice';
    my $error_key = 'Unable to track';
    my $section;
    my @scanning;
    for (@raw_data) {
	s/<.*?>/ /gi;	# Remove html tags
	s/(?:&nbsp;|[\n\t])//gi;	# Remove '&nbsp' separators
	s/^\s+//g;

	next if /^$/;
	last if /^Top\sof\sPage/;

	if (/^Tracking\sResult/) {
	    $section = 'RESULT';
	}
	elsif (/^$scan_sep/) {
	    $section = 'SCANNING';
	}
	elsif (/^$notice_sep/) {
	    $section = 'NOTICE';
	}
	elsif (/^($error_key\s.*?)\s{4}/) {
	    my $error = $1;
	    $error =~ s/\s+$/ /g;
	    $retValue{error} = $error;
	    return %retValue;
	}
	elsif ($section eq 'NOTICE') {
	    $retValue{Notice} .= $_;
	}
	elsif ($section eq 'RESULT') {
	    my ($key,$value) = /(.*?):(.*)/;
	    $value =~ s/^\s+//g;
	    $value =~ s/\s+$//g;
	    $retValue{$key} = $value;
	}
	elsif ($section eq 'SCANNING') {
	    if (/^\d/) {
		push @scanning, $_;
	    }
	    else {
		$scanning[-1] .= " = $_";
	    }
	}
    }

    $retValue{Scanning} = join "\n", @scanning;

    return %retValue;
}

sub Error {
    my $error = shift;
    print STDERR "$error\n";
    exit(1);
}


END {}



# Autoload methods go after =cut, and are processed by the autosplit program.

1;
# Below is the stub of documentation for your module. You better edit it!

__END__

=head1 NAME

Business::UPS - A UPS Interface Module

=head1 SYNOPSIS

  use Business::UPS;

  my ($shipping,$ups_zone,$error) = getUPS(qw/GNDCOM 23606 23607 50/);
  $error and die "ERROR: $error\n";
  print "Shipping is \$$shipping\n";
  print "UPS Zone is $ups_zone\n";

  %track = UPStrack("z10192ixj29j39");
  $track{error} and die "ERROR: $track{error};

  # 'Delivered' or 'In-transit'
  print "This package is $track{Current Status}\n"; 

=head1 DESCRIPTION

A way of sending four arguments to a module to get shipping charges 
that can be used in, say, a CGI.

=head1 REQUIREMENTS

I've tried to keep this package to a minimum, so you'll need:

=over 4

=item *

Perl 5.003 or higher

=item *

LWP Module

=back 4


=head1 ARGUMENTS for getUPS()

Call the subroutine with the following values:

  1. Product code (see product-codes.txt)
  2. Origin Zip Code
  3. Destination Zip Code
  4. Weight of Package

and optionally:

  5.  Country Code, (see country-codes.txt)
  6.  Length,
  7.  Width,
  8.  Height,
  9.  Oversized (defined if oversized), and
  10. COD (defined if C.O.D.)

=over 4

=item 1

Product Codes:

  1DM		Next Day Air Early AM
  1DML		Next Day Air Early AM Letter
  1DA		Next Day Air
  1DAL		Next Day Air Letter
  1DP		Next Day Air Saver
  1DPL		Next Day Air Saver Letter
  2DM		2nd Day Air A.M.
  2DA		2nd Day Air
  2DML		2nd Day Air A.M. Letter
  2DAL		2nd Day Air Letter
  3DS		3 Day Select
  GNDCOM	Ground Commercial
  GNDRES	Ground Residential
  XPR		Worldwide Express
  XDM		Worldwide Express Plus
  XPRL		Worldwide Express Letter
  XDML		Worldwide Express Plus Letter
  XPD		Worldwide Expedited


In an HTML "option" input it might look like this:

  <OPTION VALUE="1DM">Next Day Air Early AM
  <OPTION VALUE="1DML">Next Day Air Early AM Letter
  <OPTION SELECTED VALUE="1DA">Next Day Air
  <OPTION VALUE="1DAL">Next Day Air Letter
  <OPTION VALUE="1DP">Next Day Air Saver
  <OPTION VALUE="1DPL">Next Day Air Saver Letter
  <OPTION VALUE="2DM">2nd Day Air A.M.
  <OPTION VALUE="2DA">2nd Day Air
  <OPTION VALUE="2DML">2nd Day Air A.M. Letter
  <OPTION VALUE="2DAL">2nd Day Air Letter
  <OPTION VALUE="3DS">3 Day Select
  <OPTION VALUE="GNDCOM">Ground Commercial
  <OPTION VALUE="GNDRES">Ground Residential

=item 2

Origin Zip(tm) Code

Origin Zip Code as a number or string (NOT +4 Format)

=item 3

Destination Zip(tm) Code

Destination Zip Code as a number or string (NOT +4 Format)

=item 4

Weight

Weight of the package in pounds

=back

=head1 ARGUMENTS for UPStrack()

The tracking number.

  use Business::UPS;
  %t = UPStrack("1ZX29W290250xxxxxx");
  print "This package is $track{Current Status}\n";

=head1 RETURN VALUES

=over 4

=item getUPS()

	The raw http get() returns a list with the following values:

	  ##  Desc		Typical Value
	  --  ---------------   -------------
	  0.  Name of server: 	UPSOnLine3
	  1.  Product code:	GNDCOM
	  2.  Orig Postal:	23606
	  3.  Country:		US
	  4.  Dest Postal:	23607
	  5.  Country:		US
	  6.  Shipping Zone:	002
	  7.  Weight (lbs):	50
	  8.  Sub-total Cost:	7.75
	  9.  Addt'l Chrgs:	0.00
	  10. Total Cost:	7.75
	  11. ???:		-1

	If anyone wants these available for some reason, let me know.

=item UPStrack()
	
The hash that's returned is like the following:

  'Delivered on' 	=> '1-22-1998 at 2:58 PM'
  'Notice' 		=> 'UPS authorizes you to use UPS...'
  'Received by'		=> 'DR PORCH'
  'Addressed to'	=> 'NEWPORT NEWS, VA US'
  'scan'		=>  HASH(0x146e0c) (more later...)
  'Current Status'	=> 'Delivered'
  'Delivered to'	=> 'RESIDENTIAL'
  'Sent on'		=> '1-20-1998'
  'UPS Service'		=> '2ND DAY AIR'
  'Tracking Number' 	=> '1ZX29W29025xxxxxx'
  'Scanning'		=> (See next paragraph)

Notice the key 'Scanning' is a newline (\n) delineated list of
scanning locations.  Each line has two parts: 1. Time/Date of scan
and 2. Type of scan.  In its scalar context, it looks like this:

  1-22-19982:58 PM NEWPORT NEWS-OYSTER, VA US = DELIVERED
  1-21-199811:37 PM RICHMOND, VA US = LOCATION SCAN
  2:05 PM PHILA AIR HUB, PA US = LOCATION SCAN
  1-20-199811:35 PM PHILA AIR HUB, PA US = LOCATION SCAN

...but a line or two of code can make it very usable like this:

  foreach $line (split "\n", $track{Scanning}) {
    my ($location, $type) = split /=/, $line;
    print "At $location, the shipment was $type\n";
  }

=back

=head1 EXAMPLE

=over 4

=item getUPS()

To retreive the shipping of a 'Ground Commercial' Package 
weighing 25lbs. sent from 23001 to 24002 this package would 
be called like this:

  #!/usr/local/bin/perl
  use Business::UPS;

  my ($shipping,$ups_zone,$error) = getUPS(qw/GNDCOM 23001 23002 25/);
  $error and die "ERROR: $error\n";
  print "Shipping is \$$shipping\n";
  print "UPS Zone is $ups_zone\n";

=item UPStrack()

  #!/usr/local/bin/perl

  use Business:UPS;

  %t = UPStrack("z10192ixj29j39");
  $t{error} and die "ERROR: $t{error};
	
  print "This package is $t{'Current Status'}\n"; # 'Delivered' or 
						  # 'In-transit'
  print "More info:\n";
  foreach $key (keys %t) {
    print "KEY: $key = $t{$key}\n";
  }


=back

=head1 BUGS

Let me know.

=head1 AUTHOR

Mark Solomon <msolomon@seva.net>

mailto:msolomon@seva.net

http://www.seva.net/~msolomon/

NOTE: UPS is a registered trademark of United Parcel Service.

=head1 SEE ALSO

perl(1).

=cut
