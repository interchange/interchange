# Forms and user input

Almost everything a shopper *does* in an Interchange catalog — logging in,
searching, adding to the cart, checking out, updating an account — arrives as
an HTML form submission. This chapter explains how an ordinary `<form>` turns
into an Interchange *action*: the special `mv_*` fields that name the action
and the page to return to, the built-in form verbs, the widgets that build and
pre-fill fields, the profile mechanism that validates a submission, and file
uploads. Where a subsystem has its own chapter — [carts and
checkout](cart-and-checkout.md), [search](search.md), [user
accounts](user-database.md) — this chapter hands off to it and stays on the
form plumbing they share.

If you have not yet read [Templating](templating.md) (ITL syntax, `[value]`
vs `[cgi]` vs `[scratch]`) and [Sessions](sessions.md) (values, scratch, the
session id), read those first; forms sit directly on top of both.

## How a form becomes an action

A request is resolved as **(catalog, session, path) → action → page** (see
[Architecture](architecture.md)). A form submission is just a request whose
path — or whose `mv_action`/`mv_todo` fields — selects an *action* routine
instead of displaying a page directly. You never hard-code the catalog URL;
you generate the form's `action="..."` with a tag so the session id, base URL,
and http/https choice are handled for you.

The everyday entry point is [process](../tags/process.md), which returns the
URL of the catalog's process page (the [ProcessPage](../config/ProcessPage.md)
directive, normally `process`):

    <form action="[process]" method="post">
      <input name="mv_searchspec">
      <input type="submit" value="Search">
    </form>

That is a complete text [search](search.md) form. Three things can name the
action a form runs, in this order of preference:

1. **`mv_action`** — a hidden field naming the action explicitly. Setting it
   makes the submit-to page name irrelevant as an action source.
2. **The first path segment** of the URL the form posts to. Posting to
   `[area search]` runs the `search` action; `[area process]` (what
   `[process]` expands to) runs `process`.
3. **The page name**, used only to set `mv_nextpage` when nothing else does.

The built-in actions are `process` (general form processing), `search` and
`scan` (the [search engine](search.md)), `order`/`obtain` (add to cart), and
`silent` (process and return no body). A catalog adds its own with
[ActionMap](../config/ActionMap.md) — this is how strap's category URLs work.
Everything else in this chapter is about the `process` action, which is what
most forms use.

## The anatomy of a process form

A `process` form is driven by a small set of hidden `mv_*` fields. The two you
will write on nearly every form:

- **`mv_todo`** — the *verb*: what to do with this submission (`return`,
  `refresh`, `submit`, `set`, `cancel`, ...). Covered below.
- **`mv_nextpage`** — the page to display after processing succeeds.

A minimal form that saves what the shopper typed and moves on:

    <form action="[process]" method="post">
      [form-session-id]
      <input type="hidden" name="mv_todo"     value="return">
      <input type="hidden" name="mv_nextpage" value="ord/checkout">
      First name: <input name="fname" value="[value fname]">
      <input type="submit" value="Continue">
    </form>

What the pieces do:

- `mv_todo=return` runs the `return` verb, which copies submitted fields into
  the session [values](sessions.md) space and then displays `mv_nextpage`.
- `[value fname]` pre-fills the field from the session, so the form remembers
  the shopper's earlier answer.
- [form-session-id](../tags/form-session-id.md) emits a hidden
  `mv_session_id` field so the session survives the POST for shoppers who are
  not accepting cookies. It emits nothing when a cookie already carries the
  session, keeping the id out of the page source. Include it in every `<form>`
  that must preserve the session.

Values submitted under an ordinary field name (`fname` above) become
[value](../tags/value.md) data — persistent across requests in the session.
Fields named `mv_*` are *control* variables consumed by the dispatcher and
generally not stored; see the
[mv_* form-variable index](../variables/mv-form-variables.md) for the whole
reserved namespace. Two rules worth internalizing early:

- **Do not name your own fields `mv_*`.** That prefix is reserved and its
  fields are treated specially.
- **Interchange never unsets a value you don't submit.** A checkbox that is
  unchecked sends nothing, so its old value stays in the session unless you
  clear it explicitly (a hidden field of the same name with an empty value, or
  a profile `&set`).

