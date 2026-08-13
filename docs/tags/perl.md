# perl

Execute the tag body as embedded Perl code and return the value of its last
expression. Reach for it when a page needs logic beyond what individual
Interchange Tag Language (ITL) tags express — computing values, looping over
data, or manipulating strings — with access to Interchange's data structures
and, optionally, database handles.

## Syntax

    [perl]CODE[/perl]
    [perl tables="products inventory"]CODE[/perl]
    [perl global=1]CODE[/perl]

Container tag (has an end tag). Its body is interpolated by ITL first (unless
suppressed), then run as Perl. The return value replaces the tag on the page.

## Attributes

| Attribute | Default | Description |
|-----------|---------|-------------|
| `tables`  | (none)  | Whitespace-separated list of database tables to open for use inside the block as `$Db{table}` (and `$Sql{table}` for DBI tables). |
| `subs`    | off     | Share catalog `Sub` and `GlobalSub` subroutines into the block so they can be called by name. |
| `global`  | off     | Run outside the `Safe` compartment (full, unrestricted Perl). Only honored when `AllowGlobal` is set for the catalog. |
| `no_strict` | off   | Do not apply `use strict` (global blocks only). |
| `file`    | (none)  | Read this file and prepend its contents to the body before evaluating. |

Positional order: `tables`.
Alias: `table` for `tables`.

Error-formatting options `number_errors`, `trim_errors`, and `eval_label`
control how a compile/run error in the body is reported.

## Description

`perl` compiles and runs its body in Interchange's calculation context.
Several catalog data structures are pre-shared as package variables you can
read and (carefully) write:

| Variable    | Contents |
|-------------|----------|
| `$Tag`      | Object to call any ITL tag, e.g. `$Tag->data('products','price',$sku)`. |
| `$CGI`      | Hash ref of submitted form/CGI values. |
| `$Values`   | Hash ref of the user's stored form values. |
| `$Scratch`  | Hash ref of scratch variables. |
| `$Session`  | The session hash ref. |
| `$Config`   | The catalog configuration (`$Vend::Cfg`). |
| `$Variable` | Catalog `Variable` settings. |
| `$Items`    | The current shopping cart (array ref). |
| `$Carts`    | All carts. |
| `$Db{name}` | Handle for each table named in `tables`. |

### Safe vs. global

By default the body runs inside a Perl `Safe` compartment, which blocks file
access, system calls, and other unsafe operations — appropriate for
catalog-editable page code. Setting `global=1` runs it as ordinary Perl with
full privileges, but only if the `AllowGlobal` directive lists this catalog;
otherwise the request is denied. Global blocks apply `use strict` unless
`no_strict` (or the `PerlNoStrict` directive) turns it off.

### Table access

List tables in the `tables` attribute to open them before the block runs. DBI
tables also expose a raw database handle via `$Sql{name}` so you can prepare
and run statements directly.

### Return value

The block returns the value of its last evaluated expression, which is
substituted for the tag. Return an empty string (or nothing) to emit nothing.

## Examples

Compute and print a value:

    [perl]
        my $rate = 0.0825;
        return sprintf("Tax rate is %.2f%%", $rate * 100);
    [/perl]

produces:

    Tax rate is 8.25%

Read a submitted value and branch:

    [perl]
        return $CGI->{quantity} > 10 ? "Bulk order" : "Standard order";
    [/perl]

Open a table and look up a field with the `$Tag` object:

    [perl tables=products]
        my $sku = 'os28004';
        my $desc = $Tag->data('products', 'description', $sku);
        return "You are viewing: $desc";
    [/perl]

Iterate a query result built with the raw DBI handle:

    [perl tables=products]
        my $sth = $Sql{products}->prepare('SELECT sku, price FROM products');
        $sth->execute;
        my $out = '';
        while (my $r = $sth->fetchrow_arrayref) {
            $out .= "$r->[0]: $r->[1]\n";
        }
        return $out;
    [/perl]

## Notes

- For a short expression that needs no tables, no argument, and no body
  interpolation, use [calc](calc.md) — it is lower overhead. Values set in one
  [calc](calc.md) block persist to later [calc](calc.md) blocks on the same
  page.
- Perl execution is refused entirely when a request arrives over RPC/SOAP
  (`$Vend::NoInterpolate`), and nested `[perl]` inside an already-`Safe`
  context returns undef.
- Because the body is ITL-interpolated before it runs, stray `[` and `]` in
  your Perl can be misread as tags; guard them or set the appropriate pragma.

## See also

- [calc](calc.md) — lightweight expression evaluation
- [mvasp](mvasp.md) — ASP-style embedded Perl pages
- [AllowGlobal](../config/AllowGlobal.md), [PerlNoStrict](../config/PerlNoStrict.md)
- [perl embedding guide](../guides/perl-embedding.md)

## Source

Defined in `code/SystemTag/perl.coretag`. Implemented by
`Vend::Interpolate::tag_perl`.
