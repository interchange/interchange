# Vend::Options::Simple - Interchange Simple product options
#
# $Id: Simple.pm,v 1.1 2003-02-12 03:59:13 mheins Exp $
#
# Copyright (C) 2002-2003 Mike Heins <mikeh@perusion.net>
# Copyright (C) 2002-2003 Interchange Development Group <interchange@icdevgroup.org>

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
#

package Vend::Options::Simple;

$VERSION = substr(q$Revision: 1.1 $, 10);

=head1 Interchange Simple Options Support

Vend::Options::Simple $Revision: 1.1 $

=head1 SYNOPSIS

    [item-options]
 
        or
 
    [price code=SKU]
 
=head1 PREREQUISITES

Vend::Options

=head1 DESCRIPTION

The Vend::Options::Simple module implements simple product options for
Interchange. It is compatible with Interchange 4.8.x simple options.

If the Interchange Variable MV_OPTION_TABLE is not set, it defaults
to "options", which combines options for Simple, Matrix, and
Modular into that one table. This goes along with foundation and
construct demos up until Interchange 4.9.8.

The "options" table remains the default for simple options.

=head1 AUTHORS

Mike Heins <mikeh@perusion.net>

=head1 CREDITS

Jon Jensen <jon@swelter.net>

=cut

use Vend::Util;
use Vend::Data;
use Vend::Interpolate;
use Vend::Options;
use strict;

use vars qw/%Default/;

%Default = ( 
	option_template => '{LABEL} {PRICE?}({NEGATIVE?}subtract{/NEGATIVE?}{NEGATIVE:}add{/NEGATIVE:} {ABSOLUTE}) {/PRICE?}'
);

my $Admin_page;

sub price_options {
	my ($item, $table, $final, $loc) = @_;

	$loc ||= $Vend::Cfg->{Options_repository}{Simple} || {};
	my $map = $loc->{map} || {};

	my $db = database_exists_ref($table || $loc->{table} || 'options');
	if(! $db) {
		logOnce('Non-existent price option table %s', $table);
		return;
	}

	my $tname = $db->name();
	my $sku = $item->{code};

#::logDebug("Simple module price_options found enabled record");
	my $fsel = $map->{sku} || 'sku';
	my $rsel = $db->quote($sku, $fsel);
	my @rf;
	for(qw/o_group price/) {
		push @rf, ($map->{$_} || $_);
	}

	my $q = "SELECT " . join (",", @rf) . " FROM $tname where $fsel = $rsel and $rf[1] != ''";
#::logDebug("Simple module price_options query=$q");
	my $ary = $db->query($q); 
	return if ! $ary->[0];
	my $ref;
	my $price = 0;
	my $f;

	foreach $ref (@$ary) {
#::logDebug("checking option " . uneval_it($ref));
		next unless defined $item->{$ref->[0]};
		next unless length($ref->[1]);
		$ref->[1] =~ s/^\s+//;
		$ref->[1] =~ s/\s+$//;
		$ref->[1] =~ s/==/=:/g;
		my %info = split /\s*[=,]\s*/, $ref->[1];
		if(defined $info{ $item->{$ref->[0]} } ) {
			my $atom = $info{ $item->{$ref->[0]} };
			if($atom =~ s/^://) {
				$f = $atom;
				next;
			}
			elsif ($atom =~ s/\%$//) {
				$f = $final if ! defined $f;
				$f += ($atom * $final / 100);
			}
			else {
				$price += $atom;
			}
		}
	}
#::logDebug("price_options returning price=$price f=$f");
	return ($price, $f);
}

