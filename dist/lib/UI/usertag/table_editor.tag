UserTag table-editor Order mv_data_table item_id
UserTag table-editor addAttr
UserTag table-editor AttrAlias clone ui_clone_id
UserTag table-editor AttrAlias table mv_data_table
UserTag table-editor AttrAlias fields ui_data_fields
UserTag table-editor AttrAlias mv_data_fields ui_data_fields
UserTag table-editor AttrAlias key   item_id
UserTag table-editor AttrAlias view  ui_meta_view
UserTag table-editor AttrAlias profile ui_profile
UserTag table-editor AttrAlias email_fields ui_display_only
#UserTag table-editor Documentation <<EOD
#=head1 NAME
#
#[table-editor]
#
#=head1 SYNOPSIS
#
#  [table-editor
#  		table=ic_table
#		cgi=1*
#		item-id="key"
#		across=n*
#		noexport=1*
# 
#		wizard=1*
#		next_text='Next -->'*
#		cancel_text='Cancel'*
#		back_text='<-- Back'*
# 
#		hidden.formvarname="value"
#
#		item_id_left="keys remaining"
#		mv_blob_field=column*
#		mv_blob_nick=name*
#		mv_blob_pointer="current name"*
#		mv_blob_label="Label text"
#		mv_blob_title="Title HTML"
#
#		ui_break_before="field1 field2"
#		ui_break_before_label="field1=Label 1, field2=Label 2"
#		ui_data_fields="field1 field2 fieldn ..."*
#		ui_data_fields_all=1*
#		ui_display_only="no_set_field"*
#		ui_hide_key=1*
#		ui_meta_specific=1*
#		ui_meta_view="viewname"
#		ui_nextpage="next_destination"
#		ui_prevpage="back_destination"
#		ui_return_to="cancel_destination"
#		ui_new_item=1*
#		ui_sequence_edit=1*
#		ui_clone_id="key"
#		ui_clone_tables="table1 table2 ..."
#		ui_delete_box=1*
#		mv_update_empty=0*
# 
#		widget.field="select|text|any ic widget"
#		label.field="Field Label"
#		help.field="Help text"
#		help-url.field="http://url/to/more/help"
#		default.field="preset value"*
#		override.field="forced value"*
#		filter.field="filter1 filter2"
#		pre-filter.field="filter1 filter2"
#		error.field=1*
#		height.field=N
#		width.field=N
#		passed.field="val1=Label 1, val2=Label 2"
#		lookup.field="lookup_field"
#		database.field="table"
#		field.field="column"
#		outboard.field="key"
#		append.field="HTML"
#		prepend.field="HTML"
#
#	]
#
#=head1 DESCRIPTION
#
#The [table-editor] tag produces an HTML form that edits a database
#table or collects values for a "wizard". It is extremely configurable
#as to display and characteristics of the widgets used to collect the
#input.
#
#The widget types are based on the Interchange C<[display ...]> UserTag,
#which in turn is heavily based on the ITL core C<[accessories ...]> tag.
#
#The C<simplest> form of C<[table-editor]> is:
#
#	[table-editor table=foo]
#
#A page which contains only that tag will edit the table C<foo>, where
#C<foo> is the name of an Interchange table to edit. If no C<foo> table
#is C<defined>, then nothing will be displayed.
#
#If the C<mv_metadata> entry "foo" is present, it is used as the
#definition for table display, including the fields to edit and labels
#for sections of the form. If C<ui_data_fields> is defined, this
#cancels fetch of the view and any breaks and labels must be
#defined with C<ui_break_before> and C<ui_break_before_label>. More
#on the view concept later.
#
#A simple "wizard" can be made with:
#
#	[table-editor
#			wizard=1
#			ui_wizard_fields="foo bar"
#			mv_nextpage=wizard2
#			mv_prevpage=wizard_intro
#			]
#
#The purpose of a "wizard" is to collect values from the user and
#place them in the $Values array. A next page value (option mv_nextpage)
#must be defined to give a destination; if mv_prevpage is defined then
#a "Back" button is presented to allow paging backward in the wizard.
#
#EOD

