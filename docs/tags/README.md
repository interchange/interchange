# Interchange Tag Language (ITL) tags

The 157 tags in this directory are the Interchange Tag Language (ITL) — the
`[tag ...]` markup you embed in catalog pages and templates. Each tag has its
own reference page; this index groups them by what they do. Where a page marks a
tag as a **container** (it takes an end tag, `[tag]...[/tag]`) or **standalone**
(no end tag), the entry is flagged `(C)` or `(S)`. Alias stubs are nested under
their canonical tag and collected again at the end.

See the [templating guide](../guides/templating.md) for how tags are
interpolated, and the [glossary](../glossary.md) for terms such as ITL, scratch,
and flypage.

### Data access & display

- [data](data.md) (S) — Reads (or sets) a single field of any database table by key, or a value in the user's session.
- [field](field.md) (S) — Return a single column value for a product SKU from the catalog's product database(s).
- [description](description.md) (S) — Returns the description of a product from the products database.
- [image](image.md) (S) — Build an HTML `<img>` tag (or just an image URL) from a product SKU or an image filename, resolving the catalog image directory, pulling `alt` text and dimensions automatically, and optionally resizing.
- [price](price.md) (S) — Return the price of a product, formatted as currency in the catalog's locale.
- [currency](currency.md) (C) — Formats the number in its body as localized currency — applying the thousands separator, decimal point, precision, and currency symbol of the active locale.
- [config](config.md) (S) — Return the value of an Interchange configuration directive at runtime -- from the current catalog's configuration by default, or from the global (`interchange.cfg`) configuration.
- [var](var.md) (S) — Return the value of a catalog (or global) configuration Variable, with an optional filter.
- [convert-date](convert-date.md) (C) — Format a date with POSIX `strftime`, optionally shifting it by a number of days first.
- [time](time.md) (C) — Format a date/time using a `strftime`-style format string.
- [db-date](db-date.md) (S) — Return the last-modified time of a database table's source text file, formatted with POSIX `strftime`.
- [env](env.md) (S) — Return a single HTTP/CGI environment variable, or -- with no argument -- an HTML table of the entire environment.
- [banner](banner.md) (S) — Return an advertising banner (or any rotating snippet) from the `banner` table, chosen either by sequential rotation or by weighted random selection.

### Looping & lists

- [loop](loop.md) (C) — Iterate the tag body once for each item in a supplied list, a search result, or a file — the general-purpose looping tag.
- [region](region.md) (C) — Iterate a result set over a body of ITL, resolving prefix sub-tags for each row.
- [item-list](item-list.md) (C) — Iterates over the line items in a shopping cart, emitting its body once per item with a set of `item-` prefix sub-tags available for each row.
- [tree](tree.md) (C) — Walk a self-referential (parent/child) table and iterate the body over the resulting tree, depth-first, exposing each node's level and children.
- [query](query.md) (C) — Run an SQL (or Interchange search-engine) query against a catalog table and iterate the rows over the tag body.
- [report-table](report-table.md) (S) — Render the rows of an SQL query as an HTML table, with per-column formatting: filters, form widgets, links, CSS classes, nested vertical and horizontal subheaders, and virtual (computed) columns.
- [fly-list](fly-list.md) (C) — Performs the flypage lookup for a product code and renders its body as that product's flypage would be rendered — a single-item loop with `item-` prefix sub-tags.
- [levy-list](levy-list.md) (C) — Iterate the body once for each levy (a tax, shipping, or handling charge) recorded on a cart, interpolating the loop body per levy.
- [summary](summary.md) (S) — Accumulate a running total across repeated calls and display it.
- [table-organize](table-organize.md) (C) — Reflow a flat series of `<td>` cells into an HTML table of a fixed number of columns.

### Conditionals & control flow

- [if](if.md) (C) — Test a value, data field, session key, file, or Perl expression and interpolate the body when the test passes; the language's primary conditional.
  - sub-blocks: [else](else.md), [elsif](elsif.md), [and](and.md), [or](or.md)
