UserTag file-navigator Order mask
UserTag file-navigator addAttr
UserTag file-navigator Routine <<EOR
use vars qw/$CGI $Session $Tag $Scratch/;
eval {
        require Fcntl;
        import Fcntl qw/:mode/;
};
if ($@) {
        sub S_ISUID  { return 2048 }
        sub S_ISGID {return 1024}
        sub S_ISVTX {return 512}
}
sub {
	my ($dir_mask, $opt) = @_;


#::logDebug("file-nav dir_mask: $dir_mask opt: " . ::uneval($opt));
    $dir_mask = '*';

	my $base_admin = ( $::Variable->{UI_BASE} || 'admin');
	my $base_url = $Vend::Cfg->{VendURL}
				. '/'
				. $base_admin;
	my $full_path;
	my $action = $CGI::values{action} || '';
	my $already_found;

	my $edit_page = $opt->{edit_page} || 'page_edit';
	my $edit_var = $opt->{edit_var} || 'ui_page';
	
	my @errors;
	my @messages;

	$Vend::Session->{ui_cwd} = $opt->{initial_dir}
		if $opt->{initial_dir};

	if($action eq 'chdir') {
		my $newdir = $CGI::values{dir} || '.';
		if(
			Vend::Util::file_name_is_absolute($newdir)
				or
			$newdir =~ m{^\.\.|\.\./}
			)
		{
			$Scratch->{ui_error} = ::errmsg('Security violation');
			return interpolate_html("[bounce page='$base_admin/error']");
		}
		if(! -d $newdir) {
			$Scratch->{ui_error} = ::errmsg("%s not a directory", $newdir);
			return interpolate_html("[bounce page='$base_admin/error']");
		}
		$Vend::Session->{ui_cwd} = $newdir || '.';
	}

	my $curdir = $Vend::Session->{ui_cwd} || '.';
	$curdir =~ s:/+$::;
	my @files;

	FINDNAV: {
		if($action eq 'find') {
			my $regex;
			my $string = $CGI::values{find};
			if($string !~ /\S/) {
				push @errors, ::errmsg("Refuse to find a blank or whitespace.");
				last FINDNAV;
			}
			elsif( $string =~ /\(\s*\?\s*\{/) {
				$Scratch->{ui_error} = ::errmsg('Security violation');
				return interpolate_html("[bounce page='$base_admin/error']");
			}
			else {
				eval {
					if($string =~ /\*/ and $string !~ /\.\*/) {
						$regex =~ s/\*/.*/g;
					}
					$regex = qr{$string};
				};
			}

			if($@ or ! $regex) {
				push @errors, ::errmsg("%s is not a good search.", $regex);
				last FINDNAV;
			}

			$full_path = 1;
			require File::Find;
			my $wanted;

			local($SIG{__WARN__}) = sub { push @errors, $_ };

			my %exclude;
			if($CGI::values{find_action} =~ /\bfilename\b/) {
				$wanted = sub {
					push @files, $File::Find::name
						if $_ =~ $regex;
				};
			}
			else {
				if($curdir eq '.' and ! $CGI::values{find_session}) {
					%exclude = (qw! ./session 1 session 1 tmp 1 ./tmp 1!);
				}
				$wanted = sub {
					local ($/) = undef;
					if( -d $_ and $exclude{$File::Find::dir}) {
						$File::Find::prune = 1;
						return;
					}
					return unless -f _;
					-s _ > 1_000_000
						and do {
							push(@errors,
								errmsg("%s: refuse to find in megabyte-sized files",
										$File::Find::name)
								);
							return;
						};
					open(TMPFINDNAV, "< $_")
						or do {
							push(@errors,
								errmsg("%s: permission denied", $File::Find::name)
								);
							return;
						};
					my $str = <TMPFINDNAV>;
					$str =~ $regex
						and push (@files, $File::Find::name);
					return;
				};
			}
			File::Find::find($wanted, $curdir);

			 s:^./:: for @files;

			if(@files) {
				push @messages, errmsg("Found %s files.", scalar @files);
				$already_found = 1;
			}
			else {
				undef $full_path;
				push @errors, errmsg("No files found.");
			}
		}
	}

	if($already_found) {
		# do nothing
	}
	elsif($curdir eq '.') {
		if($dir_mask eq '*') {
			@files = grep $_ ne 'CVS', glob('*');
		}
		else {
			@files = split /\s+/, $dir_mask;
		}
	}
	else {
		@files = grep $_ !~ m{/CVS$}, glob("$curdir/*");
	}

	my $this_page = $Global::Variable->{MV_PAGE};
	my $this = Vend::Interpolate::tag_area($this_page);
	$this =~ s/\?(.*)//;

	my $imgpath = $::Variable->{UI_IMG} || $Global::Variable->{UI_IMG} || '';
	$imgpath .= "admin";

	my $up_img = qq{<img src="$imgpath/up.gif" align=center border=0 height=22 width=20 title="upload ~FN~">};
	my $dn_img = qq{<img src="$imgpath/down.gif" align=center border=0 height=22 width=20 title="download ~FN~">};
	my $vw_img = qq{<img src="$imgpath/index.gif" align=center border=0 height=22 width=20 title="view ~FN~">};
	my $ed_img = qq{<img src="$imgpath/layout.gif" align=center border=0 height=22 width=20 title="edit ~FN~">};
	my $dir_img = qq{<img src="$imgpath/folder.gif" align=center border=0 height=22 width=20 title="change directory to ~FN~">};
	my $del_img = qq{<img src="$imgpath/delete.gif" align=center border=0 height=20 width=20 title="DELETE ~FN~">};
	my $sp_img = qq{<img src="$imgpath/bg.gif" align=center border=0 height=20 width=20>};

	if(defined $CGI->{details}) {
		$Session->{ui_file_details} = $CGI->{details};
	}
	my $do_perms = $Session->{ui_file_details};

	my $del_string = '';
	$Tag->if_mm('advanced', 'delete_files')
		and do {
			$del_string = qq{<A onClick="return confirm('Are you sure you want to delete the file ~FN~?')" HREF="$Vend::Cfg->{VendURL}/$this_page?mv_click=file_maintenance&ui_delete_file=~FN~&mv_action=back">$del_img</A>};
		};

	my $ftmpl = <<EOF;
<A HREF="$Vend::Cfg->{VendURL}/ui_download/~FN~">$dn_img</A>$del_string<A HREF="$base_url/upload_file?mv_arg=~FN~&ui_return_to=$this_page">$up_img</A><A HREF="$base_url/do_view?mv_arg=~FN~">$vw_img</A>&nbsp;%s&nbsp;<A HREF="$base_url/do_view?mv_arg=~FN~">%s</A><BR>
EOF

	my $utmpl = <<EOF;
<A HREF="$base_url/upload_file?mv_arg=~FN~&ui_return_to=$this_page">$up_img</A>&nbsp;%s&nbsp;<A HREF="$base_url/upload_file?mv_arg=~FN~&ui_return_to=$this_page">%s</A><BR>
EOF

	my $ftmpl_ed;
	if(! $do_perms and $opt->{edit_only}) {
		$ftmpl_ed = <<EOF;
<A HREF="$base_url/$edit_page?$edit_var=~FN~&ui_return_to=$this_page">$ed_img</A>&nbsp;%s&nbsp;<A HREF="$base_url/$edit_page?$edit_var=~FN~&ui_return_to=$this_page">%s</A><BR>
EOF
	}
	else {
		$ftmpl_ed = <<EOF;
<A HREF="$Vend::Cfg->{VendURL}/ui_download/~FN~">$dn_img</A>$del_string<A HREF="$base_url/upload_file?mv_arg=~FN~&ui_return_to=$this_page">$up_img</A><A HREF="$base_url/$edit_page?$edit_var=~FN~&ui_return_to=$this_page">$ed_img</A>&nbsp;%s&nbsp;<A HREF="$base_url/$edit_page?$edit_var=~FN~&ui_return_to=$this_page">%s</A><BR>
EOF
	}

	my $dtmpl = <<EOF;
<A HREF="$Vend::Cfg->{VendURL}/$this_page?action=chdir&dir=~FN~">$dir_img</A>&nbsp;%s&nbsp;<A HREF="$Vend::Cfg->{VendURL}/$this_page?action=chdir&dir=~FN~">%s</A><BR>
EOF

	$dtmpl = "$sp_img$sp_img$sp_img$dtmpl" if $do_perms;

	my @out;
	my $out;
	
	my @dir;
	my @plain;


	sub perm_line {
		my $fn = shift;

		my @perm = qw/
			---
			--x
			-w-
			-wx
			r--
			r-x
			rw-
			rwx
		/;

		my @det;
		if (-l $fn) {
			@det = lstat($fn);
		}
		else {
			@det = stat(_);
		}
		my $time = POSIX::strftime("%d-%b-%Y %H:%M:%S", localtime($det[9]));
		my $permstring = sprintf('%04o', $det[2]);
		#push @messages, "$_ perms=$permstring\n";
		$permstring = substr($permstring, -3, 3);
		my $top;
		my (@ugo) = split //, $permstring;
		@ugo = map { $_ = $perm[$_] } @ugo;
		if    (-l _) { $top = 'l' }
		elsif (-d _) { $top = 'd' }
		elsif (-f _) { $top = '-' }
		else         { $top = '?' }
		$ugo[0] =~ s/.$/s/ if $det[2] & S_ISUID;
		$ugo[1] =~ s/.$/s/ if $det[2] & S_ISGID;
		$ugo[2] =~ s/.$/t/ if $det[2] & S_ISVTX;
		my $user = getpwuid($det[4]);
		my $grp  = getgrgid($det[5]);
		$grp = substr($grp, 0, 8) if length($grp) > 8;
		$user = substr($grp, 0, 8) if length($user) > 8;
		my $perm = join "", $top, @ugo;
		my $ret = sprintf(" <TT><SMALL>%s %-8s %-8s %s</SMALL></TT>", $perm, $user, $grp, $time);
		$ret =~ s/ /&nbsp;/g;
		return $ret;
	}

	my $perms = '';
	for(@files) {
		my $fn = $_;
		$fn =~ s:.*/::
			unless $full_path;
		my $fe = $_;
		$fe =~ s!([^-\w./:,])!sprintf('%%%02x', ord($1) )!eg;
		my $perms;
		$perms = perm_line($_) if($do_perms);
		
		if(-d $_) {
			push @dir, [$fe, $fn, $dtmpl, $perms];
		}
		elsif ($opt->{edit_all} || /\.html?$/) {
			push @plain, [$fe, $fn, $ftmpl_ed, $perms];
		}
		else {
			push @plain, [$fe, $fn, $ftmpl, $perms];
		}
	}

	my $nd = $curdir;
	if($nd ne '.') {
		$nd =~ s:/[^/]*$::
		  or $nd = '.';
		my $msg = $nd eq '.'
				? "<large><b>..</b></large>"
				: "<large><b>..</b></large>";
		unshift @dir, [ $nd, $msg, $dtmpl ];
	}

	unshift @dir, [ "$curdir/", '(new file)', $utmpl ];

	@dir = () if $opt->{no_dirs};

	for(@errors) {
		$out .= "<span class=cerror>$_</span><br>";
	}
	for(@messages) {
		$out .= "<span class=cmessage>$_</span><br>";
	}
	for (@dir, @plain) {
		$_->[2] = sprintf($_->[2], $_->[3], $_->[1]);
		$_->[2] =~ s/~FN~/$_->[0]/g;
		$out .= $_->[2];
	}

	return $out;
}
EOR
