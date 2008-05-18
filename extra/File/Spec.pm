package File::Spec;

require Exporter;

@ISA = qw(Exporter);
# Items to export into callers namespace by default. Note: do not export
# names by default without a very good reason. Use EXPORT_OK instead.
# Do not simply export all your public functions/methods/constants.
@EXPORT = qw(
	
);
@EXPORT_OK = qw($Verbose);

use strict;
use vars qw(@ISA $VERSION $Verbose $Is_VMS $Is_OS2 $Is_Mac $Is_Win32);

$VERSION = '0.5';

$Verbose = 0;

$Is_VMS   = $^O eq 'VMS';
$Is_OS2   = $^O eq 'os2';
$Is_Mac   = $^O eq 'MacOS';
$Is_Win32 = $^O eq 'MSWin32';

require File::Spec::Unix;

@ISA = qw(File::Spec::Unix);

if ($Is_VMS) {
    require File::Spec::VMS;
    require VMS::Filespec; # is a noop as long as we require it within MM_VMS
	@ISA = qw(File::Spec::VMS);
}
if ($Is_OS2) {
    require File::Spec::OS2;
	@ISA = qw(File::Spec::OS2);
}
if ($Is_Mac) {
    require File::Spec::Mac;
	@ISA = qw(File::Spec::Mac);
}
if ($Is_Win32) {
    require File::Spec::Win32;
	@ISA = qw(File::Spec::Win32);
}

1;
__END__

=head1 NAME

File::Spec - portably perform operations on file names

=head1 SYNOPSIS

C<use File::Spec;>

C<$x=File::Spec-E<gt>catfile('a','b','c');>

which returns 'a/b/c' under Unix.

=head1 DESCRIPTION

This module is designed to support operations commonly performed on file
specifications (usually called "file names", but not to be confused with the
contents of a file, or Perl's file handles), such as concatenating several
directory and file names into a single path, or determining whether a path
is rooted. It is based on code directly taken from MakeMaker 5.17, code
written by Andreas KE<ouml>nig, Andy Dougherty, Charles Bailey, Ilya
Zakharevich, and others.

Since these functions differ under different operating systems, each set of
OS specific routines is available in a separate module, including:

	File::Spec::Unix
	File::Spec::OS2
	File::Spec::Win32
	File::Spec::VMS

The module appropriate for the current OS is automatically loaded by
File::Spec. Since some modules (like VMS) make use of OS specific
facilities, it may not be possible to load all modules under all operating
systems.

Since File::Spec is object oriented, subroutines should not called directly,
as in:

	File::Spec::catfile('a','b');
	
but rather as class methods:

	File::Spec->catfile('a','b');

For a reference of available functions, pleaes consult L<File::Spec::Unix>,
which contains the entire set, and inherited by the modules for other
platforms. For further information, please see L<File::Spec::OS2>,
L<File::Spec::Win32>, or L<File::Spec::VMS>.

=head1 SEE ALSO

File::Spec::Unix, File::Spec::OS2, File::Spec::Win32, File::Spec::VMS,
ExtUtils::MakeMaker

=head1 AUTHORS

Kenneth Albanowski <F<kjahds@kjahds.com>>, Andy Dougherty
<F<doughera@lafcol.lafayette.edu>>, Andreas KE<ouml>nig
<F<A.Koenig@franz.ww.TU-Berlin.DE>>, Tim Bunce <F<Tim.Bunce@ig.co.uk>>. VMS
support by Charles Bailey <F<bailey@genetics.upenn.edu>>.  OS/2 support by
Ilya Zakharevich <F<ilya@math.ohio-state.edu>>.

=cut


1;