sub display_options {
	my ($item, $opt, $loc) = @_;
#::logDebug("Simple options, item=" . ::uneval($item) . "\nopt=" . ::uneval($opt));
#::logDebug("Simple options by module, old");

	$loc ||= $Vend::Cfg->{Options_repository}{Simple} || {};
	my $map = $loc->{map} || {};

	my $sku = $item->{code};

	my $db;
	my $tab;
	if(not $db = $opt->{options_db}) {
		$tab = $opt->{table} ||= $loc->{table} 
							 ||= $::Variable->{MV_OPTION_TABLE}
							 ||= 'options';
		$db = database_exists_ref($tab)
			or do {
				logOnce(
						"Simple options: unable to find table %s for item %s",
						$tab,
						$sku,
					);
				return undef;
			};
	}

	my $tname = $db->name();

	my @rf;
	my @out;
	my $out;

	use constant CODE   => 0;
	use constant GROUP  => 1;
	use constant VALUE  => 2;
	use constant LABEL  => 3;
	use constant WIDGET => 4;
	use constant PRICE  => 5;
	use constant HEIGHT => 6;
	use constant WIDTH  => 7;

	for(qw/code o_group o_value o_label o_widget price o_height o_width/) {
		push @rf, ($map->{$_} || $_);
	}

	my $fsel = $map->{sku} || 'sku';
	my $rsel = $db->quote($sku, $fsel);
	
	my $q = "SELECT " . join (",", @rf) . " FROM $tname where $fsel = $rsel";

	if(my $rsort = find_sort($opt, $db, $loc)) {
		$q .= $rsort;
	}
#::logDebug("tag_options simple query: $q");

	my $ary = $db->query($q)
		or return; 
#::logDebug("tag_options simple ary: " . ::uneval($ary));
#::logDebug("tag_options item=" . ::uneval($item));

	my $ishash = defined $item->{mv_ip} ? 1 : 0;
	my $ref;

	$opt->{option_template} ||= $loc->{option_template};

	foreach $ref (@$ary) {
		# skip unless o_value
		next unless $ref->[VALUE];
#::logDebug("tag_options attribute=" . GROUP);

		if ($opt->{label}) {
			$ref->[LABEL] = "<B>$ref->[LABEL]</b>" if $opt->{bold};
			push @out, $ref->[LABEL];
		}
		my $precursor = $opt->{report}
					  ? "$ref->[GROUP]$opt->{separator}"
					  : qq{<input type=hidden name="mv_item_option" value="$ref->[GROUP]">};
		push @out, $precursor . Vend::Interpolate::tag_accessories(
						$sku,
						'',
						{ 
							attribute => $ref->[GROUP],
							default => undef,
							extra => $opt->{extra},
							item => $item,
							js => $opt->{js},
							name => $ishash ? undef : "mv_order_$ref->[GROUP]",
							option_template => $opt->{option_template},
							passed => $ref->[VALUE],
							price => $opt->{price},
							price_data => $ref->[PRICE],
							height => $opt->{height} || $ref->[HEIGHT],
							width  => $opt->{width} || $ref->[WIDTH],
							type => $opt->{type} || $ref->[WIDGET] || 'select',
						},
						$item || undef,
					);
	}
	if($opt->{td}) {
		for(@out) {
			$out .= "<td>$_</td>";
		}
	}
	else {
		$opt->{joiner} = '<BR>' if ! $opt->{joiner};
		$out .= join $opt->{joiner}, @out;
	}
#::logDebug("display_options out size=" . length($out));
	return $out;
}

sub admin_page {
	my $item = shift;
	my $opt = shift;
	my $page = $Tag->file('include/Options/Simple') || $Admin_page;
	Vend::Util::parse_locale(\$page);
	return interpolate_html($page);
}

$Admin_page = <<'EoAdminPage';
[update values]
[if cgi ui_clone_options]
[and cgi ui_clone_id]
[perl interpolate=1 tables="[cgi mv_data_table]"]
	my $db = $Db{[cgi mv_data_table]}
		or return;
	my ($k,$v);
	$db->clone_row($CGI->{ui_clone_id}, $CGI->{sku});
	$db->clone_set('sku', $CGI->{ui_clone_id}, $CGI->{sku});
	return;
[/perl]
[/if]

[if cgi sku]
    [tag flag write]options[/tag]
    [perl tables="options __UI_ITEM_TABLES__"]
        my $otab = 'options';
        my $odb = $Db{$otab};

        foreach(sort keys %{$CGI}) {
            next unless /^opt_group_(.*)/;
            my $key = $1;

            my $name = $CGI->{"opt_group_$key"};
            my $value = $CGI->{"opt_value_$key"};
            my $label = $CGI->{"opt_label_$key"};

            next unless $name && $value;

            unless($key) { $key = $CGI->{sku}."-$name"; }

            my @value = split("\r\n",$value);

            my %seen = ();
            my $hasdefault = 0;

            my($left,$right);
            map {
                my $default = 0;
                s/[,\r\n]//g;
                if(s/\*//g) { $default = 1; $hasdefault = 1; }

                if($v) {
                    if(/=/) {
                        ($left,$right) = split('=',$_);
                    } else {
                        $right = $_;
                        $left = substr($right,0,3);
                    }

                    while($seen{$left}++) { $left++; }

                    $_ = join('=',$left,$right);
                    if($default) { $_ .= "*"; }
                }
            } @value;

            my $value = join(",\n",@value);

	    $key =~ s/_/-/g; # javascript won't handle form names with '-'

            $odb->set_field($key,'sku',$CGI->{sku});
            $odb->set_field($key,'o_group',$name);
            $odb->set_field($key,'o_value',$value);
            $odb->set_field($key,'o_widget','select');
	    $odb->set_field($key,'o_label',$label);
        }

        return '';
    [/perl]
[/if]


<FORM ACTION="[area @@MV_PAGE@@]" METHOD="post">
[if scratch ui_failure]
<P>
<BLOCKQUOTE>
<FONT COLOR="__CONTRAST__">[scratch ui_failure][set ui_failure][/set]</FONT>
</BLOCKQUOTE>
<P>
&nbsp;
[/if]
[if scratch ui_message]
<P>
<BLOCKQUOTE>
<FONT COLOR="__CONTRAST__">[scratch ui_message][set ui_message][/set]</FONT>
</BLOCKQUOTE>
<P>
&nbsp;
[/if]
<INPUT TYPE=hidden NAME=sku              VALUE="[cgi item_id]">
<INPUT TYPE=hidden NAME=ui_page_title    VALUE="[cgi ui_page_title]">
<INPUT TYPE=hidden NAME=ui_page_title    VALUE="[cgi ui_page_banner]">
<INPUT TYPE=hidden NAME=ui_return_to     VALUE="@@MV_PAGE@@">
<INPUT TYPE=hidden NAME=mv_action        VALUE=back>

<TABLE BORDER=0><TR><TD VALIGN=TOP>

[query list=1 sql="select * from options where sku='[filter op=sql interpolate=1][cgi item_id][/filter]' and o_group is not null"]
[list]
[if-sql-data options o_group]
[calc] $Scratch->{mod_code} = q{[sql-code]}; $Scratch->{mod_code} =~ s/-/_/g; return;[/calc]
<TABLE BORDER=0 CELLSPACING=0 CELLPADDING=3 BGCOLOR="[sql-alternate 2]__UI_T_ROW_EVEN__[else]__UI_T_ROW_ODD__[/else][/sql-alternate]">
<TR><TD VALIGN=CENTER>Name: <INPUT TYPE=text SIZE=20 NAME="opt_group_[scratch mod_code]" VALUE="[filter entities][sql-param o_group][/filter]">

<A HREF="[area href='@@MV_PAGE@@'
               form='deleterecords=1
                     ui_delete_id=[sql-code]
                     item_id=[cgi item_id]
                     mv_data_table=options
                     mv_click=db_maintenance
                     mv_action=back
                     mv_nextpage=@@MV_PAGE@@
                    '
         ]"><IMG SRC="delete.gif" ALT="[L]Delete[/L]" ALIGN=CENTER BORDER=0></A>
