# Copyright 2002-2007 Interchange Development Group and others
# 
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.  See the LICENSE file for details.
# 
# $Id: page_meta.tag,v 1.4 2007-03-30 23:40:57 pajamian Exp $

UserTag page-meta Order   page
UserTag page-meta addAttr
UserTag page-meta Version $Revision: 1.4 $
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
