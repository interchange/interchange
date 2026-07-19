# SOAP_Control

Grants or denies access to individual SOAP-RPC features (fetching values and
scratch, reading databases, running tags, invoking named actions) on a
per-subject basis. Use it to lock down what a remote SOAP client is allowed to
do against a running Interchange server.

**Scope:** both (`interchange.cfg` and `catalog.cfg`)

## Syntax

    SOAP_Control  SUBJECT  PERMISSION

Each line maps one subject to a permission. The parser (`action`) stores the
result as a hash of subject to permission. Default: empty (no explicit
controls; access is denied unless a matching rule grants it).

The recognized subjects are:

- `Values` -- read the session `$Values` space.
- `Scratch` -- read the session scratch space.
- `Database` -- read a database table. A rule may name a specific table as
  `Database/tablename` to control one table.
- `Tag` -- run an Interchange Tag Language (ITL) tag. A rule may target a
  single tag as `Tag/tagname`.
- `Action` -- invoke a named routine defined with
  [SOAP_Action](SOAP_Action.md); may be narrowed as `Action/routine`.

`PERMISSION` is one of the built-in keywords, a semicolon-separated list of
them, or a Perl `sub { ... }` code block:

- `always` -- allow unconditionally.
- `never` -- deny unconditionally.
- `local` -- allow only when the request comes from `127.0.0.1`.
- a `sub { ... }` returning true to allow, false to deny (the subject path is
  passed as the argument).

## Description

`SOAP_Control` is consulted by `soap_gate()` each time a SOAP method runs. The
gate checks the **global** control hash first and the **catalog** control hash
second; the global setting takes precedence, so a catalog cannot grant a
feature the global configuration has not also permitted.

For a given subject the gate looks for the most specific rule first (for
example `Database/products` before `Database`) and applies the first match. If
no rule grants access, the request dies with an "Unauthorized access" error.

SOAP itself must be enabled with [SOAP](SOAP.md) (global) before any of this
takes effect, and the per-catalog feature switch [SOAP_Enable](SOAP_Enable.md)
governs whether interpolation-based methods run at all.

## Examples

Allow only named actions and deny every other SOAP feature (place in
`catalog.cfg`, and ensure the global file permits the same):

```
SOAP_Control Action   always
SOAP_Control Tag      never
SOAP_Control Values   never
SOAP_Control Scratch  never
SOAP_Control Database never
```

Allow database reads only from the local host, and only for the `products`
table:

```
SOAP_Control Database/products local
```

## Notes

Because the global rules are checked first and must agree, tightening access in
one catalog does not loosen it elsewhere, but loosening it in a catalog has no
effect unless the global file already allows the subject.

## See also

[SOAP](SOAP.md), [SOAP_Enable](SOAP_Enable.md), [SOAP_Action](SOAP_Action.md),
[SOAP_Socket](SOAP_Socket.md), [ActionMap](ActionMap.md), the
[security](../guides/security.md) guide.

## Source

Parsed by `parse_action` in `lib/Vend/Config.pm` (stored in
`$Global::SOAP_Control` and `$Vend::Cfg->{SOAP_Control}`); enforced by
`soap_gate` in `lib/Vend/SOAP.pm`.
