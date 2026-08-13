# DowncaseVarname

Forces the names of selected incoming CGI variables to lowercase as requests are
parsed. Reach for it when a client or gateway may submit a form field or query
parameter under an inconsistent letter case and you need it normalized before
Interchange looks it up.

**Scope:** global (`interchange.cfg`)

## Syntax

    DowncaseVarname  name ...

The raw value is stored as a single string (no list parser is run). At request
time each incoming variable name is lowercased when the name appears in this
string, matched on word boundaries and case-insensitively. In practice you
write a whitespace-separated list of variable names. Default: empty (no names
are downcased).

## Description

While parsing a GET or POST request, Interchange checks each incoming variable
name against `DowncaseVarname`. If the configured string contains that name (as
a whole word, ignoring case), the incoming key is converted to lowercase before
any variable-name mapping and before the value is stored
(`lib/Vend/Server.pm`, `store_cgi_kv` and the query-string parser).

Only the variable name is affected; values are never altered. Names not listed
are passed through with their original case.

## Examples

Normalize the case of two fields in `interchange.cfg`:

```
DowncaseVarname mv_todo mv_click
```

A request arriving with `MV_TODO=refresh` is then stored under the key
`mv_todo`.

## Notes

Because the value is matched as a regular word-boundary substring rather than
parsed into a list, entries are simply separated by whitespace; there is no
support for wildcards. A variable name is downcased whenever it appears anywhere
in the configured string as a whole word.

## See also

[VarName](VarName.md), [Variable](Variable.md), the
[forms](../guides/forms.md) guide.

## Source

Stored as a raw string (no parser) from `global_directives()` in
`lib/Vend/Config.pm`; consumed in `lib/Vend/Server.pm`
(`$Global::DowncaseVarname`).
