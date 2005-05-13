UserTag breadcrumbs Order number
UserTag breadcrumbs addAttr
UserTag breadcrumbs Routine <<EOR
sub {
	my ($number, $opt) = @_;

	use vars qw/$Tag $Scratch $CGI $Session $Variable/;
	my $only_last = $::Variable->{BREADCRUMB_ONLY_LAST} || 'ord/basket login';
	my $exclude   = $::Variable->{BREADCRUMB_EXCLUDE};
	my $max   = $number || $::Variable->{BREADCRUMB_MAX} || 6;

	my %exclude;
	my %only_last;

	my @exclude = split /[\s,\0]+/, $exclude;
	my @only_last = split /[\s,\0]+/, $only_last;
	@exclude{@exclude} = @exclude;
	@only_last{@only_last} = @only_last;

	my $curpage = $Global::Variable->{MV_PAGE};
	my $titles = $Scratch->{bc_titles} ||= {};

	my %special = (
		scan => sub { 
			my $url = shift;
			my @items = split m{/}, $url;

			my $title;
			for(@items) {
				if(s/^se=//) {
					$title = $_;
				}
				elsif(s/^va=banner_text=//) {
					$title = $_;
				}
			}
			return ($title, $title);
		},
	);

	my $curhist   = $Session->{History}->[-1] || [];
	my $curparams = $curhist->[1] || {};

	my $keyname;

	my $curfull = $curhist->[0];
	$curfull =~ s/$Vend::Cfg->{HTMLsuffix}$//;
	$curfull =~ s{^/}{};
	my ($curaction,$curpath) = split m{/}, $curfull, 2;

	my $ptitle = $opt->{title} || $curparams->{short_title};
	$ptitle ||= $Scratch->{short_title};

	my $db;

	my @extra;

	if($special{$curaction} and ! $ptitle) {
		($ptitle, $keyname) = $special{$curaction}->($curpath);
	}
	elsif(
			$Vend::Flypart
				and
			$db = Vend::Data::product_code_exists_ref($Vend::Flypart)
		)
	{
		my $tab = $db->name();
		my $record = tag_data($tab, undef, $Vend::Flypart, { hash => 1});
		$ptitle = $keyname = $record->{$Vend::Cfg->{DescriptionField}};

		if($record and $record->{prod_group}) {
			my @parms;
			push @parms, "fi=$tab";
			push @parms, "co=yes";
			push @parms, "st=db";
			push @parms, "sf=prod_group";
			push @parms, "se=$record->{prod_group}";
			push @parms, "op=eq";
			push @extra, {
				key => $record->{prod_group},
				title => $record->{prod_group},
				description => undef,
				url => $Tag->area({ search => join("\n", @parms) }),
			};
		}
		if($record and $record->{category}) {
			my @parms;
			push @parms, "fi=$tab";
			push @parms, "co=yes";
			push @parms, "st=db";
			if($record->{prod_group}) {
				push @parms, "sf=prod_group";
				push @parms, "se=$record->{prod_group}";
				push @parms, "op=eq";
			}
			push @parms, "sf=category";
			push @parms, "se=$record->{category}";
			push @parms, "op=eq";
			push @extra, {
				key => $record->{category},
				title => $record->{category},
				description => undef,
				url => $Tag->area({ search => join "\n", @parms }),
			};
		}
	}

	if(! $ptitle) {
		$ptitle = $Scratch->{page_title};
		$ptitle =~ s/(\s*\W+\s*)?$Variable->{COMPANY}(\s*\W+\s*)?//;
	}

	$ptitle =~ s/^\s+//;
	$ptitle =~ s/\s+$//;

	$keyname ||= $curpage;

	$titles->{$curpage} = $ptitle if $ptitle;

	my %exclude_param = qw(
		mv_pc 1
		bread_reset 1
	);

	if($Scratch->{bread_reset} || $CGI->{bread_reset}) {
		delete $Session->{breadcrumbs};
	}

	my $crumbs = $Session->{breadcrumbs} ||= [];
	my $crumb;

	if($opt->{reset_on_product} and @extra) {
#::logDebug("Resetting based on product");
		@$crumbs = ();
	}

	if(! $exclude{$curpage}) {
		my $form = '';
		if(! $CGI->{bread_no_params}) {
			for(grep !$exclude_param{$_}, keys %$curparams) {
				 $form .= "\n$_=";
				 $form .= join("\n$_=", split /\0/, $curparams->{$_});
			}
		}
		$crumb = {
			key => $keyname,
			title => HTML::Entities::encode($ptitle),
			description => HTML::Entities::encode($Scratch->{page_description}),
			url => $Tag->area({ href => $curfull, form => $form, secure => $CGI->{secure} }),
		};
	}

	push @$crumbs, @extra if @extra;
	push @$crumbs, $crumb if $crumb;
	
	my %seen;
	my @new = grep !$seen{$_->{key}}++, reverse @$crumbs;
	
	my $did_one;
	for(@new) {
		## Kill ones that only are allowed in last position
		if( $did_one and $only_last{$_->{key}}) {
			$_ = undef;
		}
		$did_one = 1;
	}

	if(@new > $max) {
		splice @new, $max;
	}

	@$crumbs = grep $_, reverse @new;

	my $tpl = $opt->{template} || <<EOF;
<a href="{url}"{description?} title="{description}"{/description?} class=breadlink>{title}</a>
EOF

	my @out;
	for(@$crumbs) {
		next unless ref($_) eq 'HASH' and $_->{url};
		my $link = tag_attr_list($tpl, $_);
#::logDebug("link=$link from:\ntpl=$tpl\ncrumb=" . ::uneval($_));
		push @out, $link;
	}

	$opt->{joiner} = '&nbsp;&gt;&nbsp;' unless defined $opt->{joiner};
	return join $opt->{joiner}, @out;
}
EOR
