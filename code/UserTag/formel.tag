#
# UserTag formel - see POD documentation for more information
#
# Copyright 2000-2003 by Stefan Hornburg (Racke) <racke@linuxia.de>
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

UserTag formel Order label name type size
UserTag formel Version 0.092
UserTag formel addAttr
UserTag formel Routine <<EOF
sub {
    my ($label, $name, $type, $size, $opt) = @_;
    my ($labelhtml, $elhtml, $fmt);
    my $contrast = $::Variable->{CONTRAST} || 'red';
	my $checkfor = $opt->{'checkfor'} || $name;
    my $sizestr = '';
	my $labelproc;

	$labelproc = sub {
		my ($label, $keep) = @_;
		my ($error);

		if ($opt->{cause}) {
			if ($error = $Tag->error({name => $checkfor, keep => 1})) {
				$label .= $Tag->error({name => $checkfor, keep => $keep, 
									   text => $opt->{cause}});
			}
		} else {
			$error = $Tag->error({name => $checkfor, keep => $keep});
		}

	    if ($error) {
			if ($opt->{signal}) {
				sprintf($opt->{signal}, $label);
			} else {
		        qq{<font color="$contrast">$label</font>};
			}	
	    } else {      
    	    $label;
		}
	};

    # set defaults
    $type = 'text' unless $type;
    
    for ('cause', 'format', 'order', 'reset', 'signal', 'size') {
        next if $opt->{$_};
        if ($::Values->{"mv_formel_$_"}) {
            $opt->{$_} = $::Values->{"mv_formel_$_"};
        }   
    }
    
    if ($opt->{'format'}) {
        $fmt = $opt->{'format'};
    } else {
        $fmt = '%s %s %s';
    }

    if ($opt->{'size'}) {
		if ($type eq 'textarea') {
			my ($cols, $rows) = split (/\s*[,x\s]\s*/, $opt->{'size'});
			$sizestr = " rows=$rows cols=$cols";
		} else {
	        $sizestr = " size=$opt->{size}";
		}
    }

    if ($opt->{'maxlength'}) {
		$sizestr .= " maxlength=$opt->{maxlength}";
	}

	if ($type eq 'radio' || $type eq 'checkbox') {		
		my ($rlabel, $rvalue, $select);
		
		for my $button (split (/\s*,\s*/, $opt->{choices})) {
			$select = '';
			if ($button =~ /^(.*?)=(.*)$/) {
				$rvalue = $1;
				$rlabel = $2;
			} else {
				$rvalue = $rlabel = $button;
			}

			if ($::Values->{$name} eq $rvalue) {
				$select = ' checked';
			}

			$rlabel = &$labelproc($rlabel, 1);
			
			$elhtml .= qq{<input type=$type name=$name value="${rvalue}"$select> $rlabel};
		}
		# delete error implicitly
		$labelhtml = &$labelproc($label);
		return sprintf ($fmt, $labelhtml, $elhtml);
	}

	$labelhtml = &$labelproc($label);

	if ($type eq 'select') {
		my ($rlabel, $rvalue, $select);

		for my $option (split (/\s*,\s*/, $opt->{choices})) {
			$select = '';
			if ($option =~ /^(.*?)=(.*)$/) {
				$rvalue = $1;
				$rlabel = $2;
			} else {
				$rvalue = $rlabel = $option;
			}

			if ($::Values->{$name} eq $rvalue) {
				$select = ' selected';
			}
			if ($rvalue eq $rlabel) {	
				$elhtml .= qq{<option $select>$rlabel};
			} else {
				$elhtml .= qq{<option value="$rvalue"$select>$rlabel};
			}
		}
		return sprintf ($fmt, $labelhtml, 
			qq{<select name=$name>$elhtml</select>});
	}

	if ($type eq 'display') {
		# try to handle widget with UI tag display
		$elhtml = $Tag->display($opt->{table} || 'products', $name, '', 
			{value => $Values->{$name}});
	} elsif ($opt->{reset}) {
		if ($type eq 'textarea') {
	        $elhtml = qq{<textarea name="${name}"$sizestr></textarea>};
		} else {
	        $elhtml = qq{<input type=$type name="${name}"$sizestr>};
		}
    } else {
		if ($type eq 'textarea') {
	        $elhtml = qq{<textarea name="${name}"$sizestr>$::Values->{$name}</textarea>};
		} else {
	        $elhtml = qq{<input type=$type name=$name value="$::Values->{$name}"$sizestr>};
		}
    }

    if ($opt->{order}) {
        # display form element first
        sprintf ($fmt, $elhtml, $labelhtml, $opt->{help});
    } else {
        # display label first
        sprintf ($fmt, $labelhtml, $elhtml, $opt->{help});
    }
}
EOF
UserTag formel Documentation <<EOD
=head2 formel

This tag generates a HTML form element. It preserves the user input from
the last display of the current page and looks for
input value errors (using the C<error> tag). 
The user-visible description will be displayed
in the color defined by the variable C<CONTRAST> or in red if the
variable is not set.

Parameters for this tag are:

=over 4

=item label

The user-visible description of the form element's purpose.

=item name

The name of the form element which appears in the C<NAME>
attribute of the HTML tag.

=item type

The type of the form element (supported are text, textarea,
checkbox, radio, select and display). If the given type is display,
the display tag will be called and the return value will be used as 
form element. Note that this tag might not be available depending 
on your configuration.

=item size

The width of the form element. For textarea elements you can
specify width and height (e.g. 70x10 or 20,4).

=back

Other options are:

=over 4

=item cause

Format string for the error message. Appends the result string to
the label if set. You can use C< (%s)> for example.

=item checkfor

The name which get passed to the Error tag. The default
is the name of the form element.

=item choices

Comma-separated list of choices for radio, checkbox and select types.
To display labels different from the values, use the
C<value1=label1,value2=label2,...> notation.

=item format

The container format string for the label and the form element.
The default is C<%s %s %s>.

=item help

Help text for this form element.

=item maxlength

Add attribute C<maxlength> to the input tag.

=item order

Whether the user-visible description or the form element
comes first. Default is the first (order=0).

=item reset

Discards the user input if set to 1.

=item signal

Label container in case of errors. The default is
<font color="__CONTRAST__">%s</font>. If the variable
CONTRAST doesn't exist, the color red is used instead.

=item table

Pass this database to the display tag.
Only used for display types. 

=back

You can set defaults for cause, format, order, reset, signal and size with the
corresponding mv_formel_... form variable values, e.g.:

	[value name="mv_formel_cause" set=" (<I>%s</I>)" hide=1]
	[value name="mv_formel_format" set="<TR><TD>%s</TD><TD>%s</TD></TR>" hide=1]
	[value name="mv_formel_order" set=1 hide=1]
	[value name="mv_formel_signal" set="<BLINK>%s</BLINK>" hide=1]    

To display the label and the form element seperately call C<formel> twice:

	[formel label=Username: name=login format="%s"]
	[formel name=login order=1 format="%s"]

You may add a help text for the form element.
	
	[formel label=Username: name=login help="alphanumeric (5-10 characters)"]

=cut

EOD
