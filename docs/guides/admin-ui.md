# The admin interface

Interchange ships a complete back-office application — the **admin UI** —
for running a catalog without editing files by hand: managing orders and
customers, editing any database table, uploading and publishing pages,
tuning shipping and tax, and reconfiguring the running server. It is a
catalog-independent library (`dist/lib/UI/`) layered on top of whatever
catalog it serves, built almost entirely from ordinary
[ITL pages](templating.md) and a handful of admin-only tags. This chapter
explains how to turn it on, how its login and permission model works, and
how its main tools — the table editor, the content editor, and the wizard
framework — are built, so you can use them and extend them.

By the end you will be able to enable the UI, log in, grant other users
scoped access, build a custom edit screen with the table editor, and add or
override an admin page.

## Enabling the UI

The admin UI is gated by a single global [Variable](../config/Variable.md),
`UI`, read in `interchange.cfg`. The shipped `dist/interchange.cfg.dist`
sets it and then includes the UI's own config only when it is set:

    Variable  UI  1

    ifdef UI
    Message -i -n Calling UI...
    include lib/UI/ui.cfg
    endif

`lib/UI/ui.cfg` is the UI application's configuration. It sets `UI_BASE`
(the URL segment the admin pages live under — `admin` by default), points
[TemplateDir](../config/TemplateDir.md) at `lib/UI/pages` so the daemon
finds the admin pages as if they were in your catalog, and defines the
admin-only machinery: the `[reconfigure]` tag, the `admin_links`
[GlobalSub](../config/GlobalSub.md), and the `admin_publish`
[ActionMap](../config/ActionMap.md) used for in-browser page publishing.

Because the UI is a shared library, three per-catalog config fragments wire
it into each store. They are read automatically through
[ConfigAllBefore / ConfigAllAfter](configuration.md) and the catalog's own
`catalog.cfg`:

- **`catalog_before.cfg`** (`dist/catalog_before.cfg`) sets the `UI_*`
  layout, color, and size variables, names the tables the UI uses
  (`UI_ACCESS_TABLE access`, `UI_META_TABLE mv_metadata`), and loads the
  `ichelp` help [Database](../config/Database.md) from
  `lib/UI/ichelp.txt`.
- **`catalog_after.cfg`** (`dist/catalog_after.cfg`) defines the admin login
  (`UserDB ui`, below) and the `ui_download` ActionMap that serves
  authorized soft-goods files.
- **`catalog.cfg`** activates the per-request hook and secures the admin
  paths:

      ifdef @UI
      Autoload admin_links
      endif

      AlwaysSecureGlob   <<EOD
          admin*,
          cert*,
          ui*,
      EOD

  The `@UI` test reads the *global* Variable space from a catalog file (the
  `@` prefix; see [Configuration](configuration.md)).
  [Autoload](../config/Autoload.md) runs the `admin_links` GlobalSub on
  every request — it is what injects the "edit this page / item / component"
  links into storefront pages when an admin is logged in.
  [AlwaysSecureGlob](../config/AlwaysSecureGlob.md) forces every `admin*`,
  `ui*`, and `cert*` page onto the secure (HTTPS) URL.

With `UI 1` set and the catalog created by `makecat` (which lays down these
fragments), the admin login page is reached at the `admin` base under your
catalog URL — for the strap demo served at `/cgi-bin/strap`:

    https://your.host/cgi-bin/strap/admin/index

An unauthenticated request to any `admin/*` page bounces to `admin/login`.

## Access and permissions

### The access table and the ui login

Admin accounts live in their own table, `access` (not the storefront
`userdb`), so back-office logins are separate from customer accounts. The
strap schema (`dist/strap/dbconf/*/access.*`) is deliberately small:

    username   password   name   email   last_login   super

`catalog_after.cfg` defines a dedicated [UserDB](../config/UserDB.md)
profile, `ui`, that authenticates against it:

    ifdef @UI
    UserDB ui database   access
    UserDB ui crypt      1
    UserDB ui bcrypt     1
    UserDB ui cost       13
    UserDB ui bcrypt_pepper  __BCRYPT_PEPPER__
    UserDB ui time_field last_login
    UserDB ui admin      1
    UserDB default admin 0
    endif

Passwords are bcrypt-hashed (see [User database](user-database.md) for the
password mechanics). `UserDB ui admin 1` marks this profile as the
administrative one, and `UserDB default admin 0` ensures the ordinary
storefront login can never confer admin rights.

