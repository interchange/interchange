UserTag unlink_file Order name prefix
UserTag unlink_file PosNumber 2
UserTag unlink_file Routine <<EOR
sub {
	my ($file, $prefix) = @_;
#::logDebug("got to unlink: file=$file prefix=$prefix");
	$prefix = 'tmp/' unless $prefix;
	return if Vend::Util::file_name_is_absolute($file);
	return if $file =~ /\.\./;
	return unless $file =~ /^$prefix/;
#::logDebug("got to unlink: $file qualifies");
	unlink $file;
}
EOR

