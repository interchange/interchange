UserTag mm-value Order field table
UserTag mm-value addAttr
UserTag mm-value Routine <<EOR
sub {
	my($field, $table, $opt, $text) = @_;

	my $record;
	my $status;
	my $reverse;
	my $uid = $opt->{user};
	unless ($record = $Vend::UI_entry) {
		return '' unless ref($record = ui_acl_enabled());
	}
#::logDebug("mm-value record: " . ::uneval($record));
	$table = $opt->{table} || $::Scratch->{ui_data_table};

	if($field eq 'user') {
		return $Vend::Session->{ui_username} || $Vend::Session->{username} || $CGI::user;
	}

	my %hash_field = qw/
						acl_keys      1
						no_fields     1
						yes_fields    1
						no_keys       1
						yes_keys      1
						owner_field   1
					/;
	
	my $acl;
	my $check;
	if($check = $hash_field{$field}) {
		if ($field eq 'acl_keys') {
			return join "\n", get_ui_table_acl($table, $uid, 1);
		}
		else {
			$acl = get_ui_table_acl($table, $uid);
			return $acl->{$field};
		}
	}
	else {
		return $record->{$field};
	}
}
EOR

