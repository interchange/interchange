UserTag button Order name src text
UserTag button addAttr
UserTag button attrAlias value text
UserTag button hasEndTag
UserTag button Version $Id: button.tag,v 1.9 2003-04-29 20:03:09 mheins Exp $
UserTag button Documentation <<EOD

=pod

This tag creates an mv_click button either as a C<< <INPUT TYPE=submit ...> >>
or a JavaScript-linked C<< <A HREF=....><img src=...> >> combination.

    [button text="Delete item" confirm="Are you sure?" src="delete.gif"]
	    [comment]
		    This is the action, same as [set Delete item] action [/set]
	    [/comment]
	    [mvtag] Use any Interchange tag here, i.e. ....[/mvtag]
	    [perl] # code to delete item [/perl]
    [/button]

Parameters for this tag are:

=over 4

=item name

Name of the variable, by default mv_click.

=item src
             
Image source file. If it is a relative image, the existence
of the file is checked for.

If your images stop showing up on pages that use SSL, use an absolute
link to the image file.

Instead of,
	src="__THEME__/placeorder.gif"
try:
	src="/yourstore/images/blueyellow/placeorder.gif"

=item text             

The text of the button, also the name of the scratch action
(VALUE is an alias for TEXT.) 

=item wait-text             

The text of the button after a click -- also the name of the scratch action
instead of "text" when this is set.

=item border, height, width, vspace, hspace, align

The image alignment parameters. Border defaults to 0.

=item form      

The name of the form, defaults to document.forms[0] -- be careful!

=item confirm             

The text to use for a JavaScript confirm, if any.
             
=item getsize

If true, tries to use Image::Size to add height=Y width=X.
             
=item alt       

The alt text to be displayed in window.status and balloons.
Defaults to the same as TEXT.
             
=item anchor 

Set to the anchor text value, defaults to TEXT
             
=item hidetext

Set true if you don't want the anchor displayed

=item extra

Extra HTML you want placed inside the link or button. You can
use class,id, or style for those attributes.

=item id,class,style

The normal HTML attributes.

=back

=cut
EOD

UserTag button Routine <<EOR
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
		if(	$src =~ m{^https?:}i ) {
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
	while($action =~ s! \[
						(
							j (?:ava)? s (?:cript)?
						)
						\]
							(.*?)
					  \[ / \1 \]
					  !!xgis
		)
	{
		my $script = $2;
		$script =~ s/\s+$//;
		$script =~ s/^\s+//;
		if($script =~ s/\bonclick\s*=\s*"(.*?)"//is) {
			$onclick = $1;
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
		$onclick = qq{onClick="$confirm$onclick"};
	}

	# Constructing form button. Will be sent back in all cases,
	# either as the primary button or as the <noscript> option
	# for JavaScript-challenged browsers.
	$text =~ s/"/&quot;/g;
	$name =~ s/"/&quot;/g;
	if(! $onclick and $confirm) {
		$onclick = qq{ onclick="return $confirm"};
	}
	$out = qq{<INPUT TYPE="submit" NAME="$name" VALUE="$text"$onclick>};
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
			$onclick .= qq{this.onclick = 'alert(msg)';};
			$onclick .= qq{"};
		}

		my $out = $opt->{bold} ? "<B>" : '';
		$out .= qq{<INPUT$opt->{extra} TYPE="submit" NAME="$name" VALUE="$text"$onclick>};
		$out .= "</B>" if $opt->{bold};
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
	$out .= "</B>" if $opt->{bold};
	my $clickvar = $name;
	if($image and $name eq 'mv_click') {
		$clickvar = $text;
		$clickvar =~ s/\W/_/g;
		$clickname = "mv_click_$clickvar";
		$out = qq{<INPUT TYPE=hidden NAME="mv_click_map" VALUE="$clickvar">};
	}
	
	$out .= qq{<INPUT TYPE=hidden NAME="$clickname" VALUE="">} if $image; 

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
		$position .= " $_=$opt->{$_}" if $opt->{$_};
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
	$out .= <<EOF;
<A HREF="$opt->{link_href}"$opt->{extra} onMouseOver="window.status='$wstatus'"
	onClick="$confirm mv_click_map_unique(document.$opt->{form}, '$clickname', '$text') && $opt->{form}.submit(); return(false);"
	ALT="$wstatus"><IMG ALT="$wstatus" SRC="$src" border=$opt->{border}$position>$a_before$anchor$a_after
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
<script language="javascript1.2">
<!--$function
document.write('$out');
// -->
</script>
$no_script
EOV

	return $out;
}

EOR
