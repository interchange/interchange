UserTag export-database Order table file type
UserTag export-database addAttr
UserTag export-database Routine <<EOR
sub {
		my($table, $file, $type, $opt) = @_;
		delete $::Values->{ui_export_database}
			or return undef;
		if($opt->{delete} and ! $opt->{verify}) {
			::logError("attempt to delete field without verify, abort");
			return undef;
		}

		if(!$file and $type) {
			#::logError("exporting as default type, no file specified");
			undef $type;
		}

		$Vend::WriteDatabase{$table} = 1;

		if(! $opt->{field}) {
			#::logError("exporting:\ntable=$table\nfile=$file\ntype=$type\nsort=$opt->{sort}");
		}
		elsif($opt->{field} and $opt->{delete}) {
			::logError("delete field:\ntable=$table\nfield=$opt->{field}\nsort=$opt->{sort}\n");
		}
		elsif($opt->{field}) {
			::logError("add field:\ntable=$table\nfield=$opt->{field}\nsort=$opt->{sort}\n");
		}
		return Vend::Data::export_database(
									$table,
									$file,
									$type,
									$opt,
							);
}
EOR