The login page (`lib/UI/pages/admin/login.html`) posts to
[`[process]`](../tags/process.md) with the `MMLogin`
[order profile](forms.md) (`lib/UI/profiles/login`), which runs the
authentication and, on success, sends the user to `admin/index`:

    __NAME__ MMLogin
    mv_todo=return
    [if type=explicit compare="[userdb function=login profile=ui]"]
    mv_nextpage=[either][cgi mv_nextpage][or]__UI_BASE__/index[/either]
    [else]
    mv_nextpage=[either][cgi mv_failpage][or]__UI_BASE__/login[/either]
    [/else]
    [/if]

A successful UI login sets `$Vend::admin`; the daemon's
`$Global::SuperUserFunction` is pointed at the UI's `is_super` routine so
that the `super` flag on the access record grants unrestricted access.

### Superusers, scoped access, and if_mm

Two levels of access exist:

- **Superusers** — an access record with `super` set to `1` — pass every
  permission check.
- **Scoped users** — everyone else — are checked against an access-control
  list (ACL) attached to their record. In a fuller access schema the ACL is
  a serialized structure stored in a `table_control` field (the strap demo
  ships only the `super` column; add `table_control` and the group columns
  to use scoped ACLs). The ACL can allow or deny whole tables, individual
  keys, pages, files, and named admin functions.

Every admin page gates its content with the
[if_mm](../admin-tags/if_mm.md) tag (written `[if-mm ...]` in the shipped
pages — Interchange treats `-` and `_` as equivalent in tag names). It is
the primary access gate throughout the UI:

    [if-mm logged_in]
      ...admin content...
    [else]
      [bounce page="__UI_BASE__/login"]
    [/else]
    [/if-mm]

    [if-mm super]
      ...only superusers see this...
    [/if-mm]

    [if-mm !table products]
      You are not allowed to edit the products table.
    [/if-mm]

The check families cover `logged_in`, `super`, `table`, `key`, `page`,
`file`, and named UI functions; a leading `!` negates. Related tags read
the same ACL data: [mm_value](../admin-tags/mm_value.md) returns a
permission value and [grep_mm](../admin-tags/grep_mm.md) filters a list to
the entries the user may act on. The underlying routines
(`ui_check_acl`, `ui_acl_enabled`, `get_ui_table_acl`) live in
`UI::Primitive` and are aliased into the tag namespace by `ui.cfg`.

Admin accounts are themselves managed from the UI (Admin → Access, pages
`access.html` / `group.html`), and superusers can temporarily act as
another user with [su](../admin-tags/su.md) or
[assume_identity](../admin-tags/assume_identity.md) — useful for
reproducing a scoped user's view.

## The table editor and mv_metadata

The single most reused piece of the UI is the **table editor**: given a
table and a key, it builds a complete HTML edit form, choosing an
appropriate widget for each column. Nearly every edit screen in the admin —
products, orders, customers, shipping, preferences — is a table-editor call.
It is exposed as the [table_editor](../admin-tags/table_editor.md) tag
(implemented in `Vend::Table::Editor`).

The minimal call edits one row using the table's stored configuration:

    [table-editor table=products key=os28044]

To restrict the columns and override a widget inline, without any stored
configuration:

    [table-editor
        table=products
        key=os28044
        fields="sku price description"
        widget.description=textarea
        width.description=50
        height.description=10
    ]

`[table-editor cgi=1]` reads the table, key, and view from the current
request instead of the tag call — this is how the generic admin edit pages
work, editing any table from one page.

### Where the field configuration comes from

Field appearance is not hard-coded: it is looked up per column from a
metadata table, `mv_metadata` (named by `UI_META_TABLE`). Each row
describes how one field — or one whole table view — is displayed. The key
(`code`) is resolved from most specific to least:

    view::table::column::key
    view::table::column
    table::column::key
    table::column

If no metadata matches, the field gets a default text box. The load-bearing
columns of `mv_metadata` are:

| Column | Meaning |
|--------|---------|
| `code` | The lookup key (`table::column`, plus the view/key forms above). |
| `type` | The widget type (see below). |
| `width`, `height` | Widget dimensions; `height` also sets the table's record-list page size in a table-level record. |
| `label` | The field's display label. |
| `help` | Help text / help-table reference. |
| `lookup`, `field`, `db` | Source table/column for `select`-type option lists. |
| `options` | Explicit option list, `value=Label` per line. |
| `filter` | [Filter](../filters/README.md) chain applied to the value. |
| `outboard`, `extended` | Serialized extra settings (below). |

The `type` column selects from some two dozen widgets rendered by
`Vend::Form`, among them `text`, `textarea`, `select`, `multiple`,
`yesno` / `noyes` (with `radio` variants), `combo` and `reverse_combo`
(select-with-add), `radio`, `checkbox`, `date`, `imagehelper` (upload an
image and store its name), `value` (display only), and `hidden_text`. The
full widget catalog, with the option-list mechanics, is documented on the
[widget](../admin-tags/widget.md) and
[widget_meta](../admin-tags/widget_meta.md) tag pages;
[meta_record](../admin-tags/meta_record.md) and
[meta_info](../admin-tags/meta_info.md) read a metadata record from ITL.

