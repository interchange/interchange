%define interchange_version		4.5.8
%define interchange_package		interchange
%define interchange_user		interch
%define build_cats				construct

%define see_base For a description of Interchange see http://www.akopia.com/

Name: interchange
Summary: Interchange is a powerful database access and HTML templating daemon focused on e-commerce.
Group: Applications/Internet
Version: 4.5.8
Copyright: GNU General Public License
Release: 1.rh6
URL: http://developer.akopia.com/
Packager: Akopia <info@akopia.com>
Distribution: Red Hat Linux Applications CD
Vendor: Akopia, Inc.
Source: http://ftp.minivend.com/interchange/beta/interchange-4.5.8.tar.gz
Provides: interchange
Obsoletes: interchange

BuildRoot: /var/tmp/interchange

%description
Interchange is the most powerful free ecommerce system available today.
Its features and power rival the costliest commercial systems.

%prep
%setup

%build
mkdir -p $RPM_BUILD_ROOT
perl Makefile.PL \
	rpmbuilddir=$RPM_BUILD_ROOT \
	INTERCHANGE_USER=%{interchange_user} \
	PREFIX=$RPM_BUILD_ROOT/usr/lib/interchange \
	INSTALLMAN1DIR=$RPM_BUILD_ROOT/usr/man/man1 \
	INSTALLMAN3DIR=$RPM_BUILD_ROOT/usr/man/man8 \
	force=1
make > /dev/null
make test
RBR=$RPM_BUILD_ROOT
MBD=$RPM_BUILD_DIR/%{interchange_package}-%{version}
if test -z "$RBR" -o "$RBR" = "/"
then
	echo "RPM_BUILD_ROOT has stupid value"
	exit 1
