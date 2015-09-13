UserTag bootmenu Order        name
UserTag bootmenu hasEndTag
UserTag bootmenu AddAttr
UserTag bootmenu Description  Display menu using jQuery and standard HTML + CSS.
UserTag bootmenu Documentation <<EOD

Returns a menu using an unordered list with associated Bootstrap-recognizable classes (<ul><li>foo</li></ul>). No Javascript is needed for basic functionality.

Call with something like:
	[timed-build file="timed/bootmenu" login=1 force=1 minutes=1440][bootmenu name="catalog/menu" timed=1][/bootmenu][/timed-build]
(bootmenu's "name" opt requires a DB menu)
or for simple menu:
	[bootmenu file="includes/menus/catalog/menu.txt"][/bootmenu]

You can also put a template inside, and also use "transforms" like "logged_in", e.g.:
	[bootmenu file="include/menus/catalog/top.txt" class="nav nav-pills pull-right" logged_in=member]
		<li class="{HELP_NAME}"><a{PAGE?} href="{PAGE}"{/PAGE?} title="{DESCRIPTION}">{NAME}</a>
	[/bootmenu]

To be used with Bootstrap and the Javascript plugin for dropdown menus. See http://getbootstrap.com for more.

EOD
UserTag bootmenu Routine      <<EOR

my $indicated;
my $last_line;
my $first_line;
my $logical_field;

my %transform = (
	nbsp => sub {
		my ($row, $fields) = @_;
		return 1 if ref($fields) ne 'ARRAY';
		for(@$fields) {
			$row->{$_} =~ s/ /&nbsp;/g;
		}
		return 1;
	},
	entities => sub {
		my ($row, $fields) = @_;
		return 1 if ref($fields) ne 'ARRAY';
		for(@$fields) {
			$row->{$_} = HTML::Entities::encode_entities($row->{$_});
		}
		return 1;
	},
	localize => sub {
		my ($row, $fields) = @_;
		return 1 if ref($fields) ne 'ARRAY';
		for(@$fields) {
			$row->{$_} = errmsg($row->{$_});
		}
		return 1;
	},
	first_line => sub {
		my ($row, $fields) = @_;
		return undef if ref($fields) ne 'ARRAY';
		return 1 if $first_line;
		my $status;
		for(@$fields) {
			if(s/^!\s*//) {
				$status = $status && ! $row->{$_};
			}
			else {
				$status = $status && $row->{$_};
			}
		}
		return $first_line = $status;
	},
	last_line => sub {
		my ($row, $fields) = @_;
#::logDebug("last_line transform, last_line=$last_line");
		return 1 if ref($fields) ne 'ARRAY';
		return 0 if $last_line;
		my $status;
		for(@$fields) {
#::logDebug("last_line transform checking field $_=$row->{$_}");
			if(s/^!\s*//) {
				$status = ! $row->{$_};
			}
			else {
				$status = $row->{$_};
			}
#::logDebug("last_line transform checked field $_=$row->{$_}, status=$status");
			last if $status;
		}
#::logDebug("last_line transform returning last_line=$status");
		$last_line = $status;
#::logDebug("last_line transform returning status=" . ! $status);
		return ! $status;
	},
	first_line => sub {
		my ($row, $fields) = @_;
		return 1 if ref($fields) ne 'ARRAY';
		my $status = 1;
		for(@$fields) {
			if(s/^!\s*//) {
				$status = $status && ! $row->{$_};
			}
			else {
				$status = $status && $row->{$_};
			}
		}
		return $status;
	},
	inactive => sub {
		my ($row, $fields) = @_;
		return 1 if ref($fields) ne 'ARRAY';
		my $status = 1;
		for(@$fields) {
			if(s/^!\s*//) {
				$status = $status && $row->{$_};
			}
			else {
				$status = $status && ! $row->{$_};
			}
		}
		return $status;
	},
	active => sub {
		my ($row, $fields) = @_;
		return 1 if ref($fields) ne 'ARRAY';
		my $status = 1;
		for(@$fields) {
			if(s/^!\s*//) {
				$status = $status && ! $row->{$_};
			}
			else {
				$status = $status && $row->{$_};
			}
		}
		return $status;
	},
	ui_security => sub {
		my ($row, $fields) = @_;
		return 1 if ref($fields) ne 'ARRAY';
		my $status = 1;
		for(@$fields) {
			next if ! length($row->{$_});
			$status = $status && Vend::Tags->if_mm('advanced', $row->{$_});
		}
		return $status;
	},
	full_interpolate => sub {
		my ($row, $fields) = @_;
		return 1 if ref($fields) ne 'ARRAY';
		for(@$fields) {
			next unless $row->{$_} =~ /\[|__[A-Z]\w+__/;
			$row->{$_} = Vend::Interpolate::interpolate_html($row->{$_});
		}
		return 1;
	},
	page_class => sub {
		my ($row, $fields) = @_;
		return 1 unless $row->{indicated};
		return 1 if $row->{mv_level};
		return 1 if ref($fields) ne 'ARRAY';
		my $status = 1;
		for(@$fields) {
			my($f, $c) = split /[=~]+/, $_;
			$c ||= $f;
#::logDebug("setting scratch $f to row=$c=$row->{$c}");
			$::Scratch->{$f} = $row->{$c};
		}
		$$indicated = 0;
		return 1;
	},
	menu_group => sub {
		my ($row, $fields) = @_;
		return 1 if ref($fields) ne 'ARRAY';
		my $status = 1;
		eval {
			for(@$fields) {
				my($f, $c) = split /[=~]+/, $_;
				$c ||= $f;
				$status = $status && (
								!  $row->{$f}
								or $CGI::values{$c} =~ /$row->{$f}/i
								);
			}
		};
		return $status;
	},
	superuser => sub {
		my ($row, $fields) = @_;
		return 1 if ref($fields) ne 'ARRAY';
		my $status = 1;
		for(@$fields) {
			$status = $status && (! $row->{$_} or Vend::Tags->if_mm('super'));
		}
		return $status;
	},
	items	=> sub {
		my ($row, $fields) = @_;
		return 1 if ref($fields) ne 'ARRAY';
		my $status = 1;
		my $nitems = scalar(@{$Vend::Items}) ? 1 : 0;
		for(@$fields) {
			next if ! length($row->{$_});
			$status = $status && (! $nitems ^ $row->{$_});
		}
		return $status;
	},
	logged_in => sub {
		my ($row, $fields) = @_;
#::logDebug("logged_in... doing:$_, fields=" . ref($fields) . ', ' . uneval($fields));
		return 1 if ref($fields) ne 'ARRAY';
		my $status = 1;
		for(@$fields) {
			next if ! length($row->{$_});
			$status = $status && (! $::Vend::Session->{logged_in} ^ $row->{$_});
		}
#::logDebug("logged_in... got here. doing:$_, status=$status, row=$row->{$_}");
		return $status;
	},
	depends_on => sub {
		my ($row, $fields) = @_;
		return 1 if ref($fields) ne 'ARRAY';
		my $status = 1;
		for(@$fields) {
			next if ! $row->{$_};
			$status = $status && $CGI::values{$row->{$_}};
		}
		return $status;
	},
	exclude_on => sub {
		my ($row, $fields) = @_;
		return 1 if ref($fields) ne 'ARRAY';
		my $status = 1;
		for(@$fields) {
			$status = $status && (! $CGI::values{$row->{$_}});
		}
		return $status;
	},
	indicator_class => sub {
		my ($row, $fields) = @_;
		return 1 if ref($fields) ne 'ARRAY';
		for(@$fields) {
			my ($indicator,$rev, $last, $status);
			my($s,$r) = split /=/, $_;
			$rev = $indicator =~ s/^\s*!\s*// ? 1 : 0;
			$last = $indicator =~ s/\s*!\s*$// ? 1 : 0;
#::logDebug("checking scratch $s=$::Scratch->{$s} eq row=$r=$row->{$r}");
			$status = $::Scratch->{$s} eq $row->{$r};
			if($rev xor $status) {
				$row->{indicated} = 1;
			}
			last if $last;
		}
		if($row->{indicated}) {
			$indicated = \$row->{indicated};
		}
		return 1;
	},
	indicator_profile => sub {
		my ($row, $fields) = @_;
		return 1 if ref($fields) ne 'ARRAY';
		for(@$fields) {
			my ($indicator,$rev, $last, $status);
			next unless $indicator = $row->{$_};
			$rev = $indicator =~ s/^\s*!\s*// ? 1 : 0;
			$last = $indicator =~ s/\s*!\s*$// ? 1 : 0;
			$status = Vend::Tags->run_profile($indicator);
			if($rev xor $status) {
				$row->{indicated} = 1;
				next unless $last;
			}
			last if $last;
		}
		return 1;
	},
	indicator_page => sub {
		my ($row, $fields) = @_;
		return 1 if ref($fields) ne 'ARRAY';
		for(@$fields) {
			if ($::Scratch->{mv_logical_page} eq $row->{$_}) {
				unless(
						$::Scratch->{mv_logical_page_used}
						and $::Scratch->{mv_logical_page_used}
							  ne
							$row->{$logical_field}
						)
				{
					$row->{indicated} = 1;
					$::Scratch->{mv_logical_page_used} = $row->{$logical_field};
					last;
				}
			}
			($row->{indicated} = 1, last)
				if  $Global::Variable->{MV_PAGE} eq $row->{$_}
				and ! defined $row->{indicated};
		}
		return 1;
	},
	indicator => sub {
		my ($row, $fields) = @_;
		return 1 if ref($fields) ne 'ARRAY';
		for(@$fields) {
			my ($indicator,$rev, $last, $status);
			next unless $indicator = $row->{$_};
			$rev = $indicator =~ s/^\s*!\s*// ? 1 : 0;
			$last = $indicator =~ s/\s*!\s*$// ? 1 : 0;
			if($indicator =~ /^\s*([-\w.:][-\w.:]+)\s*$/) {
				$status =  $CGI::values{$1};
			}
			elsif ($indicator =~ /^\s*`(.*)`\s*$/s) {
				$status = Vend::Interpolate::tag_calc($1);
			}
			elsif ($indicator =~ /\[/s) {
				$status = Vend::Interpolate::interpolate_html($indicator);
				$status =~ s/\s+//g;
			}
			if($rev xor $status) {
				$row->{indicated} = 1;
			}
			else {
				$row->{indicated} = '';
			}
			last if $last;
		}
		return 1;
	},
	expand_values_form => sub {
		my ($row, $fields) = @_;
		return 1 if ref($fields) ne 'ARRAY';
		for(@$fields) {
			next unless $row->{$_} =~ /\%5b|\[/i;
			my @parms = split $Global::UrlSplittor, $row->{$_};
			my @out;
			for my $p (@parms) {
				my ($parm, $val) = split /=/, $p, 2;
				$val = unhexify($val);
				$val =~ s/\[cgi\s+([^\[]+)\]/$CGI::values{$1}/g;
				$val =~ s/\[var\s+([^\[]+)\]/$::Variable->{$1}/g;
				$val =~ s/\[value\s+([^\[]+)\]/$::Values->{$1}/g;
				push @out, join('=', $parm, hexify($val));
			}
			$row->{$_} = join $Global::UrlJoiner, @out;
		}
		return 1;
	},
	expand_values => sub {
		my ($row, $fields) = @_;
		return 1 if ref($fields) ne 'ARRAY';
		for(@$fields) {
			next unless $row->{$_} =~ /\[/;
			$row->{$_} =~ s/\[cgi\s+([^\[]+)\]/$CGI::values{$1}/g;
			$row->{$_} =~ s/\[var\s+([^\[]+)\]/$::Variable->{$1}/g;
			$row->{$_} =~ s/\[value\s+([^\[]+)\]/$::Values->{$1}/g;
		}
		return 1;
	},
);

sub reset_transforms {
#::logDebug("resetting transforms");
	my $opt = shift;
	if($opt) {
		$logical_field = $opt->{logical_page_field} || 'name';
	}
	undef $last_line;
	undef $first_line;
	undef $indicated;
}

sub {
	my($name, $opt, $template) = @_;

	reset_transforms($opt);
	
	my @transform;
	my @ordered_transform = qw/full_interpolate indicator_page page_class indicator_class localize entities nbsp/;
	my %ordered;
	@ordered{@ordered_transform} = @ordered_transform;

	for(keys %transform) {
		next if $ordered{$_};
		next unless $opt->{$_};
		my @fields = grep /\S/, split /[\s,\0]+/, $opt->{$_};
		$opt->{$_} = \@fields;
#::logDebug("opt $_ = " . uneval(\@fields));
		push @transform, $_;
	}
	for(@ordered_transform) {
		next unless $opt->{$_};
		my @fields = grep /\S/, split /[\s,\0]+/, $opt->{$_};
		$opt->{$_} = \@fields;
		push @transform, $_;
	}
	$opt->{_transform} = \@transform;
#::logDebug("in menu sub main");

	my @out;

	$template = <<EOF if $template !~ /\S/;
		{INDICATOR?}<li class="{INDICATOR}">{/INDICATOR?}
		{INDICATOR:}<li class="{BOOT_LI}">
			<a{PAGE?} href="{PAGE}"{/PAGE?} title="{DESCRIPTION}" class="{LINK_CLASS}" {BOOT_CONTENT}>{ICON?}{ICON} {/ICON?}{NAME}{CARET?} {CARET}{/CARET?}</a>
		{/INDICATOR:}
EOF

	my $top_timeout = $opt->{timeout} || 1000;

	my %o = (
			start       => $opt->{tree_selector} || $opt->{name},
			file		=> $opt->{file},
			table       => $opt->{table} || $::Variable->{MV_TREE_TABLE} || 'tree',
			master      => 'parent_fld',
			subordinate => 'code',
			autodetect  => '1',
			sort        => $opt->{sort} || 'code',
			full        => '1',
			timed		=> $opt->{timed},
			spacing     => '4',
			_transform   => $opt->{_transform},
		);

	for(@{$opt->{_transform} || []}) {
		$o{$_} = $opt->{$_};
	}

	my $main;
	my $rows;
	if($opt->{iterator}) {
		$o{iterator} = $opt->{iterator};
		$main =  Vend::Tags->tree(\%o);
		$rows = $o{object}{mv_results};
	}
	else {
		Vend::Tags->tree(\%o);
#::logDebug("bootmenu: " . uneval({ ref => \%o }) );
		my @o;
		for(@{$o{object}{mv_results}}) {
			next if $_->{deleted};

			for my $tr (@{$o{_transform}}) {
#::logDebug("running transform: $tr, on: " . uneval($_) . ", " . uneval($opt->{$tr}));
				my $status = $transform{$tr}->($_, $opt->{$tr});
#::logDebug("transform... status=$status, did: $tr, result: " . uneval($_));
				$opt->{next_level} = $_->{mv_level}
					if ! $status;
				$_->{deleted} = 1 unless $status;
			}

			if($_->{page} and $_->{page} !~ m{^(\w+:)?/}) {
				my $form = $_->{form};
				if($form and $form !~ /[\r\n]/) {
					$form = join "\n", split $Global::UrlSplittor, $form;
				}

				$_->{page} = "" if $_->{page} eq 'index';

				my $add = ($::Scratch->{mv_add_dot_html} && $_->{page} !~ /\.\w+$/) || 0;

				$_->{page} = Vend::Tags->area({
										href => $_->{page},
										form => $form,
										no_count => $o{timed},
										add_dot_html => $add,
										no_session_id => $o{timed},
										auto_format => 1,
									}) unless $_->{page} =~ /^#/;

			}
			
			push @o, $_ unless $_->{deleted};
		}
		$rows = \@o;
	}

	$rows->[-1]{mv_last_row} = 1 if @$rows;

#::logDebug("rows = " . ::uneval({ ref => $rows }) );

	$name =~ s|/|_|g;
	$opt->{ul_id} ||= $name;
	$opt->{class} ||= 'nav navbar-nav';

	my $id = $opt->{ul_id} ? q{ id="$opt->{ui_id}"} : '';
	my $style = $opt->{style} ? q{ style="$opt->{style}"} : '';

	push @out, <<EOF;
<ul$id class="$opt->{class}"$style $opt->{extra}>
EOF

#return Vend::Tags->uneval({ ref => $rows });

## Dropdown classes

	my $boot_content = qq| data-toggle="dropdown" role="button" data-target="#"|;
	my $boot_class = qq|dropdown-toggle|;
	my $boot_li = qq|dropdown|;
	my $caret = $opt->{caret} || qq|<b class="caret"></b>|;

	my $class = $opt->{class};
	my $link_class = $opt->{link_class};
	my $li_class = $opt->{li_class};

	my $z = 0;
	my $last_level = 0;

	for my $row (@$rows) {
#Debug("mvlevel:$row->{mv_level} last:$last_level lastrow:$row->{mv_last_row} z:$z");
		next if $row->{deleted};
		if($row->{mv_children} > 0){
			$row->{boot_content} = $boot_content;
			$row->{link_class} = "$boot_class $link_class";
			$row->{caret} = $caret;
			$row->{boot_li} = "$boot_li $li_class";
		}
		else{
			$row->{link_class} = $link_class;
			$row->{boot_li} = "$li_class";
		}

		## Allow for bootstrap icon set

		unless ($row->{img_icon} =~ /\.(jpg|gif|png|jpeg)$/i){
			$row->{icon} = qq|<i class="$row->{img_icon}"></i>| if $row->{img_icon};
		}

		my ($in_template, $list_open, $list_close);
		if($row->{mv_level} > $last_level) {   # new nested list
			$list_open = <<EOF;
	<ul class="dropdown dropdown-menu">
EOF

		}
		elsif($row->{mv_level} < $last_level) {   # end of nested list
			$list_close = <<EOF;
		<!-- level:$row->{mv_level} -->
		</li>
	</ul>
		</li>
EOF
			my $add_close = <<EOF;
	</ul>
EOF
			my $level_diff = $last_level - $row->{mv_level};
			for(2..$level_diff) {
				$list_close .= $add_close;
			}
		}
		elsif ($z) {
			$list_close = <<EOF;
		</li>
EOF
		}
		$in_template = $list_close . $list_open . $template;
		if($row->{mv_last_row}) {

			my $scl = <<EOF;
		</li>
EOF
			my $cl = <<EOF;
		</li>
	</ul>
EOF
			if ($row->{mv_level} == 1){
				$in_template .= $cl;
			}
			elsif ($row->{mv_level} > 1) {
				while($last_level >= 0){
					$in_template .= $cl;
					$last_level--;
				}
			}
			$in_template .= $scl;
		}

		push @out, Vend::Tags->uc_attr_list($row, $in_template);
		$last_level = $row->{mv_level};
		$z++;
	}

	push @out, <<EOF;
</ul>
EOF

	return join "", @out;
}

EOR
