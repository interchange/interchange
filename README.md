# Interchange

Interchange is a web application server, electronic catalog and database
display system. Features include:

* online ordering
* real-time credit card processing hooks
* high-level database access and retrieval with SQL support
* product categorizing, merchandising, and discounting
* basic customer relationship management
* dynamic content presentation
* content management
* internationalization and localization support
* real-time tax and shipping hooks
* reporting
* web-based administration

## License

Licensed under GPLv2. This program is offered without warranty of any kind.
See file LICENSE for redistribution terms.

Copyright (C) 2002-2019 Interchange Development Group  
Copyright (C) 1996-2002 Red Hat, Inc.  
Originally based on Vend 0.2 and 0.3, copyright 1995-96 by Andrew M. Wilcox.

## Documentation

More information is in the following files:

### README.rpm-dist

Notes on using Interchange when installed from RPM packages.

### README.debian

Notes on using Interchange when installed from Debian packages.

### README-DEVELOPMENT

How to access the Git repository to track ongoing development.

### doc/WHATSNEW-\*

Changes per specified version family.

### UPGRADE

Instructions on how to upgrade from an earlier Interchange version.

A documentation package is available, with documentation in many different
formats. This and other information is available at the Interchange home on
the web:

https://www.interchangecommerce.org/

## Repository layout

Major files and directories in the distribution:

### Makefile.PL

Script to create a Makefile, used for installation. (Run `./configure` for usage instructions)

### dist/

The distribution files, exclusive of executable files and modules. Includes:

* interchange.cfg.dist - Distribution-default interchange.cfg
* strap/ - Demo catalog skeleton, used by makecat
* src/ - C and Perl code for CGI link programs
* lib/ - Back-end administrative interface
* code/ - Usertags and other customizable code

### hints.pl

OS-specific configuration settings.

### eg/

Various helper scripts and addons.

### lib/

The library modules needed to run Interchange.

### scripts/

The executable files, relocated to bin/ in the install directory.

### relocate.pl

Script that adjusts paths in scripts/ for installation into bin/.

### test.pl

The installation test script.

## Prerequisites

Interchange requires Perl 5.14.1 or later, on a Unix-like operating
system. It is primarily used on various Linux distributions, and has
also been used on FreeBSD, OpenBSD, macOS, and other Unix variants.

Interchange requires some extra Perl modules to be installed on
your system. Unless you are installing from distribution-specific packages
(Red Hat, Debian, etc.) the quick way to install the necessary support is to
run from the untarred Interchange directory:

```
cpanm --installdeps .
```

Alternatively, you can run:

```
perl -MCPAN -e 'install Bundle::Interchange'
```

If you would like to use a specific installation of Perl, invoke
Perl with an absolute path to the perl binary, such as

```
/usr/local/bin/perl -MCPAN -e 'install Bundle::Interchange'
```

## Installation

You can install Interchange as root for a multi-user system-wide setup, or
as an unprivileged user who will be the only one modifying Interchange files.

Here is the quick installation summary:

```
tar xvzf interchange-5.12.0.tar.gz
cd interchange-5.12.0
perl Makefile.PL
make
make test
make install
```

If you would like to use a specific version of Perl, simply invoke
with an absolute path to the perl binary, such as:

```
/usr/local/bin/perl Makefile.PL
```

The build procedure asks where you'd like to install Interchange and
the name of the user account that will own the installation.

The Interchange server doesn't do much if it isn't servicing one or more
actual catalogs, so you next need to make your first Interchange catalog,
as described in the next section.

## Demo catalog

There is a demo catalog skeleton (called 'strap') included.

To build your own catalog from the demo, go to the directory where you
installed Interchange (default is "interchange" in your home directory,
/usr/local/interchange for root installations, or /usr/lib/interchange
for RPM installations) and run:

```
bin/makecat
```

Follow the prompts and after restarting the Interchange server you
should be able to access the new instance of the demo catalog.

Please note that some functionality (notably the reporting features)
may not be available if you are not using an SQL database such as
MySQL or PostgreSQL.

Try a live demo at: https://www.interchangecommerce.org/i/dev/demo
