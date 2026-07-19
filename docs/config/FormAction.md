# FormAction

Defines or overrides a *form action* -- a named handler selected by the
`mv_action`/`mv_click`/`mv_doit` variable when a form is submitted to the
`process` page. Reach for it to add custom submit behaviors (a "checkout"
button, a bulk update) or to change what a built-in action such as `submit` or
`refresh` does.

**Scope:** both (`interchange.cfg` global, `catalog.cfg` catalog)

## Syntax

    FormAction  name  CODE

`name` is the action name matched against the form's requested action.
`CODE` is one of:

- an anonymous Perl subroutine, `sub { ... }` (commonly a here-document);
- the name of a defined [Sub](Sub.md)/[GlobalSub](GlobalSub.md);
- a block of Interchange Tag Language (ITL)/HTML, interpolated at call time.

The directive accumulates: each line adds or replaces one named action.
Default: empty (only the built-in actions such as `return`, `submit`,
`refresh`, and `back` exist).

## Description

When a form posts to the `process` action, Interchange reads the requested form
action name and runs the matching handler. The routine runs in normal page
context (`$CGI`, `$Session`, `$Scratch`, `$Tag`, ...); its return value follows
the usual dispatch convention -- a true value lets page processing continue to
`mv_nextpage`, a false value ends the request.

Interchange resolves the action name in this order: a catalog `FormAction`
entry first, then the built-in/global actions, then a `CodeDef`-registered
`FormAction`. So a catalog-scope definition overrides a same-named global or
built-in one.

### Global

A global `FormAction` in `interchange.cfg` (merged from `$Global::FormAction`)
is available to every catalog. Global action code runs outside the `Safe`
compartment.

### Catalog

A catalog `FormAction` in `catalog.cfg` applies to that catalog only and takes
precedence over a global entry of the same name. Catalog action code is run
inside the `Safe` compartment.

## Examples

A "checkout" button that updates the cart and moves to the checkout page
(`catalog.cfg`):

```
FormAction checkout <<EOR
sub {
    $Tag->update('quantity');
    $CGI->{mv_nextpage} = 'checkout';
    return 1;
}
EOR
```

The matching form uses the action name as its `mv_action` (or an image submit
button named `mv_click`):

```
<form action="[area process]" method="POST">
<input type="hidden" name="mv_action" value="checkout">
<input type="submit" value="Check out">
</form>
```

## Notes

`FormAction` is parsed like [ActionMap](ActionMap.md) and
[FileControl](FileControl.md); the difference is the dispatch namespace it
feeds. Actions are chosen from `mv_action`, `mv_click`, or `mv_doit` -- see the
[forms](../guides/forms.md) guide. [CodeDef](CodeDef.md) with a type of
`FormAction` is an equivalent lower-level way to register one.

## See also

[ActionMap](ActionMap.md), [FileControl](FileControl.md),
[ItemAction](ItemAction.md), [CodeDef](CodeDef.md), [Sub](Sub.md),
[GlobalSub](GlobalSub.md), [AllowGlobal](AllowGlobal.md), the
[forms](../guides/forms.md) guide.

## Source

Parsed by `parse_action` in `lib/Vend/Config.pm`; dispatched by the form
processor in `lib/Vend/Dispatch.pm` (`do_process`, consulting
`$Vend::Cfg->{FormAction}` and the merged `$Global::FormAction`).
