# Admin UI tags

The 70 tags in this directory belong to the Interchange administrative interface
(the UI_Tag set in `code/UI_Tag/`). They are loaded only when the admin UI
feature is enabled and are not available to ordinary storefront pages. Use them
inside back-office pages and custom admin tools. Container tags (those taking an
end tag, `[tag]...[/tag]`) are flagged `(C)`, standalone tags `(S)`.

For the administrative interface as a whole, see the
[admin UI guide](../guides/admin-ui.md). Storefront tags live in
[`../tags/`](../tags/README.md).

### Database & table tools

- [flex_select](flex_select.md) (C) — Render a full tabular overview of a database table for the admin: a searchable, sortable, paged grid of records with per-row checkboxes and edit/delete controls.
- [table_editor](table_editor.md) (C) — Generate a complete HTML form for editing or creating one row of a database table, choosing a widget per column from the table's metadata.
- [row_edit](row_edit.md) (C) — Render the editable cells for one database row as a horizontal strip of table cells, one form widget per column, for the admin UI's spreadsheet-style multi-row editor.
- [quick_table](quick_table.md) (C) — Turn a block of `label: value` lines into a simple two-column HTML table, with labels bold and right-aligned.
- [db_columns](db_columns.md) (S) — Return the column names of a database table, in table order or in a caller-specified order, honoring any admin UI access-control list on the table.
- [db_hash](db_hash.md) (S) — Read or write one value inside a serialized Perl hash that is stored in a single database field, addressing nested members by a colon-separated key path.
- [list_databases](list_databases.md) (S) — List the names of the catalog's configured databases (tables), honoring the administrative access-control rules of the current user.
- [list_keys](list_keys.md) (S) — List the primary-key values of a database table, honoring the administrative user's row-level access control.
- [import_fields](import_fields.md) (S) — Load or update a database table from a delimited text file (or a spreadsheet converted to one), with optional add, delete, cleanse, and filtering.
- [export_database](export_database.md) (S) — Write a database table back out to its text source file, or add/remove a column, from within a page.
- [backup_database](backup_database.md) (S) — Export one or more database tables to flat files in a backup directory, with optional gzip compression, an aggregate download file, and Excel (`.xls`) output.
- [rotate_table](rotate_table.md) (C) — Transpose an HTML `<table>` in its body, turning rows into columns and columns into rows.
- [directive_value](directive_value.md) (S) — Return the configured value of an Interchange configuration directive as seen by the running catalog, optionally with catalog and global variables expanded.
- [global_value](global_value.md) (S) — Return the value of a Perl global variable named by its fully qualified symbol.

### Content & page editing

- [content_editor](content_editor.md) (C) — Render the admin UI editing form for an Interchange page, template, or component (the WYSIWYG-style content editor).
- [content_modify](content_modify.md) (S) — Apply one or more edit operations (save, publish, delete, add/remove component, and so on) to the page, template, or component currently held in the content editor's session store.
- [content_info](content_info.md) (S) — Return information about the components (or templates) available to the content editor: an option list for a select widget, a single component's label or class, or a component's parsed structure.
- [assume_identity](assume_identity.md) (S) — Read a disk file and interpolate it as though it were a named Interchange page, temporarily setting the current page name.
- [substitute_file](substitute_file.md) (C) — Rewrite the region of an on-disk file that lies between a begin marker and an end marker, replacing it with the tag's body.
- [list_pages](list_pages.md) (S) — List the catalog's page files, walking the page directory recursively.
- [menu_load](menu_load.md) (S) — Generate tab-delimited menu data from a database table, ready to load into the Interchange menu system.
- [diff](diff.md) (S) — Run the system `diff` program between two texts and return its output.
- [diffmerge](diffmerge.md) (C) — Three-way merge of two edits of a common ancestor text, using the system `diff3`, returning the merged result with conflict markers.
- [newer](newer.md) (S) — Compare two files by modification time and report whether the first is newer than the second.

### File management

- [file_navigator](file_navigator.md) (S) — Render an interactive file browser for the catalog directory tree: a list of files and folders with links to upload, download, view, edit, and delete them, plus a text/filename search.
- [file_info](file_info.md) (S) — Report information about a file on the server: its size, modification time, a formatted description, or the results of file-test operators.
- [cp](cp.md) (S) — Copy a file, optionally preserving its access/modification times and applying a specific umask.
- [backup_file](backup_file.md) (S) — Copy a file into the catalog's `backup/` tree, rotating any previous backup of the same file so older copies are preserved.
- [check_upload](check_upload.md) (S) — Move a file that was uploaded into the catalog's `upload/` directory into the product-data directory, so an admin-uploaded table file is picked up by Interchange's file-based import.
- [unlink_file](unlink_file.md) (S) — Safely delete a file from within the catalog directory, refusing paths that escape it or that do not match a required prefix.
- [write_relative_file](write_relative_file.md) (C) — Write the tag's body to a file inside the catalog directory, creating any missing parent directories.
- [write_shipping](write_shipping.md) (S) — Write Interchange's in-memory shipping configuration back out to a `shipping.asc` file.
- [read_shipping](read_shipping.md) (S) — Load a shipping-definition file into the running catalog configuration.
- [list_glob](list_glob.md) (S) — Expand a shell-style glob pattern into a list of matching file names, optionally stripping a common directory prefix from each result.

### User & access management