## Form verbs: mv_todo

The `process` action has a second level — the *todo* — taken from `mv_todo`,
or from `mv_doit` when `mv_todo` is absent (so `mv_doit` sets a default). The
built-in verbs (`%form_action` in `lib/Vend/Dispatch.pm`):

| Verb | Effect |
|------|--------|
| `return` / `go` | Update session values from the form, then display `mv_nextpage`. |
| `back` | Display `mv_nextpage` **without** updating any values. |
| `refresh` | Update ordered-item quantities/options in the cart, then values, then display `mv_orderpage` or `mv_nextpage`. |
| `submit` | Run checkout: validate against the order profile, place the order, run [order routes](cart-and-checkout.md). |
| `set` / `autoset` | Write a database table from the form (see [Updating a table from a form](#updating-a-table-from-a-form)). |
| `cancel` | Erase the session (empties the cart and all values), then display the `canceled` [special page](../config/SpecialPage.md). |
| `search` | Update values, then dispatch the form to the [search engine](search.md). |

An image submit button posts `mv_todo.x`/`mv_todo.y` instead of a plain
value; Interchange recognizes the `mv_todo.VERB.x` naming
(`mv_todo.submit.x`, `mv_todo.return.x`, ...) and derives the verb from it, so
`<input type="image" name="mv_todo.submit">` works as a submit. For pixel-map
control, `mv_todo.map` defines NCSA-style regions that map coordinates to
verbs.

To set a default verb so a stray Enter keypress still does the right thing:

    <input type="hidden" name="mv_doit" value="refresh">

### FormAction: your own verbs

Register a catalog-specific verb with the
[FormAction](../config/FormAction.md) directive (or a
[CodeDef](../config/CodeDef.md) of type `FormAction`). The routine runs in
place of a built-in verb of the same name:

    FormAction  subscribe  <<EOR
    sub {
        my $email = $CGI::values{email}
            or return 1;
        $Tag->email({ to => 'list@example.com', subject => 'subscribe' }, $email);
        return 1;
    }
    EOR

Then `mv_todo=subscribe` invokes it. A verb routine returning true falls
through to displaying `mv_nextpage`; returning false ends the request without a
page (useful for AJAX or redirects).

## One click, many variables: mv_click and mv_check

Sometimes one button needs to set several fields at once, or you want a hook
that runs after the form's values are in place. Two mechanisms handle this,
both drawing their definitions from a [scratch](../tags/set.md) variable (or an
order profile) of the matching name.

**`mv_click`** runs *before* the form's values are applied, so it can inject or
rewrite fields as if they had been on the form. Define the variable set in
scratch, then trigger it with a button whose name is `mv_click`:

    [set Search by Category]
    mv_search_field=category
    mv_search_file=products
    mv_todo=search
    [/set]

    <input type="submit" name="mv_click" value="Search by Category">

Clicking the button sets all three fields from the `Search by Category`
scratch block. `mv_click` must be set on the form being submitted — it is not
carried between forms. The definition is interpolated for ITL before use, so
you can compute the values (including from a `[perl]` block), but note that the
tags run *before* the field assignments, not after.

**`mv_check`** runs *after* the form's values (including any set by
`mv_click`) are applied, during the value-update step of `return`, `refresh`,
`submit`, and `search`. Use it to condition or sanity-check input:

    <input type="hidden" name="mv_check" value="Normalize ZIP">

    [set Normalize ZIP]
    [perl]
        $CGI->{b_zip} = uc $CGI->{b_zip};
        return;
    [/perl]
    [/set]

Both accept comma/null-separated lists to run several blocks.

## Remembering input and marking selections

Because `[value NAME]` reads the session, re-displaying a form after a failed
submission naturally shows what the shopper typed. For elements whose "memory"
is a *selected* state rather than a text value, use the helper tags:

- [checked](../tags/checked.md) emits `checked` when a field equals a value —
  for checkboxes and radio buttons.
- [selected](../tags/selected.md) emits `selected` for the matching
  `<option>` in a `<select>`.

Both emit their keyword into a form control:

    <select name="color">
      <option [selected color blue]>Blue
      <option [selected color green]>Green
      <option [selected color red]>Red
    </select>

    <input type="checkbox" name="subscribe" value="1" [checked subscribe 1]>

Both accept `cgi=1` to read the raw request instead of the stored value,
`multiple=1` for word-boundary matching within a multi-value field, and
`default=1` to select when the stored value is empty.

For a labeled field that pre-fills itself *and* highlights when it failed
validation, [formel](../tags/formel.md) ("form element") wraps all of this in
one tag:

    [formel "First name" fname]
    [formel label=Country name=country type=select
        choices="us=United States,ca=Canada,mx=Mexico"]

## Widgets

A **widget** is a generated form control — a text box, a select, a date picker,
a set of radio buttons — produced by the [display](../widgets/README.md)
mechanism (`lib/Vend/Form.pm`) rather than hand-written HTML. Widgets pull
their current value from the session, render their options from a list or a
database lookup, and apply a consistent set of options (`class`, `extra`,
`filter`, error highlighting). You reach a widget three ways: through
[formel](../tags/formel.md), through the `[display ...]` tag with a
`type=`, or automatically through product-option and
[accessories](../tags/accessories.md) tags at checkout.

The type names are compact and often encode their size or variant in the name
itself — `text_60` is a 60-column text box, `textarea_5_40` is 5×40,
`datetime_ampm` is a date-plus-time picker with am/pm, `yesno radio` is a
yes/no as radio buttons. The full catalog is the
[widget reference](../widgets/README.md); the common ones:

| Widget | Renders |
|--------|---------|
| [text](../widgets/text.md) / [textarea](../widgets/textarea.md) | single- and multi-line text inputs |
| [password](../widgets/text.md) | masked input |
| [select](../widgets/select.md) / [multiple](../widgets/multiple.md) | drop-down / multi-select |
| [radio](../widgets/radio.md) / [checkbox](../widgets/checkbox.md) | option groups |
| [yesno](../widgets/yesno.md) / [noyes](../widgets/noyes.md) | boolean select or radio |
| [date](../widgets/date.md) / [time](../widgets/time.md) | date and time selectors |
| [country_select](../widgets/country_select.md) / [state_select](../widgets/state_select.md) | locale-aware geographic pickers |
| [combo](../widgets/combo.md) / [movecombo](../widgets/movecombo.md) | select-plus-free-text and dual-list pickers |

A widget's option list can come from an attribute (`passed="us=United
States,ca=Canada"`), a `lookup`/`lookup_query` against a table, or product
metadata. See the [widget reference](../widgets/README.md) for each type's
attributes and the [display](../widgets/display.md) widget for the shared
options.

## Validating a submission: profiles

Interchange validates forms with a **profile**: a named list of per-field
*checks* plus `&`-prefixed control directives. A profile can simply gate a
form (all required fields present?) or run a full checkout (validate, charge,
place the order). Two form fields select one:

- **`mv_form_profile`** runs *before* any verb, purely to accept or reject the
  submission. If the check fails, processing stops and the shopper is returned
  to the form. This is what you want for ordinary input validation — a
  registration form, a contact form.
- **`mv_order_profile`** runs inside the `submit` verb as part of checkout, and
  can carry the `&final`/`&charge` directives that actually place an order. See
  [cart and checkout](cart-and-checkout.md).

Both use the same profile syntax and the same check routines
(`check_order()` in `lib/Vend/Order.pm`).

### Where profiles live

A profile is either a scratch block named the same as the value you put in
`mv_form_profile`, or a named block in a file loaded by the
[OrderProfile](../config/OrderProfile.md) directive (alias
[Profiles](../config/Profiles.md)). File profiles are split on a line of
`__END__` and named by an `__NAME__` marker; they are read at startup, so
edits take effect on the next [reconfig](configuration.md).

The quickest way to attach a check to one form is a scratch profile on the
page itself:

    [set emailcheck]
    mv_username=required Please supply your email address.
    mv_username=email    That does not look like an email address.
    [/set]

    <form action="[process secure=1]" method="post">
      [form-session-id]
      <input type="hidden" name="mv_form_profile" value="emailcheck">
      <input type="hidden" name="mv_todo"         value="return">
      <input type="hidden" name="mv_nextpage"     value="member/account">
      <input name="mv_username" value="[value mv_username]">
      <input type="submit" value="Continue">
    </form>

(strap's `pages/login.html` uses exactly this `mv_form_profile=emailcheck`
pattern.)

### Check lines

Each non-`&` line is `FIELD=CHECKTYPE [arguments] [error message]`. The trailing
text becomes the error message shown for that field. A representative profile:

    name=required    You must give us your name.
    address=required
    city=required
    state=state      Please use a two-letter state code.
    zip=zip
    email=email      Is the domain missing from your email?
    phone_day=phone_us
    comment=length 0-2000  Please keep comments under 2000 characters.

Check types come from two places, sharing one namespace:

- **Built-in checks** in `lib/Vend/Order.pm`, chiefly geographic and format
  validators: `required`, `mandatory` (must be supplied *on this form*, not a
  saved value), `defined`, `email`, `phone`, `phone_us`,
  `phone_us_with_area`, `state`, `province`, `state_province`, `zip`,
  `postcode`, `ca_postcode`, `true`, `false`.
- **Pluggable checks** registered with `CodeDef ... OrderCheck` and documented
  in the [order-checks reference](../order-checks/) — including
  [length](../order-checks/length.md), [regex](../order-checks/regex.md),
  [match](../order-checks/match.md), [filter](../order-checks/filter.md),
  [unique](../order-checks/unique.md), [numeric](../order-checks/numeric.md),
  [natural](../order-checks/natural.md), [isbn](../order-checks/isbn.md),
  [future](../order-checks/future.md), and [exists](../order-checks/exists.md).

A field may be checked more than once (as `email` is above); the lines run in
order. Write your own check as a `CodeDef OrderCheck` routine — see
[CodeDef](../config/CodeDef.md) and the order-checks reference for the calling
convention (it returns `(status, fieldname, message)`).

### Control directives

Lines beginning with `&` change how the profile itself behaves rather than
checking a field:

| Directive | Effect |
|-----------|--------|
| `&fatal=yes` | Stop the profile at the first failure from here on, instead of collecting every error. |
| `&final=yes` | On success, actually place the order (checkout profiles). |
| `&success=PAGE` / `&fail=PAGE` | Set the next page for success / failure (same as `mv_successpage` / `mv_failpage`). |
| `&update=yes` | Copy each field checked from here on into the session *even if* the profile later fails, so a redisplayed form keeps the shopper's input. |
| `&set=VAR VALUE` | Set a session value unconditionally. |
| `&setcheck=VAR VALUE` | Set a value and fail the profile if it is blank/zero. |
| `&return=1` / `&return=0` | Force immediate success/failure. |
| `&credit_card=standard` | Validate and encrypt the `mv_credit_card_*` fields (checkout). |
| `&charge=custom ROUTINE` | Run a real-time [payment](payments.md) charge through the named gateway. |

Directives take effect from the point they appear, so ordering matters. A
common pattern collects all field errors first, then stops:

    name=required     We need your name.
    email=required    We need your email.
    &fatal=yes
    email=email       That email address is malformed.
    &success=thanks

Because the specification is interpolated for ITL before it runs, you can drive
checks with `[value ...]`, `[if ...]`, or a `[perl]` block for arbitrarily
complex validation.

### Showing errors on the redisplayed form

When a check fails, its message is stored per field and the shopper is returned
to `mv_failpage` (or `mv_nextpage`). Display a field's error with the
[error](../tags/error.md) tag:

    <label>[error name=email std_label="Email"]:</label>
    <input name="email" value="[value email]">

[formel](../tags/formel.md) does this automatically — it wraps a failed
field's label in a contrast span. Note that when a `mv_form_profile` check
fails, values are *not* saved to the session by default (so the form would lose
its input); add `&update=yes` before the `&fatal` line to keep the fields the
shopper already filled in.

### Related control fields

Beyond `mv_form_profile`/`mv_order_profile`, several CGI fields fine-tune
routing (all read in `check_order()`):

- `mv_failpage` / `mv_successpage` — next page on failure / success.
- `mv_fail_href` / `mv_success_href` — same, alternate names.
- `mv_individual_profile` — a per-widget profile fragment (authorized via
  scratch, used by generated widgets).

## Uploading files

To accept a file, give the form `enctype="multipart/form-data"` and a file
input. Interchange holds the uploaded file in memory; it is discarded unless
you read or write it with [value-extended](../tags/value-extended.md).

    <form action="[process]" method="post" enctype="multipart/form-data">
      [form-session-id]
      <input type="hidden" name="mv_todo"     value="return">
      <input type="hidden" name="mv_nextpage" value="uploaded">
      <input type="file" name="newfile">
      <input type="submit" value="Upload">
    </form>

On the next page, write it out or read its contents:

    Uploaded name: [value-extended name=newfile]
    Is it a file?  [value-extended name=newfile test=isfile yes=Yes no=No]
    Save it:       [value-extended name=newfile outfile=uploads/data.csv]
    Contents:      [value-extended name=newfile file_contents=1]

`outfile` writes through Interchange's [safe file](security.md) layer, so the
path is checked against the catalog's allowed-write rules; `maxsize` caps the
accepted size and `ascii=1` normalizes line endings.
[value-extended](../tags/value-extended.md) also reads *stacked* (multi-value)
fields by index — `index=0`, `index="0..1"`, `index="*"` — which is how
checkbox groups and multi-selects are unpacked.

## Stacking fields

Several fields with the same name POST as a stacked (multi-value) variable.
This is how one form orders several items, or offers per-line delete
checkboxes on the cart:

    <form action="[process]" method="post">
      <input type="hidden" name="mv_doit" value="refresh">
      [item-list]
        <input type="checkbox" name="[quantity-name]" value="0"> Delete
        [item-description]
        <input name="[quantity-name]" value="[item-quantity]">
      [/item-list]
      <input type="submit" value="Update cart">
    </form>

Because `[quantity-name]` yields a name unique per cart line, the `refresh`
verb reads each quantity independently (a `0` deletes the line). See
[carts and checkout](cart-and-checkout.md) for the item fields
(`mv_order_item`, `mv_order_quantity`, `[item-list]`).

## Updating a table from a form

The `set` and `autoset` verbs write a database row from the form, using the
`mv_data_*` control fields — `mv_data_table`, `mv_data_key`,
`mv_data_fields`, `mv_data_function` (`insert`/`update`). This is the engine
behind the admin UI's table editors and simple "edit my account" forms. Because
it writes to the [database](databases.md) directly, keep such forms behind a
login and a profile; the [admin UI](admin-ui.md) chapter and the
[update](../tags/update.md) tag cover the full mechanism. For most catalog code
you will let the [UserDB](user-database.md) tags handle account updates rather
than driving `mv_data_*` by hand.

## Security notes

- **Submit sensitive forms securely.** `action="[process secure=1]"` posts to
  the [SecureURL](../config/SecureURL.md) base so credentials and card data
  travel over https. `secure` defaults to the current request's scheme, so a
  form on an https page stays secure automatically.
- **Card fields are never stored.** `mv_credit_card_number` and
  `mv_credit_card_cvv2` (along with `mv_password`, `mv_verify`,
  `mv_password_old`) are on the dispatcher's hide/ignore list, so they are not
  written into the session or shown by [dump](../tags/dump.md). Card data is
  encrypted for the charge and discarded; see [payments](payments.md).
- **Validate on the server.** JavaScript field checks (the admin widgets'
  `js_check` options) improve the user experience but are not a substitute for
  a profile — the profile is the authority.
- **Catalog code runs in the Safe compartment.** A `[perl]` block in a profile
  or `mv_check` is restricted; full-power hooks need
  [GlobalSub](../config/GlobalSub.md) or `FormAction`. See
  [Security](security.md).

## See also

- [Cart and checkout](cart-and-checkout.md) — the `order`/`submit` path,
  order profiles, routes, and the `mv_order_*` fields
- [Search](search.md) — the `search`/`scan` actions and `mv_search*` fields
- [User accounts](user-database.md) — login, registration, account forms
- [Templating](templating.md) — `[value]`/`[cgi]`/`[scratch]` and ITL syntax
- [Sessions](sessions.md) — where submitted values are kept
- Reference: [mv_* form variables](../variables/mv-form-variables.md),
  [process](../tags/process.md), [form-session-id](../tags/form-session-id.md),
  [formel](../tags/formel.md), [value-extended](../tags/value-extended.md),
  the [widget](../widgets/README.md) and [order-check](../order-checks/)
  catalogs
