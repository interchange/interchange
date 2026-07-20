# Templating with ITL

Interchange pages are HTML (or any text) mixed with tags in square brackets
— the **Interchange Tag Language (ITL)**. When a page is delivered, the
server *interpolates* it: variables are substituted, each tag runs and is
replaced by its output, and the finished text is sent to the browser. This
chapter explains the language itself — syntax, the interpolation pipeline,
loops and their sub-tags, conditionals, and filters. The
[tag reference](../tags/README.md) documents each tag individually.

A first taste, using the strap demo's `products` table:

    <p>We stock [item-count] items.
       Our featured hammer: [data table=products col=description key=os28044]</p>

produces (with the demo data):

    <p>We stock 1 items.
       Our featured hammer: Framing Hammer</p>

## Where interpolation happens

Everything delivered through [page display](architecture.md) is interpolated:
files under `pages/`, layout templates and components, embedded
[search results](search.md), mail templates sent with
[email](../tags/email.md), and strings you pass to
`interpolate_html()`/`$Tag` from [Perl code](perl-embedding.md). Static
files served directly by the web server (images, CSS under `html/`) are
not.

## The pre-parse phase

Before any tag runs, `interpolate_html()` (`lib/Vend/Interpolate.pm`)
makes one preparatory pass over the whole page:

1. **`[pragma]` extraction** — `[pragma name]` or `[pragma name value]`
   anywhere in the page sets a whole-page [pragma](../pragmas/README.md),
   no matter where it appears.
2. **Variable substitution** — three bracket styles, resolved from the
   [Variable](../config/Variable.md) definitions:

   | Form | Looks in |
   |------|----------|
   | `@@NAME@@` | global (interchange.cfg) only |
   | `@_NAME_@` | catalog first, then global |
   | `__NAME__` | catalog only |

   Substitution is textual and happens before parsing, so a Variable may
   contain ITL that then runs — this is how strap's `__TOP__`/`__BOTTOM__`
   page chrome works. With `Pragma dynamic_variables`, values are looked up
   per request from the variable database instead of the compiled config.
3. **`[comment]` removal** — `[comment] ... [/comment]` blocks vanish
   entirely (nothing inside them runs).
4. **HTML-comment unwrapping** — `<!--[tag ...]-->` becomes `[tag ...]`, so
   ITL can hide from HTML editors. Disable with
   `Pragma no_html_comment_embed`.
5. **Autoload wrappers** — at top level, the Variables `MV_AUTOLOAD` /
   `MV_AUTOEND` are prepended/appended to every page — a hook for
   page-wide setup ITL.

## Tag syntax

Tags come in two argument styles, usable together:

    [page href=ord/basket]                     positional
    [page href="ord/basket" secure=1]          named attributes

- **Positional** parameters are defined per tag (its `Order`). They need no
  names but must come in order: `[data products description os28005]` is
  `[data table col key]`.
- **Named attributes** are `name=value`; quote the value with `"`, `'`, or
  `` ` `` if it contains spaces. Backtick quoting ``name=`...` `` treats the
  value as Perl to evaluate (in the Safe compartment). Attribute names are
  case-insensitive; the reference pages list each tag's attributes and
  aliases.
- Tags may appear inside attribute values; they are interpolated before the
  enclosing tag runs:

      [page href="[scratch target_page]"]

**Container tags** enclose a body and end with `[/tagname]`:

    [loop list="os28004 os28005"] ... [/loop]

**Standalone tags** have no end tag. Each tag's page states which it is.
`[tagname ...]` and `[tagname...]` with interspersed whitespace/newlines are
equivalent; tag names are case-insensitive by convention written lowercase.

## The interpolation pipeline: interpolate and reparse

Two per-tag switches control how a container tag's body and output flow
through the parser — you can override either as an attribute:

- **`interpolate=1`** — interpolate the *body* first, then hand the result
  to the tag. Default varies by tag (most process their raw body).
- **`reparse=1`** — interpolate the tag's *output*. Most container tags
  reparse by default, so tags emitted by a loop body run normally. Set
  `reparse=0` when emitting literal `[`-containing text.

Two tags exist purely to control this flow: [interpolate](../tags/interpolate.md)
forces a region through the parser, and `[pragma no_html_parse]`-era
constructs are covered on their reference pages. To emit a literal bracket,
use `&#91;` or wrap the region in `[restrict] ... [/restrict]` (see
[Security](security.md)).

## Accessing data: the everyday tags

