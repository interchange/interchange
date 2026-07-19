# SOAP_Action

Defines named handlers a catalog exposes to remote SOAP callers. Reach for it to
publish specific server-side routines -- beyond the built-in allowed tags --
that SOAP clients may invoke by name.

**Scope:** catalog (`catalog.cfg`)

## Syntax

    SOAP_Action  name code

Maps an action `name` to `code`. As with other action directives, the code may
be an anonymous Perl `sub {...}`, the name of a defined [Sub](Sub.md) or
[GlobalSub](GlobalSub.md), or interpolatable Interchange Tag Language (ITL).
Default: empty.

## Description

When a SOAP request arrives for a catalog (which must have [SOAP](SOAP.md)
enabled), Interchange looks up the called routine name in `SOAP_Action`. If a
matching action exists, it runs that action's code -- with the tag and calc
environment initialized so catalog usertags work -- and returns the result to
the caller. If no `SOAP_Action` matches, the request must instead be one of the
intrinsically allowed tags, or it is refused.

Access to each action can be gated by [SOAP_Control](SOAP_Control.md), which
runs before the action to allow or deny the call.

## Examples

Expose an action, defined with Perl, that returns a fixed reply. In
`catalog.cfg`:

```
SOAP_Action  ping sub { return "pong" }
```

Define an action from an existing catalog [Sub](Sub.md):

```
SOAP_Action  lookup  order_status
```

## See also

[SOAP](SOAP.md), [SOAP_Control](SOAP_Control.md),
[SOAP_Enable](SOAP_Enable.md), [ActionMap](ActionMap.md), [Sub](Sub.md),
[GlobalSub](GlobalSub.md).

## Source

Parsed by `parse_action` in `lib/Vend/Config.pm` (into a name => coderef hash).
Consumed in `lib/Vend/SOAP.pm` (`AUTOLOAD`), which dispatches a request to
`$Vend::Cfg->{SOAP_Action}{$routine}`.
