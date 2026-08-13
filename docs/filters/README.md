# Filters

Filters transform a value on its way into or out of a page: you apply one with
the [filter](../tags/filter.md) tag, the `filter=` attribute of a form widget,
or the `filter` option of many other tags. Each page below documents one
filter — its input, its output, and a runnable example. See the
[forms](../guides/forms.md) and [templating](../guides/templating.md) guides
for where filters fit in the request cycle.

> **Start here: [Special filter notations](special-notations.md)** — five
> filter "names" are not files at all but numeric, `%N`, truncation, and
> word-limit forms recognized directly by Interchange's `filter_value()`
> routine and applied before any named filter is looked up.

## Case and text formatting

- [lc](lc.md) — lower-case the entire value, honoring the session locale.
- [lcfirst](lcfirst.md) — lower-case only the first character.
- [uc](uc.md) — upper-case the entire value.
- [ucfirst](ucfirst.md) — upper-case only the first character.
- [namecase](namecase.md) — normalize ALL-CAPS words to capitalized form
  ("DOE" → "Doe").
- [name](name.md) — rewrite a `Last, First` name into `First Last` order.
- [yesno](yesno.md) — turn a true/false value into the localized word `Yes` or
  `No`.
- [bold](bold.md) — wrap the value in an HTML `<b>` element.
- [italics](italics.md) — wrap the value in an HTML `<i>` element.
- [strikeout](strikeout.md) — wrap the value in an HTML `<strike>` element.
- [large](large.md) — wrap the value in a `<large>` element.
- [small](small.md) — wrap the value in an HTML `<small>` element.
- [pre](pre.md) — wrap the value in an HTML `<pre>` element.
- [tt](tt.md) — wrap the value in an HTML `<tt>` (monospace) element.

## HTML and entity encoding

- [encode_entities](encode_entities.md) — encode HTML-significant and
  non-printable characters as HTML entities.
- [encode_special_entities](encode_special_entities.md) — encode just the four
  HTML-special characters `"`, `&`, `<`, and `>`.
- [decode_entities](decode_entities.md) — decode HTML entities back to their
  literal characters.
- [restrict_html](restrict_html.md) — neutralize all HTML tags except an
  explicitly allowed set.
- [strip_html](strip_html.md) — remove HTML tags and comments, leaving plain
  text.
- [html2text](html2text.md) — convert HTML to plain text, turning block tags
  into newlines.
- [text2html](text2html.md) — convert plain-text line breaks into HTML `<br>`
  tags.
- [liven_urls](liven_urls.md) — wrap bare URLs in clickable `<a>` anchors.
- [mailto](mailto.md) — wrap an email address in an HTML `mailto:` link.
- [space_to_nbsp](space_to_nbsp.md) — convert literal spaces to `&nbsp;`
  entities.
- [lspace_to_nbsp](lspace_to_nbsp.md) — convert only leading spaces on each
  line to `&nbsp;`, preserving indentation.
- [textarea_put](textarea_put.md) — encode text for safe display inside an
  HTML `<textarea>`.
- [textarea_get](textarea_get.md) — decode the entities added by
  [textarea_put](textarea_put.md).
- [linkdecode](linkdecode.md) — un-escape hex-encoded ITL inside `action`,
  `href`, and `src` attributes so URL-encoded tags go live again.

## Dates and times

- [convert_date](convert_date.md) — format a date with a `strftime`-style
  string via the [convert-date](../tags/convert-date.md) tag.
- [strftime](strftime.md) — format a UNIX timestamp as a human-readable
  date/time string.
- [datetime2epoch](datetime2epoch.md) — convert a date (with optional time) to
  seconds since the Unix epoch.
- [date_change](date_change.md) — normalize a date/time into a compact
  `YYYYMMDDHHMM` string, chiefly for date-widget values.
- [duration](duration.md) — add a duration to a start date/time and return the
  resulting end date/time.
- [date2time](date2time.md) — deprecated; convert a US-style date-and-time to
  epoch seconds (prefer [datetime2epoch](datetime2epoch.md)).

## Numbers and money

- [commify](commify.md) — format a number with comma thousands separators.
- [currency](currency.md) — format a number as a currency amount per the
  catalog locale.
- [round](round.md) — round a number to a fixed number of decimal places,
  floating-point-safe.
- [integer](integer.md) — return the integer value via Perl's `int()`,
  truncating toward zero.
- [digits](digits.md) — keep only digits (`0-9`).
- [digits_dash](digits_dash.md) — keep only digits and dashes.
- [digits_dot](digits_dot.md) — keep only digits and dots.
- [zerofix](zerofix.md) — strip leading zeros from the value.
- [roman](roman.md) — convert an integer to its Roman numeral representation.

## Strings and whitespace

- [strip](strip.md) — trim leading and trailing whitespace.
- [compress_space](compress_space.md) — trim and collapse every internal run of
  whitespace to a single space.
