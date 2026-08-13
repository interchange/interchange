# css

Take CSS held in an Interchange variable (or supplied literally), write it to a
`.css` file under the image directory, and return a `<link>` element pointing
at that file -- falling back to an inline `<style>` block when the file cannot
be written. Reach for it to serve dynamically generated stylesheets as cacheable
static files.

## Syntax

    [css NAME]
    [css name=NAME media=... timed=... output_dir=...]

Standalone tag. The returned markup is not reparsed.

## Attributes

| Attribute     | Default    | Description |
|---------------|------------|-------------|
| `name`        |            | Variable name holding the CSS; also the output file basename (first positional). |
| `literal`     |            | CSS text to use directly instead of reading the `name` variable. |
| `output_dir`  | `images`   | Directory the `.css` file is written to. |
| `imagedir`    | `ImageDir` | URL prefix for the generated `<link href>`. |
| `no_imagedir` |            | Omit the image-directory URL prefix. |
| `relative`    |            | Place the file (and URL) in a subdirectory matching the current page's path. |
| `media`       |            | Value for the `<link media="...">` / stylesheet media attribute. |
| `basefile`    |            | Source file to compare modification times against; rewrite only when newer. |
| `timed`       |            | Rewrite the file only after this interval (bare number means minutes). |
| `mode`        | `0644`     | Octal permission mode for the written file. |

Positional order: `name`.

## Description

The CSS content is either `literal` or the interpolated value of the ITL
variable named `name` (as returned by [var](var.md)). A leading `<style ...>`
and trailing `</style>` are stripped, so a variable that wraps its CSS in a
style block still produces a clean stylesheet file.

The output basename is `lc(NAME).css`. The file is written to `output_dir`
(default `images`) and the returned link points at `ImageDir` + basename. The
file is (re)written when it is missing, when `basefile` is newer than it, or
when a `timed` interval has elapsed; otherwise the existing file is reused.

If the target file or directory is not writable, the tag logs the reason and
returns the CSS inline in a `<style type="text/css">...</style>` block instead
of a link, so a page still renders correctly.

## Examples

Serve the CSS held in the `STYLE` variable as `images/style.css`:

    [css STYLE]

produces:

    <link rel="stylesheet" href="/catalog-images/style.css">

(the `href` prefix is whatever [ImageDir](../config/ImageDir.md) is set to).

Add a media type and only regenerate the file every 60 minutes:

    [css name=PRINT media=print timed=60]

## Notes

Because the tag writes into the document root's image directory, the web
server must be able to write there for the link form to be used; otherwise it
silently degrades to inline CSS (with a log entry). Generating the file once
lets browsers cache the stylesheet across requests.

## See also

[var](var.md), [ImageDir](../config/ImageDir.md),
[../guides/templating.md](../guides/templating.md)

## Source

Defined in `code/UserTag/css.tag`. Implemented by the inline Routine in that
file.
