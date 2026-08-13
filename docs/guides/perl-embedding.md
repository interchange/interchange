# Embedded Perl

When configuration and [tags](templating.md) run out, Interchange lets you
drop to Perl — inline in pages, as named subroutines, as your own tags, or
as hooks into the [request lifecycle](architecture.md). This chapter covers
the embedding mechanisms, the objects your code sees, and the trust model
that decides how much Perl you get.

## The trust model in one paragraph

Interchange assumes page editors are not necessarily server
administrators. Perl embedded at the *catalog* level therefore runs inside
a **Safe compartment** (`Safe.pm`, managed by `lib/Vend/Safe.pm`): a
restricted interpreter that forbids risky opcodes — file access, `system`,
`require`, most of the dangerous parts of Perl. Code configured at the
*global* level (`interchange.cfg`: `GlobalSub`, global `UserTag`) runs as
full, unrestricted Perl. A catalog listed in
[AllowGlobal](../config/AllowGlobal.md) may request full Perl per block
(`[perl global=1]`). The practical consequences are covered in
[Security](security.md); write catalog code as if Safe is always on,
because by default it is.

## Inline: [calc] and [perl]

[calc](../tags/calc.md) evaluates an expression and inserts the result
(`[calcn]` suppresses the trailing-value output rule differences — see its
page):

    You have [calc] [nitems] * 2 [/calc] reward points.

[perl](../tags/perl.md) evaluates a block; its return value is the output:

    [perl]
        my $name = $Values->{fname} || 'friend';
        return "Welcome back, $name.";
    [/perl]

Both run in the Safe compartment (unless `global=1` as above). `[perl]`
takes attributes:

- `tables="products inventory"` — pre-open databases into `%Db` (and
  `%Sql` for DBI handles) for use inside the block
- `subs=1` — make your named `Sub`/`GlobalSub` routines callable as plain
  functions
- `global=1` — full Perl, only honored under `AllowGlobal`
- `failure=`/`no_return=` and more: see the [perl reference](../tags/perl.md)

## The embedded objects

Catalog Perl — `[perl]`, `[calc]`, custom tags, order profiles — sees a
stable set of shared variables (`@Share_vars` in
`lib/Vend/Interpolate.pm`):

| Object | Contents |
|--------|----------|
| `$Tag` | every tag as a method: `$Tag->area(...)` |
| `$CGI` | this request's CGI values (`$CGI_array` for multiples) |
| `$Values` | session-persistent form values (`[value ...]`) |
| `$Scratch` | scratch space (`[scratch ...]`) |
| `$Session` | the whole session hash |
| `$Config` | the catalog configuration (`$Vend::Cfg`) |
| `$Variable` | catalog Variables |
| `$Items` | the current shopping cart (array of item hashes) |
| `$Carts` | all carts by name |
| `$Discounts` | the session discount space |
| `%Db` / `%Sql` | database objects / raw DBI handles (via `tables=`) |
| `$DbSearch`, `$TextSearch`, `$Search` | search engines and results |
| `$Document` | the output document object (`$Document->write(...)`) |
| `$Row`, `$item`, `$s`, `$q` | loop/search context where applicable |
| `$Sub` | named catalog subroutines |

Example — three of them together:

    [perl tables=inventory]
        my $sku = $CGI->{sku} or return 'No SKU given.';
        my $qty = $Db{inventory}->field($sku, 'quantity');
        return $qty > 0
            ? "In stock: $qty"
            : $Tag->page('backorder') . 'Backorder</a>';
    [/perl]

## Calling tags from Perl: $Tag

Any tag is a method on `$Tag`; positional parameters become arguments and
named attributes a trailing hash reference:

    $Tag->data('products', 'price', $sku);
    $Tag->area({ href => 'ord/basket', secure => 1 });

The mapping and gotchas (list-returning tags, body content as the last
argument for container tags) are documented per tag. From *global* code,
use `Vend::Tags` (`$Tag` is preloaded in most contexts; `use Vend::Tags;
my $Tag = new Vend::Tags;` where not).

