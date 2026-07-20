# Installation

This chapter takes you from a git clone of the source to a running
Interchange server behind a web server, with its first catalog live. It
covers the prerequisites, the `perl Makefile.PL` build, the
file-ownership model that keeps a store's data private, building a demo
catalog with `bin/makecat`, wiring the web server to the daemon with a
link program, and starting, stopping, and reconfiguring the server. It
ends with notes on running several catalogs and on the OS packages.

Interchange is a persistent daemon that serves many catalogs through
tiny web-server link programs; if that model is unfamiliar, read
[Architecture](architecture.md) first — installation is largely about
putting its pieces in the right places with the right permissions. To
*build* a store rather than install the server, see the
[catalog-building tutorial](tutorial.md) (a store by hand) and
[Catalog anatomy](catalog-anatomy.md) (a tour of the demo).

## Before you start

Interchange runs on Unix-like systems (Linux, the BSDs, macOS). You need:

- **Perl 5.16.3 or later.** Check with `perl -v`. To build against a
  specific Perl, invoke that interpreter by absolute path throughout
  (`/usr/local/bin/perl Makefile.PL`).
- **Git**, to obtain the source (see below).
- **The prerequisite CPAN modules.** The source ships a `cpanfile`; from
  the working copy the quick way to satisfy it is:

  ```sh
  cpanm --installdeps .
  ```

  The core requirements are `DBI`, `Digest::MD5`, `Digest::SHA`,
  `Digest::Bcrypt`, `Safe::Hole`, `Set::Crontab`, `Storable`,
  `MIME::Base64`, `MIME::Lite`, `URI::URL`, `HTML::Entities`,
  `HTML::Tagset`, `Image::Size`, and `LWP` with `LWP::Protocol::https`;
  the full list is in `cpanfile`. The older
  `perl -MCPAN -e 'install Bundle::Interchange'` still works.
- **A C compiler** (`gcc` or `cc`) — needed only to compile the C link
  programs (`vlink`/`tlink`). You can skip it if you use the Perl or Rust
  link program, `mod_perl`, or `mod_interchange`.
- **A web server** (Apache, nginx, …) with a CGI directory you can write
  to, if you want to reach the store through a browser. You do not need
  one to develop against the daemon directly (the
  [tutorial](tutorial.md) shows a socket-only workflow).
- **A database.** Interchange runs on its built-in DBM tables out of the
  box, but several features (notably reporting) want SQL — SQLite, MySQL
  (or MariaDB), or PostgreSQL, with the matching `DBD::*` driver. See
  [Databases](databases.md).
- **A dedicated, non-root user account.** Interchange must not run as
  root; if you start it as root it makes you name a user to switch to.
  On a single-user machine your own login is fine.

## Getting the source

**Clone the git repository.** Versioned release tarballs are no longer
produced with any regularity, so the repository is the authoritative
source for current Interchange — don't go looking for an
`interchange-x.y.z.tar.gz` to download:

```sh
git clone https://github.com/interchange/interchange.git
cd interchange
```

