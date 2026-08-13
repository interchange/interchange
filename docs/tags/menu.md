# menu

Render a navigation menu from menu data — a menu file or database table — as
a menubar, tree, or flyout. Reach for it to build site navigation from a
maintainable data source rather than hand-coded HTML.

## Syntax

    [menu name=Menubar] TEMPLATE [/menu]
    [menu name=Products menu-type=flyout][/menu]

Container tag. The body is the per-entry template; it is **not** reparsed as
ITL (`noReparse`) — placeholders in it are filled by
[uc-attr-list](uc-attr-list.md).

## Attributes

| Attribute   | Default  | Description |
|-------------|----------|-------------|
| `name`      | (none)   | Name of the menu (menu file or menu-table key). |
| `menu-type` | `simple` | `simple` (flat bar/list), `tree`, or `flyout`. |
| `joiner`    | (none)   | HTML inserted between menu entries. |
| `localize`  | (none)   | Comma-separated list of entry fields to run through localization. |
| `logged_in` | (none)   | Selection field restricting entries to logged-in users. |
| `list`      | (none)   | Supply menu rows directly instead of loading from a file. |

Positional order: `name`.

The tree and flyout types accept many additional presentation attributes
(`link-class`, `flyout-class`, `flyout-style`, and so on) consumed by the
menu renderer.

## Description

`[menu]` reads menu data and emits HTML for each entry, substituting the
entry's columns into the `{FIELD}` placeholders of the body template (the
substitution is done by [uc-attr-list](uc-attr-list.md), so placeholder
names are uppercased and support the `{FIELD?}...{/FIELD?}` conditional
form). Menu data comes from a tab-separated menu file located under the
directory named by the `MV_MENU_DIRECTORY`
[variable](../config/Variable.md) (default `include/menus`), from a menu
database table, or from rows passed in the `list` attribute.

Menu rows carry columns such as `code`, `page`, `form`, `anchor`
(display name), and `description`; a link entry typically has a `page`
(internal) or an external URL, which the template turns into an anchor.
Selection fields such as `logged_in` filter which entries render for the
current visitor.

The `menu-type` chooses the layout: `simple` produces a flat list/bar,
`tree` produces an indented hierarchical menu (see [tree](tree.md)), and
`flyout` produces a hover/flyout menu driven by the extra class/style
attributes.

## Examples

A simple menubar, one cell per entry:

    <table><tr>
    [menu name=Menubar localize=name
          joiner='<td><img src="menu_separator.png"></td>']
    <td class="menubar" align="center">
      <a href="{HREF}" class="menubar">{NAME}</a>
    </td>
    [/menu]
    </tr></table>

A menu mixing internal pages and external links, using the conditional
placeholder form:

    [menu name="links"]
    <span class="links">
    {HREF?}<a href="{HREF}" class="links">{NAME}</a>{/HREF?}
    {URL?}<a href="{URL}" class="links">{NAME}</a>{/URL?}
    </span>
    [/menu]

A flyout menu (empty body — the renderer supplies the markup):

    [menu
      name="Products"
      link-class="barlink"
      flyout-class="flyout_class"
      menu-type=flyout
    ][/menu]

## Notes

Entry-template placeholders are filled by
[uc-attr-list](uc-attr-list.md), which is why they use `{NAME}` /
`{HREF?}...{/HREF?}` syntax rather than ITL brackets.

## See also

- [tree](tree.md) — walk a self-referential table (the tree menu engine)
- [uc-attr-list](uc-attr-list.md) — the placeholder substitution used here
- `MV_MENU_DIRECTORY` [variable](../config/Variable.md)
- [templating](../guides/templating.md)

## Source

Defined in `code/SystemTag/menu.coretag`. Implemented by `Vend::Menu::menu`
(`lib/Vend/Menu.pm`).
