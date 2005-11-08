# Copyright 2002-2005 Interchange Development Group (http://www.icdevgroup.org/)
# Licensed under the GNU GPL v2. See file LICENSE for details.
# $Id: page_meta.tag,v 1.3 2005-11-08 18:14:42 jon Exp $

UserTag page-meta Order   page
UserTag page-meta addAttr
UserTag page-meta Version $Revision: 1.3 $
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