That gives you the latest development state. Bear in mind what that
means: changes land continuously and any of them may introduce bugs, so
test thoroughly before putting a clone-built install into production, and
pin yourself to a known-good commit (`git log`, then `git checkout
<sha>`) if you need a stable base. Track changes by watching the
[repository](https://github.com/interchange/interchange) and following
the `interchange-users` mailing list.

Do **not** clone into `~/interchange`: that is the default *install*
directory, and installing on top of your working copy will tangle the two
trees. Keep the clone somewhere else (`~/src/interchange`, say) and
install to a separate path.

## Installing from source

The build uses the standard Perl `ExtUtils::MakeMaker` sequence, driven
by an interactive `Makefile.PL`, run from the working copy:

```sh
cd interchange
perl Makefile.PL
make
make test
make install
```

`README-DEVELOPMENT.md` in the repository suggests an alternative:
`perl Makefile.PL nocopy && make tardist` builds a distribution tarball
from your checkout, which you then unpack and install from. That keeps
the installed tree free of git metadata and lets you archive exactly what
you deployed. Installing directly from the working copy, as above, is
simpler and works.

`perl Makefile.PL` asks two questions that matter:

- **Where to install.** The default is `~/interchange` for an ordinary
  user, `/usr/local/interchange` for root. This directory — Interchange's
  root, referred to throughout the docs as `VendRoot` — must *not* be the
  source directory you are building in.
- **Which user will own the installation.** When you build as root this
  becomes the account the daemon runs as; the installer chowns
  `error.log` and `etc/` to it.

If `Term::ReadLine::Perl` and `Term::ReadKey` are installed you get line
editing and defaults; otherwise it falls back to plain prompts. The
installer also offers to enable Raphael Manfredi's `Storable` for faster
DBM session (and optionally database) storage — answering the default
`s` (sessions only) is safe and never invalidates existing databases.

`make install` runs the real work: it copies `dist/`, `code/`, and
`share/` into the install directory, relocates the scripts from
`scripts/` into `bin/` (rewriting their built-in paths), and checks that
the required modules load — offering to fetch any that are missing.

### Scripting the install

Every prompt has a command-line equivalent, so an unattended build passes
the answers as arguments and adds `force=1` to suppress prompting:

```sh
perl Makefile.PL PREFIX=$HOME/interchange INTERCHANGE_USER=$USER force=1
make && make test && make install
```

`PREFIX` sets the install directory and `INTERCHANGE_USER` the owning
account. (`./configure` in the source tree only prints these
instructions — it is a help stub, not an autoconf script.)

### What gets laid down

After `make install`, the install directory holds the server and its
supporting files:

    bin/          the daemon and utilities (relocated from scripts/)
    lib/          the Perl modules (Vend::*, UI/)
    code/         loadable tags, filters, widgets (scanned at startup)
    dist/         skeletons and templates makecat copies from
    etc/          run state: sockets, PID file
    share/        admin UI static assets
    error.log     the global (server-level) log

`bin/` contains `interchange` (the daemon), `makecat` (catalog builder),
`compile_link` (link-program compiler), `restart`, `expire`,
`expireall`, `localize`, `offline`, and others. Your catalogs live
*outside* this tree — conventionally under `~/catalogs/<name>` — so that
reinstalling or upgrading the server never touches store data. The
runtime layout is described in
[Architecture](architecture.md#where-things-live-at-runtime).

## The ownership and permission model

This is the part worth getting right, because it is a security boundary,
not a formality. Two identities are in play:

- **The Interchange user** runs the daemon and *owns every catalog
  file*. It reads your product data, order logs, and session files, so
  those files should be readable only by it (and, if you like, the
  catalog's human owner). It is never root.
- **The web-server user** (`www-data`, `apache`, `nobody`, …) runs the
  link program. That program needs only to reach the daemon's socket; it
  never reads catalog data directly. Pages under `pages/` are delivered
  *through* Interchange, so — unlike `html/` and `images/` — they must
  not sit in a web-served directory or carry world-readable permissions
  ([Catalog anatomy](catalog-anatomy.md)).

For a Unix-domain socket, access is controlled by filesystem
permissions: [SocketPerms](../config/SocketPerms.md) sets the socket's
mode (default `0600`, i.e. only the Interchange user). When the web
server runs as a *different* user than the daemon — the usual case — the
CGI link program cannot open a `0600` socket. The two standard fixes are:

- make the link program **setuid** to the Interchange user (what
  `makecat` and `compile_link` arrange for `vlink`), or
- open the socket wider with `SocketPerms 0666` and rely on directory
  permissions to protect it.

`makecat` asks which model you want and sets ownership accordingly. When
several people run catalogs on one server, it offers three
**permission modes**:

- **Multiple group** (recommended) — each catalog user has their own
  group, and the Interchange user is a member of each; a catalog's
  sensitive files are readable only by its owner and the daemon. Works
  cleanly when users' `umask` is `002`.
- **Group** — all files are owned by the Interchange user, group-owned by
  the user's group; simpler, less isolated.
- **User** — one person owns every catalog and runs the daemon; the
  single-machine developer case.

See [Security](security.md) for the reasoning, and
[AllowGlobal](../config/AllowGlobal.md) for the related trust boundary
between global and catalog code.

## Building a catalog with makecat

The server does nothing until it serves a catalog. The fastest way to a
working store is `bin/makecat`, which copies the **strap** demo skeleton
from `dist/strap/` into place, substitutes your paths and URLs, imports
its seed data into the database you choose, compiles a link program into
your CGI directory, and appends the [Catalog](../config/Catalog.md) line
to `interchange.cfg`. From the install directory:

```sh
cd ~/interchange
bin/makecat
```

It interviews you for, among other things:

- the **catalog name** (used everywhere — keep it short; `strap` is the
  default demo name),
- the **catalog base directory** (where the store's files go, e.g.
  `~/catalogs/strap`),
- the web server's **CGI directory** and the **document root**, so it can
  place the link program and static assets and derive the catalog URL,
- **INET or UNIX** socket mode and, for INET, the host and port,
- the **SQL backend** — set `MYSQL`, `PGSQL`, or `SQLITE` to `1` and give
  the DSN/credentials, or accept the DBM default.

When it finishes, restart the server (below) and browse to the URL it
reported (typically `http://yourhost/cgi-bin/strap/`). The strap catalog
and everything `makecat` lays down are toured in
[Catalog anatomy](catalog-anatomy.md).

Any catalog directory can serve as a `makecat` skeleton, so "copy strap
and carve it down" is a supported way to start a real store. If you would
rather understand every file by adding it yourself, the
[tutorial](tutorial.md) builds a small catalog from scratch without
`makecat` — this guide does not repeat that ground.

> **Never run `makecat` against an existing catalog** — it is for
> creating new ones. To change a catalog you already have, edit its files
> and reconfigure (below).

## Wiring up the web server

In production the browser never talks to Interchange directly. The web
server serves static assets and hands catalog URLs to a small **link
program**, which marshals the CGI environment and request body to the
daemon's socket and streams the response back
([Architecture](architecture.md)). You choose one connector; the daemon
side is identical for all of them.

### Choosing a socket mode

The daemon listens on a Unix-domain socket, a TCP socket, or both:

- **Unix mode** (default, [Unix_Mode](../config/Unix_Mode.md) `Yes`) uses
  a socket file — by default `etc/socket` under the install directory,
  configurable with [SocketFile](../config/SocketFile.md). Faster, and
  secured by filesystem permissions; use it when the web server is on the
  same machine.
- **Inet mode** ([Inet_Mode](../config/Inet_Mode.md) `Yes`, or
  `bin/interchange -i`) listens on TCP, configured by
  [TcpMap](../config/TcpMap.md) (default port `7786`) and restricted to
  trusted clients with [TcpHost](../config/TcpHost.md). Use it when the
  web server lives on another host.

The stock `interchange.cfg` binds `TcpMap 7786 -` (the `-` is a
placeholder — catalogs are selected by request path, not port). Set the
mode in `interchange.cfg`:

    Unix_Mode  Yes
    Inet_Mode  No

### CGI link programs: vlink and tlink

The classic connectors are two C programs in `dist/src/`: **`vlink`**
(Unix-domain socket) and **`tlink`** (TCP). `makecat` compiles and
installs the right one for you; to (re)build one by hand use
`bin/compile_link`, which bakes the socket location into the executable:

```sh
# Unix-socket link program into the CGI directory:
bin/compile_link -u -o /var/www/cgi-bin/strap \
    --socket=/home/you/interchange/etc/socket

# or a TCP link program pointing at a daemon on host:port:
bin/compile_link -i -o /var/www/cgi-bin/strap \
    --host=127.0.0.1 --port=7786
```

`compile_link -u` makes `vlink` setuid to the Interchange user so it can
open a `0600` socket; pass `--nosuid` under CGIWrap/suEXEC, where suid
CGI is forbidden (then you must widen [SocketPerms](../config/SocketPerms.md)
or use Inet mode instead). `--perl` builds the pure-Perl `tlink.pl`
instead of compiling C, for hosts without a compiler.

The web server then runs that program as an ordinary CGI. The URL path it
is reached at must match the catalog's [Catalog](../config/Catalog.md)
line. A minimal Apache configuration:

```apache
ScriptAlias /cgi-bin/ /var/www/cgi-bin/
# browsing http://host/cgi-bin/strap/... runs the link program
```

and the matching catalog registration in `interchange.cfg`:

    Catalog  strap  /home/you/catalogs/strap  /cgi-bin/strap

The daemon matches the incoming `SCRIPT_NAME` (`/cgi-bin/strap`) to that
line to select the catalog; an unrecognized path returns
`404 Undefined catalog`. See [Configuration](configuration.md) for the
`Catalog` line and [Architecture](architecture.md) for how the request is
routed.

### Skipping CGI: mod_perl, mod_interchange, and the Rust link

For higher throughput you can avoid a per-request CGI fork:

- **mod_perl 2** — `dist/src/mod_perl2/Interchange/Link.pm` is a handler
  that speaks the link protocol from inside Apache. Install it on Perl's
  path and configure a `<Location>`:

  ```apache
  <Location /strap>
      SetHandler perl-script
      PerlHandler Interchange::Link
      PerlSetVar InterchangeServer /home/you/interchange/etc/socket
      PerlSetVar OrdinaryFileList "/strap/images/ /strap/dl/"
  </Location>
  ```

  Because Apache reaches the socket as its own user, set
  [SocketPerms](../config/SocketPerms.md) `0666` (or run the daemon as
  the web-server user). The Apache `<Location>` path must not contain a
  dot; use `/shop-name`, not `/shop.name`.
- **mod_interchange** — `dist/src/mod_interchange/` is a C Apache module
  that replaces `vlink`/`tlink` entirely, configured with an
  `InterchangeServer` directive naming the socket or `host:port`. Note it
  is **Apache 1.x only — not compatible with Apache 2**, so it is legacy;
  prefer `mod_perl2`, the Rust link, or plain `vlink`/`tlink` on modern
  Apache.
- **Rust link** — `dist/src/rust_link/` is a modern reimplementation of
  the CGI link program (`cargo build --release`), supporting both Unix and
  TCP sockets. Unlike the C programs it has no socket compiled in;
  configure it with environment variables from the web server
  (`SetEnv MINIVEND_SOCKET /path/etc/socket`, or `MINIVEND_HOST` /
  `MINIVEND_PORT` for TCP). Tested on Linux x86-64 and macOS ARM64.

Whichever connector runs as a different user than the daemon needs the
socket opened to it — the recurring theme of
[SocketPerms](../config/SocketPerms.md). If Apache needs to see a
particular CGI variable (`MOD_PERL`, `REMOTE_USER`, …) inside Interchange
code, list it in [Environment](../config/Environment.md).

## Starting, stopping, and reconfiguring

Run the daemon from the install directory. It detaches and runs in the
background, writing progress and errors to `error.log` and its process id
to the [PIDfile](../config/PIDfile.md) (default `etc/interchange.pid`):

```sh
bin/interchange            # start
bin/interchange -r         # restart (re-read all config)
bin/interchange --stop     # stop gracefully (TERM)
```

`bin/restart` is a convenience wrapper for the restart. Every
configuration error is fatal and names the file and line — the fastest
debugging tool you have; get used to reading `error.log`. The daemon
takes many flags (`bin/interchange --help` lists them); the ones you will
use most:

| Command | Effect |
|---------|--------|
| `bin/interchange` | Start (the default `--serve` mode) |
| `bin/interchange -r` | Stop and restart, re-reading all configuration |
| `bin/interchange --stop` | Stop the server gracefully |
| `bin/interchange --kill [sig]` | Stop ungracefully (`KILL`, or the given signal) |
| `bin/interchange -t` | Parse all config and report problems, without starting |
| `bin/interchange --reconfig=NAME` | Recompile one catalog, no restart |
| `bin/interchange -i` / `-u` | Start in Inet-only / Unix-only socket mode |
| `bin/interchange -q` | Suppress informational startup messages |
| `bin/interchange -v` | Print version |

You can override a global directive for one run by appending
`Directive=value` (e.g. `bin/interchange -r SocketPerms=0666`), or a
catalog directive with `name:Directive=value` — handy for testing without
editing files. Such overrides must be repeated on each restart.

**Reconfiguration without a restart.** Editing a running catalog's config
does not require bouncing the whole server (which would drop every
catalog's sessions):

```sh
bin/interchange --reconfig=strap
```

recompiles just that catalog. The change is picked up on the next
housekeeping cycle, so allow a few seconds; the admin UI's "Apply
Changes" does the same thing. See
[Configuration](configuration.md#startup-reconfiguration-and-debugging).
Note the split every store hits: **config files** (`catalog.cfg`,
`variables/`, profiles) need a reconfig or restart, but **page files** do
not — they are re-read per request.

## Running multiple catalogs

One daemon serves any number of catalogs. Each gets its own
[Catalog](../config/Catalog.md) line in `interchange.cfg` and its own
link program at a distinct URL path:

    Catalog  strap  /home/you/catalogs/strap  /cgi-bin/strap
    Catalog  books  /home/you/catalogs/books  /cgi-bin/books

Settings shared by every catalog go in the files named by
[ConfigAllBefore](../config/ConfigAllBefore.md) and
[ConfigAllAfter](../config/ConfigAllAfter.md) (default
`catalog_before.cfg` / `catalog_after.cfg`), read around each catalog's
own `catalog.cfg`. To run two storefronts off *one* catalog's files under
different names, use [SubCatalog](../config/SubCatalog.md).

You can add or remove a catalog on a running server without a full
restart:

```sh
echo "Catalog test /home/you/catalogs/test /cgi-bin/test" \
    | bin/interchange -a          # add (implies a reconfig)
bin/interchange --remove=test     # take it out of service
```

## Installing from OS packages

Interchange also ships as distribution packages, which relocate files
into the standard Linux Standard Base locations and add init/service
integration. They are the quick path on the platforms that carry them,
but they change several paths and the control command:

- **RPM (Red Hat/derivatives)** — installs the server under
  `/usr/lib/interchange`, config as `/etc/interchange.cfg`, catalogs in
  `/var/lib/interchange`, logs in `/var/log/interchange`, run state in
  `/var/run/interchange`, and sessions/temp in `/var/cache/interchange`.
  The daemon runs as the `interch` user and **must** be controlled with
  `/usr/sbin/interchange -r`, not `bin/restart`. A separate
  `interchange-standard-demo` RPM provides a ready live demo. Details and
  the current dependency list are in `README.rpm-dist` and `README.rhel`.
- **Debian/Ubuntu** — packaged by the Interchange maintainers; per-catalog
  config goes in `catalogs.cfg` so `/etc/interchange/interchange.cfg`
  upgrades cleanly, global usertags in `/etc/interchange/usertag`, and the
  daemon is driven through the `/usr/sbin/interchange` wrapper. See
  `README.debian`.

Because these packages track their own release cadence and the packaging
notes predate current tooling (they still reference SysV init scripts and
older suites), treat the package READMEs in the source tree as the
authority for exact paths and dependencies on your distribution, and use
`rpm -qp --requires <pkg>` (or the Debian control file) for the real
module list.

## Verifying and troubleshooting

- **`make test` fails** — usually a missing prerequisite module; the
  failing test names it. Install it (`cpanm <Module>`) and retry.
- **Server won't start** — a fatal config error; `error.log` names the
  file and line. `bin/interchange -t` reports all such problems without
  starting. A warning about running "as nobody" means the daemon's UID is
  `nobody` — give it a real dedicated user.
- **Browser gets a 500 or blank page, `error.log` is silent** — the link
  program can't reach the socket. Confirm the socket exists under `etc/`,
  the link program is setuid (Unix mode) or the daemon is in Inet mode,
  and — the usual culprit — that [SocketPerms](../config/SocketPerms.md)
  lets the web-server user in (try `0666` to confirm, then tighten).
- **`404 Undefined catalog`** — the request's URL path doesn't match any
  [Catalog](../config/Catalog.md) line's script path. Check the
  `ScriptAlias`/link-program path against the third field of the `Catalog`
  line.
- **A config change doesn't show** — page files apply immediately, but
  config files need `bin/interchange --reconfig=NAME` or a restart.

For log locations, `[dump]`, and deeper diagnosis see
[Logging and debugging](logging-debugging.md). For moving an existing
install forward a version, see [Upgrading](upgrading.md).

## See also

- [Architecture](architecture.md) — the process model these pieces
  implement
- [Configuration](configuration.md) — `interchange.cfg`, `catalog.cfg`,
  and reconfiguration in depth
- [Catalog-building tutorial](tutorial.md) — build a store by hand
- [Catalog anatomy](catalog-anatomy.md) — tour the strap demo `makecat`
  installs
- [Security](security.md) — why the ownership and socket-permission model
  matters
- [Directive reference](../config/README.md) — every directive named
  above
