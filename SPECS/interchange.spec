%define ic_user				interch
%define ic_group			interch

%define filelist %{_tmppath}/%{name}-%{version}.filelist
%define webdir /var/www
%define autostart 1


Summary: A complete web application platform
Name: interchange
Version: 4.8.4
Release: 9
Vendor: Red Hat, Inc.
Group: System Environment/Daemons
BuildRoot: %{_tmppath}/%{name}-%{version}-buildroot
URL: http://interchange.redhat.com/
Source0: http://interchange.redhat.com/interchange/interchange-%{version}.tar.gz
Source1: interchange-wrapper
Source2: interchange-init
Source3: interchange-logrotate
License: GPL
Requires: perl >= 5.005
Requires: perl-Business-UPS
Requires: perl-Digest-MD5
Requires: perl-MIME-Base64
Requires: perl-Safe-Hole
Requires: perl-SQL-Statement
Requires: perl-Storable
Requires: perl-URI
Requires: perl-libnet
Requires: perl-libwww-perl
BuildPrereq: perl >= 5.005

%description
Interchange is a complete web application platform focused on
ecommerce, dynamic data presentation, and content management.


%package foundation
Summary: A template for building your own store with Interchange
Group: System Environment/Daemons
Requires: interchange = %{version}-%{release}

%description foundation
The Foundation Store is a full-featured ecommerce catalog you can
adapt to build your own store.


%package foundation-demo
Summary: A prebuilt demonstration store for Interchange
Group: System Environment/Daemons
Prereq: interchange = %{version}-%{release}

%description foundation-demo
This demo is a prebuilt installation of the Foundation Store that
makes it easy to test drive Interchange's ecommerce features.


%prep
%setup -q

%build

if test -z "$RPM_BUILD_ROOT" -o "$RPM_BUILD_ROOT" = "/"
then
	echo "RPM_BUILD_ROOT has stupid value"
	exit 1
fi
rm -rf $RPM_BUILD_ROOT
mkdir -p $RPM_BUILD_ROOT

ETCBASE=%{_sysconfdir}
RUNBASE=%{_localstatedir}/run
LOGBASE=%{_localstatedir}/log
LIBBASE=%{_localstatedir}/lib
CACHEBASE=%{_localstatedir}/cache
ICBASE=%{_libdir}/interchange

# Install Interchange
perl Makefile.PL \
	rpmbuilddir=$RPM_BUILD_ROOT \
	INTERCHANGE_USER=%ic_user \
	PREFIX=$RPM_BUILD_ROOT$ICBASE \
	INSTALLMAN1DIR=$RPM_BUILD_ROOT%{_mandir}/man1 \
	INSTALLMAN3DIR=$RPM_BUILD_ROOT%{_mandir}/man8 \
	force=1