- [unless](unless.md) (C) — The negated form of `[if]`: interpolate the body when the test fails.
- [goto](goto.md) (S) — Skip parsing forward to the matching `[label name=...]`, abandoning the intervening output.
- [label](label.md) (S) — Target marker for `[goto]`; otherwise produces nothing.
- [bounce](bounce.md) (S) — Abort the page and redirect the client to another page or URL via an HTTP Location header.
- [output](output.md) (S) — Direct subsequent output into a named region for multi-region page assembly.
- [restrict](restrict.md) (C) — Interpolate the body with a default-deny tag policy, for safely displaying untrusted ITL-bearing content.
- [pragma](pragma.md) (S) — Set a whole-page [pragma](../pragmas/README.md) from within the page.
- [try](try.md) (C) — Run a block of ITL and trap any fatal error (`die`) it raises, storing the error under a label instead of aborting the page.
- [catch](catch.md) (C) — Handles errors raised inside a matching `[try]` block, in the manner of a try/catch construct.
- [either](either.md) (C) — Return the first non-empty alternative from a list of `[or]`-separated choices in its body.
- [if_not_volatile](if_not_volatile.md) (C) — Output the body only when the current request is not "volatile" — that is, only on a normally rendered page, not on a volatile request such as a page being built for the search/robot cache.
- [timed-display](timed-display.md) (C) — Show the body only within a start/stop date-time window; otherwise show an optional `[else]` block.
- [comment](comment.md) (C) — Removes its body from the page, producing no output.
- [local](local.md) (C) — Run a block of ITL with a temporary, private copy of scratch and/or values, restoring the originals when the block ends.

### Links & URLs

- [area](area.md) (S) — Build the URL to an Interchange page or action — the value that goes inside an `href="..."` attribute, without the surrounding `<a>` tag.
  - [href](href.md) — alias of [area](area.md)
  - [process_search](process_search.md) — extended alias: expands to `[area href=search]`, the search-form action URL
- [page](page.md) (S) — Produce an opening `<a href="...">` anchor tag whose URL points at an Interchange page, search, or order action, with session information preserved automatically.
- [process](process.md) (S) — Return the URL that a completed order form or search form should submit to.
  - [process-order](process-order.md) — alias of [process](process.md) _(deprecated)_
  - [process-target](process-target.md) — alias of [process](process.md) _(deprecated)_
- [order](order.md) (S) — Produce a link that adds an item to the shopping cart when followed.
- [menu](menu.md) (C) — Render a navigation menu from menu data — a menu file or database table — as a menubar, tree, or flyout.
- [bar-button](bar-button.md) (C) — Render one entry of a navigation bar, showing a highlighted version when its page is the page currently being viewed and a normal version otherwise.
- [adjust_href](adjust_href.md) (C) — Rewrite the `<a href="...">` links in its body so that page-relative links become full Interchange URLs (session id, secure prefix, and all).
- [history-scan](history-scan.md) (S) — Return a URL from the visitor's own page-history stack, optionally filtered by pattern, so you can build a "back" or "return to previous page" link that survives the session.

### Forms & user input

- [value](value.md) (S) — Return the value of a form variable from the `$Values` space — the persistent per-session store that form fields read from and write to.
  - [evalue](evalue.md) — extended alias: expands to `[value keep=1 filter="encode_entities" name=...]` for entity-encoded display
- [value-extended](value-extended.md) (S) — Return a form variable from the `$Values` space with extra handling that plain [value](value.md) does not offer: joining multiple values, selecting by index, testing presence, and reading or writing uploaded-file contents.
- [default](default.md) (S) — Returns a user form value, substituting a fallback string when the value is empty.
- [values-space](values-space.md) (S) — Switch the active `$Values` namespace, so a page can keep several independent sets of form values (for example a "billing" set and a separate "shipping" or "quote" set).
- [cgi](cgi.md) (S) — Returns (or sets) the value of a CGI input variable submitted with the current request.
- [input-filter](input-filter.md) (C) — Registers (or removes) a filter that Interchange applies automatically to a CGI variable on every future request in the session.
- [accessories](accessories.md) (S) — Build a form widget (dropdown, radio group, checkbox set, text box, and so on) for a product's options or attributes.
- [options](options.md) (S) — Render the option-selection widgets (size, color, and the like) for a product that has variants.
- [button](button.md) (C) — Build a form submit button — a plain `<input type="submit">`, or an image button with a JavaScript click handler and a `<noscript>` fallback.
- [formel](formel.md) (S) — Emit a labeled HTML form element -- text input, textarea, select, radio, checkbox, or a metadata-driven widget -- pre-filled from the session's form values and able to highlight itself when the field failed an order-profile check.
- [checked](checked.md) (S) — Emits ` checked="checked"` when a form variable matches a given value, so a checkbox or radio button redisplays in the state the shopper last chose.
- [selected](selected.md) (S) — Emit ` selected="selected"` when a form value matches a given option value.
- [captcha](captcha.md) (S) — Generates and checks CAPTCHA images to confirm that a form was submitted by a human.
- [form-session-id](form-session-id.md) (S) — Emit a hidden `mv_session_id` form field so a submitted form carries the Interchange session, but only when it is actually needed.
- [profile](profile.md) (S) — Activate a named order or search profile — a stored block of `mv_*` settings — so it runs on subsequent form submissions, or run it immediately.
- [error](error.md) (S) — Set, test, and display the form and processing errors held in the shopper's session.
- [warnings](warnings.md) (S) — Record a warning message into the session and/or display the warnings collected so far.
  - [warning](warning.md) — alias of [warnings](warnings.md)
