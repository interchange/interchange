# bounce

Sends an HTTP redirect to the browser, sending it to another URL or
Interchange page and stopping further processing of the current page. Reach
for it to redirect after a form submission, to enforce access rules, or to
send a visitor to a computed destination.

## Syntax

    [bounce href="URL"]
    [bounce page=pagename]
    [bounce href="URL" if=condition]

Standalone tag (no end tag). It is a parser control tag handled specially in
`lib/Vend/Parse.pm`; it does not work from embedded Perl as
`$Tag->bounce(...)`.

## Attributes

| Attribute | Default     | Description |
|-----------|-------------|-------------|
| `href`    | (none)      | Absolute URL to redirect to. |
| `page`    | (none)      | Interchange page name; used to build `href` when `href` is absent. |
| `if`      | (true)      | Only redirect when this value is true. |
| `status`  | `302 moved` | HTTP status line to send. |
| `target`  | (none)      | Adds a `Window-Target` header (framed targets). |

Positional order: `href`, `if`.

Like [goto](goto.md), the `if` (and `unless`) attribute is a plain truth test
on the already-interpolated value, not an [if](if.md)-style `type term op`
test.

## Description

When `[bounce]` fires it builds an HTTP redirect response: a `Status:` line
(default `302 moved`) and a `Location:` header pointing at the target URL.
The remaining page buffer is discarded, a short "Redirecting to ..." body is
sent, and the request is aborted — so tags after the `[bounce]` do not run.

If `href` is not given but `page` is, the URL is generated from the page name
with [area](area.md) (`tag_area`), producing a catalog-correct link. The
resulting `href` is scrubbed of characters that are illegal in a header.

Because `[bounce]` acts only when the parser reaches it, a `[bounce]` inside a
looping list is not seen until the loop has run to completion.

### Conditional redirect

With `if`, the redirect happens only when the condition is true. Interpolate
the test into the attribute so it resolves to a truth value first:

    [bounce href="[area ord/basket]" if="[calc][nitems] > 2[/calc]"]

## Examples

Redirect anonymous visitors to a login/violation page (the URL comes from
[area](area.md)):

    [if !session logged_in]
    [bounce href="[area login]"]
    [/if]

Redirect to another catalog page by name:

    [bounce page=ord/basket]

Send the browser to an absolute external URL:

    [bounce href="https://example.com/"]

## Notes

HTTP requires the `Location` URL to be absolute; a bare path such as
`href="/"` may draw a browser warning. Prefer [area](area.md) (or `page=`)
to generate a fully-qualified, catalog-correct URL.

To redirect *without* discarding output already produced, or from inside
Perl, set `$Vend::StatusLine` yourself instead — `[bounce]` is specifically
the page-level, stop-everything form.

## See also

[goto](goto.md), [area](area.md); the
[templating](../guides/templating.md) guide.

## Source

Parser control tag. Registered in `%Routine`/`%Special` in
`lib/Vend/Parse.pm` (the `%Routine` entry is a stub returning `''`); the real
behavior — building `$Vend::StatusLine` and aborting the page — is in
`Vend::Parse::start` (the `$tag eq 'bounce'` branch).