| Tag | Reads | Example |
|-----|-------|---------|
| `[value name]` | user form values (session-persistent) | `[value fname]` |
| `[cgi name]` | this request's raw CGI variables | `[cgi mv_searchspec]` |
| `[scratch name]` | session scratch space | `[scratch display_class]` |
| `[data table col key]` | any database field | `[data products price os28005]` |
| `[field col key]` | shorthand over the products table(s) | `[field price os28005]` |
| `[var NAME]` | Variables at runtime | `[var COMPANY]` |
| `[set name]body[/set]` | writes scratch | `[set mv_no_count]1[/set]` |

Each has a reference page with the full attribute set (`filter=`,
`set=`, `hide=`, ...).

## Loops and prefix sub-tags

List-producing container tags — [loop](../tags/loop.md),
[item-list](../tags/item-list.md) (cart lines),
[query](../tags/query.md) (SQL), [search-region](../tags/search-region.md)
— repeat their body once per row and give the body access to the current
row through **prefix sub-tags**. The prefix defaults to the tag name
(`loop-`, `item-`, `sql-`, or `PREFIX` set via `prefix=`):

    [loop search="fi=products/st=db/co=yes/sf=category/se=Tools"]
      [loop-code]: [loop-field description], $[loop-field price]
    [/loop]

Common sub-tags (see each looping tag's page for its full set):

- `[PREFIX-code]` — the row's key (SKU)
- `[PREFIX-field name]` — column from the products table
- `[PREFIX-param name]` / `[PREFIX-pos N]` — column of the returned row by
  name / position
- `[PREFIX-calc] ... [/PREFIX-calc]` — inline Perl with the row available
- `[PREFIX-change name] ... [/PREFIX-change]` — runs only when a column's
  value changes between rows (subtotal breaks)
- `[if-PREFIX-field col] ... [/if-PREFIX-field]` — row-level conditionals
- `[PREFIX-increment]` / `[PREFIX-last]` / `[PREFIX-next]` — counter and
  loop control

Sub-tags are resolved by the looping tag itself during the loop, not by the
general parser — which is why they are documented with their parent tag.

## Conditionals

[if](../tags/if.md) tests a *type* and *term*, with optional comparison:

    [if value fname]Hello, [value fname]![/if]

    [if type=data term=products::inventory::os28005 op=<= compare=0]
      Out of stock.
    [else]
      In stock.
    [/else]
    [/if]

Types cover each data space: `value`, `cgi`, `scratch`, `session`,
`variable`, `data table::col::key`, `field`, `file`, `explicit` (Perl),
`ordered`/`items` (cart). `[elsif]`/`[else]` chain further branches, and
`[and ...]`/`[or ...]` combine tests. The [if reference](../tags/if.md)
documents every type and operator.

## Filters

Any value-producing tag accepts `filter=`, a space-separated chain applied
to its output; [filter](../tags/filter.md) does the same for a body:

    [value b_zip filter="digits 5"]
    [filter entities]<b>raw</b>[/filter]   →   &lt;b&gt;raw&lt;/b&gt;

Some 100 named filters (`entities`, `digits`, `date_change`, `strip`,
`urlencode`, ...) are cataloged in the [filter reference](../filters/README.md),
along with the compact numeric notations (`filter="20."` truncates to 20
characters with an ellipsis). Filters also run on *input* via form
[input filters](../tags/input-filter.md).

## URLs and links

Never hand-write catalog URLs; generate them so the session id, base URL,
and security are handled:

    [page ord/basket]Your cart[/page]        full <a href=...> anchor
    <a href="[area ord/basket]">Your cart</a>   URL only

`[area]`/`[page]` accept `form=` to encode form submissions as links. See
their reference pages and [Forms](forms.md).

## From tags to Perl and back

When a page needs logic beyond tags: `[calc]`/`[calcn]` evaluate a Perl
expression, `[perl]` a block — inside the Safe compartment, with `$Tag`
giving Perl code access to any tag (`$Tag->area(...)`). The whole model,
including `GlobalSub`, catalog `Sub`, `ActionMap`, and what Safe does and
doesn't allow, is the subject of [Embedded Perl](perl-embedding.md).

## Debugging pages

- `[dump]` renders the entire session/CGI state — invaluable, never leave
  it on a public page.
- `[warnings]` shows accumulated warnings; `[log ...]` writes to the
  catalog error log.
- `Pragma perl_warnings_in_page` surfaces Perl warnings during
  interpolation. More in [Logging and debugging](logging-debugging.md).

## See also

- [Catalog anatomy](catalog-anatomy.md) — where pages, templates, and
  components live and how strap assembles them
- [Tag reference](../tags/README.md) — every tag
- [Embedded Perl](perl-embedding.md), [Forms](forms.md), [Search](search.md)
