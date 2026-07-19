# value

Return the value of a form variable from the `$Values` space — the
persistent per-session store that form fields read from and write to. Reach
for `[value ...]` whenever you need to redisplay something the shopper typed
(name, address, email) or any value your pages have stashed with a form or
with [seti](seti.md)/`set`.

## Syntax

    [value name]
    [value name=name set="new value" filter=filter_name]

Standalone tag (no end tag). By default the returned text is **not** reparsed
as Interchange Tag Language (ITL): any `[` in the stored value is encoded as
`&#91;` so a value cannot inject tags. HTML `<` characters are likewise
encoded to `&lt;` unless you ask otherwise (see `enable_html`).

## Attributes

| Attribute      | Default | Description |
|----------------|---------|-------------|
| `name`         |         | Name of the form variable to read (positional 1). |
| `set`          |         | Store this string into the variable first, then return it. |
| `filter`       |         | Apply a [filter](../filters/) (or space-separated list) to the value. |
| `keep`         | `0`     | With `filter`, filter for display only; do not write the filtered value back into `$Values`. |
| `scratch`      | `0`     | Also copy the value into the scratch variable of the same name. |
| `default`      |         | String to return when the variable is missing or empty (false). |
| `hide`         | `0`     | Perform side effects (`set`, `filter`, `scratch`) but return the empty string. |
| `enable_itl`   | `0`     | Leave `[` characters intact so stored ITL is interpolated. |
| `enable_html`  | `0`     | Leave `<` characters intact so stored HTML is rendered. |
| `values_space` |         | Read from a named `$Values` namespace instead of the default (see [values-space](values-space.md)). |

Positional order: `name`.

## Description

`$Values` is the values space: the hash that holds the current session's form
input. When a shopper submits a form, each field is copied into `$Values`
under its `name`, so `[value email]` on a later page shows what they entered
on an earlier one. Interchange itself keeps order and account fields here
(`fname`, `lname`, `address1`, `mv_order_number`, and so on).

`[value name]` looks the variable up in `$Values` and returns it, or the empty
string if unset. The lookup order for side effects is: `set` (store first),
then `filter` (transform, writing back unless `keep`), then `scratch` (mirror
into scratch), then `hide`/`default`/encoding.

Because the default output is entity-encoded, `[value ...]` is safe to place
directly into an HTML attribute or body without a separate `[filter]` — a
value containing `[page ...]` or `<script>` is neutralized. Use
[value-extended](value-extended.md) when you need multi-value (`\0`-joined)
handling, indexing, file-upload access, or a custom joiner.

Related access tags: [cgi](cgi.md) reads the raw CGI submission (before it is
copied into `$Values`); [scratch](scratch.md) reads the scratch space;
[var](var.md) and [config](config.md) read catalog configuration Variables.

## Examples

Redisplay a submitted email address (encoded, safe for HTML):

    You entered [value email].

Provide a fallback when the field is empty:

    [value name=country default=US]

Seed a field and echo it in one step:

    [value name=mv_shipmode set=upsg]

Filter for display only, leaving the stored value untouched:

    [value name=phone_day filter=digits keep=1]

Pre-fill an input on an account form, exactly as the strap demo does:

    <input type="text" name="fname" value="[value fname]">

## Notes

- `[evalue name]` is a preset alias of this tag (`keep=1
  filter=encode_entities`); use it to HTML-escape a value for display without
  altering what is stored. See [evalue](evalue.md).
- `default` triggers on any false value, including `0` and the empty string,
  not only on an undefined variable.
- `set` writes into `$Values`, which persists for the session; it is not a
  scratch or temporary assignment.

## See also

- [value-extended](value-extended.md) — multi-value, indexed, and file-upload
  variants
- [evalue](evalue.md) — entity-encoding alias
- [cgi](cgi.md) — raw CGI form input
- [scratch](scratch.md) / [seti](seti.md) — scratch-space values
- [var](var.md) — catalog Variables
- The [forms guide](../guides/forms.md)

## Source

Defined in `code/SystemTag/value.coretag`. Implemented by
`Vend::Interpolate::tag_value` (`MapRoutine`).
