# captcha

Generates and checks CAPTCHA images to confirm that a form was submitted by a
human. Reach for it to protect account creation, contact forms, or anything
else you want to shield from automated submissions. Requires the Perl module
`Authen::Captcha`.

## Syntax

    [captcha function=image]
    [captcha function=check]
    [captcha function=code]

Standalone tag (no end tag).

## Attributes

| Attribute        | Default                    | Description |
|------------------|----------------------------|-------------|
| `function`       | (none)                     | What to do: `image`, `check`, or `code` (see below). |
| `length`         | `4`                        | Number of characters in a generated code. |
| `guess`          | `[cgi mv_captcha_guess]`   | The user's answer, checked against the code. |
| `source`         | last code / `[cgi mv_captcha_source]` | Code to check the guess against. |
| `image-subdir`   | `captcha`                  | Subdirectory (under the images dir) for the image files. |
| `image-location` | see below                  | Filesystem directory where PNG files are written. |
| `image-path`     | `[var IMAGE_DIR]/captcha`  | URL base used when building the image path. |
| `error-name`     | `captcha`                  | Error name used when the tag records an error. |
| `name-only`      | `0`                        | For `image`, return the image path only, not an `<img>` tag. |
| `relative`       | `0`                        | For `image` + `name-only`, return a path without the image dir prefix. |
| `reset`          | `0`                        | Discard the session code and generate a fresh one. |

Positional order: `function`. Alias: `func` for `function`. The tag accepts
arbitrary additional attributes (`addAttr`).

## Description

The tag maps to an inline routine that wraps `Authen::Captcha`. If that module
is not installed, the tag logs an error and returns nothing, so pages degrade
rather than crash.

The `function` attribute selects behavior:

- **`image`** — the usual first call on a page. It generates a code (unless one
  was already generated this request), stores it in the session at
  `$Vend::Session->{captcha}`, writes a PNG to the image directory, and returns
  an `<img>` tag (built by [image](image.md)) pointing at it. With `name-only`
  it returns just the path; with `relative` that path omits the image-dir
  prefix. Any function name matching `im?ge?` (for example `image_tag`,
  `relative_image`) is treated as an image request.
- **`check`** — validates a submitted `guess` against the stored (or `source`)
  code. It returns `1` on a match. On failure it returns `0` and records an
  error (retrievable via [error](error.md)) describing the cause: code not
  checked, expired, never generated, or mismatched.
- **`code`** — returns the raw generated code (generating one if needed).
  Useful for debugging; do not expose it to end users.

Image files are written under `ScratchDir/<image-subdir>` for bookkeeping and
to the resolved `image-location` for serving. When `Global::NoAbsolute` is off
and the `DOCROOT` variable is set, the default location is
`[var DOCROOT][var IMAGE_DIR]/<subdir>`; otherwise it falls back to
`images/<subdir>`. The variables `CAPTCHA_IMAGE_SUBDIR`, `CAPTCHA_IMAGE_LOCATION`,
`CAPTCHA_IMAGE_PATH`, and `CAPTCHA_UMASK` override the corresponding defaults.
Normally only one code/image is generated per request; set `reset` to force
another (you must then save the new code yourself, since the session slot is
overwritten).

## Examples

A form that shows a CAPTCHA image and checks the guess on resubmission:

    [if cgi mv_captcha_guess]
        [tmp good][captcha check][/tmp]
        [if scratch good]
            You guessed right!
        [else]
            Sorry, try again.
        [/else]
        [/if]
        <br>
    [/if]

    [captcha function=image]

    <form action="[process href="@@MV_PAGE@@"]">
    <input type=text name=mv_captcha_guess value="">
    <input type=submit value="Guess">
    </form>

    [error auto=1]

## Notes

- The module dependency `Authen::Captcha` is not part of a base Interchange
  install; without it every call returns an empty string and logs a message.
- Generated codes live in the session, so `check` and `image` must happen in
  the same session (the normal form-then-submit flow).

## See also

- [image](image.md) — used to build the returned `<img>` tag
- [error](error.md) — display the errors `check` records
- [cgi](cgi.md) — read the `mv_captcha_guess` field
- Guide: [Forms](../guides/forms.md)

## Source

Defined in `code/SystemTag/captcha.coretag` (inline `Routine`). Depends on the
`Authen::Captcha` Perl module.
