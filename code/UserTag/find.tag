UserTag find Order type
UserTag find addAttr
UserTag find hasEndTag
UserTag find Routine <<EOR
sub {
	my ($type, $opt, $list) = @_;
	my (@paths, @stack, @files, $file, $entry);

	# take array reference or string as list for the paths to scour for files
	if (ref($list)) {
		@paths = @$list;
	} else {
		@paths = split(/[\s,\0]+/, $list);
	}

	if ($Global::NoAbsolute) {
		# all paths need to be relative to the catalog directory
		for $file (@paths) {
			if (Vend::Util::file_name_is_absolute($file)
				or $file =~ m#\.\./.*\.\.#) {
					::logError("Can't read file '%s' with NoAbsolute set" , $file);
					::logGlobal({ level => 'auth'}, "Can't read file '%s' with NoAbsolute set" , $file );
			} else {
				push (@stack, $file);
			}
		}
	} else {
		@stack = @paths;
	}

	# now build a list of all files matching the given criteria
	while (@stack) {
		$file = shift @stack;
		if (-d $file) {
			unless (opendir(DIR, $file)) {
				::logError("Couldn't open directory %s: %s", $file, $!);
				next;
			}
			while ($entry = readdir(DIR)) {
				next if $entry =~ /^\.\.?$/;
				push (@stack, "$file/$entry");
			}
			closedir(DIR);
			push (@files, $file);
		} elsif (-e $file) {
			push (@files, $file);
		} else {
			::logError("No such file or directory: %s", $file);
		}
	}

	wantarray ? @files : join(' ', @files);
}
EOR
