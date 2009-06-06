# Copyright 2002-2007 Interchange Development Group and others
# 
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.  See the LICENSE file for details.

# [db-date table format]
#
# This tag returns the last-modified time of a database table,
# 'products' by default. Accepts a POSIX strftime value for
# date format; uses '%A %d %b %Y' by default.
#
UserTag  db-date  Order     table format
UserTag  db-date  PosNumber 2
UserTag  db-date  Version   3.0
UserTag  db-date  Routine   <<EOF
sub {
    my ($db, $format) = @_;
	my ($dbfile, $mtime);

	# use defaults if necessary
	$db = 'products' unless $db;
    $format = '%A %d %b %Y' unless $format;

	# build database file name
	$dbfile = $Vend::Cfg->{ProductDir} . '/' 
		. $Vend::Cfg->{Database}{$db}{'file'};

	# get last modified time
	$mtime = (stat ($dbfile))[9];

	if (defined ($mtime)) {
		return POSIX::strftime($format, localtime($mtime));
	} else {
		logError ("Couldn't stat $dbfile: $!\n");
	}
}
EOF