- [userdb](userdb.md) (S) — Run a user-database operation: log a customer in or out, create an account, save or restore their account fields, and save, restore, or list their carts, shipping addresses, billing addresses, and preferences.

### Cart & commerce

- [cart](cart.md) (S) — Sets the current shopping cart, so that later cart-aware tags on the page operate on that cart instead of the default `main` cart.
- [nitems](nitems.md) (S) — Return the total quantity of items in a shopping cart.
- [subtotal](subtotal.md) (S) — Return the subtotal of the products in a shopping cart — the sum of item prices before shipping, handling, and tax.
- [total-cost](total-cost.md) (S) — Return the grand total of a shopping cart — item subtotal plus all adjustments (quantity pricing, discounts, handling, shipping, and tax).
- [weight](weight.md) (S) — Add up the shipping weight of everything in the shopping cart and return the total.
- [onfly](onfly.md) (S) — Build an on-the-fly cart item — one whose fields come from a submitted string rather than a product record — and return it as an item structure.
- [update](update.md) (S) — Refresh a specific piece of Interchange's internal state on demand — the shopping cart, the form-value namespace, the order process, or table data.
- [load_cart](load_cart.md) (S) — Load a previously saved (nicknamed) shopping cart out of the user database and merge it into the visitor's current cart.
- [save_cart](save_cart.md) (S) — Save the shopper's current cart under a nickname in the user database, so a logged-in customer can restore it later.
- [delete_cart](delete_cart.md) (S) — Delete a saved, nicknamed shopping cart from the logged-in user's account in the user database.
- [discount](discount.md) — Set (or clear) a per-item discount formula in the shopper's session.
- [discount_space](discount_space.md) (S) — Switch or manage the active discount namespace (a "discount space") for the current session.
- [assign](assign.md) (S) — Store fixed numeric overrides for the sales-tax, shipping, handling, subtotal, and credit amounts in the session, so those values are used verbatim instead of being calculated.
- [accounting](accounting.md) (S) — Dispatch a call to the catalog's configured accounting subsystem, enforcing the current user's privilege level.
- [charge](charge.md) (S) — Runs a payment transaction through a named payment route (gateway) and returns the transaction identifier.
- [salestax](salestax.md) (S) — Return the calculated sales tax for the current shopping cart, formatted as currency.
- [fly-tax](fly-tax.md) (S) — Compute sales tax "on the fly" from the catalog's `TAXRATE` variable rather than from a database table.
- [tax-lookup](tax-lookup.md) (S) — Return a sales-tax amount calculated by a third-party tax service (for example TaxJar).
- [send-tax-transaction](send-tax-transaction.md) (S) — Report a completed order's tax to a third-party tax service (for example TaxJar), creating the transaction record the provider needs for filing.
- [load-tax-averages](load-tax-averages.md) (S) — Populate the local tax-averages table from a configured third-party tax service so that estimated sales tax can be calculated without a live API call per request.
- [levies](levies.md) (S) — Returns the total of the catalog's configured *levies* — the unified tax-and-shipping charges defined by the `Levies` / `Levy` directives.
- [handling](handling.md) (S) — Calculate the handling charge for the cart under a named handling mode.
- [shipping](shipping.md) (S) — Calculate the shipping cost for a shipping mode, or produce a list/widget of the available modes.
- [shipping-desc](shipping-desc.md) (S) — Return a field from a shipping mode's definition — by default its human-readable description.
  - [shipping-description](shipping-description.md) — alias of [shipping-desc](shipping-desc.md)
- [shipengine](shipengine.md) (S) — Query the ShipEngine REST API for a live shipping rate.
- [ups-query](ups-query.md) (S) — Calculate UPS shipping cost through the `Business::UPS` Perl module.
- [ups_rest_api](ups_rest_api.md) (S) — Query the UPS REST rating API for a live shipping rate.
- [usps-query](usps-query.md) (S) — Calculate a United States Postal Service shipping cost through the USPS Web Tools rate API.

### Session & scratch