<br>[L]Label[/L]: <INPUT TYPE=text SIZE=20 NAME="opt_label_[scratch mod_code]" VALUE="[filter entities][sql-param o_label][/filter]">
<INPUT TYPE=hidden NAME="reset_[scratch mod_code]" VALUE="[filter entities][sql-param o_label][/filter]">
<script><!--
document.write('<br><INPUT TYPE=checkbox [sql-calc]q{[sql-param o_label]} eq q{[sql-param o_group]} ? 'CHECKED' : undef;[/sql-calc]\n' +
'	onClick="if (this.checked) { this.form.opt_label_[scratch mod_code].value = this.form.opt_group_[scratch mod_code].value; } else { this.form.opt_label_[scratch mod_code].value = this.form.reset_[scratch mod_code].value; }">\n' +
'<font size=2>[L]Set label to name[/L]</font>');
// -->
</script>
</TD></TR>
[tmp o_value][perl]
    my @vals = split(',',q{[sql-param o_value]});
    map { s/[\r\n]//g; } @vals;
    return join("\n",@vals);
[/perl][/tmp]

<TR><TD>
<TEXTAREA ROWS=5 COLS=30 NAME="opt_value_[scratch mod_code]">[scratch o_value]</TEXTAREA><br>
[page href="admin/flex_editor"
		form="
			mv_data_table=options
			item_id=[sql-code]
			ui_return_to=admin/item_option
			ui_return_to=item_id=[cgi item_id]
			ui_data_fields=code o_widget o_width o_height
		"]Widget type edit</A>
</TD></TR>
</TABLE>
[/if-sql-data]
[/list]
[/query]

<BR><BR><BR>
[button text="[L]Commit Changes[/L]"]

</TD><TD><PRE>                          </PRE></TD><TD VALIGN=TOP>

<B>[L]Create a new option[/L]:</B><BR>
[L]Name[/L]: <INPUT TYPE=text SIZE=20 NAME="opt_group_" VALUE="">
<br>[L]Label[/L]: <INPUT TYPE=text SIZE=20 NAME="opt_label_">
<script><!--
document.write('<br><INPUT TYPE=checkbox\n' +
'	onClick="if (this.checked) { this.form.opt_label_.value = this.form.opt_group_.value; } else { this.form.opt_label_.value = \'\'; }">\n' +
'<font size=2>[L]Set label to name[/L]</font>');
// -->
</script>
<BR>
<TEXTAREA ROWS=5 COLS=30 NAME="opt_value_"></TEXTAREA>
<BR>
[button text="[L]Create option[/L]"]
<BR><BR>

<HR>

<BR><BR><B>[L]Clone an existing option set[/L]:</B><BR>

[query
	list=1
	prefix=clone
	sql="select DISTINCT sku from [cgi mv_data_table]"
	more=1]
<SELECT NAME=ui_clone_id>
<OPTION VALUE=""> --
[list]
[if-clone-data options o_enable]
<OPTION VALUE="[clone-code]">[clone-filter 20][clone-description][/clone-filter]
[/if-clone-data]
[/list]
</SELECT>[more-list]<BR>[more]<BR>[/more-list][/query]&nbsp;[button text="[L]Clone options[/L]"]<BR>
</FORM>

</TD></TR></TABLE>

EoAdminPage

1;
