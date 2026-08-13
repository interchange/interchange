# deliver

Sends raw content — a file, or the tag body — straight to the browser
without wrapping it in the page template, or issues an HTTP redirect. Reach
for it to serve a download (a PDF, CSV, or binary file) or to bounce the
shopper to another URL from within a page.

## Syntax

    [deliver type="mime/type" file="path"]
    [deliver type="mime/type"]...body content...[/deliver]
    [deliver location="url" status="302 moved"]

Container tag (has an end tag). It takes over the response: after it runs,
the request is considered sent.

## Attributes

| Attribute       | Default                     | Description |
|-----------------|-----------------------------|-------------|
| `type`          | `application/octet-stream`  | Content MIME type (for a file, guessed from the name if omitted). |
| `file`          | (none)                      | File to read and deliver. |
| `location`      | (none)                      | URL to redirect to instead of delivering content. |
| `status`        | `302 moved` (for a bounce)  | HTTP status line. |
| `extra_headers` | (none)                      | Additional HTTP headers, one per line (`Header: value`). |
| `get_encrypted` | (none)                      | Extract the Nth PGP message block from the content before sending. |

Positional order: `type`. `[deliver]` accepts arbitrary additional
attributes (`addAttr`).

## Description

The content comes from `file` (read from disk) or from the tag body. For a
file, when `type` is omitted the MIME type is guessed from the filename,
and non-`text/*` types are read in raw (binary-safe) mode.

`[deliver]` sets the response headers directly:

- **Download / raw content.** It sends a `Content-Type` header (and a
  `Status` header if you set `status`), plus any `extra_headers`, turns on
  the `download` pragma, and writes the content as the entire response.
- **Redirect.** If you supply `location`, the tag instead emits `Status`
  (default `302 moved`) and `Location` headers and a short "Redirecting…"
  body, bouncing the browser to that URL. Header values are scrubbed to
  prevent header injection.
- **PGP extraction.** `get_encrypted` strips everything outside the Nth
  `BEGIN PGP MESSAGE`/`END PGP MESSAGE` block before sending — used to
  deliver an encrypted payload.

In all content cases the tag marks the response as sent (`$Vend::Sent`),
so no page template is applied around it. Place `[deliver]` where it will
run before any other output for the page.

## Examples

Deliver a CSV file as a download:

    [deliver type="text/csv" file="tmp/stats.csv"]

Redirect the shopper to another page:

    [deliver location="[area index]"]

Deliver generated content built in the body:

    [deliver type="text/plain"][loop list="a b c"][loop-code]
    [/loop][/deliver]

## Notes

Access to files delivered this way should be authorized first — a common
pattern gates delivery behind a [userdb](userdb.md) access-control check
(see `dist/strap/pages/deliver.html`, which verifies a file ACL before
streaming the file).

Because `[deliver]` writes the whole response and marks it sent, any page
content after it is not used; do not expect the surrounding template to
render.

## See also

[file](file.md), [tag](tag.md) (for `[tag header]`),
[userdb](userdb.md), the [security](../guides/security.md) guide.

## Source

Defined in `code/SystemTag/deliver.coretag` (inline `Routine`).
