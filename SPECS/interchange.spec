%define ic_version			4.8.4
%define ic_rpm_release		1
%define ic_package_basename	interchange
%define ic_user				interch
%define ic_group			interch
# Currently only one demo catalog name may be specified,
# and it must also be the skeleton name.
%define cat_name foundation


Summary: Interchange - a database access and HTML templating system focused on ecommerce
Name: %ic_package_basename
Version: %ic_version
Release: %ic_rpm_release
Vendor: Red Hat, Inc.
License: GPL
URL: http://interchange.redhat.com/
Packager: Interchange Development Team <interchange@redhat.com>
Source: http://interchange.redhat.com/interchange/interchange-%{ic_version}.tar.gz
Group: Applications/Internet
Requires: perl >= 5.005
BuildPrereq: perl >= 5.005
Provides: %ic_package_basename
Obsoletes: %ic_package_basename
BuildArch: noarch i386

BuildRoot: %{_tmppath}/%{name}-%{version}-buildroot

%description
Interchange is the most powerful free ecommerce system available today.


%package %cat_name
Summary: Interchange Foundation skeleton - a template for building your own store
Group: Applications/Internet
Requires: %ic_package_basename
Provides: %{ic_package_basename}-%cat_name
Obsoletes: %{ic_package_basename}-%cat_name

%description %cat_name
The Foundation Store is a basic catalog you can adapt to build your own store.


%package %{cat_name}-demo
Summary: Interchange Foundation demo - a prebuilt demonstration store
Group: Applications/Internet
Prereq: %ic_package_basename
Requires: %ic_package_basename
Provides: %{ic_package_basename}-%{cat_name}-demo
Obsoletes: %{ic_package_basename}-%{cat_name}-demo

%description %{cat_name}-demo
This demo is a prebuilt installation of the Foundation Store that makes
it easy to try out a number of Interchange's features.


%define warning_file %{_docdir}/%{ic_package_basename}-%{version}/WARNING_YOU_ARE_MISSING_SOMETHING
%define filelist_main %{_tmppath}/%{name}-%{version}.filelist

# if user su'd to root but didn't get /usr/sbin added to the PATH,
# we need to get to it on our own
%define useradd %( which useradd || echo /usr/sbin/useradd )

# Find base directory for web files
# Red Hat Linux 7: /var/www
# Red Hat Linux 6: /home/httpd
%define webdir %( if [ -d /var/www ]; then echo -n '/var/www' ; else echo -n '/home/httpd' ; fi )

# This is obviously a terrible oversimplification of whether the build system
# is Red Hat Linux 7 or not, but it has worked so far.
#%define interchange_rpm_subrelease %( if [ "%webdir" = "/var/www" ]; then echo -n rh7 ; else echo -n rh6 ; fi )


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

ETCBASE=/etc
RUNBASE=/var/run
LOGBASE=/var/log
LIBBASE=/var/lib
CACHEBASE=/var/cache
ICBASE=%{_libdir}/interchange

# Create an interch user if one doesn't already exist (on build machine).
if [ -z "`grep '^%{ic_user}:' /etc/passwd`" ]
then
	if [ -n "`grep ^%{ic_group}: /etc/group`" ]
	then
		GROUPOPT='-g %{ic_group}'
	else
		GROUPOPT=
	fi
	%useradd -M -r -d $LIBBASE/interchange -s /bin/bash -c "Interchange server" $GROUPOPT %ic_user
fi

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
make install
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
#bin/compile_link -build src

mkdir -p $RPM_BUILD_ROOT$LIBBASE/interchange
mkdir -p $RPM_BUILD_ROOT$RUNBASE/interchange
mkdir -p $RPM_BUILD_ROOT$LOGBASE/interchange
mkdir -p $RPM_BUILD_ROOT$CACHEBASE/interchange

