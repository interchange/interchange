Summary: Apache Module to link with Interchange
Name: mod_interchange
Version: 1.30
Release: 1
License: GPL
Group: WWW/Applications
Source: http://ftp.icdevgroup.org/interchange/%{name}-%{version}.tar.gz
URL: http://www.icdevgroup.org/
BuildRoot: /var/tmp/%{name}-%{version}-root

%description
Apache module that replaces the tlink and vlink program from the 
Interchange distribution.

Please note that this module is not compatible with Apache 2.

%prep
%setup -q

%build
/usr/sbin/apxs -c mod_interchange.c

%install
rm -fr $RPM_BUILD_ROOT

mkdir -p $RPM_BUILD_ROOT/usr/lib/apache
install -m 755 mod_interchange.so $RPM_BUILD_ROOT/usr/lib/apache

mkdir -p $RPM_BUILD_ROOT/home/httpd/html/manual/mod
install -m 644 mod_interchange.html $RPM_BUILD_ROOT/home/httpd/html/manual/mod

%clean
rm -fr $RPM_BUILD_ROOT

%files
%defattr(-,root,root)
/usr/lib/apache/mod_interchange.so
/home/httpd/html/manual/mod/mod_interchange.html

%changelog
* Fri Mar 26 2004  Kevin Walsh <kevin@cursor.biz>
  [1.30]
- Added a note to point out that this module is not compatible with Apache 2.

* Mon Feb 12 2001  Jon Jensen <jon@akopia.com>
  [1.04-1]
- Renamed to mod_interchange.

* Mon Aug 02 1999  Francis J. Lacoste <francis.lacoste@iNsu.COM> 
  [1.03-1i]
- Last bugfixes.

* Mon Aug 02 1999  Francis J. Lacoste <francis.lacoste@iNsu.COM> 
  [1.02-1i]
- Fixed spec files bugs.

* Mon Aug 02 1999  Francis J. Lacoste <francis.lacoste@iNsu.COM> 
  [1.00-1i]
- Packaged for iNs/linux.
