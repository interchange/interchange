UserTag capture_page Order page file
UserTag capture_page addAttr
UserTag capture_page Routine <<EOR
sub {
	my ($page, $file, $opt) = @_;

	# check if we are allowed to write the file
	unless (Vend::File::allowed_file($file, 1)) {
		Vend::File::log_file_violation($file, 'capture_page');
		return 0;
	}

	if ($opt->{scan}) {
		Vend::Page::do_scan($opt->{scan});
	}

	my $pageref = Vend::Page::display_page($page,{return => 1});

	return Vend::File::writefile (">$file", $pageref, 
        {auto_create_dir => $opt->{auto_create_dir},
		umask => $opt->{umask}});
}
EOR
