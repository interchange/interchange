UserTag grep-mm Order function
UserTag grep-mm addAttr
UserTag grep-mm Interpolate
UserTag grep-mm hasEndTag
UserTag grep-mm Routine <<EOR
sub {
	my($func, $opt, $text) = @_;
#::logDebug("grep-mm record: " . Vend::Util::uneval_it(\@_));
	my $table = $opt->{table} || $::Values->{mv_data_table};
	my $acl = UI::Primitive::get_ui_table_acl($table);
	return $text unless $acl;
	my @items = grep /\S/, Text::ParseWords::shellwords($text);
	return join "\n", UI::Primitive::ui_acl_grep($acl, $func, @items);
}
EOR