- [no_white](no_white.md) — remove every whitespace character.
- [alpha](alpha.md) — keep only ASCII letters.
- [alphanumeric](alphanumeric.md) — keep only ASCII letters and digits.
- [word](word.md) — keep only word characters (letters, digits, underscores).
- [backslash](backslash.md) — remove every backslash character.
- [line](line.md) — return only the first line, discarding the rest.
- [oneline](oneline.md) — keep only the first line (discard from the first
  break onward).
- [tabbed](tabbed.md) — replace newlines with TAB characters.
- [dos](dos.md) — convert newlines to DOS/Windows `CR`+`LF`.
- [mac](mac.md) — convert line endings to classic Mac OS `CR`.
- [unix](unix.md) — normalize line endings to a single Unix line feed.
- [space_to_null](space_to_null.md) — replace runs of whitespace with a single
  NUL character.
- [qb_safe](qb_safe.md) — remove characters QuickBooks cannot handle in
  imported data.
- [loc](loc.md) — localize the value via the active locale's message catalog.

## Data structures and options

- [option_format](option_format.md) — convert NUL-delimited option triples into
  a `value=label*` option string.
- [line2options](line2options.md) — convert a multi-line string into a
  comma-separated options list.
- [options2line](options2line.md) — turn a comma-separated list into one item
  per line.
- [colons_to_null](colons_to_null.md) — replace each `::` with an ASCII NUL.
- [null_to_colons](null_to_colons.md) — replace NUL characters with `::`.
- [null_to_comma](null_to_comma.md) — replace NUL characters with a comma.
- [null_to_space](null_to_space.md) — replace NUL characters with a space.
- [last_non_null](last_non_null.md) — return the last non-empty NUL-separated
  field.
- [nullselect](nullselect.md) — return the first non-empty value from a
  NUL-separated list.
- [show_null](show_null.md) — make embedded NUL characters visible as literal
  `\0`.
- [checkbox](checkbox.md) — return the value unchanged if it has length, else
  the empty string (checkbox storage filter).
- [cgi](cgi.md) — replace the value with the current CGI value of the variable
  it names.
- [value](value.md) — return the value of the user variable named by the input.
- [gate](gate.md) — pass the input through when a scratch variable is true,
  else return empty (conditional suppression).
- [vars_and_comments](vars_and_comments.md) — run Interchange's standard
  variable-substitution and comment-stripping pass over the value.

## Security and hashing

- [bcrypt](bcrypt.md) — hash a password with bcrypt using a
  [UserDB](../guides/user-database.md) profile's cost.
- [crypt](crypt.md) — hash the value with the system `crypt()` function.
- [encrypt](encrypt.md) — PGP/GPG-encrypt the input with the catalog's
  configured program and key.
- [md5](md5.md) — return the 32-character lowercase hex MD5 digest of the input.
- [sha1](sha1.md) — replace the value with its SHA-1 digest, in hexadecimal.

## SQL and database

- [dbi_quote](dbi_quote.md) — quote a value for SQL using a specific database's
  DBI `quote` method.
- [sql](sql.md) — escape a string for SQL without reference to a particular
  driver.
- [pgbool](pgbool.md) — coerce a value to a PostgreSQL boolean, undefined as
  false.
- [pgbooln](pgbooln.md) — coerce a value to a PostgreSQL boolean, undefined as
  NULL.
- [lookup](lookup.md) — treat the input as a key and return a column value from
  a named table.
- [next_sequential](next_sequential.md) — supply the next unused value in a
  database-backed numbering sequence when a field is blank.

## Files and URLs

- [urlencode](urlencode.md) — percent-encode the value so it is safe in a URL.
- [urldecode](urldecode.md) — decode URL `%XX` percent-encoding back to
  characters.
- [filesafe](filesafe.md) — escape the input so it is safe as a filename, using
  `%XX` escapes.
- [strip_path](strip_path.md) — remove every directory component, leaving the
  file name.
- [pagefile](pagefile.md) — strip leading `.` and `/` so a value is safe as a
  page name.
- [mime_type](mime_type.md) — return the MIME type for a filename from its
  extension.
- [upload](upload.md) — replace a form variable with the contents of the file
  uploaded for it.

## Private and internal

- [acl2hash](acl2hash.md) — convert an access-control-list string into a Perl
  hash literal; used by the admin ACL widget.
- [hash2acl](hash2acl.md) — serialize an option-hash string back into an ACL
  string; the inverse of [acl2hash](acl2hash.md).
- [filter_select](filter_select.md) — choose a value-storage filter
  automatically from the submitting widget type; used by the survey/form
  machinery.

## Aliases

- [calculated](calculated.md) → [filter_select](filter_select.md).
- [e](e.md) → [encode_entities](encode_entities.md).
- [entities](entities.md) → [encode_entities](encode_entities.md).
- [lower](lower.md) → [lc](lc.md).
- [upper](upper.md) → [uc](uc.md).
- [urldecode](urldecode.md) has two aliases: [urld](urld.md) and
  [url](url.md).
