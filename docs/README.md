# Interchange Documentation

Comprehensive developer documentation for [Interchange](https://www.interchangecommerce.org/),
the Perl web application server, electronic catalog, and database display
system. This documentation targets the current source tree; it consolidates
and supersedes the historic MiniVend manual, the Akopia-era SDF manuals, and
the xmldocs project.

## Guides

Read in order for a ground-up introduction, or jump to the topic you need.

### Getting started
- [Introduction](guides/introduction.md) — what Interchange is, history, capability tour
- [Architecture](guides/architecture.md) — server model, request lifecycle, link programs
- [Installation](guides/installation.md) — installing, `makecat`, web server wiring
- [Catalog-building tutorial](guides/tutorial.md) — build a working store step by step
- [Catalog anatomy](guides/catalog-anatomy.md) — guided tour of a catalog via the strap demo

### Core concepts
- [Configuration](guides/configuration.md) — `interchange.cfg` vs `catalog.cfg`, Variables, parsing
- [Templating with ITL](guides/templating.md) — the Interchange Tag Language: interpolation, loops, prefixes
- [Embedded Perl](guides/perl-embedding.md) — `[perl]`, `[calc]`, GlobalSub, ActionMap, the Safe model
- [Databases](guides/databases.md) — the data layer: DBM and SQL tables, import/export
- [Sessions](guides/sessions.md) — session data, scratch space, cookies, storage backends

### Building a store
- [Forms and user input](guides/forms.md)
- [The search engine](guides/search.md)
- [Carts, order process, and checkout](guides/cart-and-checkout.md)
- [Product pricing and discounts](guides/pricing.md)
- [Shipping](guides/shipping.md)
- [Sales tax](guides/taxes.md)
- [Payment processing](guides/payments.md)
- [User accounts (UserDB)](guides/user-database.md)
- [Internationalization](guides/internationalization.md)

### Operations
- [The admin interface](guides/admin-ui.md)
- [Scheduled jobs](guides/jobs.md)
- [Sending email](guides/email.md)
- [Security](guides/security.md)
- [Logging and debugging](guides/logging-debugging.md)
- [Performance and optimization](guides/performance.md)
- [Upgrading](guides/upgrading.md)

### Help
- [HOWTO recipes](guides/howtos.md)
- [FAQ](guides/faq.md)
- [Glossary](glossary.md)

## Reference

- [Configuration directives](config/README.md) — every `interchange.cfg` and `catalog.cfg` directive
- [Tags](tags/README.md) — the ITL tag reference (system and user tags)
- [Admin UI tags](admin-tags/README.md) — tags used by the back-office interface
- [Filters](filters/README.md) — value/output filters
- [Widgets](widgets/README.md) — form input widgets
- [Order checks](order-checks/README.md) — order profile validation routines
- [Payment gateways](payments/README.md) — `Vend::Payment::*` gateway modules
- [Pragmas](pragmas/README.md) — per-page/per-catalog behavior switches
- [Special variables](variables/README.md) — `MV_*` and `mv_*` variable namespaces

## Conventions

Examples use the **strap** demo catalog (`dist/strap/` in the source tree,
installed via `bin/makecat`) and its sample data, so you can paste and run
them. Configuration examples state whether they belong in `interchange.cfg`
(global) or `catalog.cfg` (per catalog).
