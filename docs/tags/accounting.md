# accounting

Dispatch a call to the catalog's configured accounting subsystem, enforcing the
current user's privilege level. Reach for it when integrating an external
bookkeeping or ERP module that Interchange drives through an `Accounting`
class.

## Syntax

    [accounting function]
    [accounting function=name system=repository_key ...]

Standalone tag (no end tag). The return value is whatever the accounting
method returns; it is not reparsed as Interchange Tag Language (ITL).

## Attributes

| Attribute         | Default | Description |
|-------------------|---------|-------------|
| `function`        | none    | Name of the method to call on the accounting object. |
| `system`          | current | Key into the `Accounting_repository` naming an alternate accounting configuration to switch to for this call. |
| `can_do_function` | `0`     | When true, do not run the method; instead return a true value if the accounting class *can* perform `function`, false otherwise. |

Positional order: `function`.

Because the tag declares `addAttr`, every other attribute you pass is collected
into the option hash and handed to the accounting method as its argument, so
the available options depend entirely on the configured module.

## Description

The tag requires the [Accounting](../config/Accounting.md) directive to name an
accounting class; without it the tag dies with `Accounting not enabled!`.

Before dispatching, it checks privilege. Two function names are gated:
`noparts_update` requires an administrative session whose user passes the
`super` merchandising-manager check, and `inventory_update` requires any
administrative session. All other functions are ungated. A privilege failure
raises an error naming the function.

If `system` is given, the tag swaps `$Vend::Cfg->{Accounting}` for the entry at
`Accounting_repository{system}` for the duration of the call; if that key is
missing it logs an error, restores the former system, and returns undef.

It then instantiates the class (`new $class`) and looks up `function` as a
method. If the class cannot do it, the tag logs an error and returns undef.
With `can_do_function` set, it returns the method reference (truthy) instead of
calling it. Otherwise it calls `$self->$function($opt)` and returns the result.

## Examples

Call a `close_period` method on the configured accounting system:

    [accounting close_period]

Probe whether the current accounting class supports a method before using it:

    [if type=explicit compare="[accounting function=post_invoice can_do_function=1]"]
      [accounting function=post_invoice invoice="[value inv_no]"]
    [/if]

Switch to a named accounting configuration for one call:

    [accounting function=sync system=quickbooks]

## Notes

This tag is only useful with a site-specific accounting module wired in through
`Accounting`; Interchange ships the dispatcher, not a concrete backend. The
methods, their arguments, and their return values are defined by that module.

The `super` privilege check is evaluated inside an `eval`, so if the admin
framework is unavailable the gated function is simply treated as not enabled
rather than throwing.

## See also

- [Accounting](../config/Accounting.md)
- [if](if.md)
- Concepts: [admin UI](../guides/admin-ui.md)

## Source

Defined in `code/SystemTag/accounting.coretag` (inline Routine).
