# Accounting

Configures the pluggable accounting back end that Interchange calls when
customer and order data should be pushed into external accounting software
(for example SQL-Ledger). Reach for it when you want account creation and
order posting mirrored into a general-ledger system.

**Scope:** catalog (`catalog.cfg`)

## Syntax

    Accounting  name  key value [key value ...]

The value is parsed like a `Locale`: the first token is a name for the
setting group and the remaining tokens are shell-quoted `key value` pairs
merged into a hash. Interchange exposes that hash as
`$Vend::Cfg->{Accounting}`. The key `Class` must give the Perl class of
the accounting interface module. Default: empty (no accounting back end).

## Description

When `$Vend::Cfg->{Accounting}` is set, the user-database and order code
(`lib/Vend/UserDB.pm`, `lib/Vend/UserControl.pm`) instantiate the class
named by its `Class` key and hand it customer data. The accounting module
must be a subclass of `Vend::Accounting` living under
`lib/Vend/Accounting/` -- for example
`lib/Vend/Accounting/SQL_Ledger.pm` provides
`Vend::Accounting::SQL_Ledger`. Every key/value pair you set is copied
into the module's configuration hash, so module-specific options (such as
`link_table` or `counter` for SQL-Ledger) are set the same way as `Class`.

## Examples

Configure the SQL-Ledger back end (in `catalog.cfg`):

```
Accounting sql Class Vend::Accounting::SQL_Ledger assign_username 0
```

This makes `$Config->{Accounting}{Class}` equal
`Vend::Accounting::SQL_Ledger`, which is exactly what the admin accounting
page tests for.

## Notes

Because the directive uses the `Locale` parser, all the key/value pairs
that make up one accounting configuration must be given with a leading
group name on a single logical line (a here-document works). Older
documentation showed a name-less, one-key-per-line form
(`Accounting Class ...` then `Accounting assign_username ...`); with the
current parser each such line replaces the stored hash with a group named
after its first token, so `Class` would not survive as a key. Use the
single grouped form shown above.

To see which accounting modules ship with your installation, list
`lib/Vend/Accounting/` in the Interchange source tree.

## See also

[UserDB](UserDB.md), the [user-database](../guides/user-database.md) and
[payments](../guides/payments.md) guides.

## Source

Parsed by `parse_locale` in `lib/Vend/Config.pm`; consumed via
`$Vend::Cfg->{Accounting}` in `lib/Vend/UserDB.pm`,
`lib/Vend/UserControl.pm`, and the `Vend::Accounting` subclasses under
`lib/Vend/Accounting/`.
