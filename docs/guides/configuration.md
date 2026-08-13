# Configuration

Interchange is configured by plain-text directive files, compiled once at
server start into in-memory structures. There are two levels: one global
file for the server, and one file per catalog. This chapter covers the
model, the config-file syntax (including its here-documents, file includes,
and conditionals), Variables, and how to reconfigure a running server. The
[directive reference](../config/README.md) documents every directive
individually.

## Two levels: interchange.cfg and catalog.cfg

**`interchange.cfg`** (in the server root, `VendRoot`) configures the
daemon: sockets and process model, global code (usertags, GlobalSub
routines), trust and safety limits, and — crucially — the list of catalogs
it serves:

    Catalog  strap  /home/mark/catalogs/strap  /cgi-bin/strap

That [Catalog](../config/Catalog.md) line names the catalog, its base
directory, and the URL (`SCRIPT_NAME`) that routes requests to it (see
[Architecture](architecture.md)). There are ~112
[global directives](../config/README.md).

**`catalog.cfg`** (in each catalog's base directory) configures one store:
its databases, URLs, order processing, payment, session behavior — ~190
[catalog directives](../config/README.md). Each catalog is compiled into
its own configuration ($Vend::Cfg at request time), fully independent of
other catalogs.

Two global directives wrap every catalog's file:
[ConfigAllBefore](../config/ConfigAllBefore.md) (default
`catalog_before.cfg`) and [ConfigAllAfter](../config/ConfigAllAfter.md)
(default `catalog_after.cfg`) are read before/after each `catalog.cfg` —
the place for settings shared by all catalogs on the server.

A directive is only recognized at its own level: putting a catalog
directive in `interchange.cfg` is a startup error ("Unknown directive").
About 29 names (e.g. `Variable`, `Database`, `UserTag`, `Require`) exist at
*both* levels, sometimes with different behavior; their reference pages
document both scopes.

## File syntax

    # comment
    DirectiveName  value continues to end of line

Directive names are case-insensitive; one directive per line, leading
whitespace allowed. Values take several forms beyond the single line:

**Here-documents** for multi-line values (the marker must start the ending
line, no trailing whitespace):

    SpecialSub  <<EOR
    missing  ncheck_category
    EOR

**Read-from-file** — `<` pulls the value from a file, resolved against
[ConfigDir](../config/ConfigDir.md) (default `etc/lib`) then the current
directory:

    OrderReport  <etc/report

(A bare `Directive <` reads `ConfigDir/DirectiveName`.)

**Apache-style containers** are accepted for grouped values:

    <Locale fr_FR>
        ...
    </Locale>

**`include`** interpolates other files at that point, with shell-style
globbing and loop protection:

    include dbconf/mysql/mysql.cfg
    include usertag/*

**Conditionals** — `ifdef`/`ifndef` ... `endif` test a Variable (by
default in the current level's Variable space; prefix `@` to test the
global space from catalog.cfg). Tests may be existence, `ifdef NAME
value`, or a simple expression. Blocks cannot nest:

    ifdef MYSQL
    include dbconf/mysql/mysql.cfg
    endif

**Variable expansion in values** — off by default; after
`ParseVariables Yes`, `__NAME__` and `@@NAME@@` in subsequent directive
values are substituted:

    Variable  SERVER_NAME  www.example.com
    ParseVariables Yes
    VendURL   http://__SERVER_NAME__/cgi-bin/strap
    ParseVariables No

strap's `catalog.cfg` (`dist/strap/catalog.cfg`) exercises every one of
these forms and is the best worked example.

## Variables

[Variable](../config/Variable.md) defines simple named strings — the
workhorse of catalog customization:

    Variable COMPANY  West Branch Hardware

They appear in pages as `__COMPANY__` (catalog), `@@COMPANY@@` (global), or
`@_COMPANY_@` (catalog falling back to global), substituted before parsing
(see [Templating](templating.md)); in config files after `ParseVariables`;
and at runtime via `[var COMPANY]` or `$::Variable->{COMPANY}`. Variants:

- [DirConfig](../config/DirConfig.md) loads a whole directory of files as
  Variables — strap's `variables/` directory defines `__TOP__`,
  `__CSS__`, etc., one file each, editable without touching catalog.cfg.
- [VariableDatabase](../config/VariableDatabase.md) loads Variables from a
  database table; with `Pragma dynamic_variables` lookups happen
  per-request, so admin edits take effect without a reconfig.
- `AutoVariable` turns other directives' values into Variables.

Variable names of the form `MV_*` configure Interchange behavior itself —
see the [special variables reference](../variables/README.md).

## How values are parsed

Each directive has a *parser* that turns its text into the runtime
structure — `yesno` (`Yes`/`No`/`1`/`0`), `integer`, `time` (`30`, `5
minutes`), `array` (accumulates one entry per occurrence), `hash`
(`key value` pairs), `root_dir`/`relative_dir` (path-checked), `routine`
(compiles Perl), and some 50 more. Reference pages state each directive's
accepted syntax in words; repeated directives either *accumulate* (array
and hash types) or *replace* the prior value (scalar types) — noted per
directive. Get it wrong and the server tells you at startup with the file
and line number; configuration errors are fatal on purpose, so a typo
cannot silently run a store with defaults.

Code-bearing directives — [UserTag](../config/UserTag.md),
[GlobalSub](../config/GlobalSub.md), [CodeDef](../config/CodeDef.md),
[Sub](../config/Sub.md) — compile their Perl at config time. Global code
is full-power Perl; catalog-level code compiles into the Safe-restricted
space ([Security](security.md)). Loadable code also comes from directories:
[TagDir](../config/TagDir.md) (`code/` in the distribution) is scanned for
`*.tag`, `*.coretag`, `*.filter`, `*.widget` files at startup, and
[AccumulateCode](../config/AccumulateCode.md) defers compilation for
faster development restarts.

## Startup, reconfiguration, and debugging

At startup the server reads `interchange.cfg`, then every catalog's
(`ConfigAllBefore`, `catalog.cfg`, `ConfigAllAfter`) sequence. After that,
config is static in memory. To change it:

    bin/interchange -r                    # full restart (HUP)
    bin/interchange --reconfig=strap      # recompile one catalog, no restart
    echo "Catalog test /path /test.cgi" | bin/interchange -a   # add catalog live

Reconfiguration is picked up during the housekeeping cycle, so allow a few
seconds. The admin UI's "Apply Changes" performs the same reconfig.

Debugging aids: [DumpAllCfg](../config/DumpAllCfg.md) writes every line the
server read (includes expanded) to `RunDir/allconfigs.cfg`;
[Message](../config/Message.md) prints progress during config parsing;
[Require](../config/Require.md) / [Suggest](../config/Suggest.md) assert
that modules, usertags, or globals a catalog depends on actually exist —
`Require` aborts, `Suggest` warns. See also
[Logging and debugging](logging-debugging.md).

## See also

- [Directive reference](../config/README.md) — all directives by category
- [Catalog anatomy](catalog-anatomy.md) — where config files sit in a
  catalog and how strap organizes them
- [Architecture](architecture.md) — what the compiled config drives
