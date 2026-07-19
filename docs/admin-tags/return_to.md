# return_to

Emit the navigation state that sends an administrative form or link back to the
page the user came from. It reads the `ui_return_to` request stack and renders
it as hidden form fields, click settings, a URL, or a form link, depending on
the output type you ask for. This tag is part of the admin UI toolset
(registered from `code/UI_Tag/` and loaded only when the administrative
interface is enabled), not a storefront tag.

## Syntax

    [return_to]
    [return_to type=form]
    [return_to type=click exclude=regex stack=1]
    [return_to type=url]

Standalone tag (no end tag). Returns markup or settings text whose form depends
on `type`.

## Attributes

| Attribute    | Default | Description |
|--------------|---------|-------------|
| `type`       | `form`  | Output format: `form`, `click`, `formlink`, `url`, or `regen`. See below. |
| `table_hack` | none    | When true, rewrite an `mv_data_table` argument in the saved state into `mv_return_table` (and honor an existing `ui_/mv_return_table`). |
| `page`       | saved   | Override the return page instead of using the one saved in `ui_return_to`. |
| `exclude`    | none    | For `type=click`, a regular expression; matching argument keys are dropped. |
| `stack`      | off     | For `type=click`, keep the return stack (behave like `formlink`) instead of clearing it. |
| `scratch`    | off     | Also store an [area](../tags/area.md) URL for the return page in the scratch variable `ui_location`. |

Positional order: `type`, `table_hack`. Remaining named attributes are
collected as options (`addAttr`).

## Description

The administrative interface tracks where a user should return to in the CGI
variable `ui_return_to`, a null-separated list whose first element is the return
page and whose remaining elements are `name=value` request arguments. This tag
turns that saved state into whatever the current page needs:

- **`form`** (default) — hidden `<input>` fields named `ui_return_to`, one for
  the page and one per saved argument, to embed inside a form so the round-trip
  is preserved on submit.
- **`click`** — settings lines (`mv_nextpage=...`, then `key=value` per
  argument) suitable for an `mv_click`/button action. Keys matching `exclude`
  are skipped. If `stack` (or the incoming `ui_return_stack`) is set the stack
  is preserved; otherwise it is cleared with a trailing `ui_return_to=` line.
- **`formlink`** — `ui_return_to=` settings lines that rebuild the stack,
  defaulting the page to the current `MV_PAGE`.
- **`url`** — a single link built with the [area](../tags/area.md) tag pointing
  at the return page with the saved arguments as its form.
- **`regen`** — hidden inputs that regenerate the nested `ui_return_to` stack
  verbatim.

If the request also carries a `ui_target`, it is appended as a `ui_target=`
argument. With `table_hack` true, a saved `mv_data_table=` argument is converted
to `mv_return_table=` so the destination page knows which table to return to.

## Examples

Embed return state in an edit form (the common case):

    <form method="post" action="[area @@MV_PAGE@@]">
    [return_to]
    ...form fields...
    <input type="submit" value="Save">
    </form>

Produce click settings for a "Cancel" button that returns to the prior page and
clears the stack:

    [button text="Cancel" form-only=1]
    [return_to type=click]
    [/button]

Render a plain return link:

    <a href="[return_to type=url]">Back</a>

## Notes

This tag is tightly coupled to the administrative UI's `ui_return_to`
convention; it is not meant for general storefront navigation, where
[area](../tags/area.md) and [page](../tags/page.md) are the right tools.

## See also

- [area](../tags/area.md)
- [page](../tags/page.md)
- Concepts: [admin UI](../guides/admin-ui.md)

## Source

Defined in `code/UI_Tag/return_to.coretag`, registered as the UserTag
`return_to` (inline Routine).
