%define minivend_version		4.04
%define minivend_user		minivend
%define build_cats          basic simple

%define see_base For a description of Minivend see http://www.minivend.com

Name: minivend
Summary:	Minivend is a powerful database access and HTML templating daemon focused on e-commerce.
Group:		Applications/Internet
Version: 4.04
Copyright: GNU General Public License
Release: 1
URL: http://www.minivend.com/
Packager: Mike Heins <nospam@minivend.com>
Source: http://larry.minivend.com/minivend-4.04.tar.gz
Provides: minivend
Obsoletes: minivend MiniMate

BuildRoot: /var/tmp/minivend

# From the manual
%description
MiniVend is the most powerful free shopping cart system available today. Its features
and power rival the costliest commercial systems.

MiniMate is the companion administration application for Minivend.

%prep
%setup

%build
mkdir -p $RPM_BUILD_ROOT
perl Makefile.PL \
	rpmbuilddir=$RPM_BUILD_ROOT \
	MINIVEND_USER=minivend \
	PREFIX=$RPM_BUILD_ROOT/usr/local/minivend \
	INSTALLMAN1DIR=$RPM_BUILD_ROOT/usr/local/man/man1 \
	INSTALLMAN3DIR=$RPM_BUILD_ROOT/usr/local/man/man8 \
	force=1
make > /dev/null
make test
RBR=$RPM_BUILD_ROOT
MBD=$RPM_BUILD_DIR/%{package}-%{version}
if test -z "$RBR" -o "$RBR" = "/"
then
	echo "RPM_BUILD_ROOT has stupid value"
	exit 1
fi
rm -rf $RBR
mkdir -p $RBR
make install
cp extra/HTML/Entities.pm $RBR/usr/local/minivend/build
cp extra/IniConf.pm $RBR/usr/local/minivend/build
chown -R root.root $RBR
cd $RBR/usr/local/minivend
export PERL5LIB=$RBR/usr/local/minivend/lib
export MINIVEND_ROOT=$RBR/usr/local/minivend
perl -pi -e 's:^\s+LINK_FILE\s+=>.*:	LINK_FILE => "/var/run/minivend/socket",:' bin/compile_link
bin/compile_link -build src
sh build/makedirs.redhat
sh build/makecat.redhat %{build_cats}

for i in %{build_cats}
do
	ln -s /var/log/minivend/$i.error.log $RBR/var/lib/minivend/$i/error.log
done
mv minivend.cfg $RBR/etc/minivend.cfg
ln -s /etc/minivend.cfg .
rm -f error.log
ln -s /var/log/minivend/error.log .
chmod +r $RBR/etc/minivend.cfg

%install

%pre
if test -x /etc/rc.d/init.d/minivend
then
  /etc/rc.d/init.d/minivend stop > /dev/null 2>&1
  echo "Giving minivend a couple of seconds to exit nicely"
  sleep 5
fi

# Create a minivend user. Do not report any problems if it already
# exists. We do it first so it won't error on chmod
useradd -M -r -d /var/lib/minivend -s /bin/bash -c "Minivend server" minivend 2> /dev/null || true 

%files
%config(noreplace) /etc/minivend.cfg
%config(noreplace) /etc/logrotate.d/minivend
%config(missingok) /usr/local/minivend/lib/IniConf.pm
%config(missingok) /usr/local/minivend/lib/HTML/Entities.pm
/etc/rc.d/init.d/minivend
/home/httpd/cgi-bin/basic
/home/httpd/cgi-bin/simple
/home/httpd/html/basic
/home/httpd/html/simple
/var/lib/minivend/basic
/var/lib/minivend/simple
/usr/local/bin/minivend
/usr/local/minivend
/usr/local/man/man1
/usr/local/man/man8
%dir /var/lib/minivend
/var/log/minivend
/var/run/minivend

%post
# Make Minivend start/shutdown automatically when the machine does it.
/sbin/chkconfig --add minivend

# Change permissions so that the user that will run the Minivend daemon
# owns all database files.
chown -R minivend.minivend /var/lib/minivend
chown -R minivend.minivend /var/log/minivend
chown -R minivend.minivend /var/run/minivend

for i in %{build_cats}
do
	chown minivend.minivend /home/httpd/cgi-bin/$i
	chmod 4755 /home/httpd/cgi-bin/$i
done

# Set the hostname
HOST=`hostname`
perl -pi -e "s/RPM_CHANGE_HOST/$HOST/g"	/var/lib/minivend/*/catalog.cfg /home/httpd/html/basic/index.html /home/httpd/html/simple/index.html

# Get to a place where no random Perl libraries should be found
chdir /usr

status=`perl -e "require HTML::Entities and print 1;" 2>/dev/null`
if test "x$status" != x1
then
	mkdir -p /usr/local/minivend/lib/HTML 2>/dev/null
	cp /usr/local/minivend/build/Entities.pm /usr/local/minivend/lib/HTML
fi

status=`perl -e "require IniConf and print 1;" 2>/dev/null`
if test "x$status" != x1
then
	cp /usr/local/minivend/build/IniConf.pm /usr/local/minivend/lib
fi

status=`perl -e "require Storable and print 1;" 2>/dev/null`
if test "x$status" != x1
then
	rm -f /usr/local/minivend/_*storable
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

if test -n "$missing"
then
        echo "Minivend will work without them, but it will work much"
		echo "better if you install these Perl modules:"
		echo ""
		echo "$missing"
		echo ""
		echo "Try:"
		echo ""
		echo " perl -MCPAN -e \"install Bundle::Minivend\""
		echo ""
fi

# Restart in the same way that minivend will be started normally.
/etc/rc.d/init.d/minivend start

# Allow minivend to start and print a message before we exit
sleep 2
echo ""
echo You should now be able to access the Minivend demos with:
echo ""
echo "	http://$HOST/basic"
echo "	http://$HOST/simple"

%preun
if test -x /etc/rc.d/init.d/minivend
then
  /etc/rc.d/init.d/minivend stop > /dev/null
fi
# Remove autostart of minivend
if test $1 = 0
then
   /sbin/chkconfig --del minivend
fi

rm -rf /var/run/minivend/*
rm -rf /usr/local/minivend/lib/HTML
