# AccumulateCode

Fetches Interchange tag and code definitions on demand from a
`CodeRepository` instead of loading everything at startup, copying each
used piece into an accumulated directory as it is needed. Reach for it
during development to shorten startup time and shrink the memory
footprint.

**Scope:** global (`interchange.cfg`)

## Syntax

    AccumulateCode  Yes|No

A yes/no boolean (`yes`/`no`, `true`/`false`, `1`/`0`, `on`/`off`,
case-insensitive). Default: `No`.

## Description

With `AccumulateCode` on, when a page needs a tag, filter, widget, or
other code block that is not yet present in the running server,
Interchange copies the definition from the configured `CodeRepository`
into `$Global::TagDir/Accumulated/` and activates it immediately. On the
next restart the block is found in the accumulated directory and loaded
normally, so it is not fetched again.

Over time, as pages and routines are exercised, the accumulated directory
fills with the full set of code a catalog actually uses. At that point you
can turn `AccumulateCode` off and ship only what is needed.

The lookup is consulted from the tag parser and related code loaders
(`lib/Vend/Parse.pm`, `lib/Vend/Util.pm`, `lib/Vend/Form.pm`) whenever a
requested routine is not already defined.

## Examples

Enable on-demand code loading in `interchange.cfg`:

```
CodeRepository  /usr/lib/interchange/code
AccumulateCode  Yes
```

## Notes

`AccumulateCode` is intended for development. Turn it off in production:
a production server should start with exactly the code it needs, and the
on-demand copy adds first-hit latency and filesystem writes you do not
want under load. See `CodeRepository` for the full discussion of the
repository layout.

## See also

[CodeRepository](CodeRepository.md), [TagDir](TagDir.md), [UserTag](UserTag.md), [CodeDef](CodeDef.md).

## Source

Parsed by `parse_yesno` in `lib/Vend/Config.pm`; consumed via
`$Global::AccumulateCode` in `lib/Vend/Parse.pm`, `lib/Vend/Util.pm`,
and `lib/Vend/Form.pm`.
