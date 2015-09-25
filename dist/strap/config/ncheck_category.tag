GlobalSub <<EOS
sub ncheck_category {
	##
	## Subroutine that looks for a prod_group and category in
	## a missing page and delivers them
	##
	my ($name) = @_;
	return unless $name =~ m{^[A-Z]};
	my $results_page = $Vend::Cfg->{'SpecialPage'}{'results'} || 'results';
	
	my $xmoz = Vend::Tags->env('HTTP_X_MOZ') || '';
	if($xmoz eq 'prefetch') {
		## fail to deliver page if Firefox is prefetching, as they will send 2nd request and mess up paging
		return Vend::Tags->deliver({ location => Vend::Tags->area('prefetch-not-allowed'), type => 'text/html' });
	}

	my ($prod_group, $category, $page) = split m{/}, $name; 
	my $a_prod_group = $prod_group;
	my $a_category = $category;
	for($prod_group, $category) {
		s,-, ,g;
		s,_,-,g;
		s,::,/,g;
	}
	my ($search, $o);
	my $limit = $::Values->{mv_matchlimit} || $::Variable->{MV_DEFAULT_MATCHLIMIT} || 50;
	my $more_link = $a_prod_group;
	if($category && $category !~ /^([0-9]+|Next|Previous)$/ ) {
		$more_link .= '/' . $a_category;
	}
	else {
		$page = $category;
		$category = undef;
	}
#::logDebug("prod_group = $prod_group, category = $category, page = $page");

	if($page) {
		my $first_match = $::Values->{mv_first_match} || 0;
#::logDebug("first_match starts with = $first_match");
		if($page =~ /[0-9]+/) { $first_match = (($page - 1) * $limit) + 1; }
		elsif($page eq 'Next') { $first_match += $limit unless $::Scratch->{did_order}; }
		elsif($page eq 'Previous') { $first_match -= $limit unless $::Scratch->{did_order}; }
		else { $first_match = 0; }
		$search->{fm} = $first_match > 0 ? $first_match : 0;
#::logDebug("first_match = $first_match, limit = $limit");
	}
	else {
		$search->{fm} = 0;
	}

	if($a_prod_group eq 'All-Products') {
		$search->{ra} = 1;
		$search->{tf} = [ 'category', 'description' ];
	}
	else {
		$search->{co} = 1;
		$search->{sf} = [ 'prod_group', 'category' ];
		$search->{op} = [ 'eq', 'eq' ];
		$search->{se} = [ $prod_group, $category ];
		$search->{tf} = [ 'prod_group', 'category', 'description' ];
	}
	$search->{sp} = $results_page;
	$search->{fi} = 'products';
	$search->{st} = 'db';
	$search->{ml} = $limit;
	$search->{va} = "more_link=$more_link";
	$search->{mv_todo} = 'search';
#::logDebug("search is: " . Vend::Tags->uneval({ ref => $search }) );
	Vend::Tags->search({ search => $search });
	if (($o = $::Instance->{SearchObject}->{''}) && @{$o->{mv_results}}) {
		return (1,  $search->{sp});
	}

	return;
}
EOS
