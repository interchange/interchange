UserTag adjust_href hasEndTag
UserTag adjust_href Routine <<EOR
sub {
	my $text = shift;
	use HTML::Parser;
	use vars qw/ $Tag /;

	my @out;

	my $starth = sub {
		my $tag = shift;
		if(lc($tag) ne 'a') {
			push @out, shift;
			return;
		}
		my $text = shift;
		my $attr = shift;
		my $href = $attr->{href};
		if($::Pragma->{allow_for_users} and $href =~ s{^$Vend::Cfg->{VendURL}/}{}) {
			## Do nothing, removed user-clipped link intro
			$attr->{href} = $href;
		}
		if($href =~ m{^\w+:} or $href =~ /^[^\w]/) {
			push @out, $text;
			return;
		}

		my $needform;
		if($::Pragma->{allow_for_users} and $attr->{href} =~ s/\?(.*)//) {
			my @parms = split /\&/, $1;
			my @ignore = qw/ mv_pc mv_session_id mv_source= id=/;
			my $ignore = join "|", @ignore;
			$ignore = qr/($ignore)/;
			for(@parms) {
				next if $_ =~ $ignore;
				$needform++;
				$attr->{form} .= "\n";
				$attr->{form} .= $_;
			}
		}

		my %handled = qw/
				add_dot_html    1
				add_source      1
				anchor          1
				auto_format     1
				form            1
				href            1
				link_relative   1
				match_security  1
				no_count        1
				no_session      1
				no_session_id   1
				path_only       1
				link_relative   1
				secure          1
		/;
		
		my $attrseq = shift;
		push @out, "<a ";
		my $seq = '';
		my $opt = {};
		my %seen;
		$needform and @$attrseq = grep !$seen{$_}, @$attrseq, 'form';
		for(@$attrseq) {
			if($handled{$_}) {
				$opt->{$_} = $attr->{$_};
			}
			else {
				$seq .= qq{ $_="};
				$seq .= $attr->{$_};
				$seq .= '"';
			}
		}
		push @out, qq{ href="};
		push @out, $Tag->area($opt);
		push @out, '"';
		push @out, $seq;
		push @out, ">";
	};

	my $p = HTML::Parser->new();
	$p->handler( start => $starth, "tagname, text, attr, attrseq");
	$p->handler( end => sub { push @out, shift }, "text");
	$p->handler( text => sub { push @out, shift }, "text");
	$p->handler( comment => sub { push @out, shift }, "text");
	$p->handler( process => sub { push @out, shift }, "text");
	$p->handler( declaration => sub { push @out, shift }, "text");
	$p->parse($text);

	return join "", @out;

}
EOR
UserTag adjust_href Documentation <<EOD
=head1 NAME

ITL tag [adjust-href/ -- Turn standard <a href="page?parm=val"> into Interchange link

=head1 SYNOPSIS

  [adjust-href]
  <a href="somepage.html?parameter=value">
	link anchor
  </a>
  [/adjust-href]

 becomes

  <a href="https://srv.dmn.com/cgi/link/somepage.html?parameter=value&id=x338Dbll">
  	link anchor
  </a>

=head1 DESCRIPTION

Reads HTML passed to it, finds <a href> links and adjusts ones that
don't begin with an absolute path to Interchange URLs. Normally done
by setting

  Pragma adjust_href

in catalog.cfg (or [pragma adjust_href] at the top of the page). When
this is done, transformation is done for every HTML page without the
tag being present.

This allows an HTML editor to edit pages/links and result in valid 
Interchange URLs.

=head2 Options

Can set Pragma allow_for_users to allow users to send/resend existing links
and adjust them. Otherwise, previously adjusted URLs that were downloaded will
not be adjusted.

=head1 BUGS

Does not allow for relative paths using ../ -- it probably should. Will look at
enhancing tag to do so.

=head1 AUTHOR

Mike Heins

=cut
EOD