- [scratch](scratch.md) (S) — Return the value of a scratch variable.
- [scratchd](scratchd.md) (S) — Return the value of a scratch variable and then delete it (a destructive read).
- [set](set.md) (C) — Store a value into a scratch variable, without interpolating the body.
- [seti](seti.md) (C) — Store a value into a scratch variable, interpolating the body first.
- [tmp](tmp.md) (C) — Set a temporary scratch variable to the interpolated body, marking it for automatic deletion at the end of the page.
- [tmpn](tmpn.md) (C) — Set a temporary scratch variable to the raw (un-interpolated) body, marking it for automatic deletion at the end of the page.
- [ts](ts.md) (C) — Set a truly temporary value in Interchange's `$Tmp` space, interpolating the body first.
- [tn](tn.md) (C) — Set a truly temporary value in Interchange's `$Tmp` space, storing the body verbatim (without interpolating it).
- [tv](tv.md) (S) — Return a truly temporary value previously set with [ts](ts.md) or [tn](tn.md).
- [read-cookie](read-cookie.md) (S) — Return the value of a browser cookie by name.
- [set-cookie](set-cookie.md) (S) — Queue a cookie to be sent to the browser with the current response.

### Database write & import

- [import](import.md) (C) — Import one or more records into an existing database table from the tag body.
- [export](export.md) (S) — Write a database table back out to its text (ASCII) source file.
- [record](record.md) (S) — Write several columns of one database record in a single operation.
- [index](index.md) (S) — Rebuild the sorted search index (`.idx`) for a database table.
- [flag](flag.md) (S) — Sets a runtime flag on one or more database tables (or on the request), most often to enable writing or transactions for the rest of the current page.

### Search

- [search](search.md) (S) — Run a search against a catalog database and set up its results for display.
- [search-region](search-region.md) (C) — Run a search and iterate its result rows over the tag's body.

### Email & communication

- [email](email.md) (C) — Send an email whose body is the tag's content, with structured headers, header-injection protection, optional CC/BCC, attachments, HTML alternatives, and UTF-8 handling.
- [email-raw](email-raw.md) (C) — Send an email whose body already contains the complete header block -- headers, a blank line, then the message text -- exactly as it should be delivered.
- [mail](mail.md) (C) — Send an email whose body is the tag body.
- [get-url](get-url.md) (S) — Fetch the contents of a remote URL from within a page and return the response body.
- [soap](soap.md) (S) — Make a SOAP client call from a page: invoke a remote method over a URI and proxy, and return (or store) the result.
- [soap_entity](soap_entity.md) (S) — Build a `SOAP::Data` object to use as a structured argument in a [soap](soap.md) call.

### Files & output

- [file](file.md) (S) — Insert the contents of a file into the page verbatim, with optional line-ending conversion.
- [include](include.md) (S) — Read another file and interpolate its contents inline as part of the current page.
- [deliver](deliver.md) (C) — Sends raw content — a file, or the tag body — straight to the browser without wrapping it in the page template, or issues an HTTP redirect.
- [capture_page](capture_page.md) (S) — Render an Interchange page and capture its finished output — into a scratch variable, a file, or both — instead of sending it to the browser.
- [css](css.md) (S) — Take CSS held in an Interchange variable (or supplied literally), write it to a `.css` file under the image directory, and return a `<link>` element pointing at that file -- falling back to an inline `<style>` block when the file cannot be written.
- [output-to](output-to.md) (C) — Capture the body of the tag and append it to a named output buffer instead of emitting it where the tag appears.
- [unpack](unpack.md) (C) — Flush the deferred output regions built up by [output-to](output-to.md) into the current page template, then hand the assembled page to the normal template processor.
- [timed-build](timed-build.md) (C) — Cache the interpolated output of its body in a file and reuse it until a timeout expires.
- [row](row.md) (C) — Lay body text out into fixed-width columns for plain-text output.
- [log](log.md) (C) — Append a message from the tag body to a log file.
- [debug](debug.md) (C) — Writes its body to the Interchange debug log.

### Perl & code

- [perl](perl.md) (C) — Execute the tag body as embedded Perl code and return the value of its last expression.
- [calc](calc.md) (C) — Evaluate the body as Perl and return the result.
- [calcn](calcn.md) (C) — Evaluate the body as Perl and return the result, **without** interpolating the body first.
- [mvasp](mvasp.md) (C) — Run the tag body as an ASP-style embedded-Perl page, mixing literal HTML with `<% ... %>` Perl blocks.
- [child-process](child-process.md) (C) — Run the body's Interchange Tag Language (ITL) in a forked, detached child process so the current request can return without waiting for it.
- [harness](harness.md) (C) — Run a block of Interchange Tag Language (ITL) and check its output against an expected value, reporting `OK`, `NOT OK`, or `DIED`.

