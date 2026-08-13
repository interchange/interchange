# SpecialSub

Registers catalog Perl subroutines as handlers for specific Interchange events
-- a missing page, session creation, credit-card type detection, shipping and
weight callouts, and more. Use it to hook custom logic into points the core
already exposes.

**Scope:** catalog (`catalog.cfg`)

## Syntax

    SpecialSub  EVENT  SUBNAME

The value is one or more `event subname` pairs (parser type `hash`), where
`SUBNAME` names a subroutine defined with [Sub](Sub.md) (or a
[GlobalSub](GlobalSub.md)). Default: empty.

Recognized events include:

- `request_init` -- runs on every request, right after catalog selection and
  before the session is assigned. (Named `catalog_init` before Interchange
  5.5.2.)
- `admin_init` -- runs on every request from an administrative user, after the
  embedded-Perl objects are initialized.
- `debug_qualify` -- decides whether debug mode applies to the current client
  (consulted only when [DebugHost](DebugHost.md) is unset or the client matches
  it).
- `flypage` -- determines the result set for the flypage.
- `guess_cc_type` -- derives the credit-card type from the card number; return
  a type name to override Interchange's built-in detection, or a false value to
  fall through to it.
- `init_session` -- runs when a new session is created; called with the new
  session hash.
- `lockout` -- runs when a misbehaving client is locked out (see
  [RobotLimit](RobotLimit.md)); a true return suppresses the default
  [LockoutCommand](LockoutCommand.md) action.
- `missing` -- runs when a requested page is missing; may return `(1, PAGE)`
  to serve `PAGE`, a plain true value to indicate it handled the response, or a
  false value to fall through to the `missing`
  [SpecialPage](SpecialPage.md).
- `order_missing` -- runs when a missing product is added to the cart; a true
  return suppresses the log message.
- `shipping_callout` -- runs after shipping is calculated, before the result is
  formatted.
- `weight_callout` -- runs after weight is computed for shipping; returns the
  adjusted weight.

The core also dispatches a few internal events (for example `set_source`,
`areapage`, and `autoload_inspect`); the list above covers the events intended
for catalog customization.

## Description

Each handler is a normal catalog subroutine. Because catalog code runs under
Perl's `Safe` compartment, a `SpecialSub` may lack permission for some
operations; relax specific operators with [SafeUntrap](SafeUntrap.md), or
define the routine as an unrestricted [GlobalSub](GlobalSub.md) at the global
level instead.

## Examples

Handle a missing page by treating its name as a product-group/category search
(from the strap demo's `catalog.cfg`):

```
SpecialSub  missing  ncheck_category
```

Recognize a local credit-card type, defined inline with [Sub](Sub.md):

```
SpecialSub  guess_cc_type  check_cc

Sub check_cc <<EOS
sub {
    my $num = shift;
    return 'LOCAL_TYPE' if $num =~ /^41/;
    return;
}
EOS
```

Give dealers a 10% shipping discount on UPS modes:

```
SpecialSub shipping_callout custom_shipping

Sub custom_shipping <<EOS
sub {
    my ($final, $mode, $opt, $o) = @_;
    $final *= .90 if $Scratch->{dealer} and $mode =~ /UPS/i;
    return $final;
}
EOS
```

## See also

[Sub](Sub.md), [GlobalSub](GlobalSub.md), [SpecialPage](SpecialPage.md),
[SafeUntrap](SafeUntrap.md), [DebugHost](DebugHost.md),
[RobotLimit](RobotLimit.md).

## Source

Parsed by `parse_hash` in `lib/Vend/Config.pm` (stored in
`$Vend::Cfg->{SpecialSub}`); dispatched at the corresponding events in
`lib/Vend/Dispatch.pm`, `lib/Vend/Ship.pm`, and related modules.
