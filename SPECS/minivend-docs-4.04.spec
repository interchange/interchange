%define minivend_version 4.04
%define minivend_release 1
%define minivend_package minivend
%define mvdocs_name mvdocs

Name: minivend-docs
Summary:	Extended documentation for Interchange
Group:		Applications/Internet
Version: %{minivend_version}
Copyright: GNU General Public License
Release: %{minivend_release}
URL: http://www.minivend.com
Packager: Mike Heins <nospam@minivend.com>
Source: http://larry.minivend.com/mvdocs-4.04.tar.gz
Provides: minivend-docs
Obsoletes: minivend-docs

BuildRoot: /var/tmp/minivend_docs

# From the manual
%description
Provides the complete documentation for Interchange in HTML.
Use either:

	file:/usr/doc/%{minivend_package}-%{minivend_version}/index.html

or

	http://localhost/docs/minivend/

%setup

%build
tar xzvf ../SOURCES/mvdocs-%{minivend_version}.tar.gz
RBR=$RPM_BUILD_ROOT
if test -z "$RBR" -o "$RBR" = "/"
then
	echo "RPM_BUILD_ROOT has stupid value"
	exit 1
fi
rm -rf $RBR
mkdir -p $RBR/home/httpd/html/docs/minivend
cp -ra mvdocs-%{minivend_version}/* $RBR/home/httpd/html/docs/minivend
chown -R root.root $RBR/home/httpd/html/docs/minivend

%install

%files
/home/httpd/html/docs/minivend

%post
mkdir -p /usr/doc/%{minivend_package}-%{minivend_version}
cp -ra /home/httpd/html/docs/minivend/* /usr/doc/%{minivend_package}-%{minivend_version}

%preun
rm -rf /usr/doc/%{minivend_package}-%{minivend_version}
