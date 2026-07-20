# MV_PAGE

Holds the relative path of the page Interchange is currently serving, without
the page suffix. Reach for it when a page or component needs to know its own
name — for building self-referential links or driving admin "edit this page"
tools.

**Scope:** runtime (set by the Interchange server; read-only)

`MV_PAGE` is a *variable* in the `MV_*` namespace, but unlike most it is not
something you set in a configuration file. The server writes it into the global
variable space on every request. Interpolating it is fine; writing to it is not
meaningful.

## Syntax

    @@MV_PAGE@@

Because the server stores it in `$Global::Variable`, reference it with the
global-variable form `@@MV_PAGE@@`, or with the [var](../tags/var.md) tag using
the "global" flag:

    [var MV_PAGE 1]

Default: none (set per request).

## Description

On each request the dispatcher records the requested page's path — relative to
the catalog's pages directory and stripped of its `HTMLsuffix` — in
`$Global::Variable->{MV_PAGE}`. A request for `pages/ord/basket.html` yields a
value of `ord/basket`.

This is the value the admin UI and several templates use to build a link back
to the current page (for example, the "edit page" links in the foundation
templates use `[var MV_PAGE 1]` to construct their target).

## Examples

Show the current page name anywhere on a page:

    This page is: @@MV_PAGE@@

On `pages/ord/basket.html` this produces:

    This page is: ord/basket

Build a form that submits back to the same page:

    <form action="[area @@MV_PAGE@@]" method="post">

## Notes

This variable is maintained by the server and is not intended to be written to.
Setting it from catalog configuration has no effect on dispatching.

## See also

[MV_PREV_PAGE](MV_PREV_PAGE.md), [MV_FILE](MV_FILE.md),
[var](../tags/var.md), the [templating](../guides/templating.md) guide.

## Source

Set by the request dispatcher in `lib/Vend/Dispatch.pm` and consumed
system-wide via `$Global::Variable->{MV_PAGE}` (for example in
`lib/Vend/Interpolate.pm`).
