# Pragmas

Pragmas control aspects of page parsing, output, and data handling in
Interchange. Unlike ordinary configuration directives, a pragma can be set at
three levels:

- **Catalog-wide**, with the [Pragma](../config/Pragma.md) directive in
  `catalog.cfg` — equivalent to placing a `[pragma ...]` tag on every page, but
  resolved once at catalog startup.
- **Page-wide**, with the `[pragma NAME]` (or `[pragma NAME 0]`) tag anywhere
  on a page.
- **Block-wide**, with `[tag pragma NAME]VALUE[/tag]` around an Interchange Tag
  Language (ITL) block.

In Interchange source, pragmas are read through `$::Pragma->{NAME}` (the older
`$Vend::Cfg->{Pragma}{NAME}` form was replaced in 5.0). The default value for a
pragma comes from the [Pragma](../config/Pragma.md) directive; a page or block
setting overrides it for the duration of that page or block.

Each page below documents one pragma: its accepted values, default, runtime
effect, and the source that consumes it.

## Page processing and interpolation

- [init_page](init_page.md) — run a Sub/GlobalSub over a page before any
  variable substitution or tag interpolation.
- [pre_page](pre_page.md) — run a Sub/GlobalSub after variable substitution but
  before tag interpolation.
- [post_page](post_page.md) — run a Sub/GlobalSub over output before image
  rewriting; a true return skips the image rewrite.
- [download](download.md) — deliver content verbatim, suppressing all output
  interpolation and image rewriting.
- [no_default_reparse](no_default_reparse.md) — stop container-tag output from
  being reparsed by default.
- [no_html_comment_embed](no_html_comment_embed.md) — stop ITL wrapped in HTML
  comments (`<!--[tag]-->`) from being unwrapped and interpolated.
- [interpolate_itl_references](interpolate_itl_references.md) — interpolate ITL
  inside reference-based (dotted/array) tag attributes.
- [safe_data](safe_data.md) — allow database output to be reparsed for ITL tags
  (security-sensitive).
- [strip_white](strip_white.md) — strip leading whitespace from the top of
  output pages.
- [perl_warnings_in_page](perl_warnings_in_page.md) — enable Perl warnings
  during page interpolation.

## Variables

- [dynamic_variables](dynamic_variables.md) — resolve page variables from files
  and databases at render time.
- [dynamic_variables_file_only](dynamic_variables_file_only.md) — restrict
  dynamic variable lookups to files, skipping the database.

## Images, links, and URLs

- [no_image_rewrite](no_image_rewrite.md) — disable rewriting of image
  locations to point at `ImageDir`.
- [adjust_href](adjust_href.md) — rewrite plain `<a href>` links in HTML output
  into Interchange URLs automatically.
- [allow_for_users](allow_for_users.md) — re-adjust user-supplied links that
  were already turned into Interchange URLs.
- [url_no_session_id](url_no_session_id.md) — omit the session ID and page count
  from generated URLs.

## HTTP headers and caching

- [cache_control](cache_control.md) — set the `Cache-Control` response header.
- [x_accel_expires](x_accel_expires.md) — set the `X-Accel-Expires` header for
  nginx proxy caching.
- [set_httponly](set_httponly.md) — add `HttpOnly` to all or named cookies.
- [set_samesite](set_samesite.md) — add `SameSite` to all or named cookies.

## Localization and tax

- [no_locale_parse](no_locale_parse.md) — disable parsing of `[L]` / `[LC]`
  localization pseudo-tags.
- [no_negative_tax](no_negative_tax.md) — floor a computed sales tax at zero.

## Data and search

- [dml](dml.md) — control `update_data()` write semantics (upsert / preserve /
  strict).
- [max_matches](max_matches.md) — cap the number of rows a search returns.
- [filter_sql_no_backslash](filter_sql_no_backslash.md) — disable backslash
  escaping in the `sql` filter.

## Order processing

- [require_order_profile](require_order_profile.md) — fail order submission when
  no order profile is named.

## Removed pragmas

The following pragmas appeared in older Interchange documentation but are no
longer consulted by the current code. They are listed here only so upgraders can
recognize them; setting them now has no effect.

- `compatible_5_2` — kept table-editor error text (mistakenly) hidden, as it was
  up to Interchange 5.2. Removed with the deprecated-feature cleanup in 5.12.
- `no_html_parse` — disabled parsing of `MV=` arguments inside HTML tags. The
  underlying code was removed in the 4.9 development series and the pragma was
  dropped in the 5.12 cleanup.
- `substitute_table_image` — added in 4.6.2 to rewrite table `background=` image
  paths; superseded by [no_image_rewrite](no_image_rewrite.md) (added 4.7.0),
  which controls all image-path rewriting.

## See also

- [Pragma](../config/Pragma.md) directive
- [Configuration](../guides/configuration.md) guide
- [Templating](../guides/templating.md) guide
