# Vend::Parser - Interchange parser class
#
# $Id: Parser.pm,v 2.13 2007-08-09 13:40:53 pajamian Exp $
#
# Copyright (C) 2002-2007 Interchange Development Group
# Copyright (C) 1997-2002 Red Hat, Inc.
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

Copyright 2002-2007 Interchange Development Group
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
no warnings qw(uninitialized numeric);

use HTML::Entities ();
use vars qw($VERSION);
$VERSION = substr(q$Revision: 2.13 $, 10);


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

	my $eaten;
	# Parse html text in $$buf.  The strategy is to remove complete
	# tokens from the beginning of $$buf until we can't deside whether
	# it is a token or not, or the $$buf is empty.
	while (1) {  # the loop will end by returning when text is parsed
		# If a preceding routine sent the response, stop 
		if ($Vend::Sent) {
			${$self->{OUT}} = $self->{_buf} = '';
			@Vend::Output = ();
			return $self;
		}
		# We try to pull off any plain text (anything before a '[')
		if ($$buf =~ s/^([^[]+)// ) {
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

			# First find a tag name. It must immediately follow the
			# opening '[', then start with a letter, and be followed by
			# letters, numbers, dot, or underscore.
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
				while (	$$buf =~ s|^(([_a-zA-Z][-a-zA-Z0-9._]*)\s*)|| or
					 	$$buf =~ s|^(([=!<>][=~]?)\s+)||                 )
				{
					$eaten .= $1;
					my $attr = lc $2;
					$attr =~ tr/-/_/;
#::logDebug("in parse, eaten=$eaten");
					$attr =~ s/\.(.*)//
						and $element = $1;
						
					my $val;
					
					# The attribute might take an optional value.
					# First we check for an unquoted value
					if ($$buf =~ s~(^=\s*([^\|\"\'\`\]\s][^\]>\s]*)\s*)~~) {
						$eaten .= $1;
						next unless defined $attr;
						$val = $2;
					# or quoted by " or '
					} elsif ($$buf =~ s~(^=\s*(["\'])(.*?)\2\s*)~~s) {
						$eaten .= $1;
						next unless defined $attr;
						$val = $3;
						HTML::Entities::decode($val) if $attr{entities};
					} elsif ($$buf =~ s~(^=\s*([\`\|])(.*?)\2\s*)~~s) {
						$eaten .= $1;
						# or quoted by ` to send to [calc]
						if    ($2 eq '`') {
							$val = Vend::Interpolate::tag_calc($3)
								unless defined $Vend::Cfg->{AdminSub}{calc};
						}
						# or quoted by | to strip leading & trailing whitespace
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
						# assume attribute with implicit value, but if not,
						# no value is set and the eaten value is grown
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
						$val = Vend::Interpolate::interpolate_html($val)
							if  $::Pragma->{interpolate_itl_references}
							and $val =~ /\[\w[-\w]*\s+.*]/s;
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
						elsif(ref($attr{$attr}) eq 'ARRAY') {
							if($element =~ /\D/) {
								push @{$attr{$attr}}, $val;
							}
							else {
								$attr{$attr}->[$element] = $val;
							}
						}
						elsif (ref($attr{$attr}) eq 'HASH') {
							$attr{$attr}->{$element} = $val;
						}
						undef $element;
						next;
					}
					$attr{$attr} = $val;
					push(@attrseq, $attr) unless $nopush;
				}

				# At the end there should be a closing ']'
				if ($$buf =~ s|^\]|| ) {
					$self->start($tag, \%attr, \@attrseq, "$eaten]");
				} elsif ($$buf =~ s|^/\s*\]||) {
					# XML-style empty container tag like [this /]
					$self->start($tag, \%attr, \@attrseq, "$eaten]", 1);
				} elsif ($$buf =~ s|^([^\]\n]+\])||) {
					$eaten .= $1;
					$self->start($tag, {}, [], $eaten);
				} else {
#::logDebug("eaten $eaten");
					# Not a conforming start tag, regard it as normal text
					$self->text($eaten);
				}

			} else {
#::logDebug("eaten $eaten");
				$self->text($eaten);
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