make
make test
make NOCPANINSTALL=1 install
gzip $RPM_BUILD_ROOT%{_mandir}/man*/*

# Copy over extra stuff that usually stays in source directory
mkdir -p $RPM_BUILD_ROOT$ICBASE/build
cp extra/HTML/Entities.pm $RPM_BUILD_ROOT$ICBASE/build
cp extra/IniConf.pm $RPM_BUILD_ROOT$ICBASE/build
cp -R -p eg extensions $RPM_BUILD_ROOT$ICBASE

# Tell Perl where to find IC libraries during build time
export PERL5LIB=$RPM_BUILD_ROOT$ICBASE/lib
export MINIVEND_ROOT=$RPM_BUILD_ROOT$ICBASE

# Fix paths of link file in compile script
cd $RPM_BUILD_ROOT$ICBASE
perl -pi -e "s:^(\s+)LINK_FILE(\s+)=>.*:\$1LINK_FILE\$2=> \"$RUNBASE/interchange/socket\",:" bin/compile_link

# Build link program
bin/compile_link -build src

mkdir -p $RPM_BUILD_ROOT$LIBBASE/interchange
mkdir -p $RPM_BUILD_ROOT$RUNBASE/interchange
mkdir -p $RPM_BUILD_ROOT$LOGBASE/interchange
mkdir -p $RPM_BUILD_ROOT$CACHEBASE/interchange

# Install wrapper script
mkdir -p $RPM_BUILD_ROOT%{_sbindir}
install -m755 %{SOURCE1} $RPM_BUILD_ROOT%{_sbindir}/interchange

# Install SysV-style system startup/shutdown script
mkdir -p $RPM_BUILD_ROOT$ETCBASE/rc.d/init.d
install -m755 %{SOURCE2} $RPM_BUILD_ROOT$ETCBASE/rc.d/init.d/interchange

# Install log rotation script
mkdir -p $RPM_BUILD_ROOT$ETCBASE/logrotate.d
install -m644 %{SOURCE3} $RPM_BUILD_ROOT$ETCBASE/logrotate.d/interchange

# Build the demo catalog
HOST=RPM_CHANGE_HOST
BASEDIR=%{_localstatedir}/lib/interchange
LOGDIR=%{_localstatedir}/log/interchange
CACHEDIR=%{_localstatedir}/cache/interchange
DOCROOT=%{webdir}/html
CGIDIR=%{webdir}/cgi-bin
CGIBASE=/cgi-bin
HTTPDCONF=%{_sysconfdir}/httpd/conf/httpd.conf
for i in foundation
do 
	mkdir -p $RPM_BUILD_ROOT$CGIDIR
	mkdir -p $RPM_BUILD_ROOT$DOCROOT/$i/images
	mkdir -p $RPM_BUILD_ROOT$BASEDIR/$i
	bin/makecat \
		-F \
		--relocate=$RPM_BUILD_ROOT \
		--nocfg \
		--norunning \
		--demotype=$i \
		--catalogname=$i \
		--basedir=$BASEDIR \
		--catroot=$BASEDIR/$i \
		--documentroot=$DOCROOT \
		--samplehtml=$DOCROOT/$i \
		--sampleurl=http://$HOST/$i \
		--imagedir=$DOCROOT/$i/images \
		--imageurl=/$i/images \
		--sharedir=$DOCROOT \
		--shareurl= \
		--cgidir=$CGIDIR \
		--cgibase=$CGIBASE \
		--cgiurl=$CGIBASE/$i \
		--interchangeuser=%ic_user \
		--interchangegroup=%ic_group \
		--permtype=user \
		--serverconf=$HTTPDCONF \
		--vendroot=$ICBASE \
		--linkmode=UNIX \
		--servername=$HOST \
		--catuser=%ic_user \
		--mailorderto=%{ic_user}@$HOST \
		cachedir=$CACHEDIR/$i \
		logdir=$LOGDIR/$i
done

# Clean up empty placeholder files used to keep CVS from pruning away
# otherwise empty directories
find $RPM_BUILD_ROOT -type f -name .empty \( -size 0b -o -size 1b \) -exec rm -f \{\} \;

# Put interchange.cfg in /etc instead of IC software directory
mv interchange.cfg.dist $RPM_BUILD_ROOT$ETCBASE/interchange.cfg
ln -s $ETCBASE/interchange.cfg

# Put global error log in /var/log/interchange instead of IC software directory
RPMICLOG=$LOGBASE/interchange/error.log
rm -f error.log
ln -s $RPMICLOG
touch $RPM_BUILD_ROOT$RPMICLOG

# Make a symlink from docroot area into /usr{/share}/doc/interchange-x.x.x.
ln -s %{_docdir}/interchange-%{version} $RPM_BUILD_ROOT$DOCROOT/interchange/doc

# I don't know of a way to exclude a subdirectory from one of the directories
# listed in the %files section, so I have to use this monstrosity to generate
# a list of all directories in /usr/lib/interchange except the foundation demo
# directory and pass the list to %files below.
DIRDEPTH=`echo $ICBASE | sed 's:[^/]::g' | awk '{print length + 1}'`
cd $RPM_BUILD_ROOT
find . -path .$ICBASE/foundation -prune -mindepth $DIRDEPTH -maxdepth $DIRDEPTH \
	-o -print | grep "^\.$ICBASE" | sed 's:^\.::' | \
	sed 's:^\(/usr/lib/interchange/etc\):%attr(-, %{ic_user}, %{ic_group}) \1:' \
	> %filelist


%install


%pre

/sbin/service interchange stop > /dev/null 2>&1

# Create interch user/group if they don't already exist
[ -z "`grep ^%{ic_group}: /etc/group`" ] && \
	/usr/sbin/groupadd -g 52 %ic_group
[ -z "`grep ^%{ic_user}: /etc/passwd`" ] && \
	/usr/sbin/useradd -u 52 -c "Interchange server" \
	-s /bin/bash -r -d %{_localstatedir}/lib/interchange %ic_user


%files foundation

%defattr(-, root, root)
%{_libdir}/interchange/foundation


%files -f %filelist

%defattr(-, %{ic_user}, %{ic_group})

%dir %{_localstatedir}/run/interchange
%dir %{_localstatedir}/cache/interchange
%dir %{_localstatedir}/log/interchange
%dir %{_localstatedir}/lib/interchange
%config(noreplace) %{_sysconfdir}/interchange.cfg

%defattr(-, root, root)

%doc LICENSE
%doc README
%doc README.rpm
%doc README.cvs
%doc WHATSNEW
%config(noreplace) %{_sysconfdir}/logrotate.d/interchange
%config %{_sysconfdir}/rc.d/init.d/interchange
%{_sbindir}/interchange
%dir %{_libdir}/interchange
%{webdir}/html/interchange
%{_mandir}/*/*


