UserTag page-meta Order page
UserTag page-meta addAttr
UserTag page-meta Routine <<EOR
sub {
	my ($page, $opt) = @_;
	$page ||= $Global::Variable->{MV_PAGE};
	$page = "pages/$page";
	my $meta = Vend::Table::Editor::meta_record($page)
		or return;
	while (my ($k, $v) = each %$meta) {
		next if $k eq 'code';
		next unless length $v;
		if($v =~ /\[\w/ or $v =~ /__[A-Z]\w+__/) {
			$v = interpolate_html($v);
		}
		set_tmp($k,$v);
	}
	return;
}
EOR
