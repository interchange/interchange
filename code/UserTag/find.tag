UserTag find addAttr
UserTag find PosNumber 0
UserTag find hasEndTag
UserTag find Routine <<EOR

my %typemap = (b => '-b _', c => '-c _', d => '-d _', dir => '-d _',
	p => '-p _', pipe => '-p _',	
	f => '-f _', file => '-f _', 
	l => '-l _', symlink => '-l _', 
	s => '-S _', S => '-S _', socket => '-S _');
					
sub {
	my ($opt, $list) = @_;
	my (@paths, @stack, @files, $file, $entry, @statinfo, $nmatch);

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
	
	if ($opt->{name}) {
		$nmatch = $opt->{name};
		$nmatch =~ s/\./\\./g;
		$nmatch =~ s/\*/.*/g;
		$nmatch =~ s/\?/./g;		
		$nmatch =~
			s[({(?:.+?,)+.+?})]
			 [ local $_ = $1; tr/{,}/(|)/; $_ ]eg;
		$nmatch =~ s/\s+/|/g;
		$nmatch = qr($nmatch);
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
		} elsif (! -e $file) {
			::logError("No such file or directory: %s", $file);
			next;
		}

		if ($opt->{type}) {
			# make stat call ahead so info is accessible via _ filehandle
			unless (@statinfo = stat($file)) {
				::logError("Stat call failed on file %s: %s", $file, $!);
				next;
			}
		}	

		# match file against our specifications
		if ($nmatch) {
			next unless $file =~ /$nmatch/;
		}

		if ($opt->{type}) {
			next unless eval "$typemap{$opt->{type}}";
		}

		push (@files, $file);
	}

	wantarray ? @files : join(' ', @files);
}
EOR
UserTag find Documentation <<EOD

=pod

This tag produces a list of files which match the given criteria.

	[find name="*.html"]pages[/find]

Parameters for this tag are:

=over 4

=item name I<PATTERN>

Excludes any files not matching I<PATTERN>.

=item type I<TYPE>

Excludes any files not of type I<TYPE>.

=back

=cut
EOD
