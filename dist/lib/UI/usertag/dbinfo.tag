# Return some info about a database
# Goes in minivend.cfg, not catalog.cfg
#
# THIS REQUIRES 3.12beta4 or higher!
#
# Examples:
#
# <PRE>
# columns:    [dbinfo table=products columns=1 joiner="|"]
# file:       [dbinfo table=products attribute=file]
# dir:        [dbinfo table=products attribute=dir]
# storage:    [dbinfo table=products storage=1]
# INDEX:      [dbinfo table=products attrib=INDEX]
# CONTINUE:   [dbinfo table=products attrib=CONTINUE]
# path to db: [dbinfo db=products attr=dir]/[dbinfo db=products attr=file]
# exists category: [dbinfo db=products column_exists=category]
# exists nevairbe: [dbinfo db=products column_exists=nevairbe No="Nope."]
# exists 00-0011: [dbinfo
#                    db=products
#                    record_exists="00-0011"
#                    YES="Yup."
#                    No="Nope."]
# exists 00-0000: [dbinfo
#                    db=products
#                    record_exists="00-0000"
#                    YES="Yup."
#                    No="Nope."]
#
# </PRE>
#
UserTag dbinfo Order table
UserTag dbinfo addAttr
UserTag dbinfo attrAlias base table
UserTag dbinfo attrAlias db table
UserTag dbinfo Routine <<EOR
sub {
	my ($table, $opt) = @_;

	sub _die {
		$Vend::Session->{failure} .= shift;
		return;
	}

	my $db_obj = $Vend::Cfg->{Database}{$table}
				|| return _die("Table '$table' does not exist\n");

	# attributes are: (case matters)
	#
	#	CONTINUE
	#	dir
	#	EXCEL
	#	file
	#	INDEX
	#	MEMORY
	#	type

	if($opt->{attribute} or $opt->{attribute} = $opt->{attrib} || $opt->{attr}) {
		return $db_obj->{$opt->{attribute}};
	}

	# COLUMN_DEF, NUMERIC, NAME
	if($opt->{attribute_ref}) {
		return Vend::Util::uneval($db_obj->{$opt->{attribute_ref}});
	}

	my $db = Vend::Data::database_exists_ref($table)
				|| return _die("Table '$table' does not exist\n");
	$db = $db->ref() unless $Vend::Interpolate::Db{$table};

    if($opt->{storage}) {
        my $string = $db;
        $string =~ /.*::(\w+).*/;
        return $1;
    }

	# doesn't include first column!
	return join (($opt->{joiner} || "\n"), $db->columns())
		if($opt->{columns});

	if($opt->{column_exists}) {
		return defined $db->test_column($opt->{column_exists})
				? ($opt->{yes} || 1)
				: ($opt->{'no'} || '');
	}
	if($opt->{record_exists}) {
		return $db->record_exists($opt->{record_exists})
				? ($opt->{yes} || 1)
				: ($opt->{'no'} || '');
	}
	return;
}
EOR