%files foundation-demo

%defattr(-, %{ic_user}, %{ic_group})
%{_localstatedir}/lib/interchange/foundation
%{_localstatedir}/log/interchange/foundation
%{_localstatedir}/cache/interchange/foundation
%{webdir}/html/foundation
%{webdir}/cgi-bin/foundation


%post

# Create the error log if it doesn't exist
if [ ! -f %{_localstatedir}/log/interchange/error.log ]; then
    touch %{_localstatedir}/log/interchange/error.log
    chown %{ic_user}.%{ic_group} %{_localstatedir}/log/interchange/error.log
fi

# Make Interchange start/stop automatically with the operating system.
[ "%{autostart}" != 0 ] && /sbin/chkconfig --add interchange

# Get to a place where no random Perl libraries should be found
cd /usr

# Install private copies of key CPAN modules if necessary
status=`perl -e "require HTML::Entities and print 1;" 2>/dev/null`
if test "x$status" != x1
then
	mkdir -p %{_libdir}/interchange/lib/HTML 2>/dev/null
	cp -p %{_libdir}/interchange/build/Entities.pm %{_libdir}/interchange/lib/HTML 2>/dev/null
fi

status=`perl -e "require IniConf and print 1;" 2>/dev/null`
if test "x$status" != x1
then
	cp -p %{_libdir}/interchange/build/IniConf.pm %{_libdir}/interchange/lib 2>/dev/null
fi

# Storable is technically optional; be careful in case user
# installed with --nodeps
status=`perl -e "require Storable and print 1;" 2>/dev/null`
if test "x$status" != x1
then
	rm -f %{_libdir}/interchange/_*storable
fi


%post foundation-demo

HOST=`hostname`

