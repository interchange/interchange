# mvasp

Run the tag body as an ASP-style embedded-Perl page, mixing literal HTML
with `<% ... %>` Perl blocks. Reach for it when you want to write a page
mostly in Perl with occasional HTML, the inverse of sprinkling
[perl](perl.md) tags into HTML.

## Syntax

    [mvasp tables="products inventory"]
    <% my $n = 3; %>
    <p>The number is <%= $n %>.</p>
    [/mvasp]

Container tag. The body is **not** reparsed as ITL (`NoReparse`); it is
translated to Perl and executed once.

## Attributes

| Attribute   | Default | Description |
|-------------|---------|-------------|
| `tables`    | (none)  | Space-separated list of database tables to make available inside the Perl. |
| `no_return` | on      | Suppress the value of the final Perl expression as output (only explicit `HTML()`/`<%= %>` emit text). |

Positional order: `tables`.
Alias: `table` for `tables`.

## Description

`[mvasp]` treats its body as an ASP template: text outside `<% %>` markers is
literal output, `<% ... %>` runs Perl for its side effects, and `<%= expr %>`
runs Perl and emits the result. The tag rewrites the body into a Perl program
— literal spans become `HTML(...)` calls and code spans are spliced in
between — and passes the whole thing to the same executor as
[perl](perl.md) (`Vend::Interpolate::tag_perl`). It therefore runs under the
same `Safe` restrictions and honors the `tables` list the same way `[perl]`
does: tables you name become available as `$Db{table}` handles.

Use `HTML(...)` inside a `<% %>` block, or `<%= ... %>`, to produce output;
by default (`no_return=1`) the value of the last statement is discarded.

Because the body is embedded Perl, all of Interchange's Perl API is
available (`$Tag`, `$Values`, `$Scratch`, `$CGI`, and so on). See
[embedding Perl](../guides/perl-embedding.md) for that interface and its
security implications.

## Examples

A minimal page fragment:

    [mvasp]
    <%
        my @colors = qw/red green blue/;
    %>
    <ul>
    <% for my $c (@colors) { %>
        <li><%= $c %></li>
    <% } %>
    </ul>
    [/mvasp]

produces:

    <ul>
        <li>red</li>
        <li>green</li>
        <li>blue</li>
    </ul>

Read a product description with a table made available:

    [mvasp tables=products]
    <%
        my $desc = $Db{products}->field('os28005', 'description');
    %>
    <p>Featured: <%= $desc %></p>
    [/mvasp]

## Notes

`[mvasp]`, like `[perl]`, runs only where Interchange permits embedded Perl
(`Safe`-restricted unless global Perl is enabled for the catalog). It cannot
be invoked from RPC contexts. Prefer [perl](perl.md) for small snippets;
reach for `[mvasp]` when Perl dominates the page.

## See also

- [perl](perl.md) — embedded Perl the other way round (Perl in HTML)
- [calc](calc.md), [calcn](calcn.md)
- [embedding Perl](../guides/perl-embedding.md)

## Source

Defined in `code/SystemTag/mvasp.coretag`. Implemented by
`Vend::Interpolate::mvasp` (`lib/Vend/Interpolate.pm`), which delegates to
`Vend::Interpolate::tag_perl`.
