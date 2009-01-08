# Copyright 2008 Interchange Development Group and others
# 
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.  See the LICENSE file for details.
# 
# $Id: child-process.tag,v 1.3 2009-01-08 12:05:16 markj Exp $

UserTag child-process addAttr
UserTag child-process HasEndTag
UserTag child-process NoReparse 0
UserTag child-process Interpolate 0
UserTag child-process Version $Revision: 1.3 $
UserTag child-process Documentation <<EOD

=head1 NAME

child_process - Execute ITL code in a forked child process

=head1 SYNOPSIS

[child-process] ... ITL ... [/child-process]

=head1 DESCRIPTION

Runs Interchange markup code in a forked child process.
Useful for off-loading processes that take a relatively long time to complete.

Has no effect if the body is empty or contains only whitespace.

Options are:

=over 4

=item filename

File name relative to catalog directory to file where output from forked
process should be stored.

=item label

Optional descriptive label for this process that will be put in the operating
system process list. Default is "child-process tag".

=item notifyname

File name relative to catalog directory where a file of zero length will
be created if the file in option 'filename' is created successfully.

This empty file could be used for notification purposes, e.g. as an
indicator that the child process has delivered its output. When placed
in web docroot space one could poll for the existence of this file and
when it exists bounce to a page that will display the results.

=back

=head1 EXAMPLES

 This is the parent process.

 Child process starts here.
 [child-process filename="tmp/report_[time]%Y%m%d%H%M%S[/time].txt"]
 [query
     list=1
     sql="
         ... some long-running SQL query ...
     "
 ][sql-line]
 [/query]
 [/child-process]
 Child process ends here.

 Some more parent stuff....

=head1 AUTHORS

Ton Verhagen <tverhagen@alamerce.nl>

Jon Jensen <jon@endpoint.com>


=cut

EOD
UserTag child-process Routine <<EOR

use POSIX ();

sub {
    my ($opt, $body) = @_;
    use vars qw/ $Tag /;

    return unless defined($body) and $body =~ /\S/;

    defined(my $kid = fork) or die "Cannot fork: $!\n";
    if ($kid) {
        waitpid($kid, 0);
        return;
    }
    else {

        Vend::Server::sever_database();

        defined (my $grandkid = fork) or die "Kid cannot fork: $!\n";
        exit if $grandkid;

        Vend::Server::cleanup_for_exec();

        # Disconnect from parent's terminal
        POSIX::setsid() or die "Can't start a new session: $!\n";

        defined $opt->{label} or $opt->{label} = 'child-process tag';
        Vend::Server::set_process_name($opt->{label});

        my $output = interpolate_html($body, 1);

        my $filename = $opt->{filename};
        if (defined($filename) and length($filename)) {
            $filename = $Tag->filter('filesafe', $filename);
            my $status = $Tag->write_relative_file($filename, $$output);

            my $notifyname = $opt->{notifyname};
            if ($status and defined($notifyname) and length($notifyname)) {
                $notifyname = $Tag->filter('filesafe', $notifyname);
                $Tag->write_relative_file($notifyname, $opt, '');
            }
        }

        exit;
    }
}
EOR