# Make SysV-style system startup/shutdown script
mkdir -p $RPM_BUILD_ROOT$ETCBASE/rc.d/init.d
cat > $RPM_BUILD_ROOT$ETCBASE/rc.d/init.d/interchange <<EOF
#!/bin/sh
#
# Run control script for Interchange
# http://interchange.redhat.com/
#
# chkconfig: 345 96 4
# description: Interchange is a database access and HTML templating system focused on ecommerce
# processname: interchange
# pidfile: $RUNBASE/interchange/interchange.pid
# config: $ETCBASE/interchange.cfg
# config: $LIBBASE/interchange/*/catalog.cfg

# Source function library.
. /etc/rc.d/init.d/functions

# See how we were called.
case "\$1" in
	start)
		echo -n "Starting Interchange: "
		daemon interchange -q
		echo
		touch /var/lock/subsys/interchange
		;;
	stop)
		echo -n "Shutting down Interchange: "
		killproc interchange
		echo
		rm -f /var/lock/subsys/interchange
		rm -f $RUNBASE/interchange/interchange.pid
		;;
	status)
		status interchange
		;;
	restart)
		\$0 stop
		\$0 start
		;;
	*)
		echo "Usage: \$0 {start|stop|restart|status}"
		exit 1
esac

exit 0
EOF
chmod +x $RPM_BUILD_ROOT$ETCBASE/rc.d/init.d/interchange

# Make log rotation script
mkdir -p $RPM_BUILD_ROOT$ETCBASE/logrotate.d
cat > $RPM_BUILD_ROOT$ETCBASE/logrotate.d/interchange <<EOF
/var/log/interchange/*.log {
	rotate 4
	weekly
	compress
}

/var/log/interchange/*/error.log {
	rotate 4
	weekly
	compress
}

