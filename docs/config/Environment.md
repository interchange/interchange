# Environment

Names the environment variables Interchange should copy from the calling CGI
link program into each request's environment. Reach for it to make a variable
set by your web server (such as `MOD_PERL` or `REMOTE_USER`) visible to
Interchange code.

**Scope:** global (`interchange.cfg`)

## Syntax

    Environment  variable_name ...

A whitespace- or comma-separated list of environment variable names, appended to
an array. Default: empty (only Interchange's own variables are present).

## Description

Interchange runs as a persistent daemon behind a small CGI or link program. Most
of the web server's environment does not automatically reach the daemon. For
each name listed in `Environment`, Interchange copies the value supplied by the
link program into `%ENV` when populating a request (`populate` in
`lib/Vend/Server.pm`), so the variable is available to embedded Perl and to code
that reads `%ENV`.

Only the named variables are imported, and only when the link program actually
passes them.

## Examples

Import the `MOD_PERL` marker (as shipped in `interchange.cfg.dist`):

```
Environment  MOD_PERL
```

Import several variables:

```
Environment MOD_PERL REMOTE_USER PGPPATH
```

## See also

[GlobalSub](GlobalSub.md), [TcpMap](TcpMap.md), the
[perl-embedding](../guides/perl-embedding.md) and
[architecture](../guides/architecture.md) guides.

## Source

Parsed by `parse_array` in `lib/Vend/Config.pm`; consumed in
`lib/Vend/Server.pm` (`populate`, `$Global::Environment`).
