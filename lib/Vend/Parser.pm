# Vend::Parser - Interchange parser class
#
# $Id: Parser.pm,v 2.0.2.2 2002-11-26 03:21:10 jon Exp $
#
# Copyright (C) 1997-2002 Red Hat, Inc. and
# Interchange Development Group, http://www.icdevgroup.org/
#
# Based on HTML::Parser
# Copyright 1996 Gisle Aas. All rights reserved.

=head1 NAME

Vend::Parser - Interchange parser class

=head1 DESCRIPTION

C<Vend::Parser> will tokenize a Interchange page when the $p->parse()
method is called. The document to parse can be supplied in arbitrary
chunks. Call $p->eof() the end of the document to flush any remaining
text. The return value from parse() is a reference to the parser object.

=over 4

=item $self->start($tag, $attr, $attrseq, $origtext)

This method is called when a complete start tag has been recognized.
The first argument is the tag name (in lower case) and the second
argument is a reference to a hash that contain all attributes found
within the start tag. The attribute keys are converted to lower case.
Entities found in the attribute values are already expanded. The
third argument is a reference to an array with the lower case
attribute keys in the original order. The fourth argument is the
original Interchange page.

=item $self->end($tag)

This method is called when an end tag has been recognized. The
argument is the lower case tag name.

=item $self->text($text)

This method is called when plain text in the document is recognized.
The text is passed on unmodified and might contain multiple lines.
Note that for efficiency reasons entities in the text are B<not>
expanded. 

=back

=head1 COPYRIGHT

Copyright 1997-2002 Red Hat, Inc.  
Original HTML::Parser module copyright 1996 Gisle Aas.

This library is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

=head1 AUTHORS

Vend::Parser - Mike Heins <mike@perusion.com>
HTML::Parser - Gisle Aas <aas@sn.no>

=cut

package Vend::Parser;

use strict;

use HTML::Entities ();
use vars qw($VERSION);
$VERSION = substr(q$Revision: 2.0.2.2 $, 10);


sub new
{
	my $class = shift;
	my $self = bless { '_buf' => '' }, $class;
	$self;
}


sub eof
{
	shift->parse(undef);
}


use vars qw/$Find_tag/;

