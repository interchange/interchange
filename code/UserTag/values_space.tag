# Copyright 2004 Interchange Development Group (http://www.icdevgroup.org/)
# Licensed under the GNU GPL v2. See file LICENSE for details.
# $Id: values_space.tag,v 1.3 2005-02-10 14:38:39 docelic Exp $

UserTag values-space Order   name
UserTag values-space addAttr
UserTag values-space Version $Revision: 1.3 $
UserTag values-space Routine <<EOR
sub {
	my ($name, $opt) = @_;
	return $Vend::ValuesSpace unless defined $name;

	my $old_name = $Vend::ValuesSpace;
	my $old_ref;
	if ($old_name eq '') {
		$old_ref = $Vend::Session->{values};
	}
	else {
		$old_ref = $Vend::Session->{values_repository}{$old_name} ||= {};
	}

	if ($name eq '') {
		$::Values = $Vend::Session->{values};
	}
	else {
		$::Values = $Vend::Session->{values_repository}{$name} ||= {};
	}
	$Vend::ValuesSpace = $name;

	%$::Values = () if $opt->{clear};

	my @copy;
	if ($opt->{copy_all}) {
		@copy = keys %$old_ref;
	}
	elsif ($opt->{copy}) {
		@copy = grep /\S/, split / /, $opt->{copy};
	}
	$::Values->{$_} = $old_ref->{$_} for @copy;

#Debug("changed values space from $old_name to $name; new contents:\n" . ::uneval($::Values));
	return $opt->{show} ? $old_name : '';
}
EOR