## Named subroutines: Sub and GlobalSub

Define reusable routines in config — catalog-level
[Sub](../config/Sub.md) (Safe) or trusted
[GlobalSub](../config/GlobalSub.md) in `interchange.cfg`:

    Sub <<EOS
    sub cart_total_items {
        my $count = 0;
        $count += $_->{quantity} for @$Items;
        return $count;
    }
    EOS

Call them from embedded code with `[perl subs=1]` (as plain functions), or
anywhere ITL allows a "macro" name — e.g.
`Autoload cart_total_items` or `SpecialSub` hooks. `GlobalSub` routines
marked `AdminSub` are callable only from `AllowGlobal` catalogs.

## Writing your own tags: UserTag

The workhorse of catalog customization. Inline in `catalog.cfg`:

    UserTag company_phone Routine <<EOR
    sub {
        return $Variable->{PHONE} || '555-0100';
    }
    EOR

    UserTag reverse_text  hasEndTag
    UserTag reverse_text  Routine <<EOR
    sub {
        my $body = shift;
        return scalar reverse $body;
    }
    EOR

Then in a page:

    [company-phone]  and  [reverse-text]hello[/reverse-text]

(Hyphens and underscores are interchangeable in tag names.) The
[UserTag](../config/UserTag.md) directive's sub-directives declare the
interface, mirroring how core tags are defined:

- `Order attr1 attr2` — positional parameters, passed as arguments
- `addAttr` — pass the named-attribute hash as the argument after the
  positionals
- `hasEndTag` — container tag; the body arrives as the last argument
- `attrAlias alias real` — attribute aliases
- `Interpolate`, `MapRoutine`, `Documentation` — see the directive page

A `UserTag` in `catalog.cfg` compiles into the Safe-guarded catalog space;
the same directive in `interchange.cfg` makes a **global** usertag with
full Perl — which is why the distribution's shipped tags live in
`code/UserTag/*.tag` files (loaded via [TagDir](../config/TagDir.md)) and
review-worthy custom ones conventionally go in an included `usertag/`
directory at the global level. Larger code (filters, widgets, jobs,
order checks) registers through [CodeDef](../config/CodeDef.md) the same
way.

## Hooking the request lifecycle

Perl can run at fixed points without appearing in any page
([Architecture](architecture.md) shows where each fires):

- [Autoload](../config/Autoload.md) — macro/sub run at the start of every
  request for the catalog (strap uses it to build admin links)
- [Preload](../config/Preload.md) — before session resolution
- [ActionMap](../config/ActionMap.md) — your own first-path-segment
  actions (`/wishlist/...` → sub); `FormAction` likewise for `mv_todo`
  values; both receive the path/form and decide whether a page displays
- [SpecialSub](../config/SpecialSub.md) — named hooks: `missing` (404
  handling — strap's SEO URLs), `admin_init`, and others listed on its page
- Order-time Perl: profiles and [order checks](../order-checks/README.md),
  route `expressions`, `[calc]` in `etc/log_transaction`
  ([Carts and checkout](cart-and-checkout.md))

## Debugging embedded code

Errors in Safe code usually surface as an empty tag result plus a line in
the catalog error log. While developing:

- `$Tag->log({ file => 'logs/dev.log' }, "value=$x")` or `[log ...]` for
  page-side prints; `::logError('...')`/`::logGlobal('...')` from global
  code
- `[perl]` with `Pragma perl_warnings_in_page` surfaces warnings in output
- `[dump]` shows the session state your code just modified
- A "Safe: ... trapped by operation ..." log line means the compartment
  blocked an opcode: restructure the code, move it to a global UserTag, or
  (deliberately, sparingly) loosen with
  [SafeUntrap](../config/SafeUntrap.md)

More in [Logging and debugging](logging-debugging.md).

## See also

- [Security](security.md) — what Safe blocks and why; AllowGlobal policy
- [Templating](templating.md) — the tag side of the same coin
- [Tag reference](../tags/README.md): [perl](../tags/perl.md),
  [calc](../tags/calc.md), [mvasp](../tags/mvasp.md)
