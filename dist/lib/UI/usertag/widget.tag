UserTag widget Order name
UserTag widget PosNumber 1
UserTag widget attrAlias table db
UserTag widget attrAlias field column
UserTag widget attrAlias outboard key
UserTag widget addAttr
UserTag widget HasEndTag 1
UserTag widget Interpolate 1
UserTag widget Routine <<EOR
sub {
	my($name, $opt, $string) = @_;
	#my($name, $type, $value, $table, $column, $key, $data, $string) = @_;
	my $value;
	
	if(defined $opt->{set}) {
		$value = $opt->{set};
	}
	else {
		$value = $::Values->{$name} || $opt->{default};
	}
	if($opt->{pre_filter}) {
#::logDebug("pre-filter with $opt->{pre_filter}");
		$value = $Tag->filter($opt->{pre_filter}, $value);
	}
	my $ref = {
				attribute	=> $opt->{attribute} || 'attribute',
				db			=> $opt->{table} || undef,
				field		=> $opt->{field} || undef,
				extra		=> $opt->{extra} || $opt->{js} || undef,
				cols		=> $opt->{cols} || undef,
				rows		=> $opt->{rows} || undef,
				name		=> $name,
				outboard	=> $opt->{key} || undef,
				passed		=> $opt->{data} || $opt->{passed} || $string,
				type		=> $opt->{type} || 'select',
				};
	my $item = { $ref->{attribute} => $value };
	if($ref->{type} =~ /date/i) {
		return UI::Primitive::date_widget($name, $value);
	}

	my $w = Vend::Interpolate::tag_accessories('', '', $ref, $item);
	if($opt->{filter}) {
		$w .= qq{<INPUT TYPE=hidden NAME="ui_filter:$name" VALUE="};
		$w .= $opt->{filter};
		$w .= '">';
	}
	return $w;
}
EOR