### Internationalization

- [loc](loc.md) (C) — Localize (translate) the body text through Interchange's locale message tables.
  - [l](l.md) — alias of [loc](loc.md)
- [msg](msg.md) (C) — Return a localized message for a key, with optional `%s`-style argument substitution.
- [parse_locale](parse_locale.md) (C) — Interpolate `[L]...[/L]` and `[LC]...[/LC]` localization markup in the tag's body, translating phrases against the active locale.
- [getlocale](getlocale.md) (S) — Extended alias: expands to `[setlocale get=1]`, returning the active locale without changing it.
- [setlocale](setlocale.md) (S) — Switch the active locale and/or currency.

### Utility & miscellaneous

- [attr_list](attr_list.md) (C) — Interpolate `{name}` placeholders in the body from a set of attributes or a Perl hash.
- [uc-attr-list](uc-attr-list.md) (C) — Interpolate `{PLACEHOLDER}` markers in the tag body from a set of named attributes or a hash reference, exactly like [attr-list](attr_list.md) but with the placeholder names written in uppercase.
- [component](component.md) (S) — Render a named page component -- a reusable fragment of Interchange Tag Language (ITL) stored in the `component` table or in a template file -- and optionally cache its rendered output.
- [control](control.md) (S) — Reads (or, with `set`, stores) one attribute of the current "control" record — the indexed set of options that drives a page [component](component.md).
- [control-set](control-set.md) (C) — Populates one control record in a single block, reading a group of `[name]value[/name]` pairs from its body.
- [counter](counter.md) (S) — Returns the next value of a persistent, named counter, incrementing it as a side effect.
  - [fcounter](fcounter.md) — alias of [counter](counter.md)
- [page-meta](page-meta.md) (S) — Load a page's stored metadata (title, description, and any other fields configured for it) into temporary scratch variables so the surrounding template can emit them.
- [rand](rand.md) (C) — Return one randomly chosen alternative from a set.
- [fortune](fortune.md) (S) — Return a random quotation by running the system `fortune` program.
- [make-password](make-password.md) (S) — Generate a random, reasonably pronounceable password string.
- [strip](strip.md) (C) — Remove leading and trailing whitespace from its body.
- [filter](filter.md) (C) — Applies one or more filters to the text between its tags.
- [html-table](html-table.md) (C) — Turn delimited text (or an array) into HTML table rows and cells.
- [title-bar](title-bar.md) (C) — Wrap its body in a single-cell colored table to make a simple heading bar.
- [tag](tag.md) (C) — Generic dispatcher for a fixed set of built-in operations, invoked as `[tag OP ...]BODY[/tag]`.
- [dump](dump.md) (S) — Print a human-readable dump of the current session, the HTTP environment, and the CGI/form variables.
- [usertrack](usertrack.md) (S) — Record a custom name/value data point into Interchange's user-tracking log for the current session.
- [flag_job](flag_job.md) (S) — Sets or clears a server-side job flag, used to coordinate background (`jobs`-group) processing.
- [forum](forum.md) (C) — Render a threaded discussion display from a `forum` database table: a post and its nested replies, formatted with customizable templates and scored so low-rated posts can be collapsed.
- [forum-userlink](forum-userlink.md) (S) — Return a display name for a discussion-forum poster.

### Deprecated & aliases

These names all resolve to a canonical tag documented above. Two kinds
exist: *pure renames*, and **extended aliases** whose definition carries
attributes — the parser substitutes the alias text into the tag source and
re-parses it, so `[evalue foo]` literally becomes
`[value keep=1 filter="encode_entities" name=foo]` (see `%Alias` and the
`Alias` handling in `lib/Vend/Parse.pm`). Extended aliases are marked below.

- [evalue](evalue.md) → [value](value.md) **(extended: presets `keep=1 filter=encode_entities`, positional → `name=`)**
- [fcounter](fcounter.md) → [counter](counter.md)
- [href](href.md) → [area](area.md)
- [getlocale](getlocale.md) → [setlocale](setlocale.md) **(extended: presets `get=1`)**
- [l](l.md) → [loc](loc.md)
- [process_search](process_search.md) → [area](area.md) **(extended: presets `href=search`)**
- [process-order](process-order.md) → [process](process.md) _(deprecated — use the canonical tag)_
- [process-target](process-target.md) → [process](process.md) _(deprecated — use the canonical tag)_
- [shipping-description](shipping-description.md) → [shipping-desc](shipping-desc.md)
- [warning](warning.md) → [warnings](warnings.md)
