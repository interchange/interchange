# AlwaysSecure

Lists pages that must be served over a secure (HTTPS) connection, so that
links Interchange generates to them use `SecureURL`. Reach for it to keep
login, account, and checkout pages on HTTPS.

**Scope:** catalog (`catalog.cfg`)

## Syntax

    AlwaysSecure  page ...

A whitespace-separated list of page names (a here-document is convenient
for long lists). Each name is stored as a key set true in a hash. The
directive accumulates across lines. Default: empty.

## Description

`AlwaysSecure` marks page paths as secure-only. It has two effects:

- When Interchange builds a link to a marked page (`vendUrl` in
  `lib/Vend/Util.pm`), it uses the catalog's `SecureURL` base instead of
  the plain `VendURL`, producing an `https://` link.
- When `ExtraSecure` is also enabled, `lib/Vend/Page.pm` refuses to
  display a marked page that was requested over a non-secure connection,
  substituting the `violation` special page.

Page names are matched exactly. To match by pattern, use
`AlwaysSecureGlob`.

## Examples

A single secure page (in `catalog.cfg`):

```
AlwaysSecure ord/checkout
```

The strap demo marks the whole login/account/checkout flow:

```
AlwaysSecure   <<EOD
	login
	member/account
	member/change_email
	member/change_password
	new_account
	ord/billing
	ord/checkout
	ord/finalize
	ord/shipping
	query/order_detail
EOD
```

## Notes

Marking a page secure only changes the links Interchange generates and,
with `ExtraSecure`, enforces the connection. It does not configure the web
server's TLS; you must have a working HTTPS front end and a correct
`SecureURL`.

## See also

[AlwaysSecureGlob](AlwaysSecureGlob.md), [ExtraSecure](ExtraSecure.md), [SecureURL](SecureURL.md), [VendURL](VendURL.md), the
[security](../guides/security.md) guide.

## Source

Parsed by `parse_boolean` in `lib/Vend/Config.pm`; consumed via
`$Vend::Cfg->{AlwaysSecure}` in `lib/Vend/Util.pm` (link generation) and
`lib/Vend/Page.pm` (enforcement with `ExtraSecure`).