- [if_mm](if_mm.md) (C) — Conditionally include page content based on whether the current admin user has permission for a UI task, table, page, or field.
- [mm_value](mm_value.md) (S) — Return a field from the current administrator's access-control record, or a per-table ACL setting.
- [grep_mm](grep_mm.md) (C) — Filter a list of items down to those the current admin user is permitted to act on, according to the UI access-control list for a table.
- [su](su.md) (S) — Switch the current session to another user's identity ("switch user"), and later switch back, so a catalog superuser can act as a customer or another administrator.
- [run_profile](run_profile.md) (S) — Validate a set of submitted values against a form profile and return the pass/fail status, so an admin page can check input without going through the normal order-processing path.
- [user_merge](user_merge.md) (S) — Merge one or more user accounts into a target user, moving their transactions and order lines and combining their saved carts, then deleting the merged accounts.
- [dump_session](dump_session.md) (S) — Show the contents of a stored user session, in whole or in part, or list the sessions that are currently active.
- [crypt](crypt.md) (S) — Encrypt a string with Perl's built-in `crypt()`, exactly like the C library `crypt(3)` function.
- [add_gpg_key](add_gpg_key.md) (S) — Import an ASCII-armored GnuPG public key into the server's GPG keyring, used when setting up encrypted-payment or encrypted-email delivery from the admin interface.
- [get_gpg_keys](get_gpg_keys.md) (S) — List the public keys in a GPG keyring as `id=description` pairs, suitable for populating a select widget.

### Shipping & orders

- [available_ups_internal](available_ups_internal.md) (S) — List the internal ("zone file") UPS shipping tables that exist in the catalog, as an option string for a select widget.
- [available_www_shipping](available_www_shipping.md) (S) — List the real-time ("www") shipping modes available on this server, based on which shipping Perl modules are installed.
- [update_order_status](update_order_status.md) (S) — Mark an order shipped, partially shipped, or canceled: it updates the order's line-item and transaction status, optionally records tracking numbers, settles or voids the payment, archives the order, and queues a shipment-notice email.
- [recompute_transaction](recompute_transaction.md) (S) — Recalculate the stored totals of a completed order: line-item subtotals, item count, order subtotal, and grand total (optionally sales tax), writing the corrected values back to the `transactions` and `orderline` tables.

### Metadata & widgets

- [display](display.md) (S) — Render a single HTML form element for a database column, driven by the column's metadata.
- [widget](widget.md) (C) — Build a single HTML form control (a `select`, radio group, checkbox set, text box, and so on) from a widget definition and a value.
- [widget_info](widget_info.md) (S) — Look up the registered metadata for a form-widget type: its implementing widget code, description, help text, documentation, visibility, and whether it supports multiple values.
- [widget_meta](widget_meta.md) (S) — Return the meta record (the default option hash) associated with a form-widget type.
- [meta_info](meta_info.md) (S) — Return a single named setting from a metadata (`mv_metadata`) record.
- [meta_record](meta_record.md) (S) — Return the complete metadata record for a meta item as a hash reference, merging the meta table row with its serialized `extended` settings.

### UI utilities

- [tabbed_display](tabbed_display.md) (C) — Break a block of content into a dynamic tabbed panel display: each panel gets a clickable tab, and selecting a tab reveals its panel.
- [auto_wizard](auto_wizard.md) (C) — Compile and run a multi-page "wizard" (a sequence of form screens with Back, Next, and Finish navigation) from a compact text script in the tag body.
- [return_to](return_to.md) (S) — Emit the navigation state that sends an administrative form or link back to the page the user came from.
- [traffic_report](traffic_report.md) (S) — Summarize the catalog's traffic log into an HTML table of visits, hits, page views, product views, cart adds, and orders, broken down by month or by day.
- [base_url](base_url.md) (S) — Return the catalog's non-secure base URL (the `VendURL` the server was configured with).
- [mm_locale](mm_locale.md) (S) — Switch the current request into the administrative UI's locale, loading that locale's settings and text direction.
- [reconfig](reconfig.md) (S) — Queue a catalog for reconfiguration so the Interchange server rereads its configuration on the next request, without restarting the daemon.
- [reconfig_time](reconfig_time.md) (S) — Read back a catalog's reconfiguration status file, so an administrative page can report the result of a pending or completed [reconfig](reconfig.md).
- [uninstall_feature](uninstall_feature.md) (S) — Remove a catalog feature that was previously installed through Interchange's Feature mechanism, reversing the files and configuration that feature added.
- [version](version.md) (S) — Report Interchange version and system information: the server version, the database and Perl module inventory, locale and environment details, and the result of testing whether a named Perl module is installed.
- [uneval](uneval.md) (S) — Serialize a Perl data structure to a Perl-source string, for dumping a session element or a passed reference while debugging.
- [xfer_catalog](xfer_catalog.md) (S) — Package an entire catalog into a gzipped tar image for backup or transfer, exporting its databases, dumping any SQL databases with their native tools, and generating a `restore.sh` script that rebuilds the catalog on the destination.

### JS / JSON helpers

- [jsonq](jsonq.md) (S) — Generate a cached, tokenized URL that returns the result of a SQL query as JSON (or as templated text) when fetched.
- [jsq](jsq.md) (C) — Quote a block of text so it is safe to drop into a JavaScript string literal, performing simple `$variable` substitution as it goes.
  - [jsquote](jsquote.md) — alias of [jsq](jsq.md)
- [jsqn](jsqn.md) (C) — Quote a block of text so it is safe to drop into a JavaScript string literal, **without** performing any variable substitution.
