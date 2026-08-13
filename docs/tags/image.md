# image

Build an HTML `<img>` tag (or just an image URL) from a product SKU or an
image filename, resolving the catalog image directory, pulling `alt` text and
dimensions automatically, and optionally resizing. Reach for it wherever a
page shows a product or catalog image.

## Syntax

    [image src]
    [image src=os29000]
    [image src="thumb/os29000.png" alt="Step ladder"]

Standalone tag (no end tag). It returns an `<img ...>` element by default, or
a bare path/URL with the `src_only`, `name_only`, or `dir_only` options. The
result is not reparsed as Interchange Tag Language (ITL).

## Attributes

| Attribute           | Default | Description |
|---------------------|---------|-------------|
| `src`               | required | Product SKU, image basename, or a literal (relative or absolute) URL. |
| `sku`               | none    | Force lookup of the `image` field in the products database for this SKU before falling back to filename guesses. |
| `alt`               | product `description` (when `src` is a SKU) | Text for the `alt` attribute. |
| `title`             | value of `alt` | Text for the `title` attribute. |
| `default`           | `mv_imagedefault` scratch | Image used when none is found for the SKU. |
| `descriptionfields` | `DESCRIPTIONFIELDS` variable, else `description` | Product fields to draw the default `alt`/`title` from. |
| `imagefields`       | `IMAGEFIELDS` variable, else `image` | Product fields to draw the image filename from. |
| `imagesubdir`       | `mv_imagesubdir` scratch | Single subdirectory of the image dir to look in. |
| `getsize`           | `1`     | Use `Image::Size` to fill in `width` and `height`. |
| `makesize`          | none    | Resize the image (ImageMagick `mogrify` geometry, e.g. `64x48`), creating a per-size subdirectory. |
| `check_date`        | `0`     | With `makesize`, rebuild the resized copy when the source is newer. |
| `secure`            | same as current page | `1` forces an `https://` (secure image dir) path; `0` forces the plain path. |
| `ui`                | `0`     | Use the Admin UI image dirs (`UI_IMAGE_DIR`) with a locale segment. |
| `force`             | `0`     | Skip the on-disk existence/extension checks. |
| `dir_only`          | `0`     | Return only the resolved image directory. |
| `exists_only`       | `0`     | Return true only if the image exists. |
| `src_only`          | `0`     | Return only the resolved image path/URL, without the `<img>` wrapper. |
| `name_only`         | none    | Return the `src` prefixed with the image dir, without probing the filesystem. |
| `size_scratch_prefix` | none  | Store the discovered `width`/`height` into `$Tmp` values with this prefix. |
| `extra`             | none    | Extra literal text appended inside the `<img>` tag. |

Positional order: `src`.

Aliases: `geometry` and `resize` for `makesize`.

Standard HTML attributes are passed through to the tag when set: `width`,
`height`, `border`, `hspace`, `vspace`, `align`, `valign`, `style`, `class`,
`name`, and `id`. Because the tag declares `addAttr`, other named attributes
are accepted as options.

## Description

`[image]` resolves its `src` in stages:

1. An absolute URL (`http://` or `https://`) is used as-is.
2. If `src` looks like a filename (has an extension), it is used directly.
3. Otherwise `src` is treated as a product SKU: the products tables are
   searched for the fields named by `imagefields` (default `image`), and the
   product `description` is pulled in as the default `alt` text.
4. When only a basename is known, the tag probes for `.jpg`, `.gif`, `.png`,
   and `.jpeg` (in that order) in the resolved image directory.

The resolved name is prefixed with [ImageDir](../config/ImageDir.md) — or
[ImageDirSecure](../config/ImageDirSecure.md) on secure requests — unless it
is already absolute. When `getsize` is on and the file is found on disk, the
`Image::Size` module fills in the `width` and `height` attributes.

With `makesize` (or its `geometry`/`resize` aliases) and ImageMagick
installed, the tag creates a resized copy in a size-named subdirectory (for
example `64x48/`) using `mogrify`, and points the `<img>` at it. This
requires a writable image directory; the `mogrify` location can be set with
the `IMAGE_MOGRIFY` global variable.

## Examples

Show the image for product SKU `os29000`, whose `image` field is
`os29000.png`:

    [image os29000]

produces something like:

    <img src="/standard/images/os29000.png" width="120" height="150"
         alt="3' Step Ladder" title="3' Step Ladder">

Show a thumbnail by filename with a fallback default:

    [image src="thumb/[loop-field thumb]" default="thumb.gif"]

Get just the resolved path, for use in your own markup or JavaScript:

    [image src=os29000 src_only=1]

Generate a resized 100x100 copy on the fly:

    [image src=os29000 makesize="100x100"]

## Notes

The tag makes several assumptions about catalog layout (image directories,
product image fields, on-disk file presence), so for unusual setups it may be
simpler to build the `<img>` tag by hand. Resizing depends on ImageMagick's
`mogrify` being available on the server.

## See also

- [area](area.md)
- [ImageDir](../config/ImageDir.md),
  [ImageDirSecure](../config/ImageDirSecure.md)
- Concepts: [templating](../guides/templating.md),
  [catalog anatomy](../guides/catalog-anatomy.md)

## Source

Defined in `code/SystemTag/image.tag` as an inline Routine.
