%define interchange_version		4.6.5
%define interchange_rpm_release	1
%define interchange_package		interchange
%define interchange_user		interch
%define build_cats				construct

# Relevant differences between Red Hat 6 and Red Hat 7 file layout:
# /home/httpd -> /var/www
# /usr/man    -> /usr/share/man
# /usr/doc    -> /usr/share/doc

%define webdir %( if [ -d /var/www ]; then echo -n '/var/www' ; else echo -n '/home/httpd' ; fi )

# This is obviously a terrible oversimplification of whether a system
# is Red Hat 7 or not, but it's worked so far.
%define interchange_rpm_subrelease %( if [ "%webdir" = "/var/www" ]; then echo -n rh7 ; else echo -n rh6 ; fi )

Name: %interchange_package
Version: %interchange_version
Release: %{interchange_rpm_release}.%interchange_rpm_subrelease
Summary: Interchange is a powerful database access and HTML templating daemon focused on ecommerce.
Vendor: Akopia, Inc.
Copyright: GNU General Public License
URL: http://developer.akopia.com/
Packager: Akopia <info@akopia.com>
Source: http://ftp.minivend.com/interchange/interchange-%{interchange_version}.tar.gz
Group: Applications/Internet
Distribution: Red Hat Linux Applications CD
Provides: %interchange_package
Obsoletes: %interchange_package

BuildRoot: /var/tmp/interchange

%description
Interchange is the most powerful free ecommerce system available today.
Its features and power rival costly commercial systems.

%define warning_file %{_docdir}/%{interchange_package}-%{version}/WARNING_YOU_ARE_MISSING_SOMETHING


%prep


%setup


%build

if test -z "$RPM_BUILD_ROOT" -o "$RPM_BUILD_ROOT" = "/"
then
	echo "RPM_BUILD_ROOT has stupid value"
	exit 1
fi
rm -rf $RPM_BUILD_ROOT
mkdir -p $RPM_BUILD_ROOT

if test -n "$RPM_RUN_BASE"
then
	RUNBASE=$RPM_RUN_BASE
else
	RUNBASE=/var/run
fi

if test -n "$RPM_LOG_BASE"
then
	LOGBASE=$RPM_LOG_BASE
else
	LOGBASE=/var/log
fi

if test -n "$RPM_LIB_BASE"
then
	LIBBASE=$RPM_LIB_BASE
else
	LIBBASE=/var/lib
fi

if test -n "$RPM_ETC_BASE"
then
	ETCBASE=$RPM_ETC_BASE
else
	ETCBASE=/etc
fi

# Create an interch user if one doesn't already exist (on build machine).
if [ -n "$RPM_BUILD_ROOT" ] && [ -z "`grep '^%{interchange_user}:' /etc/passwd`" ]
then
	if [ -n "`grep ^%{interchange_user}: /etc/group`" ]
	then
		GROUPOPT='-g %{interchange_user}'
	else
		GROUPOPT=
	fi
	useradd -M -r -d $LIBBASE/interchange -s /bin/bash -c "Interchange server" $GROUPOPT %interchange_user
fi

perl Makefile.PL \
	rpmbuilddir=$RPM_BUILD_ROOT \
	INTERCHANGE_USER=%interchange_user \
	PREFIX=$RPM_BUILD_ROOT/%{_prefix}/lib/interchange \
	INSTALLMAN1DIR=$RPM_BUILD_ROOT/%{_mandir}/man1 \
	INSTALLMAN3DIR=$RPM_BUILD_ROOT/%{_mandir}/man8 \
	force=1
make > /dev/null
make test
make install
gzip $RPM_BUILD_ROOT%{_mandir}/man*/* 2>/dev/null
mkdir -p $RPM_BUILD_ROOT/%{_prefix}/lib/interchange/build
cp extra/HTML/Entities.pm $RPM_BUILD_ROOT/%{_prefix}/lib/interchange/build
cp extra/IniConf.pm $RPM_BUILD_ROOT/%{_prefix}/lib/interchange/build
cp -a eg extensions $RPM_BUILD_ROOT/%{_prefix}/lib/interchange
chown -R root.root $RPM_BUILD_ROOT
cd $RPM_BUILD_ROOT/%{_prefix}/lib/interchange
export PERL5LIB=$RPM_BUILD_ROOT/%{_prefix}/lib/interchange/lib
export MINIVEND_ROOT=$RPM_BUILD_ROOT/%{_prefix}/lib/interchange
perl -pi -e 's:^\s+LINK_FILE\s+=>.*:	LINK_FILE => "/var/run/interchange/socket",:' bin/compile_link
bin/compile_link -build src


ETCDIRS="rc.d/init.d logrotate.d"
LIBDIRS="interchange"
ICDIRS="$RPM_BUILD_ROOT$RUNBASE/interchange $RPM_BUILD_ROOT$LOGBASE/interchange"

for i in $ETCDIRS
do
	mkdir -p $RPM_BUILD_ROOT$ETCBASE/$i
done

for i in $LIBDIRS
do
	mkdir -p $RPM_BUILD_ROOT$LIBBASE/$i
done

for i in $ICDIRS
do
	mkdir -p $i
	if test -z "$RPM_BUILD_DIR"
	then
		chown %{interchange_user}.%interchange_user $i
		chmod 751 $i
	fi
done

mkdir -p $RPM_BUILD_ROOT$ETCBASE/rc.d/init.d
mkdir -p $RPM_BUILD_ROOT/usr/sbin

cat > $RPM_BUILD_ROOT$ETCBASE/rc.d/init.d/interchange <<EOF
#!/bin/sh
#
# Startup script for Interchange
# http://developer.akopia.com/
#
# chkconfig: 345 96 4
# description: Interchange is a database access and HTML templating system focused on ecommerce
# processname: interchange
# pidfile: $RUNBASE/interchange/interchange.pid
# config: $ETCBASE/interchange.cfg
# config: $LIBBASE/interchange/*/catalog.cfg


