#
# values-space tag
# $Id: values_space.tag,v 1.1 2004-04-13 01:10:13 jon Exp $
#
# Usage:
#
# [values-space checkout]
#     Switches current values space to "checkout" for duration of page.
#
# [values-space name=checkout copy-all=1]
#     Same as above, but copies all values from main values space into "checkout"
#     values space. (Does not dereference nested data structures.)
#
# [values-space name=checkout copy="lname fname company"]
#     Copies only three named values instead of all values.
#
# [values-space name=checkout clear=1]
#     Removes all values from values space "checkout", then switches to it.
#
# [values-space]
# [perl] $Tag->values_space() [/perl]
#     Returns the name of the current values space (here 'checkout').
#
# [values-space name=""]
# or: [perl] $Tag->values_space('') [/perl]
#     Switches back to default values space.
#
# [values-space name="" show=1]
#     Switches back to default values space but returns name of previous space.
#

UserTag values-space Order name
UserTag values-space addAttr
UserTag values-space Version $Revision: 1.1 $
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
