# Introduction

Interchange is a web application server, electronic catalog, and database
display system written in Perl, built for running online stores. It is one
of the longest-lived open-source e-commerce platforms: Andrew Wilcox's Vend
(1995) became Mike Heins's MiniVend, which merged with Akopia's Tallyman to
become Interchange in 2000; it has been maintained by the Interchange
Development Group ever since, under the GPL (version 2).

This documentation is the first comprehensive, single-source manual for
the full system: guides that teach the concepts in order, and reference
pages for every configuration directive, tag, filter, widget, order check,
and payment module in the current source tree.

## What Interchange does

Out of the box, one Interchange server gives you:

- **A catalog engine** — pages templated in the
  [Interchange Tag Language](templating.md) over
  [DBM or SQL databases](databases.md) (MySQL, PostgreSQL, SQLite, and
  anything with a DBD driver), with a built-in
  [search engine](search.md), product options and variants, and
  category/navigation machinery.
- **Commerce** — [carts and a configurable order process](cart-and-checkout.md)
  with validation profiles and order routes;
  [pricing](pricing.md) with quantity/group discounts;
  [shipping](shipping.md) with carrier rate lookups; [taxes](taxes.md)
  including tax-service integrations;
  [payment processing](payments.md) through 20+ gateway modules;
  [customer accounts](user-database.md); gift certificates and
  affiliate tracking.
- **Operations** — a web-based [administration interface](admin-ui.md)
  with table editing, content editing, and permissions;
  [sessions](sessions.md) with pluggable storage;
  [internationalization](internationalization.md);
  [scheduled jobs](jobs.md); [email](email.md); logging and usage
  tracking.
- **Multi-store hosting** — one daemon serves any number of independent
  catalogs ([Architecture](architecture.md)).

The design premise, inherited from MiniVend, is that a working store is
*configuration plus templates, not application code*: directives declare
the store's behavior, ITL pages present it, and Perl is available — inside
a [restricted compartment](security.md) — when you need custom logic
([Embedded Perl](perl-embedding.md)).

## What Interchange is not

Interchange predates, and does not follow, the MVC-framework style of
modern web development. There is no ORM, no routing DSL, no REST API out
of the box; pages, actions, and configuration are the interfaces. It runs
as its own persistent daemon behind your web server rather than inside a
PSGI/Plack stack. Teams maintaining Interchange stores should expect a
system with deep, stable conventions of its own — this manual's job is to
make those conventions plain.

## How to read this documentation

New to Interchange:

1. [Architecture](architecture.md) — the server model and request
   lifecycle; the vocabulary everything else uses.
2. [Installation](installation.md) — get a server and the strap demo
   running.
3. [Catalog-building tutorial](tutorial.md) — build a store step by step.
4. [Catalog anatomy](catalog-anatomy.md) — map what the demo gave you.
5. [Configuration](configuration.md) and [Templating](templating.md) —
   the two core skills.

Maintaining an existing store: start with
[Catalog anatomy](catalog-anatomy.md) and the
[reference sections](../README.md#reference), and see
[Upgrading](upgrading.md) for version changes. The
[glossary](../glossary.md) decodes the system's jargon (flypage, scratch,
route, pragma, ...), and the [FAQ](faq.md) answers the classics.

## Requirements at a glance

Perl 5.16.3+ on a Unix-like OS (Linux distributions primarily; also the
BSDs and macOS), a web server for the front end, and optionally an SQL
database — some features (notably admin reporting) expect one. Perl module
dependencies install with `cpanm --installdeps .` from the source tree.
Details: [Installation](installation.md).

## Project resources

- Website and demo: https://www.interchangecommerce.org/
- Source: https://github.com/interchange/interchange
- Historic documentation this manual supersedes: the MiniVend manual, the
  Akopia-era SDF manuals (`interchange/docs`), and the xmldocs project
  (`interchange/xmldocs`) — see [Upgrading](upgrading.md) when working
  with older material, and trust the current reference pages over old
  sources where they differ.
