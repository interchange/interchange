package Vend::CharSet;

use strict;
use warnings;

use Encode qw( decode resolve_alias is_utf8 );

use constant DEFAULT_ENCODING => 'utf-8';

=pod

=head1 NAME

Vend::CharSet

=head1 SYNOPSIS

=head1 DESCRIPTION

This modules contains some utility methods for handling character
encoding in general and UTF-8 in particular.

=head1 METHODS

=over 

=item B<decode_urlendcode>( $octets, $encoding )

=cut

sub decode_urlencode {
	my ($class, $octets, $encoding) = (@_);
	$encoding ||= DEFAULT_ENCODING;
#	::logDebug("decode_urlencode--octets: $octets, encoding: $encoding");

	return undef unless $class->validate_encoding($encoding);

	$octets =~ tr/+/ /;
	$octets =~ s/%([0-9a-fA-F][0-9a-fA-F])/chr(hex $1)/ge;
	my $string = $class->to_internal($encoding, $octets);

#	::logDebug("decoded string: " . display_chars($string)) if $string;
	return $string;
}

sub to_internal {
	my ($class, $encoding, $octets) = @_;
#	::logDebug("to_internal - converting octets from $encoding to internal");
	if (is_utf8($octets)) {
#		::logDebug("to_internal - octets are already utf-8 flagged");
		return $octets;
	}

	my $string = eval {	decode($encoding, $octets, Encode::FB_CROAK) };
	if ($@) {
		::logError("Unable to properly decode <" 
				   . display_chars($octets) 
				   . "> with $encoding");
		return;
	}
	return $string;
}

sub validate_encoding {
	my ($class, $encoding) = (@_);
	return resolve_alias($encoding);
}

sub default_charset {
	my $g = $Global::Selector{$CGI::script_name};
	return $g->{Variable}->{MV_HTTP_CHARSET}	
	  || $Global::Variable->{MV_HTTP_CHARSET};
}

## stolen from the Encode man page, for diagnostic purposes
sub display_chars {
	return unless $_[0];
	join("",
		 map { $_ > 255 ?                  # if wide character...
				   sprintf("\\x{%04X}", $_) :  # \x{...}
				   chr($_) =~ /[[:cntrl:]]/ ?  # else if control character ...
				   sprintf("\\x%02X", $_) :    # \x..
				   quotemeta(chr($_))          # else quoted or as themselves
			   } unpack("U*", $_[0]));           # unpack Unicode characters
}



1;