You rarely edit `mv_metadata` by hand. The UI ships two editors for it: the
**table definition editor** (`pages/admin/db_metaconfig.html`), which
controls a table's overall view — which fields appear, in what order, on
which tabs — and the **field definition editor**
(`pages/admin/meta_editor.html`), which sets one field's widget, label,
help, and options. Reaching a table through Admin → Tables opens exactly
these table-editor-driven screens.

### Tabbed views and linked tables

Two features make the table editor a full application rather than a form
generator. A field specification of the form `tab_label=field field ...`
produces a **tabbed** interface automatically (rendered with
[tabbed_display](../admin-tags/tabbed_display.md)), so a long record is
split into logical pages. And a base record can pull in and edit fields
from *other* tables in the same form, so related rows (a product and its
pricing, inventory, and options) are edited together — this is how the
product editor's Base / Pricing / Inventory / Options tabs work.

For read-only or lighter-weight displays, the UI also provides
[quick_table](../admin-tags/quick_table.md) (a record as a simple
two-column table), [row_edit](../admin-tags/row_edit.md), and
[flex_select](../admin-tags/flex_select.md) (a configurable record list).
Whole tables can be moved or dumped with
[export_database](../admin-tags/export_database.md),
[backup_database](../admin-tags/backup_database.md), and
[import_fields](../admin-tags/import_fields.md).

## The content editor

While the table editor edits *data*, the **content editor**
(`pages/admin/content_editor.html`, engine `UI::ContentEditor`) edits
*pages*. It treats a catalog page as three layers:

- a **template** (from `templates/layout/`, e.g. `leftonly`) that provides
  the page chrome and defines named **slots**;
- **components** dropped into those slots (from `templates/components/`),
  each with its own settings; and
- the page's own **content** and **page controls** (title, access flags).

A content-editable page carries a small map of markers the editor reads and
rewrites. A leading `[comment]` block records the template name and whether
the page publishes statically; `[set ...]` blocks hold page controls;
`[control-set] ... [/control-set]` blocks hold each component's settings;
and the body is bracketed by `<!-- BEGIN CONTENT -->` /
`<!-- END CONTENT -->` (with optional `PREAMBLE` / `POSTAMBLE` sections for
init and cleanup Perl). A typical page skeleton:

    [comment]
    ui_template: leftonly
    ui_static: 0
    [/comment]

    [set page_title]A typical page[/set]

    [control reset=1]
    [control-set]
        [component]cart_tiny[/component]
    [/control-set]
    [control reset=1]

    @_LEFTONLY_TOP_@

    <!-- BEGIN CONTENT -->
        The content of a typical page.
    <!-- END CONTENT -->

    @_LEFTONLY_BOTTOM_@

The editor parses these regions into form fields — a textarea for the
content, per-component control forms, page-control inputs — and writes the
file back on save. The admin tags [content_info](../admin-tags/content_info.md)
and [content_modify](../admin-tags/content_modify.md) read and apply those
changes; `templates/` and `components/` are enumerated so the editor can
offer the available choices.

### In-browser publishing

The `admin_links` GlobalSub (loaded in `ui.cfg`, run via `Autoload`)
injects edit links into storefront pages for a logged-in admin, and a
companion **publish** path lets an external HTML editor save a page back
into the catalog. The `admin_publish` ActionMap (also in `ui.cfg`,
`SpecialPage put_handler`) accepts an HTTP `PUT`, verifies the request came
from an authenticated admin (`403` otherwise) and that the user is
authorized for that page or file (via `if_mm`), reassembles the template /
content / component structure, and writes the result — optionally checking
the previous version into RCS (`PUBLISH_DO_RCS`) or staging to a preview
directory (`PUBLISH_TO_PREVIEWS`). The relevant `PUBLISH_*` Variables
(`PUBLISH_PUT_PAGES`, `PUBLISH_PUT_IMAGES`, `PUBLISH_NO_PAGE_ROOT`, …) tune
where and how published files land.

## Wizards

The table editor has a **wizard mode** for multi-step data collection —
setup and install tasks that walk the user through Next / Back / Cancel /
Finish steps rather than presenting one flat form. The same engine that
renders an edit form renders a wizard step; the difference is the button set
and the flow control. The [auto_wizard](../admin-tags/auto_wizard.md) tag
drives a wizard from a specification, and the shipped
`pages/admin/search_wizard*.html` and `auto_wizard.html` pages are worked
examples. Because a wizard is just a configured table editor, everything you
know about widgets and metadata applies.

