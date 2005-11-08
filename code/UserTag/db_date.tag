# Copyright 2002-2005 Interchange Development Group (http://www.icdevgroup.org/)
# Licensed under the GNU GPL v2. See file LICENSE for details.
# $Id: db_date.tag,v 1.3 2005-11-08 18:14:42 jon Exp $

# [db-date table format]
#
# This tag returns the last-modified time of a database table,
# 'products' by default. Accepts a POSIX strftime value for
# date format; uses '%A %d %b %Y' by default.
#
UserTag  db-date  Order     table format
UserTag  db-date  PosNumber 2
UserTag  db-date  Version   $Revision: 1.3 $
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
