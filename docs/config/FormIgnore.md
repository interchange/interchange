# FormIgnore

Lists CGI variables that should *not* be copied from submitted form data into
the Values space. Reach for it to stop a user from overriding sensitive values
(handling charges, order routes) by posting a form field of the same name.

**Scope:** catalog (`catalog.cfg`)

## Syntax

    FormIgnore  variable[ variable...]

Parsed as a set of keys: each named variable is flagged to be ignored. Multiple
names may appear on one line and/or across several `FormIgnore` lines; they
accumulate. Default: empty (nothing ignored).

Values space: the per-session store of form values, read with
[value](../tags/value.md) and written by form submissions. CGI variables are
the fields a browser posts.

## Description

When Interchange folds submitted form fields into the Values space -- as an
`[update values]` or an ordinary form post does -- it skips any field whose name
appears in `FormIgnore`. The submitted value is discarded rather than stored,
so page code and order routing see whatever value was already set (or the
default), not the user's version.

This is a guardrail against tampering: a field the catalog computes itself
should not be settable from the client. The check is applied per key as the
values are updated.

## Examples

Prevent the user from setting the handling charge (from the strap demo
`catalog.cfg`):

```
FormIgnore   mv_handling
```

Also protect the chosen order route, so a submitted `mv_order_route` cannot
redirect the order:

```
FormIgnore   mv_order_route
```

## Notes

`FormIgnore` blocks a value from entering Values space; it does not remove a
variable that is set some other way. Administrative sessions are exempt --
values still update for a logged-in admin. To transform (rather than drop)
incoming values, see [Filter](Filter.md).

## See also

[Filter](Filter.md), [ValuesDefault](ValuesDefault.md),
[ScratchDefault](ScratchDefault.md), the [value](../tags/value.md) tag, the
[forms](../guides/forms.md) guide.

## Source

Parsed by `parse_boolean` in `lib/Vend/Config.pm`; consumed in
`lib/Vend/Dispatch.pm`, which skips any key present in
`$Vend::Cfg->{FormIgnore}` while updating the Values space.
