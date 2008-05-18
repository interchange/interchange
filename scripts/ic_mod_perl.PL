#!/usr/bin/perl
##!~_~perlpath~_~


=head1 NAME

ic_mod_perl -- Run Interchange entirely inside Apache/mod_perl


=head1 SYNOPSIS

  # Add to Apache httpd.conf:
  PerlRequire /usr/lib/interchange/bin/ic_mod_perl
  PerlChildInitHandler Vend::ModPerl::child_start
  PerlChildExitHandler Vend::ModPerl::child_end
  <Location /ic>
      SetHandler perl-script
      PerlHandler Vend::ModPerl
      PerlSendHeader Off
      PerlSetupEnv On
  </Location>


=head1 DESCRIPTION


=head2 Benefits

=item *

Possibly better stability, especially on non-Linux platforms where
Perl signals are often buggy.

=item *

Use less memory total; don't have preforked Apache I<and> Interchange
daemons. Adds about 8 MB more to a typical Apache/mod_perl child process,
for a total of, say, 32 MB per Apache child process. But standalone
Interchange usually has 3 processes: an Interchange child process (~24
MB), an httpd child (~24 MB), I<and> a link CGI (~1 MB), so it's
actually a decent savings in total memory used.

=item *

Speed (ranging from slightly faster to the same on heavy pages,
to 10 hits/sec. faster on empty pages).

=item *

Debugging -- delve into bowels with Apache::Status.

=item *

Easier coexistence with other mod_perl code and libraries.

=item *

Can coexist with standalone Interchange codebase without problems.

=item *

Administrative ease (for sysadmins who know Apache but not Interchange).


=head2 Drawbacks

=item *

Interchange runs as web server user, which in a standard system is usually
apache or www, so you wouldn't want to share that Apache installation
with untrusted user CGIs, PHP, etc. as they could read any Interchange
files, including DSNs, userdb, etc.

=item *

Apache needs to be dedicated, or very closely watched because all
mod_perl stuff runs in the same interpreter, and lots of mod_perl code
doesn't use Safe.

=item *

How do you scale to multiple app servers in this configuration?

=over 4

=item *

Hardware or software port redirector

=item *

Tux CGI front-end redirector like tlink

=item *

Separate lightweight Apache (no modules) that proxies /ic requests

=back


=head2 Ideal system setup

Use Tux to serve images & static content, and a dedicated Apache for
Interchange running under the 'interch' user and with no UserDir, CGI,
PHP, etc. enabled and an empty DocRoot.


=head1 CAVEATS

=item *

Watch out for differing Storable versions in sessions when switching
between standalone and mod_perl runs!


=head1 BUGS

=item *

Haven't yet implemented form/multipart submissions.

=item *

Don't yet handle TolerateGet.

=item *

Don't yet handle MiniVend 3 style GETs (mv_session_id;mv_arg;mv_pc)

=item *

URIs must follow format C</ic/catalogname/page...>, where /ic is
customizable but must only be one "directory" deep (i.e., no
slashes).


=head1 AUTHOR

Jon Jensen <jon@icdevgroup.org>, March 2002

=cut


die <<EOF unless $ENV{MOD_PERL};

ic_mod_perl is meant to run only inside of Apache/mod_perl.
Please see the POD documentation for details:

perldoc $0

EOF


$Global::mod_perl = 1;

package main;
require '/home/jon/xfxf/bin/interchange';
#require '~_~INSTALLARCHLIB~_~/bin/interchange';


1;