for i in foundation
do 
	perl -pi -e "s/RPM_CHANGE_HOST/$HOST/g" \
		%{_localstatedir}/lib/interchange/$i/catalog.cfg \
		%{_localstatedir}/lib/interchange/$i/products/*.txt \
		%{_localstatedir}/lib/interchange/$i/products/*.asc \
		%{_localstatedir}/lib/interchange/$i/config/* \
		%{webdir}/html/$i/index.html

	# Add Catalog directive to interchange.cfg
	ICCFG=%{_sysconfdir}/interchange.cfg
	catline="`grep -i \"^#*[ \t]*Catalog[ \t][ \t]*$i[ \t]\" $ICCFG`"
	if [ -z "$catline" ]; then
		catline="Catalog  $i  /var/lib/interchange/$i  /cgi-bin/$i"
		perl -pi -e "next if ! /^\s*#\s*Catalog\s/i or \$done; s,\$,\n$catline,; ++\$done" $ICCFG
	fi

	# Add the new catalog to the running Interchange daemon
	if [ -n "`/sbin/service interchange status 2>/dev/null | grep -i 'interchange.*is running'`" ]
	then
		echo "$catline" | %{_sbindir}/interchange --add=$i > /dev/null 2>&1
	fi
done


%preun

# Stop Interchange if running
/sbin/service interchange stop > /dev/null 2>&1

# Remove autostart of interchange
/sbin/chkconfig --del interchange 2>/dev/null

# Remove non-user data
rm -rf %{_localstatedir}/run/interchange/*
rm -rf %{_localstatedir}/cache/interchange/*
rm -rf %{_libdir}/interchange/lib/HTML


%preun foundation-demo

for i in foundation
do
	# Remove catalog from running Interchange
	if [ -n "`/sbin/service interchange status 2>/dev/null | grep -i 'interchange.*is running'`" ]
	then
		%{_sbindir}/interchange --remove=$i > /dev/null 2>&1
	fi

	# Remove Catalog directive from interchange.cfg
	perl -pi -e "s/^\s*Catalog\s+$i\s[^\n]+\n//i" %{_sysconfdir}/interchange.cfg

	# Remove leftover machine-generated files
	rm -rf %{_localstatedir}/cache/interchange/$i/tmp/*
	rm -rf %{_localstatedir}/cache/interchange/$i/session/*
	rm -rf %{_localstatedir}/log/interchange/$i/orders/*
	rm -rf %{_localstatedir}/log/interchange/$i/logs/*
	rm -rf %{_localstatedir}/lib/interchange/$i/products/*.db
	rm -rf %{_localstatedir}/lib/interchange/$i/products/products.txt.*
	rm -rf %{_localstatedir}/lib/interchange/$i/products/*.autonumber
	rm -rf %{_localstatedir}/lib/interchange/$i/products/*.numeric
	rm -rf %{_localstatedir}/lib/interchange/$i/etc/status.$i
done


%clean

rm -f %filelist
[ "$RPM_BUILD_ROOT" != "/" ] && rm -rf $RPM_BUILD_ROOT


%changelog
* Mon Apr 29 2002 Jon Jensen <jon@redhat.com> 4.8.4-9
- Back out Stronghold index.html patch.
- Force uid and gid to be 52, Red Hat's assigned numbers for Interchange.
- Adapt a few more Gary-isms (manpage filelist, NOCPANINSTALL setting).

* Fri Feb 15 2002 Jon Jensen <jon@redhat.com> 4.8.4-8
- Keep foundation demo's Catalog directive out of interchange.cfg for
  the base Interchange package; add it separately after installation.
- Drop unneeded interchange.cfg.dist.
- Quell some minor uninstall noise.

* Wed Feb 13 2002 Gary Benson <gbenson@redhat.com> 4.8.4-7
- made the init script more consistent with other RHL packages.

* Wed Feb 13 2002 Gary Benson <gbenson@redhat.com>
- don't ship an empty logfile in the brpm
- use _sysconfdir and _localstatedir instead of /etc and /var

* Tue Feb 12 2002 Gary Benson <gbenson@redhat.com>
- replace ic_version, ic_rpm_release, etc. with version, release, etc.
- remove cat_name definition, since "Foundation" appears multiple times.
- tidy summaries and reflow descriptions.
- remove provides self, obsoletes self and buildarch devilry.
- change groups to System Environment/Daemons.
- add versioned subpackage dependencies.
- split init scripts and logrotate config into separate files.

* Wed Jan 30 2002 Jon Jensen <jon@redhat.com> 4.8.4-6
- Allow non-root RPM builds (required some changes to makecat as well).
- Don't add interch user on build machine.
- Allow easy en/disabling of daemon autostart with defined parameter
  and default to off to prevent any surprises.
- Start using Red Hat standard /sbin/service instead of directly running
  /etc/rc.d/init.d/interchange.
- Remove unneeded .empty files used in CVS to avoid pruning important but
  empty directories.
- Make admin UI images owned by root.
- Don't include /usr/share/man/man[18] system directories in RPMs.
- Start using RPM dependencies for Perl CPAN modules. Users who install
  directly from CPAN will have to use --nodeps.
- Make main interchange package architecture-dependent, because it includes
  precompiled vlink and tlink CGIs, and we shouldn't require a C compiler
  on the install machine if users run makecat later.
- Stop checking for /home/httpd, but use a define for webdir that can
  easily be changed if needed.

* Wed Sep 19 2001 Jon Jensen <jon@redhat.com>
- Add Prereq: interchange to interchange-foundation-demo because the demo
  installs files owned by the interch user, which gets created when the base
  package is installed. This way the order the RPMs are given on the command
  line won't cause trouble.

* Fri Jul 27 2001 Jon Jensen <jon@redhat.com>
- Make a symlink to /usr{/share}/doc/interchange-x.x.x in
  /var/www/html/interchange/doc.

* Sat Jul 14 2001 Jon Jensen <jon@redhat.com>
- Add some files to list for replacing RPM_CHANGE_HOST to real hostname.

* Wed Jun 20 2001 Jon Jensen <jon@redhat.com>
- Make /usr/lib/interchange/etc owned by interch.interch for makecat.cfg
  and reconfig and whatever else needs it.

* Thu Jun 14 2001 Jon Jensen <jon@redhat.com>
- Bring back prebuilt demo, but as a separate package called
  interchange-foundation-demo. It's helpful to have prebuilt CGI binaries
  for emaciated OS installations without a C compiler.
- Handle admin images moved to /var/www/html/interchange.

* Fri May 25 2001 Jon Jensen <jon@redhat.com>
- Use new split confdir/rundir option to keep important things in
  /var/run/interchange from getting erased at OS boot time.
- Add usertrack and catalog error.log to log rotation.

* Tue May 15 2001 Jon Jensen <jon@redhat.com>
- Quiet restart notice when removing foundation RPM.
- Correct bad --add option when adding foundation to running Interchange.
- Move session and temporary files to /var/cache/interchange per LSB.
- Allow makecat to handle logdir location rather than manually symlinking.
- Remove admin images when foundation is uninstalled (need to find a better
  way to deal with this in the future).
 
* Sat May 12 2001 Jon Jensen <jon@redhat.com>
- Deal with 'useradd' not being in path.
- Remove some superfluous chowning and chmodding.
- Show messages from /usr/sbin/interchange; quiet only from rc.d script.
- Make all Interchange global files owned by root for security -- that way
  even catalog admin users can't change files if checks are bypassed.
  Since one must be root to install the RPM at all and to add files to
  /var/www, this doesn't seem unreasonable. You can still start and stop
  the server as the interch user. It does mean that you have to be root to
  run makecat. To allow makecat as interch user, chown interch.interch on
  these files and directories:
    /etc/interchange.cfg
    /var/lib/interchange
    /usr/lib/interchange/etc/makecat.cfg
    /var/www/cgi-bin (or copy the link manually)
    /var/www/html (or add HTML & images manually)
  And I think that would do it.
- Make demo package quiet during install.
- Cleaner delete during uninstall of main package.
- Safer delete during uninstall of foundation package -- during install
  stamp the catalog directory with a file and later skip the delete step
  if that file is not found.
- Fix a few typos, add some comments.

* Tue Mar 27 2001 Jon Jensen <jon@redhat.com>
- Fix error.log symlink.
- Specify that socket.ipc goes in /var/run/interchange
- Work with Red Hat Linux 6 or 7 from same RPM file.
- Move to noarch RPM builds. The downside is that we're compiling vlink for
  foundation *after* install ... This should be ok if we can fall back to
  the Perl vlink if compile fails.

* Fri Feb 23 2001 Jon Jensen <jon@redhat.com>
- Check for existing foundation catalog before install (can't count on RPM
  checks since Interchange is building the catalog after skeleton install)
- Completely uninstall new locally-built foundation instance

* Tue Feb 20 2001 Jon Jensen <jon@redhat.com>
- build separate packages for Interchange server and foundation demo
- run makecat on foundation at install time, rather than build time
  - this shaves around 500 kB from the RPM package size
  - don't need to know web directory at build time now, which brings us
    very close to a single RPM for both RH 6 and 7 platforms; docs are
    now the only difference left
- clean up RPM build root after build
- update text throughout to reflect Red Hat acquisition of Akopia

* Sat Jan  6 2001 Jon Jensen <jon@akopia.com>
- purge global error.log and most of construct demo when uninstalling
  to satisfy Red Hat's RPM certification requirements

* Fri Dec  1 2000 Jon Jensen <jon@akopia.com>
- combined Red Hat 6 and Red Hat 7 specfiles -- target platform is now
  determined by build machine
- fixed bug for HTML::Entities and IniConf installation caused by
  /usr/lib/interchange/build directory not being created
- imported makedirs.redhat and makecat.redhat scripts into specfile
- allow creation of interch user even if interch group already exists
  (relevant only to Red Hat 7 AFAIK)
- numerous other minor modifications