/var/log/interchange/*/logs/usertrack {
	rotate 12
	monthly
	compress
}
EOF

# Make special Interchange start/stop script with RPM-specific paths
mkdir -p $RPM_BUILD_ROOT%{_sbindir}
cat > $RPM_BUILD_ROOT%{_sbindir}/interchange <<EOF
#!/bin/sh

# Interchange control script
# Calls Interchange with special locations of files as installed by RPM
# http://interchange.redhat.com/

RUNSTRING="%{_libdir}/interchange/bin/interchange \\
	-configfile $ETCBASE/interchange.cfg \\
	-pidfile $RUNBASE/interchange/interchange.pid \\
	-logfile $LOGBASE/interchange/error.log \\
	ErrorFile=$LOGBASE/interchange/error.log \\
	PIDfile=$RUNBASE/interchange/interchange.pid \\
	-confdir $ICBASE/etc \\
	-rundir $RUNBASE/interchange \\
	SocketFile=$RUNBASE/interchange/socket \\
	IPCsocket=$RUNBASE/interchange/socket.ipc"

if test "\`whoami\`" = root
then 
	exec su %ic_user -c "\$RUNSTRING \$*"
else
	exec \$RUNSTRING \$*
fi
EOF
chmod +x $RPM_BUILD_ROOT%{_sbindir}/interchange

# Build the demo catalog
HOST=RPM_CHANGE_HOST
BASEDIR=/var/lib/interchange
LOGDIR=/var/log/interchange
CACHEDIR=/var/cache/interchange
DOCROOT=%{webdir}/html
CGIDIR=%{webdir}/cgi-bin
CGIBASE=/cgi-bin
HTTPDCONF=/etc/httpd/conf/httpd.conf
for i in %cat_name
do 
	mkdir -p $RPM_BUILD_ROOT$CGIDIR
	mkdir -p $RPM_BUILD_ROOT$DOCROOT/$i/images
	mkdir -p $RPM_BUILD_ROOT$BASEDIR/$i
	bin/makecat \
		-F \
		--relocate=$RPM_BUILD_ROOT \
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

# Put interchange.cfg in /etc instead of IC software directory
mv interchange.cfg $RPM_BUILD_ROOT$ETCBASE/interchange.cfg
ln -s $ETCBASE/interchange.cfg

# Put global error log in /var/log/interchange instead of IC software directory
RPMICLOG=$LOGBASE/interchange/error.log
rm -f error.log
ln -s $RPMICLOG
touch $RPM_BUILD_ROOT$RPMICLOG
chown %{ic_user}.%ic_group $RPM_BUILD_ROOT$RPMICLOG

# Make a symlink from docroot area into /usr{/share}/doc/interchange-x.x.x.
ln -s %{_docdir}/interchange-%ic_version $RPM_BUILD_ROOT$DOCROOT/interchange/doc

# I don't know of a way to exclude a subdirectory from one of the directories
# listed in the %files section, so I have to use this monstrosity to generate
# a list of all directories in /usr/lib/interchange except the foundation demo
# directory and pass the list to %files below.
DIRDEPTH=`echo $ICBASE | sed 's:[^/]::g' | awk '{print length + 1}'`
cd $RPM_BUILD_ROOT
find . -path .$ICBASE/%cat_name -prune -mindepth $DIRDEPTH -maxdepth $DIRDEPTH \
	-o -print | grep "^\.$ICBASE" | sed 's:^\.::' | \
	sed 's:^\(/usr/lib/interchange/etc\):%attr(-, %{ic_user}, %{ic_group}) \1:' \
	> %filelist_main


%install


%pre

if test -x /etc/rc.d/init.d/interchange
then
	/etc/rc.d/init.d/interchange stop > /dev/null 2>&1
	#echo "Giving interchange a couple of seconds to exit nicely" >&2
	sleep 5
fi

# Create an interch user if one doesn't already exist (on install machine).
if [ -z "`grep '^%{ic_user}:' /etc/passwd`" ]
then
	if [ -n "`grep ^%{ic_group}: /etc/group`" ]
	then
		GROUPOPT='-g %{ic_group}'
	else
		GROUPOPT=
	fi
	%useradd -M -r -d /var/lib/interchange -s /bin/bash -c "Interchange server" $GROUPOPT %ic_user 2> /dev/null || true 
fi


%ifarch noarch

%files -f %filelist_main

%defattr(-, %{ic_user}, %{ic_group})

%dir /var/run/interchange
%dir /var/cache/interchange
%dir /var/log/interchange
%dir /var/lib/interchange
/var/log/interchange/error.log
%config(noreplace) /etc/interchange.cfg
%{webdir}/html/interchange

%defattr(-, root, root)

%doc LICENSE
%doc README
%doc README.rpm
%doc README.cvs
%doc WHATSNEW
%{_mandir}/man1
%{_mandir}/man8
%config(noreplace) /etc/rc.d/init.d/interchange
%config(noreplace) /etc/logrotate.d/interchange
%config(noreplace) %{_sbindir}/interchange
%dir %{_libdir}/interchange


%files %cat_name

%defattr(-, root, root)
%{_libdir}/interchange/%cat_name

%endif


%ifarch i386

%files %{cat_name}-demo

%defattr(-, %{ic_user}, %{ic_group})
/var/lib/interchange/%cat_name
/var/log/interchange/%cat_name
/var/cache/interchange/%cat_name
%{webdir}/html/%cat_name
%{webdir}/cgi-bin/%cat_name

%endif


%post

# Make Interchange start/stop automatically with the operating system.
/sbin/chkconfig --add interchange

# Get to a place where no random Perl libraries should be found
cd /usr

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

status=`perl -e "require Storable and print 1;" 2>/dev/null`
if test "x$status" != x1
then
	rm -f %{_libdir}/interchange/_*storable
fi

missing=
for i in Digest::MD5 MIME::Base64 URI::URL SQL::Statement Safe::Hole
do
	status=`perl -e "require $i and print 1;" 2>/dev/null`
	if test "x$status" != x1
	then
		missing="$missing $i"
	fi
done

if test -n "$missing"
then
	{
		echo ""
		echo "Missing Perl modules:"
		echo ""
		echo "$missing"
		echo ""
		echo "Interchange catalogs will work without them, but the admin interface will not."
		echo "You need to install these modules before you can use the admin interface."
		echo ""
		echo "You can find the appropriate RPM packages at:"
		echo ""
		echo "http://interchange.redhat.com/"
		echo ""
		echo "Or, as a last resort, you can build and install them from source. Try:"
		echo ""
		echo 'perl -MCPAN -e "install Bundle::Interchange"'
		echo ""
	} > %warning_file
fi


%post %{cat_name}-demo

HOST=`hostname`
perl -pi -e "s/RPM_CHANGE_HOST/$HOST/g" \
	/var/lib/interchange/%{cat_name}/catalog.cfg \
	/var/lib/interchange/%{cat_name}/products/*.txt \
	/var/lib/interchange/%{cat_name}/products/*.asc \
	/var/lib/interchange/%{cat_name}/config/* \
	%{webdir}/html/%{cat_name}/index.html

for i in %cat_name
do 
	# Add the new catalog to the running Interchange daemon
	if test -x /etc/rc.d/init.d/interchange && test -n \
		"`/etc/rc.d/init.d/interchange status | grep 'interchange.*is running'`"
	then
		catline="`grep \"^[ \t]*Catalog[ \t][ \t]*$i[ \t]\" /etc/interchange.cfg`"
		if [ -n "$catline" ]
		then
			echo "$catline" | %{_sbindir}/interchange --add=$i > /dev/null 2>&1
		fi
	fi
done


%preun

if test -x /etc/rc.d/init.d/interchange
then
	# Stop Interchange if running
	/etc/rc.d/init.d/interchange stop > /dev/null
	# Remove autostart of interchange
	/sbin/chkconfig --del interchange
fi

# Remove non-user data
rm -rf /var/run/interchange/*
rm -rf /var/cache/interchange/*
rm -rf %{_libdir}/interchange/lib/HTML
rm -f %warning_file


%preun %{cat_name}-demo

for i in %cat_name
do
	# Remove catalog from running Interchange
	if test -x /etc/rc.d/init.d/interchange && test -n \
		"`/etc/rc.d/init.d/interchange status | grep 'interchange.*is running'`"
	then
		if test -x %{_sbindir}/interchage
		then
			%{_sbindir}/interchange --remove=$i > /dev/null 2>&1
		fi
	fi

	# Remove Catalog directive from interchange.cfg
	ICCFG=/etc/interchange.cfg
	if [ -f $ICCFG ]
	then
		ICCFGTMP=/tmp/rpm.$$.interchange.cfg
		grep -v "^[ \t]*Catalog[ \t][ \t]*$i[ \t]" $ICCFG > $ICCFGTMP && \
			chown --reference=$ICCFG $ICCFGTMP && \
			chmod --reference=$ICCFG $ICCFGTMP && \
			mv $ICCFGTMP $ICCFG
	fi

	# Remove leftover machine-generated files
	rm -rf /var/cache/interchange/$i/tmp/*
	rm -rf /var/cache/interchange/$i/session/*
	rm -rf /var/log/interchange/$i/orders/*
	rm -rf /var/log/interchange/$i/logs/*
	rm -rf /var/lib/interchange/$i/products/*.db
	rm -rf /var/lib/interchange/$i/products/products.txt.*
	rm -rf /var/lib/interchange/$i/products/*.autonumber
	rm -rf /var/lib/interchange/$i/products/*.numeric
	rm -rf /var/lib/interchange/$i/etc/status.$i
done


%clean

rm -f %filelist_main
[ "$RPM_BUILD_ROOT" != "/" ] && rm -rf $RPM_BUILD_ROOT


%changelog

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
