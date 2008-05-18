# Copyright 2002-2008 Interchange Development Group and others
# 
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.  See the LICENSE file for details.
# 
# $Id: button.tag,v 1.24 2008-03-25 15:23:10 racke Exp $

UserTag button Order     name src text
UserTag button addAttr
UserTag button attrAlias value text
UserTag button hasEndTag
UserTag button Version   $Revision: 1.24 $
UserTag button Routine   <<EOR
sub {
	my ($name, $src, $text, $opt, $action) = @_;

	my $trigger_text;

	if($opt->{wait_text}) {
		$trigger_text = $opt->{wait_text};
	}
	else {
		$trigger_text = $text;
	}

	my @js;
	my $image;

	my @from_html = qw/class id style/;

	if($src) {
		my $dr = $::Variable->{DOCROOT};
		my $id = $Tag->image( { dir_only => 1 } );
		$id =~ s:/+$::;
		$id =~ s:/~[^/]+::;
		if(	$src =~ m{^https?://}i ) {
			$image = $src;
		}
		elsif( $dr and $id and $src =~ m{^[^/]} and -f "$dr$id/$src" ) {
			$image = $src;
		}
		elsif( $dr and $src =~ m{^/} and -f "$dr/$src" ) {
			$image = "$id/$src";
		}
	}

	my $onclick = '';
	my $onmouseover = '';
	my $onmouseout = '';
	while($action =~ s! \[
						(
							j (?:ava)? s (?:cript)?
						)
						\]
							(.*?)
					  \[ / \1 \]
					  !!xis
		)
	{
		my $script = $2;
		$script =~ s/\s+$//;
		$script =~ s/^\s+//;
		if($script =~ s/\bonclick\s*=\s*"(.*?)"//is) {
			$onclick = $1;
			next;
		}
		if ($script =~ s/\bonmouse(\w+)\s*=\s*"(.*?)"//is) {
			if (lc($1) eq 'over') {
				$onmouseover .= ($onmouseover ? ';' : '') . $2;
			}
			elsif (lc($1) eq 'out') {
				$onmouseout .= ($onmouseout ? ';' : '') . $2;
			}
			else {
				logError(q{Skipping 'onmouse%s', invalid JavaScript event}, $1);
			}
			next;
		}
		push @js, $script;
	}

	if(! $name or $name eq 'mv_click') {
		$action =~ s/^\s+//;
		$action =~ s/\s+$//;
		my $set_text = HTML::Entities::decode($trigger_text);
		$::Scratch->{$set_text} = $action;
		$name = 'mv_click' if ! $name;
	}
	
	my $out = '';
	my $confirm = '';
	my $wait = '';
	$opt->{extra} = $opt->{extra} ? " $opt->{extra}" : '';
	if($opt->{confirm}) {
		$opt->{confirm} =~ s/'/\\'/g;
		$confirm = "confirm('$opt->{confirm}')";
	}

	if($onclick) {
		$confirm .= ' && ' if $confirm;
		$onclick = qq{ onClick="$confirm$onclick"};
	}

	# Constructing form button. Will be sent back in all cases,
	# either as the primary button or as the <noscript> option
	# for JavaScript-challenged browsers.
	$text =~ s/"/&quot;/g;
	$name =~ s/"/&quot;/g;
	$out = qq{<input type="submit" name="$name" value="$text"$onclick$Vend::Xtrailer>};
	if (@js) {
		$out =~ s/ /join "\n", '', @js, ''/e;
	}

	$opt->{extra} ||= '';
	for(@from_html) {
		next unless $opt->{$_};
		$opt->{extra} .= qq{ $_="$opt->{$_}"};
	}

	# return submit button if not an image
	if(! $image) {
		$text =~ s/"/&quot;/g;
		$name =~ s/"/&quot;/g;
		if(! $onclick and $confirm) {
			$onclick = qq{ onclick="return $confirm"};
		}
		elsif(! $onclick and $opt->{wait_text}) {
			$opt->{wait_text} = HTML::Entities::encode($trigger_text);
			$onclick  = qq{ onClick="};
			$onclick .= qq{var msg = 'Already submitted.';};
			$onclick .= qq{this.value = '$opt->{wait_text}';};
			$onclick .= qq{this.onclick = 'alert(msg)'; return true;};
			$onclick .= qq{"};
		}

		my $out = $opt->{bold} ? '<b>' : '';
		$out .= qq{<input$opt->{extra} type="submit" name="$name" value="$text"$onclick$Vend::Xtrailer>};
		$out .= '</b>' if $opt->{bold};
		if(@js) {
			$out =~ s/ /join "\n", '', @js, ''/e;
		}
		return $out;
	}

	# If we got here the button is an image
	# Wrap form button code in <noscript>
	my $no_script = qq{<noscript>$out</noscript>\n};
	$out = '';

	my $wstatus = $opt->{alt} || $text;
	$wstatus =~ s/'/\\'/g;

	my $clickname = $name;
	my $clickvar = $name;
	if($image and $name eq 'mv_click') {
		$clickvar = $text;
		$clickvar =~ s/\W/_/g;
		$clickname = "mv_click_$clickvar";
		$out = qq{<input type='hidden' name='mv_click_map' value='$clickvar'$Vend::Xtrailer>};
	}
	
	$out .= qq{<input type='hidden' name='$clickname' value=''$Vend::Xtrailer>} if $image; 

	my $formname;
	$opt->{form} = 'forms[0]'
		if ! $opt->{form};

	$confirm .= ' && ' if $confirm;
	$opt->{border} = 0 if ! $opt->{border};

	if($opt->{getsize}) {
		eval {
			require Image::Size;
			($opt->{width}, $opt->{height}) = Image::Size::imgsize($image);
		};
	}

	$opt->{align} = 'top' if ! $opt->{align};

	my $position = '';
	for(qw/height width vspace hspace align/) {
		$position .= " $_='$opt->{$_}'" if $opt->{$_};
	}

	my $anchor = '';
	unless( $opt->{hidetext}) {
		$anchor = $opt->{anchor} || $text;
		$anchor =~ s/ /&nbsp;/g;
		$anchor = "<b>$anchor</b>";
	}

	my $a_before = '</a>';
	my $a_after  = '';
	if($opt->{link_text_too}) {
		$a_before = '';
		$a_after = '</a>';
	}

	$opt->{link_href} ||= 'javascript: void 0';
	if ($onclick =~ /^\s*onclick\s*=\s*"(.*?)"/i) {
		$onclick = $1 . ' && ';
	}
	# QUOTING (fix here too?)
	$out .= <<EOF;
<a href="$opt->{link_href}"$opt->{extra} onMouseOver="window.status='$wstatus';$onmouseover"
EOF
	$out .= <<EOF if $onmouseout;
	onMouseOut="$onmouseout"
EOF
	$out .= <<EOF;
	onClick="$confirm $onclick mv_click_map_unique(document.$opt->{form}, '$clickname', '$text') && $opt->{form}.submit(); return(false);"
	alt="$wstatus"><img alt="$wstatus" src="$src" border='$opt->{border}'$position>$a_before$anchor$a_after
EOF

	my $function = '';
	unless ($::Instance->{js_functions}{mv_do_click}++) {
		$function = "\n" . <<'EOJS';
function mv_click_map_unique(myform, clickname, clicktext) {
	for (var i = 0; i < myform.length; i++) {
		var widget = myform.elements[i];
		if (
			(widget.type == 'hidden')
			&& (widget.name != 'mv_click_map')
			&& (widget.name.indexOf('mv_click_') == 0)
		)
			widget.value = (widget.name == clickname) ? clicktext : '';
	}
	return true;
}
EOJS
	}

	# Must escape backslashes and single quotes for JavaScript write function.
	# Also must get rid of newlines and carriage returns.
	$out =~ s/(['\\])/\\$1/g;
	$out =~ s/[\n\r]+/ /g;
	$out = <<EOV;
<script language="javascript1.2" type="text/javascript">
<!--$function
document.write('$out');
// -->
</script>
$no_script
EOV

	return $out;
}

EOR