# Source function library.
. /etc/rc.d/init.d/functions

# Handle /usr/local
PATH=\$PATH:/usr/local/bin

# See how we were called.
case "\$1" in
  start)
	echo -n "Starting interchange: "
	daemon interchange
	echo
	touch /var/lock/subsys/interchange
	;;
  stop)
	echo -n "Shutting down interchange: "
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

cat > $RPM_BUILD_ROOT/etc/logrotate.d/interchange <<EOF
/var/log/interchange/*log {
        rotate 4
        weekly
        compress
}
EOF

cat > $RPM_BUILD_ROOT/usr/sbin/interchange <<EOF
#!/bin/sh

RUNSTRING="/usr/lib/interchange/bin/interchange -q \\
	-configfile $ETCBASE/interchange.cfg \\
	-pidfile $RUNBASE/interchange/interchange.pid \\
	-logfile $LOGBASE/interchange/error.log \\
	ErrorFile=$LOGBASE/interchange/error.log \\
	PIDfile=$RUNBASE/interchange/interchange.pid \\
	-confdir $RUNBASE/interchange \\
	SocketFile=$RUNBASE/interchange/socket"

USER=\`whoami\`
if test \$USER = "root"
then 
	exec su %interchange_user -c "\$RUNSTRING \$*"
else
	exec \$RUNSTRING \$*
fi
EOF

chmod +x $RPM_BUILD_ROOT$ETCBASE/rc.d/init.d/interchange $RPM_BUILD_ROOT/usr/sbin/interchange

DOCROOT=%{webdir}/html
CGIDIR=%{webdir}/cgi-bin
SERVERCONF=/etc/httpd/conf/httpd.conf
CGIBASE=/cgi-bin
HOST=RPM_CHANGE_HOST
BASEDIR=/var/lib/interchange

for i in %build_cats
do 
	mkdir -p $RPM_BUILD_ROOT$CGIDIR
	mkdir -p $RPM_BUILD_ROOT$DOCROOT/$i/images
	mkdir -p $RPM_BUILD_ROOT$BASEDIR/$i
	bin/makecat \
		-F \
		--cgibase=$CGIBASE \
		--basedir=$BASEDIR \
		--documentroot=$DOCROOT \
		--sharedir=$DOCROOT \
		--shareurl=/ \
		--interchangeuser=%interchange_user \
		--interchangegroup=%interchange_user \
		--serverconf=$SERVERCONF \
		--vendroot=/usr/lib/interchange \
		--catroot=$BASEDIR/$i \
		--cgidir=$CGIDIR \
		--relocate=$RPM_BUILD_ROOT \
		--servername=$HOST \
		--cgiurl=$CGIBASE/$i \
		--demotype=$i \
		--mailorderto=%{interchange_user}@$HOST \
		--catuser=%interchange_user \
		--permtype=user \
		--samplehtml=$DOCROOT/$i \
		--imagedir=$DOCROOT/$i/images \
		--imageurl=/$i/images \
		--linkmode=UNIX \
		--sampleurl=http://$HOST/$i \
		--catalogname=$i
done

find $RPM_BUILD_ROOT/var/lib/interchange -type d | xargs chmod 755
find $RPM_BUILD_ROOT/%{_prefix}/lib/interchange/bin -type f | xargs chmod 755

for i in %build_cats
do
	touch $RPM_BUILD_ROOT/var/log/interchange/$i.error.log
	ln -s ../../../log/interchange/$i.error.log $RPM_BUILD_ROOT/var/lib/interchange/$i/error.log
done
mv interchange.cfg $RPM_BUILD_ROOT/etc/interchange.cfg
ln -s /etc/interchange.cfg .
rm -f error.log
ln -s /var/log/interchange/error.log .
chmod +r $RPM_BUILD_ROOT/etc/interchange.cfg


%install


%pre

if test -x /etc/rc.d/init.d/interchange
then
	/etc/rc.d/init.d/interchange stop > /dev/null 2>&1
	#echo "Giving interchange a couple of seconds to exit nicely"
	sleep 5
fi

# Create an interch user if one doesn't already exist (on install machine).
if [ -n "`grep ^%{interchange_user}: /etc/group`" ]
then
	GROUPOPT='-g %{interchange_user}'
else
	GROUPOPT=
fi
useradd -M -r -d /var/lib/interchange -s /bin/bash -c "Interchange server" $GROUPOPT %interchange_user 2> /dev/null || true 


%files

%doc QuickStart
%doc LICENSE
%doc README
%doc README.rpm
%doc README.cvs
%doc UPGRADE_FROM_MV3
%doc WHATSNEW
%doc pdf/icbackoffice.pdf
%doc pdf/icconfig.pdf
%doc pdf/icdatabase.pdf
%doc pdf/icinstall.pdf
%doc pdf/icintro.pdf
%doc pdf/ictemplates.pdf
%config(noreplace) /etc/interchange.cfg
%config(noreplace) /etc/logrotate.d/interchange
%config /etc/rc.d/init.d/interchange
%{webdir}/cgi-bin/construct
%{webdir}/html/construct
%{webdir}/html/akopia
/var/lib/interchange/construct
%{_prefix}/sbin/interchange
%{_prefix}/lib/interchange
%{_mandir}/man1
%{_mandir}/man8
%dir /var/lib/interchange
/var/log/interchange
/var/run/interchange


%post

# Make Interchange start/stop automatically with the operating system.
/sbin/chkconfig --add interchange

# Change permissions so that the user that will run the Interchange daemon
# owns all database files.
chown -R %{interchange_user}.%interchange_user /var/lib/interchange
chown -R %{interchange_user}.%interchange_user /var/log/interchange
chown -R %{interchange_user}.%interchange_user /var/run/interchange

for i in %build_cats
do
	ln -s %{webdir}/html/$i/images /var/lib/interchange/$i
	chown %{interchange_user}.%interchange_user %{webdir}/cgi-bin/$i
	chmod 4755 %{webdir}/cgi-bin/$i
done

# Set the hostname
HOST=`hostname`
perl -pi -e "s/RPM_CHANGE_HOST/$HOST/g"	/var/lib/interchange/*/catalog.cfg /var/lib/interchange/*/products/variable.txt %{webdir}/html/construct/index.html

# Get to a place where no random Perl libraries should be found
cd /usr

status=`perl -e "require HTML::Entities and print 1;" 2>/dev/null`
if test "x$status" != x1
then
	mkdir -p %{_prefix}/lib/interchange/lib/HTML 2>/dev/null
	cp %{_prefix}/lib/interchange/build/Entities.pm %{_prefix}/lib/interchange/lib/HTML 2>/dev/null
fi

status=`perl -e "require IniConf and print 1;" 2>/dev/null`
if test "x$status" != x1
then
	cp %{_prefix}/lib/interchange/build/IniConf.pm %{_prefix}/lib/interchange/lib 2>/dev/null
fi

status=`perl -e "require Storable and print 1;" 2>/dev/null`
if test "x$status" != x1
then
	rm -f %{_prefix}/lib/interchange/_*storable
fi

missing=
for i in MD5 MIME::Base64 URI::URL SQL::Statement Safe::Hole
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
		echo "Interchange catalogs will work without them, but the admin interface"
		echo "will not. You need to install them for the UI to work."
		echo ""
		echo "Try:"
		echo ""
		echo 'perl -MCPAN -e "install Bundle::Interchange"'
		echo ""
	} > %warning_file
fi


%preun

# Stop Interchange if running
if test -x /etc/rc.d/init.d/interchange
then
	/etc/rc.d/init.d/interchange stop > /dev/null
fi

# Remove autostart of interchange
if test $1 = 0
then
	/sbin/chkconfig --del interchange
fi

# Remove non-user data
rm -rf /var/run/interchange/*
rm -rf /var/lib/interchange/*/images
rm -rf %{_prefix}/lib/interchange/lib/HTML
rm -f %warning_file
rm -f /var/log/interchange/error.log

# Remove construct demo stuff -- we'd rather not do this, but
# Red Hat's certification tests require no files be left over
DEMOCATDIR=/var/lib/interchange/construct
rm -rf $DEMOCATDIR/tmp/* $DEMOCATDIR/session/* $DEMOCATDIR/logs/*
rm -f $DEMOCATDIR/products/*.gdbm $DEMOCATDIR/products/Ground.csv.numeric $DEMOCATDIR/products/products.txt.*
rm -f $DEMOCATDIR/etc/status.construct


%changelog
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
