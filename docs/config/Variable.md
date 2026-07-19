# Variable

Defines a named Interchange variable holding a piece of text -- a URL, an
email address, a snippet of HTML, a configuration flag. Reach for it to keep
values you reuse across pages (or that control Interchange behavior, the
`MV_*` variables) in one place.

**Scope:** both (`interchange.cfg` global, `catalog.cfg` catalog)

## Syntax

    Variable  NAME  value

`parse_variable` splits on the first whitespace: everything before it is the
variable name, everything after (with the trailing newline stripped) is the
value. The value may contain spaces and, in `catalog.cfg`, may span multiple
lines with a here-document. Default: empty.

Variable names are case sensitive and may contain only word characters
(`A-Z`, `a-z`, `0-9`, `_`).

## Description

A `Variable` line stores `value` under `NAME`. Where it is stored, and how
you read it back, depends on scope.

Three literal substitution forms are expanded on a page *before* ITL tag
processing (in `vars_and_comments`, `lib/Vend/Interpolate.pm`):

- `__NAME__` -- catalog variable only (`$Variable`).
- `@@NAME@@` -- global variable only (`$Global::Variable`).
- `@_NAME_@` -- catalog variable, falling back to the global if unset.

You can also read a variable with the [var](../tags/var.md) tag, which is
processed together with the other ITL tags rather than in the pre-pass.

### Global

Defined in `interchange.cfg`, a variable goes into `$Global::Variable` and is
readable as `@@NAME@@` from any catalog on the server.

### Catalog

Defined in `catalog.cfg`, a variable goes into the catalog's own `Variable`
hash and is readable as `__NAME__`. Certain uppercase `MV_*` catalog
variables configure Interchange itself -- for example `MV_UTF8` and
`MV_HTTP_CHARSET` select character handling.

## Examples

A catalog variable for a contact address (in `catalog.cfg`):

```
Variable  EMAIL  orders@example.com
```

Used on a page:

```
Contact us at __EMAIL__
```

produces:

    Contact us at orders@example.com

A global variable in `interchange.cfg`, read from any catalog with the
`@@...@@` form:

```
Variable  TRAFFIC  low
```

```
Server traffic mode: @@TRAFFIC@@
```

A configuration variable that changes Interchange behavior:

```
Variable  MV_UTF8  1
```

## Notes

Variable names do **not** have to begin with a capital letter, though
writing them in all uppercase is common practice (and required-looking
because the shipped `MV_*` variables are uppercase). The `@@NAME@@` and
`@_NAME_@` forms require a name of at least three characters; `__NAME__`
accepts two or more. Because the `__NAME__`/`@@NAME@@` forms are substituted
before tags run, they cannot see values that are only set later during tag
processing -- use the [var](../tags/var.md) tag for those.

## See also

[var](../tags/var.md), [VariableDatabase](VariableDatabase.md),
[VarName](VarName.md), [AutoVariable](AutoVariable.md),
[ScratchDefault](ScratchDefault.md), the
[configuration](../guides/configuration.md) and
[templating](../guides/templating.md) guides.

## Source

Parsed by `parse_variable` in `lib/Vend/Config.pm` (stored in
`$C->{Variable}` for catalogs or `$Global::Variable` globally); the
`__VAR__`/`@@VAR@@`/`@_VAR_@` forms are expanded in `vars_and_comments`
(`lib/Vend/Interpolate.pm`).