UserTag table-editor hasEndTag
UserTag table-editor Routine <<EOR
sub {
	my ($table, $key, $opt, $template) = @_;

	package Vend::Interpolate;
	use vars qw/$Values $Scratch $Db $Tag $Config $CGI $Variable $safe_safe/;

	init_calc() if ! $Vend::Calc_initialized;

	my @messages;
	my @errors;

	FORMATS: {
		no strict 'refs';
		my $ref;
		for(qw/
					default     
					error       
					extra       
					filter      
					height      
					help        
					label       
					override    
					passed      
					outboard
					append
					prepend
					lookup
					field
					pre_filter  
					widget      
					width       
				/ )
		{
#::logDebug("doing te_hash $_");
			next if ref $opt->{$_};
#::logDebug("te_hash $_ not a ref");
			($opt->{$_} = {}, next) if ! $opt->{$_};
#::logDebug("te_hash $_ has a value");
			my $ref = {};
			my $string = $opt->{$_};
#::logDebug("te_hash $_ = $string");
			$string =~ s/^\s+//gm;
			$string =~ s/\s+$//gm;
#::logDebug("te_hash $_ now = $string");
			while($string =~ m/^(.+?)=\s*(.+)/mg) {
				$ref->{$1} = $2;
#::logDebug("te_hash $1 = $2");
			}
			$opt->{$_} = $ref;
		}
	}

	my $rowcount = 0;
	my $rowdiv = $opt->{across} || 1;
	my $span = $rowdiv * 2;
	my $oddspan = $span - 1;
	$opt->{table_width} = '60%' if ! $opt->{table_width};
	$opt->{left_width} = '30%' if ! $opt->{left_width};
	if (! $opt->{inner_table_width}) {
		if($opt->{table_width} =~ /%/) {
			$opt->{inner_table_width} = '100%';
		}
		elsif ($opt->{table_width} =~ /^\d+$/) {
			$opt->{inner_table_width} = $opt->{table_width} - 2;
		}
		else {
			$opt->{inner_table_width} = $opt->{table_width};
		}
	}
	my $check       = $opt->{check};
	my $default     = $opt->{default};
	my $error       = $opt->{error};
	my $extra       = $opt->{extra};
	my $filter      = $opt->{filter};
	my $height      = $opt->{widget_height};
	my $help        = $opt->{help};
	my $help_url    = $opt->{help_url};
	my $label       = $opt->{label};
	my $override    = $opt->{override};
	my $pre_filter  = $opt->{pre_filter};
	my $passed      = $opt->{passed};
	my $outboard    = $opt->{outboard};
	my $prepend     = $opt->{prepend};
	my $append      = $opt->{append};
	my $lookup      = $opt->{lookup};
	my $database    = $opt->{database};
	my $field       = $opt->{field};
	my $widget      = $opt->{widget};
	my $width       = $opt->{widget_width};
#::logDebug("widget=" . ::uneval_it($widget) );

	#my $blabel      = $opt->{begin_label} || '<b>';
	#my $elabel      = $opt->{end_label} || '</b>';
	my $blabel      ;
	my $elabel      ;
	my $mlabel = '';

	if($opt->{wizard}) {
		$opt->{noexport} = 1;
		$opt->{next_text} = 'Next -->' unless $opt->{next_text};
		$opt->{cancel_text} = 'Cancel' unless $opt->{cancel_text};
		$opt->{back_text} = '<-- Back' unless $opt->{back_text};
	}
	else {
		$opt->{cancel_text} = 'Cancel' unless $opt->{cancel_text};
		$opt->{next_text} = "Ok" unless $opt->{next_text};
	}

	my $ntext;
	my $btext;
	my $ctext;
	unless ($opt->{wizard} || $opt->{nosave}) {
		$Scratch->{$opt->{next_text}} = $Tag->return_to('click', 1);
	}
	else {
		$ntext = $Scratch->{$opt->{next_text}} = <<EOF;
mv_todo=return
mv_click=ui_override_next
EOF
		my $hidgo = $opt->{hidden}{ui_return_to} || $CGI->{return_to};
		$hidgo =~ s/\0.*//s;
		$ctext = $Scratch->{$opt->{cancel_text}} = <<EOF;
mv_form_profile=
mv_nextpage=$hidgo
mv_todo=return
EOF
		if($opt->{mv_prevpage}) {
			$btext = $Scratch->{$opt->{back_text}} = <<EOF;
mv_form_profile=
mv_nextpage=$opt->{mv_prevpage}
mv_todo=return
EOF
		}
		else {
			delete $opt->{back_text};
		}
	}

	for(qw/next_text back_text cancel_text/) {
		$opt->{"orig_$_"} = $opt->{$_};
	}

	$Scratch->{$opt->{next_text}}   = $ntext if $ntext;
	$Scratch->{$opt->{cancel_text}} = $ctext if $ctext;
	$Scratch->{$opt->{back_text}}   = $btext if $btext;

	$opt->{next_text} = HTML::Entities::encode($opt->{next_text});
	$opt->{back_text} = HTML::Entities::encode($opt->{back_text});
	$opt->{cancel_text} = HTML::Entities::encode($opt->{cancel_text});

	$Scratch->{$opt->{next_text}}   = $ntext if $ntext;
	$Scratch->{$opt->{cancel_text}} = $ctext if $ctext;
	$Scratch->{$opt->{back_text}}   = $btext if $btext;

	if($opt->{cgi}) {
		my @mapdirect = qw/
			item_id
			item_id_left
			mv_data_decode
			mv_data_table
			mv_blob_field
			mv_blob_nick
			mv_blob_pointer
			mv_blob_label
			mv_blob_title
			ui_break_before
			ui_break_before_label
			ui_data_fields
			ui_data_fields_all
			ui_data_key_name
			ui_display_only
			ui_hide_key
			ui_meta_specific
			ui_meta_view
			ui_nextpage
			ui_new_item
			ui_sequence_edit
			ui_clone_id
			ui_clone_tables
			ui_delete_box
			mv_update_empty
		/;
		for(@mapdirect) {
			next if ! defined $CGI->{$_};
			$opt->{$_} = $CGI->{$_};
		}
		my @hmap = (
			[ qr/^ui_te_check:/, $check ],
			[ qr/^ui_te_default:/, $default ],
			[ qr/^ui_te_extra:/, $extra ],
			[ qr/^ui_te_widget:/, $widget ],
			[ qr/^ui_te_passed:/, $passed ],
			[ qr/^ui_te_outboard:/, $outboard ],
			[ qr/^ui_te_prepend:/, $prepend ],
			[ qr/^ui_te_append:/, $append ],
			[ qr/^ui_te_lookup:/, $lookup ],
			[ qr/^ui_te_database:/, $database ],
			[ qr/^ui_te_field:/, $field ],
			[ qr/^ui_te_override:/, $override ],
			[ qr/^ui_te_filter:/, $filter ],
			[ qr/^ui_te_pre_filter:/, $pre_filter ],
			[ qr/^ui_te_widget_height:/, $height ],
			[ qr/^ui_te_widget_width:/, $width ],
			[ qr/^ui_te_help:/, $help ],
			[ qr/^ui_te_help_url:/, $help_url ],
		);
		my @cgi = keys %{$CGI};
		foreach my $row (@hmap) {
			my @keys = grep $_ =~ $row->[0], @cgi;
			for(@keys) {
#::logDebug("found key $_");
				/^ui_\w+:(\S+)/
					and $row->[1]->{$1} = $CGI->{$_};
#::logDebug("set $1=$_");
			}
		}
		$table = $opt->{mv_data_table};
		$key = $opt->{item_id};
	}

	$opt->{color_success} = $Variable->{UI_C_SUCCESS} || '#00FF00'
		if ! $opt->{color_success};
	$opt->{color_fail} = $Variable->{UI_CONTRAST} || '#FF0000'
		if ! $opt->{color_fail};
	### Build the error checking
	my $error_show_var = 1;
	my $have_errors;
	if($opt->{ui_profile} or $check) {
		$Tag->error( { all => 1 } ) if ! $CGI->{mv_form_profile};
		my $prof = $opt->{ui_profile} || '';
		if ($prof =~ s/^\*//) {
			# special notation ui_profile="*whatever" means
			# use automatic checklist-related profile
			my $name = $prof;
			$prof = $Scratch->{"profile_$name"} || '';
			if ($prof) {
				$prof =~ s/^\s*(\w+)[\s=]+required\b/$1=mandatory/mg;
				for (grep /\S/, split /\n/, $prof) {
					if (/^\s*(\w+)\s*=(.+)$/) {
						my $k = $1; my $v = $2;
						$v =~ s/\s+$//;
						$v =~ s/^\s+//;
						$error->{$k} = 1;
						$error_show_var = 0 if $v =~ /\S /;
					}
				}
				$prof = '&calc delete \\$Values->{step_' . $name . "}\n" . $prof;
				$opt->{ui_profile_success} = "&set=step_$name 1";
			}
		}
		my $success = $opt->{ui_profile_success};
		if(ref $check) {
			while ( my($k, $v) = each %$check ) {
				$error->{$k} = 1;
				$v =~ s/\s+$//;
				$v =~ s/^\s+//;
				$v =~ s/\s+$//mg;
				$v =~ s/^\s+//mg;
				$v =~ s/^required\b/mandatory/mg;
				unless ($v =~ /^\&/m) {
					$error_show_var = 0 if $v =~ /\S /;
					$v =~ s/^/$k=/mg;
					$v =~ s/\n/\n&and\n/g;
				}
				$prof .= "$v\n";
			}
		}
		elsif ($check) {
			for (@_ = grep /\S/, split /[\s,]+/, $check) {
				$error->{$_} = 1;
				$prof .= "$_=mandatory\n";
			}
		}
		$opt->{hidden} = {} if ! $opt->{hidden};
		$opt->{hidden}{mv_form_profile} = 'ui_profile';
		my $fail = $opt->{mv_failpage} || $Global::Variable->{MV_PAGE};
		$Scratch->{ui_profile} = <<EOF;
[perl]
#Debug("cancel='$opt->{orig_cancel_text}' back='$opt->{orig_back_text}' click=\$CGI->{mv_click}");
	my \@clicks = split /\\0/, \$CGI->{mv_click};
	
	my \$fail = '$fail';
	for( qq{$opt->{orig_cancel_text}}, qq{$opt->{orig_back_text}}) {
#Debug("compare is '\$_'");
		next unless \$_;
		my \$cancel = \$_;
		for(\@clicks) {
#Debug("click is '\$_'");
			return if \$_ eq \$cancel; 
		}
	}
	
	return <<EOP;
$prof
&fail=$fail
&fatal=1
$success
mv_form_profile=mandatory
&set=mv_todo set
EOP
[/perl]
EOF
		$blabel = '<span style="font-weight: normal">';
		$elabel = '</span>';
		$mlabel = ($opt->{message_label} || '&nbsp;&nbsp;&nbsp;<B>Bold</B> fields are required');
		$have_errors = $Tag->error( {
									all => 1,
									show_var => $error_show_var,
									show_error => 1,
									joiner => '<BR>',
									keep => 1}
									);
		if($opt->{all_errors}) {
			if($have_errors) {
				$mlabel .= '<P>Errors:';
				$mlabel .= qq{<FONT COLOR="$opt->{color_fail}">};
				$mlabel .= "<BLOCKQUOTE>$have_errors</BLOCKQUOTE></FONT>";
			}
		}
	}
	### end build of error checking

	$opt->{clear_image} = "bg.gif" if ! $opt->{clear_image};

#::logDebug("table-editor opt: " . ::uneval($opt));
	my $die = sub {
		::logError(@_);
		$Scratch->{ui_error} .= "<BR>\n" if $Scratch->{ui_error};
		$Scratch->{ui_error} .= ::errmsg(@_);
		return undef;
	};

	if($opt->{wizard} and ! $table) {
		$table = 'mv_null';
		$Vend::Database{mv_null} = 
			bless [
					{},
					undef,
					[ 'code', 'value' ],
					[ 'code' => 0, 'value' => 1 ],
					0,
					{ },
					], 'Vend::Table::InMemory';
	}

	my $db = Vend::Data::database_exists_ref($table)
		or return $die->('table-editor: bad table %s', $table);

	if($opt->{ui_wizard_fields}) {
		$opt->{ui_data_fields} = $opt->{ui_display_only} = $opt->{ui_wizard_fields};
	}

	$Variable->{UI_META_TABLE} = 'mv_metadata' if ! $Variable->{UI_META_TABLE};

	my $mdb = Vend::Data::database_exists_ref($Variable->{UI_META_TABLE})
		or return $die->('table-editor: bad meta table %s', $table);

	my $keycol = $db->config('KEY');

	my $view_table = $opt->{ui_meta_view};

	if (! $view_table) {
		$view_table = $table;
	}
	elsif ("\L$view_table" ne 'none') {
		$view_table = "$view_table::$table";
	}

	$opt->{form_name} = qq{ NAME="$opt->{form_name}"}
		if $opt->{form_name};

	###############################################################
	# Get the field display information including breaks and labels
	###############################################################
	if( $mdb
		and ! $opt->{ui_data_fields}
		and ! $opt->{ui_data_fields_all}
		and $view_table
		and $mdb->record_exists($view_table)
		)
	{
::logDebug("meta info for table: view_table=$view_table table=$table");
		$opt->{ui_data_fields} = $mdb->field($view_table || $table, 'options');
	}

	$opt->{ui_data_fields} =~ s/\r\n/\n/g;
	$opt->{ui_data_fields} =~ s/\r/\n/g;

	if($opt->{ui_data_fields} =~ /\n\n/) {
#::logDebug("Found break fields");
		my @breaks;
		my @break_labels;
		while ($opt->{ui_data_fields} =~ s/\n+(?:\n[ \t]*=(.*))?\n+[ \t]*(\w+)/\n$2/) {
			push @breaks, $2;
			push @break_labels, "$2=$1" if $1;
		}
		$opt->{ui_break_before} = join(" ", @breaks)
			if ! $opt->{ui_break_before};
#::logDebug("break_before=$opt->{ui_break_before}");
		$opt->{ui_break_before_label} = join(",", @break_labels)
			if ! $opt->{ui_break_before_label};
#::logDebug("break_before_label=$opt->{ui_break_before_label}");
	}

	$opt->{ui_data_fields} = $opt->{mv_data_fields} || (join " ", $db->columns())
		if ! $opt->{ui_data_fields};

	$opt->{ui_data_fields} =~ s/[,\0\s]+/ /g;
	###############################################################

	my $linecount;

	CANONCOLS: {
		my @cols = split /[,\0\s]/, $opt->{ui_data_fields};
		#@cols = grep /:/ || $db->column_exists($_), @cols;

		$opt->{ui_data_fields} = join " ", @cols;

		$linecount = scalar @cols;
	}

	my $url = $Tag->area('ui');

	my $key_message;
	if($opt->{ui_new_item}) {
		if( ! $db->config('_Auto_number') ) {
			$db->config('AUTO_NUMBER', '000001');
			$key = $db->autonumber($key);
		}
		else {
			$key = '';
			$opt->{mv_data_auto_number} = 1;
			$key_message = '(new key will be assigned if left blank)';
		}
	}

	my $data;
	my $exists;

	if($opt->{ui_clone_id} and $db->record_exists($opt->{ui_clone_id})) {
		$data = $db->row_hash($opt->{ui_clone_id})
			or
			return $die->('table-editor: row_hash function failed for %s.', $key);
		$data->{$keycol} = $key;
	}
	elsif ($db->record_exists($key)) {
		$data = $db->row_hash($key);
		$exists = 1;
	}

	if ($opt->{reload} and $have_errors) {
		if($data) {
			for(keys %$data) {
				$data->{$_} = $CGI->{$_}
					if defined $CGI->{$_};
			}
		}
		else {
			$data = { %$CGI };
		}
	}


	my $blob_data;
	my $blob_widget;
	if($opt->{mailto} and $opt->{mv_blob_field}) {
		$opt->{hidden}{mv_blob_only} = 1;
		$opt->{hidden}{mv_blob_nick}
			= $opt->{mv_blob_nick}
			|| POSIX::strftime("%Y%m%d%H%M%S", localtime());
	}
	elsif($opt->{mv_blob_field}) {
#::logDebug("checking blob");

		my $blob_pointer;
		$blob_pointer = $data->{$opt->{mv_blob_pointer}}
			if $opt->{mv_blob_pointer};
		$blob_pointer ||= $opt->{mv_blob_nick};
			

		DOBLOB: {

			unless ( $db->column_exists($opt->{mv_blob_field}) ) {
				push @errors, ::errmsg(
									"blob field %s not in database.",
									$opt->{mv_blob_field},
								);
				last DOBLOB;
			}

			my $bstring = $data->{$opt->{mv_blob_field}};

#::logDebug("blob: bstring=$bstring");

			my $blob;

			if(length $bstring) {
				$blob = $safe_safe->reval($bstring);
				if($@) {
					push @errors, ::errmsg("error reading blob data: %s", $@);
					last DOBLOB;
				}
#::logDebug("blob evals to " . ::uneval_it($blob));

				if(ref($blob) !~ /HASH/) {
					push @errors, ::errmsg("blob data not a storage book.");
					undef $blob;
				}
			}
			else {
				$blob = {};
			}
			my %wid_data;
			my %url_data;
			my @labels = keys %$blob;
			for my $key (@labels) {
				my $ref = $blob->{$_};
				my $lab = $ref->{$opt->{mv_blob_label} || 'name'};
				if($lab) {
					$lab =~ s/,/&#44/g;
					$wid_data{$lab} = "$key=$key - $lab";
					$url_data{$lab} = $Tag->page( {
											href => $Global::Variable->{MV_PAGE},
											form => "
												item_id=$opt->{item_id}
												mv_blob_nick=$key
											",
										});
					$url_data{$lab} .= "$key - $lab</A>";
				}
				else {
					$wid_data{$key} = $key;
					$url_data{$key} = $Tag->page( {
											href => $Global::Variable->{MV_PAGE},
											form => "
												item_id=$opt->{item_id}
												mv_blob_nick=$key
											",
										});
					$url_data{$key} .= "$key</A>";
				}
			}
#::logDebug("wid_data is " . ::uneval_it(\%wid_data));
			$opt->{mv_blob_title} = "Stored settings"
				if ! $opt->{mv_blob_title};

			$Scratch->{Load} = <<EOF;
[return-to type=click stack=1 page="$Global::Variable->{MV_PAGE}"]
ui_nextpage=
[perl]Log("tried to go to $Global::Variable->{MV_PAGE}"); return[/perl]
mv_todo=back
EOF
#::logDebug("blob_pointer=$blob_pointer blob_nick=$opt->{mv_blob_nick}");

			my $loaded_from;
			if( $opt->{mv_blob_nick} ) {
				$loaded_from = $opt->{mv_blob_nick};
			}
			else {
				$loaded_from = "current values";
			}
			$loaded_from = <<EOF;
<I>(loaded from $loaded_from)</I><BR>
EOF
			if(@labels) {
				$loaded_from .= "Load from:<BLOCKQUOTE>";
				$loaded_from .=  join (" ", @url_data{ sort keys %url_data });
				$loaded_from .= "</BLOCKQUOTE>";
			}

			my $checked;
			my $set;
			if( $opt->{mv_blob_only} and $opt->{mv_blob_nick}) {
				$checked = ' CHECKED';
				$set 	 = $opt->{mv_blob_nick};
			}

			unless ($opt->{nosave}) {
				$blob_widget = $Tag->widget({
									name => 'mv_blob_nick',
									type => $opt->{ui_blob_widget} || 'combo',
									filter => 'nullselect',
									override => 1,
									set => "$set",
									passed => join (",", @wid_data{ sort keys %wid_data }) || 'default',
									});
				$blob_widget = <<EOF unless $opt->{ui_blob_hidden};
<B>Save to:</B> $blob_widget&nbsp;
<INPUT TYPE=checkbox NAME=mv_blob_only VALUE=1$checked>&nbsp;Save&nbsp;here&nbsp;only</SMALL>
EOF
			}

			$blob_widget = <<EOF unless $opt->{ui_blob_hidden};
<TR class=rnorm>
	 <td class=clabel width="$opt->{left_width}">
	   <SMALL>$opt->{mv_blob_title}<BR>
		$loaded_from
	 </td>
	 <td class=cwidget>
	 	$blob_widget&nbsp;
	 </td>
</TR>

<tr class=rtitle>
<td colspan=$span><img src="$opt->{clear_image}" width=1 height=3 alt=x></td>
</tr>
EOF

		if($opt->{mv_blob_nick}) {
			my $ref = $blob->{$opt->{mv_blob_nick}}
				or last DOBLOB;
			for(keys %$ref) {
				$data->{$_} = $ref->{$_};
			}
		}

		}
	}

#::logDebug("data is: " . ::uneval($data));
	$data = { $keycol => $key }
		if ! $data;

	if(! $opt->{mv_data_function}) {
		$opt->{mv_data_function} = $exists ? 'update' : 'insert';
	}

	$opt->{mv_nextpage} = $Global::Variable->{MV_PAGE} if ! $opt->{mv_nextpage};
	$opt->{mv_update_empty} = 1 unless defined $opt->{mv_update_empty};

	my $url_base = $opt->{secure} ? $Config->{SecureURL} : $Config->{VendURL};
#Debug("Urlbase=$url_base");
	$opt->{href} = "$url_base/ui" if ! $opt->{href};
	$opt->{href} = "$url_base/$opt->{href}"
		if $opt->{href} !~ m{^(https?:|)/};
#Debug("href=$opt->{href}");

	my $sidstr;
	if ($opt->{get}) {
		$opt->{method} = 'GET';
		$sidstr = '';
	} else {
		$opt->{method} = 'POST';
		$sidstr = qq{<INPUT TYPE=hidden NAME=mv_session_id VALUE="$Session->{id}">
};
	}
	$opt->{enctype} = $opt->{file_upload} ? ' ENCTYPE="multipart/form-data"' : '';

	my $out = <<EOF;
[restrict]
<FORM METHOD=$opt->{method} ACTION="$opt->{href}"$opt->{form_name}$opt->{enctype}>
$sidstr<INPUT TYPE=hidden NAME=mv_todo VALUE="set">
<INPUT TYPE=hidden NAME=mv_click VALUE="process_filter">
<INPUT TYPE=hidden NAME=mv_nextpage VALUE="$opt->{mv_nextpage}">
<INPUT TYPE=hidden NAME=mv_data_table VALUE="$table">
<INPUT TYPE=hidden NAME=mv_data_key VALUE="$keycol">
EOF

	my @opt_set = (qw/
						ui_meta_specific
						ui_hide_key
						ui_meta_view
						ui_data_decode
						mv_blob_field
						mv_blob_label
						mv_blob_title
						mv_blob_pointer
						mv_update_empty
						mv_data_auto_number
						mv_data_function
				/ );

	my @cgi_set = ( qw/
						item_id_left
						ui_sequence_edit
					/ );

	push(@opt_set, splice(@cgi_set, 0)) if $opt->{cgi};
	for(@opt_set) {
		next unless length $opt->{$_};
		my $val = $opt->{$_};
		$val =~ s/"/&quot;/g;
		$out .= qq{<INPUT TYPE=hidden NAME=$_ VALUE="$val">\n};
	}

	for (@cgi_set) {
		next unless length $CGI->{$_};
		my $val = $CGI->{$_};
		$val =~ s/"/&quot;/g;
		$out .= qq{<INPUT TYPE=hidden NAME=$_ VALUE="$val">\n};
	}

	if($opt->{mailto}) {
		$opt->{mailto} =~ s/\s+/ /g;
		$Scratch->{mv_email_enable} = $opt->{mailto};
		$opt->{hidden}{mv_data_email} = 1;
	}

	$Vend::Session->{ui_return_stack} ||= [];

	if($opt->{cgi}) {
		my $r_ary = $Vend::Session->{ui_return_stack};

#::logDebug("ready to maybe push/pop return-to from stack, stack = " . ::uneval($r_ary));
		if($CGI::values{ui_return_stack}++) {
			push @$r_ary, $CGI::values{ui_return_to};
			$CGI::values{ui_return_to} = $r_ary->[0];
		}
		elsif ($CGI::values{ui_return_to}) {
			@$r_ary = ( $CGI::values{ui_return_to} ); 
		}
		$out .= $Tag->return_to();
#::logDebug("return-to stack = " . ::uneval($r_ary));
	}

	if(ref $opt->{hidden}) {
		my ($hk, $hv);
		while ( ($hk, $hv) = each %{$opt->{hidden}} ) {
			$out .= qq{<INPUT TYPE=hidden NAME="$hk" VALUE="$hv">\n};
		}
	}

	$out .= <<EOF;
<table class=touter border="" cellspacing="0" cellpadding="0" width="$opt->{table_width}">
<tr>
  <td>

<table class=tinner  width="$opt->{inner_table_width}" cellspacing=0 cellmargin=0 width="100%" cellpadding="2" align="center" border="0">
EOF
	$out .= <<EOF unless $opt->{no_top};
<tr class=rtitle> 
<td align=right colspan=$span><img src="$opt->{clear_image}" width=1 height=3 alt=x></td>
</tr>
EOF

	  #### Extra buttons
      my $extra_ok =	$blob_widget
	  					|| $linecount > 4
						|| defined $opt->{include_form}
						|| $mlabel;
      if ($extra_ok and ! $opt->{no_top} and ! $opt->{nosave}) {
	  	if($opt->{back_text}) {
		  $out .= <<EOF;
<TR class=rnorm>
<td>&nbsp;</td>
<td align=left colspan=$oddspan class=cdata>
EOF
			$out .= <<EOF if ! $opt->{bottom_buttons};
<INPUT TYPE=submit NAME=mv_click VALUE="$opt->{back_text}">&nbsp;<INPUT TYPE=submit NAME=mv_click VALUE="Cancel">&nbsp;<B><INPUT TYPE=submit NAME=mv_click VALUE="$opt->{next_text}"></B>
<BR>
EOF
			$out .= <<EOF;
$mlabel
</TD>
</TR>

<tr class=rspacer>
<td colspan=$span><img src="$opt->{clear_image}" width=1 height=3 alt=x></td>
</tr>
EOF
		}
		elsif ($opt->{wizard}) {
		  $out .= <<EOF;
<TR class=rnorm>
<td>&nbsp;</td>
<td align=left colspan=$oddspan class=cdata>
EOF
			$out .= <<EOF if ! $opt->{bottom_buttons};
<INPUT TYPE=submit NAME=mv_click VALUE="Cancel">&nbsp;<B><INPUT TYPE=submit NAME=mv_click VALUE="$opt->{next_text}"></B>
<BR>
EOF
			$out .= <<EOF;
$mlabel
</TD>
</TR>

<tr class=rspacer>
<td colspan=$span><img src="$opt->{clear_image}" width=1 height=3 alt=x></td>
</tr>
EOF
		}
		else {
		  $out .= <<EOF;
<TR class=rnorm>
<td>&nbsp;</td>
<td align=left colspan=$oddspan class=cdata>
<B><INPUT TYPE=submit NAME=mv_click VALUE="$opt->{next_text}">
</B>
&nbsp;
<INPUT TYPE=submit NAME=mv_click VALUE="Cancel">$mlabel
</TD>
</TR>

<tr class=rspacer>
<td colspan=$span><img src="$opt->{clear_image}" width=1 height=3 alt=x></td>
</tr>
EOF
		}
	}

	$out .= $blob_widget;

	  #### Extra buttons

	if($opt->{ui_new_item} and $opt->{ui_clone_tables}) {
		my @sets;
		my %seen;
		my @tables = split /[\s\0,]+/, $opt->{ui_clone_tables};
		for(@tables) {
			if(/:/) {
				push @sets, $_;
			}
			s/:.*//;
		}

		@tables = grep ! $seen{$_}++ && defined $Config->{Database}{$_}, @tables;

		my $tab = '';
		my $set .= <<'EOF';
[flag type=write table="_TABLES_"]
[perl tables="_TABLES_"]
	delete $Scratch->{clone_tables};
	return if ! $CGI->{ui_clone_id};
	return if ! $CGI->{ui_clone_tables};
	my $id = $CGI->{ui_clone_id};

	my $out = "Cloning id=$id...";

	my $new =  $CGI->{$CGI->{mv_data_key}}
		or do {
				$out .= ("clone $id: no mv_data_key '$CGI->{mv_data_key}'");
				$Scratch->{ui_message} = $out;
				return;
		};

	if($new =~ /\0/) {
		$new =~ s/\0/,/g;
		Log("cannot clone multiple keys '$new'.");
		return;
	}

	my %possible;
	my @possible = qw/_TABLES_/;
	@possible{@possible} = @possible;
	my @tables = grep /\S/, split /[\s,\0]+/, $CGI->{ui_clone_tables};
	my @sets = grep /:/, @tables;
	@tables = grep $_ !~ /:/, @tables;
	for(@tables) {
		next unless $possible{$_};
		my $db = $Db{$_};
		next unless $db;
		my $new = 
		my $res = $db->clone_row($id, $new);
		if($res) {
			$out .= "cloned $id to to $new in table $_<BR>\n";
		}
		else {
			$out .= "FAILED clone of $id to to $new in table $_<BR>\n";
		}
	}
	for(@sets) {
		my ($t, $col) = split /:/, $_;
		my $db = $Db{$t} or next;
		my $res = $db->clone_set($col, $id, $new);
		if($res) {
			$out .= "cloned $col=$id to to $col=$new in table $t<BR>\n";
		}
		else {
			$out .= "FAILED clone of $col=$id to to $col=$new in table $t<BR>\n";
		}
	}
	$Scratch->{ui_message} = $out;
	return;
[/perl]
EOF
		my $tabform = '';
		@tables = grep $Tag->if_mm( { table => "$_=i" } ), @tables;

		for(@tables) {
			my $db = Vend::Data::database_exists_ref($_)
				or next;
			next unless $db->record_exists($opt->{ui_clone_id});
			$tabform .= <<EOF;
<INPUT TYPE=CHECKBOX NAME=ui_clone_tables VALUE="$_"> clone to <b>$_</B><BR>
EOF
		}
		for(@sets) {
			my ($t, $col) = split /:/, $_;
			$tabform .= <<EOF;
<INPUT TYPE=CHECKBOX NAME=ui_clone_tables VALUE="$_"> clone entries of <b>$t</B> matching on <B>$col</B><BR>
EOF
		}

		my $tabs = join " ", @tables;
		$set =~ s/_TABLES_/$tabs/g;
		$Scratch->{clone_tables} = $set;
		$out .= <<EOF;
<tr class=rtitle>
<td colspan=$span>
$tabform<INPUT TYPE=hidden NAME=mv_check VALUE="clone_tables">
<INPUT TYPE=hidden NAME=ui_clone_id VALUE="$opt->{ui_clone_id}">
</td>
</tr>
EOF
	}

	my %break;
	my %break_label;
	if($opt->{ui_break_before}) {
		my @tmp = grep /\S/, split /[\s,\0]+/, $opt->{ui_break_before};
		@break{@tmp} = @tmp;
		if($opt->{ui_break_before_label}) {
			@tmp = grep /\S/, split /\s*[,\0]\s*/, $opt->{ui_break_before_label};
			for(@tmp) {
				my ($br, $lab) = split /\s*=\s*/, $_;
				$break_label{$br} = $lab;
			}
		}
	}
	if(!$db) {
		return "<TR><TD>Broken table '$table'</TD></TR>";
	}

	my $passed_fields = $opt->{ui_data_fields};

	my @extra_cols;
	my %email_cols;
	my %ok_col;

	while($passed_fields =~ s/(\w+:+\S+)//) {
		push @extra_cols, $1;
	}

	my %display_only;
	my @do = grep /\S/, split /[\0,\s]+/, $opt->{ui_display_only};
	for(@do) {
		$email_cols{$_} = 1 if $opt->{mailto};
		$display_only{$_} = 1;
		push @extra_cols, $_;
	}

	my @cols;
	my (@dbcols)  = split /\s+/, $Tag->db_columns( {
										name	=> $table,
										columns	=> $passed_fields,
										passed_order => 1,
									});

	if($opt->{ui_data_fields}) {
		for(@dbcols, @extra_cols) {
			unless (/^(\w+):+(\S+)/) {
				$ok_col{$_} = 1;
				next;
			}
			my $t = $1;
			my $c = $2;
			next unless $Tag->db_columns( { name	=> $t, columns	=> $c, });
			$ok_col{$_} = 1;
		}
	}
	
	@cols = grep $ok_col{$_}, split /\s+/, $opt->{ui_data_fields};

	if($opt->{defaults}) {
		for(@cols) {
			if($opt->{wizard}) {
				$default->{$_} = $::Values->{$_} if defined $::Values->{$_};
			}
			else {
				next if defined $default->{$_};
				next unless defined $::Values->{$_};
				$default->{$_} = $::Values->{$_};
			}
		}
	}

	my $super = $Tag->if_mm('super');

	my $refkey = $key;

	my @data_enable = ($opt->{mv_blob_pointer}, $opt->{mv_blob_field});
	my @ext_enable;
 	my $row_template = $opt->{row_template} || <<EOF;
   <td class=clabel width="$opt->{left_width}"> 
     $blabel\$LABEL\$$elabel~META~
   </td>
   <td class=cdata> 
     <table cellspacing=0 cellmargin=0 width="100%">
       <tr> 
         <td class=cwidget> 
           \$WIDGET\$
         </td>
         <td class=chelp>~TKEY~<i>\$HELP\$</i>{HELPURL}<BR><A HREF="\$HELP_URL\$">help</A>{/HELPURL}</FONT></td>
       </tr>
     </table>
   </td>
EOF
	$row_template =~ s/~OPT:(\w+)~/$opt->{$1}/g;
	$row_template =~ s/~BLABEL~/$blabel/g;
	$row_template =~ s/~ELABEL~/$elabel/g;
	foreach my $col (@cols) {
		my $t;
		my $c;
		my $k;
		my $tkey_message;
		if($col eq $keycol) {
			if($opt->{ui_hide_key}) {
				my $kval = $key || $override->{$col} || $default->{$col};
				$out .= <<EOF;
	<INPUT TYPE=hidden NAME="$col" VALUE="$kval">
EOF
				next;
			}
			elsif ($opt->{ui_new_item}) {
				$tkey_message = $key_message;
			}
		}

		my $do = $display_only{$col};
		
		my $currval;
		if($col =~ /(\w+):+([^:]+)(?::+(\S+))?/) {
			$t = $1;
			$c = $2;
			$k = $3 || undef;
			push @ext_enable, ("$t:$c" . $k ? ":$k" : '')
				unless $do;
		}
		else {
			$t = $table;
			$c = $col;
			push @data_enable, $c
				unless $do and ! $opt->{mailto};
		}

		my $type;
		my $overridden;

		$currval = $data->{$col} if defined $data->{$col};
		if (defined $override->{$c} ) {
			$currval = $override->{$c};
			$overridden = 1;
#::logDebug("hit override for $col,currval=$currval");
		}
		elsif (defined $CGI->{"ui_preload:$t:$c"} ) {
			$currval = delete $CGI->{"ui_preload:$t:$c"};
			$overridden = 1;
#::logDebug("hit preload for $col,currval=$currval");
		}
		elsif( ($do && ! $currval) or $col =~ /:/) {
			if(defined $k) {
				my $check = $k;
				undef $k;
				for( $override, $data, $default) {
					next unless defined $_->{$check};
					$k = $_->{$check};
					last;
				}
			}
			else {
				$k = defined $key ? $key : $refkey;
			}
			$currval = tag_data($t, $c, $k) if defined $k;
#::logDebug("hit display_only for $col, t=$t, c=$c, k=$k, currval=$currval");
		}
		elsif (defined $default->{$c} and ! length($data->{$c}) ) {
			$currval = $default->{$c};
#::logDebug("hit preload for $col,currval=$currval");
		}
		else {
#::logDebug("hit data->col for $col, t=$t, c=$c, k=$k, currval=$currval");
			$currval = length($data->{$col}) ? $data->{$col} : '';
			$overridden = 1;
		}

		$type = 'value' if $do and ! ($opt->{wizard} || ! $opt->{mailto});

		if (! length $currval and defined $default->{$c}) {
			$currval = $default->{$c};
		}

		my $meta = '';
		my $template = $row_template;
		if($error->{$c}) {
			my $parm = {
					name => $c,
					std_label => '$LABEL$',
					required => 1,
					};
			if($opt->{all_errors}) {
				$parm->{keep} = 1;
				$parm->{text} = <<EOF;
<FONT COLOR="$opt->{color_fail}">\$LABEL\$</FONT><!--%s-->
[else]{REQUIRED <B>}{LABEL}{REQUIRED </B>}[/else]
EOF
			}
			$template =~ s/\$LABEL\$/$Tag->error($parm)/eg;
		}
		$template =~ s/~TKEY~/$tkey_message || ''/eg;
#::logDebug("col=$c widget=$widget->{$c} (type=$type)");
		my $display = $Tag->display({
										applylocale => 1,
										arbitrary => $opt->{ui_meta_view},
										column => $c,
										default => $currval,
										extra => $extra->{$c},
										fallback => 1,
										filter => $filter->{$c},
										height => $height->{$c},
										help => $help->{$c},
										help_url => $help_url->{$c},
										label => $label->{$c},
										key => $key,
										name => $col,
										override => $overridden,
										field => $field->{$c},
										passed => $passed->{$c},
										outboard => $outboard->{$c},
										append => $append->{$c},
										prepend => $prepend->{$c},
										lookup => $lookup->{$c},
										db => $database->{$c},
										pre_filter => $pre_filter->{$c},
										table => $t,
										type => $widget->{$c} || $type,
										width => $width->{$c},
										template => $template,
									});
		if($super and ($Variable->{UI_META_LINK} || $::Values->{ui_meta_force}) ) {
			$meta .= '<BR><FONT SIZE=1>';
			# Get global variables
			my $base = $Tag->var('UI_BASE', 1);
			my $page = $Tag->var('MV_PAGE', 1);
			my $id = $t . "::$c";
			$id = $opt->{ui_meta_view} . "::$id"
				if $opt->{ui_meta_view} and $opt->{ui_meta_view} ne 'metaconfig';

			my $return = <<EOF;
ui_return_to=$page
ui_return_to=item_id=$opt->{item_id}
ui_return_to=ui_meta_view=$opt->{ui_meta_view}
ui_return_to=mv_return_table=$t
mv_return_table=$table
ui_return_stack=$CGI->{ui_return_stack}
EOF

			$meta .= $Tag->page(
							{	href => "$base/meta_editor",
								form => qq{
										item_id=$id
										$return
										}
							});
			$meta .= 'meta</A>';
			$meta .= '<br>' . $Tag->page(
							{	href => "$base/meta_editor",
								form => qq{
										item_id=${t}::${c}::$key
										$return
										}
							}) . 'item-specific meta</A></FONT>'
				if $opt->{ui_meta_specific};
			$meta .= '</FONT>';
		}
		$display =~ s/\~META\~/$meta/g;
		$display =~ s/\~ERROR\~/$Tag->error({ name => $c, keep => 1 })/eg;
        
		if ($break{$col}) {
			while($rowcount % $rowdiv) {
				$out .= '<TD>&nbsp;</td><TD>&nbsp;</td>';
				$rowcount++;
			}
			$out .= "</TR>\n";
			$out .= <<EOF if $break{$col};
<TR class=rbreak>
	<TD COLSPAN=$span class=cbreak>$break_label{$col}<IMG SRC="$opt->{clear_image}" WIDTH=1 HEIGHT=1 alt=x></TD>
</TR>
EOF
			$rowcount = 0;
		}
		$out .= "<tr class=rnorm>" unless $rowcount++ % $rowdiv;
		$out .= $display;
		$out .= "</TR>\n" unless $rowcount % $rowdiv;
	}

	while($rowcount % $rowdiv) {
		$out .= '<TD>&nbsp;</td><TD>&nbsp;</td>';
		$rowcount++;
	}

	$Scratch->{mv_data_enable} = '';
	if($opt->{auto_secure}) {
		$Scratch->{mv_data_enable} .= "$table:" . join(",", @data_enable) . ':';
		$Scratch->{mv_data_enable_key} = $opt->{item_id};
	}
	if(@ext_enable) {
		$Scratch->{mv_data_enable} .= " " . join(" ", @ext_enable) . " ";
	}

	###
	### Here the user can include some extra stuff in the form....
	###
	$out .= <<EOF if $opt->{include_form};
<tr class=rnorm>
<td colspan=$span>$opt->{include_form}</td>
</tr>
EOF
	### END USER INCLUDE

	unless ($opt->{mailto} and $opt->{mv_blob_only}) {
		@cols = grep ! $display_only{$_}, @cols;
	}
	$passed_fields = join " ", @cols;

	$out .= <<EOF;
<INPUT TYPE=hidden NAME=mv_data_fields VALUE="$passed_fields">
<tr class=rspacer>
<td colspan=$span ><img src="$opt->{clear_image}" height=3 alt=x></td>
</tr>
EOF

  SAVEWIDGETS: {
  	last SAVEWIDGETS if $opt->{nosave}; 
	  	if($opt->{back_text}) {
		  $out .= <<EOF;
<TR class=rnorm>
<td>&nbsp;</td>
<td align=left colspan=$oddspan class=cdata>
<INPUT TYPE=submit NAME=mv_click VALUE="$opt->{back_text}">&nbsp;<INPUT TYPE=submit NAME=mv_click VALUE="Cancel">&nbsp;<B><INPUT TYPE=submit NAME=mv_click VALUE="$opt->{next_text}"></B>
EOF
		}
		elsif($opt->{wizard}) {
		  $out .= <<EOF;
<TR class=rnorm>
<td>&nbsp;</td>
<td align=left colspan=$oddspan class=cdata>
<INPUT TYPE=submit NAME=mv_click VALUE="Cancel">&nbsp;<B><INPUT TYPE=submit NAME=mv_click VALUE="$opt->{next_text}"></B>
EOF
		}
		else {
		  $out .= <<EOF;
<TR class=rnorm>
<td>&nbsp;</td>
<td align=left colspan=$oddspan class=cdata>
<B><INPUT TYPE=submit NAME=mv_click VALUE="$opt->{next_text}"></B>&nbsp;<INPUT TYPE=submit NAME=mv_click VALUE="Cancel">
EOF
		}
#
#	$out .= <<EOF;
#
#<TR class=rnorm>
#<td>&nbsp;</td>
#<td align=left colspan=$oddspan>
#<B><INPUT TYPE=submit NAME=mv_click VALUE="$opt->{next_text}"></B>
#&nbsp;
#&nbsp;
#<INPUT TYPE=submit NAME=mv_click VALUE=Cancel>
#EOF
	if($Tag->if_mm('tables', "$table=x") and ! $db->config('LARGE') ) {
		my $checked = ' CHECKED';
		$checked = ''
			if defined $opt->{mv_auto_export} and ! $opt->{mv_auto_export};
		$out .= <<EOF unless $opt->{noexport} or $opt->{nosave};
<small>
&nbsp;
&nbsp;
&nbsp;
&nbsp;
&nbsp;
	<INPUT TYPE=checkbox NAME=mv_auto_export VALUE="$table"$checked>&nbsp;Auto-export
EOF

	}

	if($exists and ! $opt->{nodelete} and $Tag->if_mm('tables', "$table=d")) {
		my $extra = $Tag->return_to( { type => 'click', tablehack => 1 });
		my $page = $CGI->{ui_return_to};
		$page =~ s/\0.*//s;
		my $url = $Tag->area( {
					href => $page,
					form => qq!
						deleterecords=1
						ui_delete_id=$key
						mv_data_table=$table
						mv_click=db_maintenance
						mv_action=back
						$extra
					!,
					});
		$out .= <<EOF if ! $opt->{nosave};
<BR><BR><A
onClick="return confirm('Are you sure you want to delete $key?')"
HREF="$url"><IMG SRC="delete.gif" ALT="Delete $key" BORDER=0></A> Delete
EOF
	}
	$out .= <<EOF;
</small>
</td>
</tr>
EOF
  } # end SAVEWIDGETS

	my $message = '';

#	if($opt->{bottom_errors}) {
#		my $err = $Tag->error( {
#									show_var => $error_show_var,
#									show_error => 1,
#									joiner => '<BR>',
#								}
#								);
#		push @errors, $err if $err;
#	}

	if(@errors) {
		$message .= '<P>Errors:';
		$message .= qq{<FONT COLOR="$opt->{color_fail}">};
		$message .= '<BLOCKQUOTE>';
		$message .= join "<BR>", @errors;
		$message .= '</BLOCKQUOTE></FONT>';
	}
	if(@messages) {
		$message .= '<P>Messages:';
		$message .= qq{<FONT COLOR="$opt->{color_success}">};
		$message .= '<BLOCKQUOTE>';
		$message .= join "<BR>", @messages;
		$message .= '</BLOCKQUOTE></FONT>';
	}
	$Tag->error( { all => 1 } );

	$out .= <<EOF unless $opt->{no_bottom} and ! $message;
<tr class=rtitle>
<td colspan=$span><!-- $Scratch->{$opt->{next_text}} -->$message<img src="$opt->{clear_image}" height=3 alt=x></td>
</tr>
EOF
	$out .= <<EOF;
</table>
</td></tr></table>

</form>
[/restrict]
EOF

}
EOR
