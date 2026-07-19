# ItemAction

Maps a product code to a Perl subroutine that Interchange runs against each
matching cart line when the cart is updated. Reach for it to attach
per-item side effects (logging, dependent-item adjustment, custom
validation) to specific SKUs.

**Scope:** catalog (`catalog.cfg`)

## Syntax

    ItemAction  CODE  HANDLER

Parsed the same way as [ActionMap](ActionMap.md): `CODE` is the name the
action is filed under -- for `ItemAction` this is matched against a cart
item's product code (SKU) -- and `HANDLER` is one of:

- an anonymous Perl subroutine, `sub { ... }` (often a here-document);
- the name of a defined [Sub](Sub.md)/`GlobalSub`;
- a block of Interchange Tag Language (ITL)/HTML, wrapped and interpolated.

The directive accumulates; each line registers one handler. Default: empty.

## Description

When the cart is processed (the `toss_cart` routine that runs as cart
contents change), Interchange walks each line item. If an `ItemAction` is
registered under a name equal to that item's `code`, the handler is called
with a reference to the cart-item hash as its only argument. Its return
value is not used.

Because the lookup key is the item's product code, a handler fires only for
lines whose SKU matches its registered name -- `ItemAction` is per-SKU, not
a single catch-all cart hook. The routine may run more than once per request
if a page makes several changes to the cart.

Direct manipulation of the cart from your own Perl does *not* trigger
`ItemAction`; the hook fires only when the cart is changed through
Interchange's standard CGI-variable processing.

## Examples

Run a handler whenever the SKU `os28004` is present in a cart being
updated (put in `catalog.cfg`):

```
ItemAction os28004 <<EOR
sub {
    my $item = shift;
    Vend::Tags->log({ file => 'logs/items.log',
                      body => "touched $item->{code} qty $item->{quantity}" });
    return;
}
EOR
```

## Notes

The Interchange cart is a plain array of hash references with no
encapsulation, so nothing prevents other code from changing it without
firing this hook -- that is by design.

For more flexible, cart-wide triggers, prefer the newer
[CartTrigger](CartTrigger.md) and
[CartTriggerQuantity](CartTriggerQuantity.md) directives.

## See also

[CartTrigger](CartTrigger.md), [CartTriggerQuantity](CartTriggerQuantity.md),
[ActionMap](ActionMap.md), [FormAction](FormAction.md),
[FileControl](FileControl.md), the
[cart and checkout](../guides/cart-and-checkout.md) guide.

## Source

Parsed by `parse_action` in `lib/Vend/Config.pm`; dispatched per cart item
in `Vend::Cart::toss_cart` (`lib/Vend/Cart.pm`).
