# Sub

Defines a named Perl subroutine belonging to a catalog, callable from embedded
Perl ([perl] and [mvasp] blocks) and from event hooks such as
[SpecialSub](SpecialSub.md). Use it to package catalog logic once and reuse it
across pages.

**Scope:** catalog (`catalog.cfg`)

## Syntax

    Sub  <<MARKER
    sub subname { ... }
    MARKER

The value is the subroutine's Perl source (parser type `subroutine`). The
routine name is taken from the `sub NAME { ... }` you write. The "here
document" form shown above is the usual way to give a multi-line body. Default:
empty (no catalog subs).

## Description

`Sub` compiles the subroutine into the catalog's namespace and registers it
under its name, so embedded Perl can call it directly and directives that take a
subroutine name (for example [SpecialSub](SpecialSub.md), or a `Sub`-typed
[ActionMap](ActionMap.md)) can reference it.

Catalog subroutines run under Perl's `Safe` compartment and may not perform
operations that are trapped there (many I/O and system operations). To allow a
specific operator, use [SafeUntrap](SafeUntrap.md); for a routine that genuinely
needs unrestricted access, define it globally with
[GlobalSub](GlobalSub.md) instead, which requires
[AllowGlobal](AllowGlobal.md) for the catalog.

## Examples

Define a subroutine and call it from a page. In `catalog.cfg`:

```
Sub <<EOF
sub product_line {
    my ($sku) = @_;
    my $desc  = $Tag->data('products', 'description', $sku);
    my $price = $Tag->data('products', 'price', $sku);
    return "$sku: $desc \$$price";
}
EOF
```

On a page:

```
[perl tables=products]
    return main::product_line('os28004');
[/perl]
```

## Notes

As with any Perl here document, the end marker (`EOF` above) must be the only
text on its line, with no leading or trailing whitespace, and no trailing
semicolon.

## See also

[GlobalSub](GlobalSub.md), [SpecialSub](SpecialSub.md),
[AllowGlobal](AllowGlobal.md), [SafeUntrap](SafeUntrap.md),
[CodeDef](CodeDef.md), the [perl-embedding](../guides/perl-embedding.md) guide.

## Source

Parsed by `parse_subroutine` in `lib/Vend/Config.pm` (stored in
`$Vend::Cfg->{Sub}`); invoked from embedded Perl and from directives that
reference subroutine names.
