# Tracking Interchange development in Git

If you don't want to wait for an official release, you can use Git to follow
the latest Interchange development.

**Warning:** There may be bugs introduced at any time! Thoroughly test any changes
before incorporating.


## Git repository

To browse the Interchange Git repository online at GitHub or to see
instructions on cloning and using a local Git working copy go to the [Interchange download page](https://www.interchangecommerce.org/i/dev/download).


## Make a distribution tar file

It's best to build a distribution tar file to install from, rather than
installing straight from your Git working copy. To do so:

```sh
$ cd interchange
$ perl Makefile.PL nocopy
Writing Makefile for Interchange
$ make tardist
# much output ...
$ ls interch*.tar.gz
interchange-5.7.3.tar.gz
```


## Unpack and install

Unpack the tar file and install as normal. See the README file and other
documentation for help. You should already be familiar with the [Interchange
developer website](https://www.interchangecommerce.org/).

Make sure you don't put your Git working copy at `$HOME/interchange`
and then install on top of it, since `$HOME/interchange` is the default
install directory.


## Updating

Follow development discussions by joining the interchange-announce and
interchange-users mailing lists.

Keep track of ongoing code changes by watching the [repository in GitHub](https://github.com/interchange/interchange).

In many cases, the major differences in the distribution will be easily
updateable. You can copy any changed files directly to these library
directories and all their subdirectories:

* `lib/Vend`
* `lib/UI`

You should check the files:

* `catalog_after.cfg`
* `catalog_before.cfg`
* `interchange.cfg.dist`
* `usertag/*`

Finally, you should check differences in the `bin/*` files. While they
are not as frequently updated as the `lib/*` files, they do change. Run
diffs against the source files in `scripts/*.PL`, or do another install
to a blank directory and do a diff to that.


## Keeping the catalog in sync

If you are patterning your order methods after one of the template
catalogs, you will want to check the products/*.txt and products/*.asc
files for changes. In particular, mv_metadata.asc is used to format
and present quite a few things in the user interface. You may have
to merge the databases, but there is an automated admin UI facility
that can help you do this.


## Troubleshooting

If you get a complaint that a "file is not found" when trying to do a
`make tardist` or `make dist`, that means your MANIFEST file is out of
sync with the current codebase. Just do:

```sh
rm MANIFEST
make manifest
```


## Perl minimum version requirement

The Interchange developers occasionally increase the minimum Perl version required to run the latest Interchange.

Doing this allows us to use modern Perl language features, stay current with security and bugfix updates, and direct our efforts productively by not dealing with unsupported and outdated versions of Perl, and by extension, CPAN modules and Linux distributions.

Production business applications should only run on supported versions of the entire software stack as a matter of good hosting practice, but also because of [PCI DSS](https://www.pcisecuritystandards.org/) requirements which Interchange ecommerce deployments often need to meet.

After many years of no change, an increase to the minimum Perl version was announced in a [message to the interchange-users mailing list on 2018-07-16](https://www.interchangecommerce.org/pipermail/interchange-users/2018-July/055949.html) and in a [commit to the interchange Git repository on 2021-03-01](https://github.com/interchange/interchange/commit/025b44743bef3dc4d0f249a24bb2db418c50a175) which explained …

> our policy to routinely increase the minimum supported Perl version:
>    
> Interchange will require a version of Perl at least as new as the oldest one shipped with one of the three major Linux distributions widely used for production Interchange deployments: Ubuntu, Debian, and RHEL/CentOS.

Many Interchange developers use the latest version of Perl installed separately via plenv or perlbrew anyway, but this policy sets a minimum baseline.

### Status as of 2022-06-13

As of this writing the oldest member of each Linux distribution, its announced general end-of-life date for support, and its standard Perl version are:

| Distribution | End of life | Perl version |
| ------------ | ----------- | ------------ |
| [Ubuntu 18.04 LTS](https://wiki.ubuntu.com/Releases) | 2023-04 | 5.26.1 |
| [Debian 10](https://www.debian.org/releases/)        | 2024-06 | 5.28.1 |
| [RHEL/CentOS 7](https://centos.org/centos-linux/)    | 2024-06 | 5.16.3 |

Thus Interchange currently requires Perl 5.16.3 or newer.