fi
rm -rf $RBR
mkdir -p $RBR
make install
gzip $RBR/usr/man/man*/* 2>/dev/null
cp extra/HTML/Entities.pm $RBR/usr/lib/interchange/build
cp extra/IniConf.pm $RBR/usr/lib/interchange/build
chown -R root.root $RBR
cd $RBR/usr/lib/interchange
export PERL5LIB=$RBR/usr/lib/interchange/lib
export MINIVEND_ROOT=$RBR/usr/lib/interchange
perl -pi -e 's:^\s+LINK_FILE\s+=>.*:	LINK_FILE => "/var/run/interchange/socket",:' bin/compile_link
bin/compile_link -build src
sh build/makedirs.redhat
sh build/makecat.redhat %{build_cats} 2>/dev/null
find $RBR/var/lib/interchange -type d | xargs chmod 755
find $RBR/usr/lib/interchange/bin -type f | xargs chmod 755

#mkdir $RBR/var/log/interchange
for i in %{build_cats}
do
	touch $RBR/var/log/interchange/$i.error.log
	ln -s ../../../log/$i.error.log $RBR/var/lib/interchange/$i/error.log
done
mv interchange.cfg $RBR/etc/interchange.cfg
ln -s /etc/interchange.cfg .
rm -f error.log
ln -s /var/log/interchange/error.log .
chmod +r $RBR/etc/interchange.cfg

%install

%pre
if test -x /etc/rc.d/init.d/interchange
then
  /etc/rc.d/init.d/interchange stop > /dev/null 2>&1
  #echo "Giving interchange a couple of seconds to exit nicely"
  sleep 5
fi

# Create an interch user. Do not report any problems if it already
# exists. We do it first so it won't error on chmod
useradd -M -r -d /var/lib/interchange -s /bin/bash -c "Interchange server" %{interchange_user} 2> /dev/null || true 

%files
%doc QuickStart
%doc WHATSNEW
%doc README
%doc README.rpm
%doc README.cvs
%doc pdf/icbackoffice.pdf
%doc pdf/icconfig.pdf
%doc pdf/icdatabase.pdf
%doc pdf/icinstall.pdf
%doc pdf/icintro.pdf
%doc pdf/ictemplates.pdf
%config(noreplace) /etc/interchange.cfg
%config(noreplace) /etc/logrotate.d/interchange
%config /etc/rc.d/init.d/interchange
/home/httpd/cgi-bin/construct
/home/httpd/html/construct
/home/httpd/html/akopia
/var/lib/interchange/construct
/usr/sbin/interchange
/usr/lib/interchange
/usr/man/man1
/usr/man/man8
%dir /var/lib/interchange
/var/log/interchange
/var/run/interchange

%post
# Make Interchange start/shutdown automatically when the machine does it.
/sbin/chkconfig --add interchange

# Change permissions so that the user that will run the Interchange daemon
# owns all database files.
chown -R %{interchange_user}.%{interchange_user} /var/lib/interchange
chown -R %{interchange_user}.%{interchange_user} /var/log/interchange
chown -R %{interchange_user}.%{interchange_user} /var/run/interchange

for i in %{build_cats}
do
	ln -s /home/httpd/html/$i/images /var/lib/interchange/$i
	chown %{interchange_user}.%{interchange_user} /home/httpd/cgi-bin/$i
	chmod 4755 /home/httpd/cgi-bin/$i
done

# Set the hostname
HOST=`hostname`
perl -pi -e "s/RPM_CHANGE_HOST/$HOST/g"	/var/lib/interchange/*/catalog.cfg /var/lib/interchange/*/products/variable.txt /home/httpd/html/construct/index.html

# Get to a place where no random Perl libraries should be found
cd /usr

status=`perl -e "require HTML::Entities and print 1;" 2>/dev/null`
if test "x$status" != x1
then
	mkdir -p /usr/lib/interchange/lib/HTML 2>/dev/null
	cp /usr/lib/interchange/build/Entities.pm /usr/lib/interchange/lib/HTML 2>/dev/null
fi

status=`perl -e "require IniConf and print 1;" 2>/dev/null`
if test "x$status" != x1
then
	cp /usr/lib/interchange/build/IniConf.pm /usr/lib/interchange/lib 2>/dev/null
fi

status=`perl -e "require Storable and print 1;" 2>/dev/null`
if test "x$status" != x1
then
	rm -f /usr/lib/interchange/_*storable
fi

missing=
for i in MD5 MIME::Base64 URI::URL SQL::Statement Safe::Hole
do
    status=`perl -e "require $i and print 1;" 2>/dev/null`
    if test "x$status" = x1
    then
        echo > /dev/null
    else
		missing="$missing $i"
    fi
done

WARNDEST=/usr/doc/%{interchange_package}-%{version}/WARNING_YOU_ARE_MISSING_SOMETHING
if test -n "$missing"
then
        echo "" >> $WARNDEST
        echo "MISSING Perl modules:"  >> $WARNDEST
        echo ""  >> $WARNDEST
	echo "$missing"  >> $WARNDEST
        echo ""  >> $WARNDEST
        echo "Interchange catalogs will work without them, but the admin interface"  >> $WARNDEST
	echo "will not. You need to install them for the UI to work."  >> $WARNDEST
	echo ""  >> $WARNDEST
	echo "Try:"  >> $WARNDEST
	echo ""  >> $WARNDEST
	echo " perl -MCPAN -e \"install Bundle::Interchange\""  >> $WARNDEST
	echo ""  >> $WARNDEST
fi

# Restart in the same way that interchange will be started normally.
# Would like to start, but then cannot pass RedHat tests
#/etc/rc.d/init.d/interchange start >/dev/null 2>/dev/null

# Allow Interchange to start and print a message before we exit
#sleep 2
#echo ""
#echo You should now be able to access the Interchange demos with:
#echo ""
#echo "	http://$HOST/construct"

%preun
if test -x /etc/rc.d/init.d/interchange
then
  /etc/rc.d/init.d/interchange stop > /dev/null
fi
# Remove autostart of interchange
if test $1 = 0
then
   /sbin/chkconfig --del interchange
fi

rm -rf /var/run/interchange/*
rm -rf /var/lib/interchange/*/images
rm -rf /usr/lib/interchange/lib/HTML
