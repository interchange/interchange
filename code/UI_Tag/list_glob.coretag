UserTag list_glob Order spec prefix
UserTag list_glob PosNumber 2 
UserTag list_glob Routine <<EOR
sub {
	my @files = UI::Primitive::list_glob(@_);
	return (wantarray ? @files : join "\n", @files);
}
EOR

