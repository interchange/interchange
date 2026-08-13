# RemoteUser

Names the value the web server's `REMOTE_USER` variable must hold before
Interchange will allow a catalog reconfigure or other secure operation.
Reach for it to gate administrative operations behind the web server's HTTP
authentication.

**Scope:** catalog (`catalog.cfg`)

## Syntax

    RemoteUser  USERNAME

A single username, stored verbatim (no parser). Default: empty.

## Description

Interchange guards "secure operations" -- notably catalog reconfigure --
behind at least one of three checks: [MasterHost](MasterHost.md),
[Password](Password.md), or `RemoteUser`. When `RemoteUser` is set,
Interchange compares it to the `REMOTE_USER` HTTP environment variable
(`$CGI::user`) supplied by the web server; the operation proceeds only when
they match, and a mismatch is logged as an alert.

For this to work the web server must perform HTTP authentication (for
example Apache basic auth) on the relevant URL so that `REMOTE_USER` is
populated. Interchange does not itself prompt for the credentials; it only
trusts the name the web server passes through.

The value is consumed in `lib/Vend/Util.pm`, both when matching HTTP basic
credentials against [Password](Password.md) and when authorizing secure
operations.

## Examples

Require the web server to have authenticated the user `interchange`:

```
RemoteUser interchange
```

With Apache configured to require authentication on the catalog's
reconfigure URL, only a request carrying `REMOTE_USER: interchange` may
trigger a reconfigure.

## Notes

`RemoteUser` is only as trustworthy as the web server's authentication in
front of it; without HTTP auth configured, `REMOTE_USER` is empty and the
check cannot succeed. If none of `MasterHost`, `Password`, or `RemoteUser`
is set, secure operations are disabled entirely.

## See also

[MasterHost](MasterHost.md), [Password](Password.md),
[Environment](Environment.md), the [security](../guides/security.md) and
[admin-ui](../guides/admin-ui.md) guides.

## Source

Stored unparsed by `catalog_directives()` in `lib/Vend/Config.pm`;
consumed in `lib/Vend/Util.pm`.