sub parse
{
	my $self = shift;
	my $buf = \ $self->{_buf};
	unless (defined $_[0]) {
		# signals EOF (assume rest is plain text)
		$self->text($$buf) if length $$buf;
		$$buf = '';
		return $self;
	}
	$$buf .= $_[0];
	$Find_tag	= $Vend::Cfg->{Pragma}{no_html_parse}
				?  qr{^([^[]+)}
				:  qr{^([^[<]+)}
				;
#::logDebug("no_html_parse=$Vend::Cfg->{Pragma}{no_html_parse} Find_tag=$Find_tag");

	my $eaten;
	# Parse html text in $$buf.  The strategy is to remove complete
	# tokens from the beginning of $$buf until we can't deside whether
	# it is a token or not, or the $$buf is empty.
	while (1) {  # the loop will end by returning when text is parsed
		# First we try to pull off any plain text (anything before a "<" char)
		if ($$buf =~ s/$Find_tag// ) {
#my $eat = $1;
#::logDebug("plain eat='$eat'");
#$self->text($eat);
			$self->text($1);
			return $self unless length $$buf;
		# Find the most common tags
		} elsif ($$buf =~ s|^(\[([-a-z0-9A-Z_]+)[^"'=\]>]*\])||) {
#my $tag=$2; my $eat = $1;
#undef $self->{HTML};
#::logDebug("tag='$tag' eat='$eat'");
#$self->start($tag, {}, [], $eat);
				undef $self->{HTML};
				$self->start($2, {}, [], $1);
		# Then, finally we look for a start tag
		} elsif ($$buf =~ s|^\[||) {
			# start tag
			$eaten = '[';
			$self->{HTML} = 0 if ! defined $self->{HTML};
#::logDebug("do [ tag");

			# This first thing we must find is a tag name.  RFC1866 says:
			#   A name consists of a letter followed by letters,
			#   digits, periods, or hyphens. The length of a name is
			#   limited to 72 characters by the `NAMELEN' parameter in
			#   the SGML declaration for HTML, 9.5, "SGML Declaration
			#   for HTML".  In a start-tag, the element name must
			#   immediately follow the tag open delimiter `<'.
			if ($$buf =~ s|^(([a-zA-Z][-a-zA-Z0-9._]*)\s*)||) {
				$eaten .= $1;

				my ($tag);
				my ($nopush, $element);
				my %attr;
				my @attrseq;
				my $old;

				$tag = lc $2;
#::logDebug("tag='$tag' eat='$eaten'");

				# Then we would like to find some attributes
				#
				# Arrgh!! Since stupid Netscape violates RCF1866 by
				# using "_" in attribute names (like "ADD_DATE") of
				# their bookmarks.html, we allow this too.
				while (	$$buf =~ s|^(([a-zA-Z][-a-zA-Z0-9._]*)\s*)|| or
					 	$$buf =~ s|^(([=!<>][=~]?)\s+)||                 )
				{
					$eaten .= $1;
					my $attr = lc $2;
					$attr =~ tr/-/_/;
#::logDebug("in parse, eaten=$eaten");
					$attr =~ s/\.(.*)//
						and $element = $1;
						
					my $val;
					
					# The attribute might take an optional value (first we
					# check for an unquoted value)
					if ($$buf =~ s~(^=\s*([^\|\"\'\`\]\s][^\]>\s]*)\s*)~~) {
						$eaten .= $1;
						next unless defined $attr;
						$val = $2;
					# or quoted by " or ' or # or $ or |
					} elsif ($$buf =~ s~(^=\s*(["\'])(.*?)\2\s*)~~s) {
						$eaten .= $1;
						next unless defined $attr;
						$val = $3;
						HTML::Entities::decode($val) if $attr{entities};
					# or quoted by `` to send to [calc]
					} elsif ($$buf =~ s~(^=\s*([\`\|])(.*?)\2\s*)~~s) {
						$eaten .= $1;
						if    ($2 eq '`') {
							$val = Vend::Interpolate::tag_calc($3)
								unless defined $Vend::Cfg->{AdminSub}{calc};
						}
						elsif ($2 eq '|') {
								$val = $3;
								$val =~ s/^\s+//;
								$val =~ s/\s+$//;
						}
						else {
							die "parse error!";
						}
					# truncated just after the '=' or inside the attribute
					} elsif ($$buf =~ m|^(=\s*)$|s or
							 $$buf =~ m|^(=\s*[\"\'].*)|s) {
						$$buf = "$eaten$1";
						return $self;
					} elsif (!$old) {
						# assume attribute with implicit value, but
						# if not,no value is set and the
						# eaten value is grown
						undef $nopush;
						($attr,$val,$nopush) = $self->implicit($tag,$attr);
						$old = 1 unless $val;

					}
					next if $old;
					if(! $attr) {
						$attr->{OLD} = $val if defined $attr;
						next;
					}
					if(defined $element) {
#::logDebug("Found element: $element val=$val");
						if(! ref $attr{$attr}) {
							if ($element =~ /[A-Za-z]/) {
								$attr{$attr} = { $element => $val };
							}
							else {
								$attr{$attr} = [ ];
								$attr{$attr}->[$element] = $val;
							}
							push (@attrseq, $attr);
						}
						elsif($attr{$attr} =~ /ARRAY/) {
							if($element =~ /\D/) {
								push @{$attr{$attr}}, $val;
							}
							else {
								$attr{$attr}->[$element] = $val;
							}
						}
						elsif ($attr{$attr} =~ /HASH/) {
							$attr{$attr}->{$element} = $val;
						}
						undef $element;
						next;
					}
					$attr{$attr} = $val;
					push(@attrseq, $attr) unless $nopush;
				}

				# At the end there should be a closing "\] or >"
				if ($$buf =~ s|^\]|| ) {
					$self->start($tag, \%attr, \@attrseq, "$eaten]");
				} elsif ($$buf =~ s|^([^\]\n]+\])||) {
					$eaten .= $1;
					$self->start($tag, {}, [], $eaten);
				} elsif (length $$buf) {
#::logDebug("eaten $eaten");
					# Not a conforming start tag, regard it as normal text
					$self->text($eaten);
				} else {
					$$buf = $eaten;  # need more data to know
					return $self;
				}

			} elsif (length $$buf) {
#::logDebug("eaten $eaten");
				$self->text($eaten);
			} else {
				$$buf = $eaten;  # need more data to parse
				return $self;
			}
		} elsif ($$buf =~ s|^<||) {
			# start tag
			$eaten = '<';
#::logDebug("do < tag") if ! $Tmp::DoneDebug++;

			# This first thing we must find is a tag name.  RFC1866 says:
			#   A name consists of a letter followed by letters,
			#   digits, periods, or hyphens. The length of a name is
			#   limited to 72 characters by the `NAMELEN' parameter in
			#   the SGML declaration for HTML, 9.5, "SGML Declaration
			#   for HTML".  In a start-tag, the element name must
			#   immediately follow the tag open delimiter `<'.
			if ($$buf =~ s|^(([a-zA-Z][-a-zA-Z0-9._]*)((?:\s+[^>]+)?\s+[mM][Vv]\s*=)\s*)||) {
#::logDebug("REALLY do < tag") if ! $Tmp::DoneDebug++;
				$eaten .= $1;
				$self->{HTML} = 1;

				my ($tag, $end_tag);
				my ($nopush, $element);
				my %attr;
				my @attrseq;
				my $old;

				$end_tag = $2;
#::logDebug("end_tag='$end_tag' eat='$eaten'");
				( $$buf =~ s|^((['"])(.*?)\2\s*)||s and $tag = $3 )
				or
				( $$buf =~ s|^(([a-zA-Z][-a-zA-Z0-9._]*)\s*)|| and $tag = $2)
				or ($self->text($eaten), next);
				$eaten .= $1;
				if( index($tag, " ") != -1 ) {
					($tag, $attr{OLD}) = split /\s+/, $tag, 2;
				}
#::logDebug("< tag='$tag' eat='$eaten'");
				$tag = lc $tag;

				# Then we would like to find some attributes
				#
				# Arrgh!! Since stupid Netscape violates RCF1866 by
				# using "_" in attribute names (like "ADD_DATE") of
				# their bookmarks.html, we allow this too.
				while (	$$buf =~ s|^(([a-zA-Z][-a-zA-Z0-9._]*)\s*)|| ) {
					$eaten .= $1;
#::logDebug("in parse, eaten=$eaten");
					my $attr = lc $2;
					$attr =~ s/^mv\.?//
						or $tag =~ /^urld/
						or undef $attr;
					$attr =~ s/\.(.*)//
						and $element = $1;
						
					my $val;
					
					# The attribute might take an optional value (first we
					# check for an unquoted value)
					if ($$buf =~ s~(^=\s*([^\!\|\@\"\'\`\]\s][^\]>\s]*)\s*)~~) {
						$eaten .= $1;
						next unless defined $attr;
						$val = $2;
					# or quoted by " or ' or # or $ or |
					} elsif ($$buf =~ s~(^=\s*(["\'])(.*?)\2\s*)~~s) {
						$eaten .= $1;
						next unless defined $attr;
						$val = $3;
						HTML::Entities::decode($val) if $attr{entities};
					# or quoted by `` to send to [calc]
					} elsif ($$buf =~ s~(^=\s*([\`\|]?)(.*?)\2\s*)~~s) {
						$eaten .= $1;
						if    ($2 eq '`') {
							$val = Vend::Interpolate::tag_calc($3)
								unless defined $Vend::Cfg->{AdminSub}{calc};
						}
						elsif ($2 eq '|') {
								$val = $3;
								$val =~ s/^\s+//;
								$val =~ s/\s+$//;
						}
						else {
							die "parse error!";
						}
					# truncated just after the '=' or inside the attribute
					} elsif ($$buf =~ m|^(=\s*)$|s or
							 $$buf =~ m|^(=\s*[\"\'].*)|s) {
#::logDebug("Truncated? eaten=$eateni buf=$$buf");
						$$buf = "$eaten$1";
						return $self;
					} 

					if(defined $element) {
#::logDebug("Found element: $element val=$val");
						if(! ref $attr{$attr}) {
							if ($element =~ /[A-Za-z]/) {
								$attr{$attr} = { $element => $val };
							}
							else {
								$attr{$attr} = [ ];
								$attr{$attr}->[$element] = $val;
							}
							push (@attrseq, $attr);
						}
						elsif($attr{$attr} =~ /ARRAY/) {
							if($element =~ /\D/) {
								push @{$attr{$attr}}, $val;
							}
							else {
								$attr{$attr}->[$element] = $val;
							}
						}
						elsif ($attr{$attr} =~ /HASH/) {
							$attr{$attr}->{$element} = $val;
						}
						undef $element;
						next;
					}
					$attr{$attr} = $val;
					push(@attrseq, $attr) unless $nopush;
				}

				# At the end there should be a closing "\] or >"
				if ($$buf =~ s|^>|| ) {
					$self->start($tag, \%attr, \@attrseq, "$eaten>", $end_tag);
				} elsif (length $$buf) {
#::logDebug("not conforming, eaten $eaten");
					# Not a conforming start tag, regard it as normal text
					$self->text($eaten);
				} else {
					$$buf = $eaten;  # need more data to know
					return $self;
				}

			} elsif (length $$buf) {
#::logDebug("eaten $eaten");
				$self->text($eaten);
			} else {
				#$$buf = $eaten;  # need more data to parse
				return $self;
			}

		} elsif (length $$buf) {
			::logDebug("remaining: $$buf");
			die $$buf; # This should never happen
		} else {
			# The buffer is empty now
			return $self;
		}
		return $self if $self->{SEND};
	}
	$self;
}


1;
__END__
