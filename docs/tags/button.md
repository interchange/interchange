# button

Build a form submit button — a plain `<input type="submit">`, or an image
button with a JavaScript click handler and a `<noscript>` fallback. Its body
becomes the action Interchange runs when the button is clicked. Reach for it to
place "Checkout", "Place order", or similar action buttons in a form.

## Syntax

    [button text="Label"] mv_todo=action [/button]
    [button name=mv_click text="Label" form=formname] ...action... [/button]
    [button src="image.gif" text="Label"] ...action... [/button]

Container tag. The body is the click *action* — one or more `name=value`
lines that are stored and executed when the button fires (see below).

## Attributes

| Attribute   | Default      | Description |
|-------------|--------------|-------------|
| `name`      | `mv_click`   | Form-field name for the button (positional 1). |
| `src`       |              | Image URL; makes an image button instead of a plain submit (positional 2). |
| `text`      |              | Button label / value (positional 3). Alias: `value`. |
| `wait_text` |              | Text the button changes to after it is clicked, to discourage double submits. |
| `confirm`   |              | JavaScript `confirm()` prompt shown before the action runs. |
| `form`      | `forms[0]`   | Name of the form the (image) button submits. |
| `class` / `id` / `style` |  | Copied onto the generated `<input>`. |
| `extra`     |              | Extra literal attributes for the `<input>`. |
| `bold`      | `0`          | Wrap a text button in `<b>...</b>`. |
| `hidetext`  | `0`          | For image buttons, suppress the text anchor beside the image. |
| `srcliteral`| `0`          | Use `src` verbatim rather than resolving it against the image directory. |

Positional order: `name`, `src`, `text`. Alias: `value` for `text`.

The tag also honors image-layout options (`border`, `width`, `height`,
`align`, `vspace`, `hspace`, `getsize`, `anchor`, `alt`, `link_href`,
`link_text_too`).

## Description

The tag's body is treated as the button's **action**. When `name` is
`mv_click` (the default), the action lines are stored into scratch under a key
equal to the button label, and the button is emitted as
`<input type="submit" name="mv_click" value="LABEL">`. On submit, Interchange's
click-map mechanism looks up that label in scratch and runs the stored
`mv_todo`/`mv_nextpage`/etc. settings — the same pattern as an
[area](area.md)/[process](process.md) form action, but driven by which button
was pressed.

With `src`, the tag builds an image button: a JavaScript `document.write` that
draws a linked image submitting the named `form`, wrapped in a `<noscript>`
block containing the plain submit button so it still works without JavaScript.

A `[js]...[/js]` (or `[javascript]...[/javascript]`) block inside the body is
pulled out and attached as `onclick`/`onmouseover`/`onmouseout` handlers rather
than treated as action lines.

## Examples

A minimal action button:

    [button text="Add to cart"]
    mv_todo=refresh
    [/button]

The strap basket's checkout button, submitting the `basket` form to the
checkout page:

    [button
      text="[L]Checkout now[/L]"
      class="btn btn-primary btn-lg"
      form=basket
    ]
        mv_todo=return
        mv_nextpage=__CHECKOUT_PAGE__
    [/button]

A "Place order" button that changes its label while the order posts:

    [button
        name="mv_click"
        text="[L]Place Order[/L]"
        wait-text="-- [L]Wait[/L] --"
        form=checkout
        class="btn btn-primary btn-lg"
    ]
        mv_todo=submit
    [/button]

## Notes

- Do not confuse `[button]` with the separate `[buttons]` component used on
  strap pages; they are different tags.
- The label text doubles as the scratch key for the default `mv_click`
  action, so two buttons in one form should have distinct labels.

## See also

- [process](process.md) — the form-action URL these buttons post to
- [area](area.md) — link-based equivalents
- [scratch](scratch.md) — where the click action is stored
- The [forms guide](../guides/forms.md) and
  [cart-and-checkout guide](../guides/cart-and-checkout.md)

## Source

Defined in `code/UserTag/button.tag` (inline `Routine`).