## Customizing the admin

The UI is built from ordinary ITL, so it is customizable at several levels
without touching the core library.

**Appearance and sizing.** The `UI_*` Variables set in `catalog_before.cfg`
control colors, widths, and list sizes (`UI_T_ROW_EVEN`, `UI_MAIN_WIDTH`,
`UI_SZ_LIST_ORDER`, …). Override them in your `catalog.cfg` (after the
`before` file has run) to reskin the admin per catalog.

**Menus.** The left-hand navigation is data, not code: the menu text files
in `lib/UI/pages/include/menus/` (`Top.txt`, `Orders.txt`, `Items.txt`, …)
define the tree, loaded with [menu_load](../admin-tags/menu_load.md). Add or
reorder entries by editing (or shadowing) those files.

**Overriding a page.** Because `TemplateDir lib/UI/pages` is searched *after*
your catalog's own `pages/`, a page you create at `pages/admin/index.html`
in your catalog takes precedence over the shipped one — the standard way to
customize a single admin screen without forking the library. Add a wholly
new admin page the same way: drop `pages/admin/my_report.html` in your
catalog, gate it with `[if-mm logged_in]`, and it appears under the admin
base URL.

**Localization.** The UI is translated through
`include lib/UI/locales/*_*.cfg` (about a dozen languages); admin strings
are wrapped in `[L]...[/L]` / `[loc]...[/loc]` and resolve per the logged-in
user's locale. See [Internationalization](internationalization.md).

## Reconfiguring from the UI

Changes that require re-reading `catalog.cfg` (new directives, edited
Variables) are applied from the admin's "Apply Changes" action, which calls
the [reconfig](../admin-tags/reconfig.md) tag. Under the hood, `ui.cfg`'s
`[reconfigure]` tag writes a request line to `$Global::RunDir/reconfig`;
the daemon picks it up on its next [housekeeping](architecture.md) pass and
recompiles the catalog in place, with no restart — the same mechanism as
`bin/interchange --reconfig=catalog` described in
[Configuration](configuration.md). [reconfig_time](../admin-tags/reconfig_time.md)
reports when the catalog was last reconfigured.

## Admin tag reference

The tags used only by the admin UI — the ones above plus the table,
metadata, content, file, GPG, session, and reporting helpers — are
cataloged separately in the [admin tag reference](../admin-tags/README.md).
They are loaded only when `Variable UI` is set, so they are not available on
an ordinary storefront page. Some you will reach for often:

- Editing and display —
  [table_editor](../admin-tags/table_editor.md),
  [row_edit](../admin-tags/row_edit.md),
  [quick_table](../admin-tags/quick_table.md),
  [flex_select](../admin-tags/flex_select.md),
  [tabbed_display](../admin-tags/tabbed_display.md),
  [widget](../admin-tags/widget.md).
- Metadata —
  [meta_record](../admin-tags/meta_record.md),
  [meta_info](../admin-tags/meta_info.md),
  [widget_meta](../admin-tags/widget_meta.md).
- Content —
  [content_info](../admin-tags/content_info.md),
  [content_modify](../admin-tags/content_modify.md),
  [content_editor](../admin-tags/content_editor.md).
- Permissions and identity —
  [if_mm](../admin-tags/if_mm.md),
  [mm_value](../admin-tags/mm_value.md),
  [grep_mm](../admin-tags/grep_mm.md),
  [su](../admin-tags/su.md),
  [assume_identity](../admin-tags/assume_identity.md).
- Tables and files —
  [export_database](../admin-tags/export_database.md),
  [backup_database](../admin-tags/backup_database.md),
  [list_databases](../admin-tags/list_databases.md),
  [file_navigator](../admin-tags/file_navigator.md),
  [list_pages](../admin-tags/list_pages.md).
- Server —
  [reconfig](../admin-tags/reconfig.md),
  [reconfig_time](../admin-tags/reconfig_time.md),
  [version](../admin-tags/version.md),
  [directive_value](../admin-tags/directive_value.md),
  [global_value](../admin-tags/global_value.md).

## See also

- [Configuration](configuration.md) — the `interchange.cfg` / `catalog.cfg`
  model the UI plugs into, and reconfiguration
- [User database](user-database.md) — the login/password mechanics behind
  the `ui` UserDB profile
- [Databases](databases.md) — the tables the editor edits
- [Forms](forms.md) — order profiles, the `[process]` action, and widgets
- [Templating](templating.md) — the ITL the admin pages are written in
- [Security](security.md) — why admin paths are secured and code trust
  levels
- [Admin tag reference](../admin-tags/README.md) — every admin-only tag
