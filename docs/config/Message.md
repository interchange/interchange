# Message

Prints a message to the console and the Interchange log while configuration is
being read. Reach for it to mark progress or announce which branch of a
conditional configuration block was taken during startup.

**Scope:** both (`interchange.cfg` and `catalog.cfg`)

## Syntax

    Message  [-n] [-i] text

The message text (`parse_message`). Two leading option flags are recognized:

- `-n` -- strip trailing whitespace from the text before it is logged.
- `-i` -- info-only: print the message to the console but do not write it to
  the log, and only when Interchange is running in the foreground.

Default: empty (no message).

## Description

`Message` is evaluated the moment the directive line is read while parsing the
configuration, not at runtime. Its purpose is diagnostic output during startup
and reconfiguration. The text is emitted with [logGlobal](../tags/log.md) at
`info` level so it appears both on the console (when Interchange runs in the
foreground) and in the global log.

The flags are parsed off the front of the value in `parse_message` in
`lib/Vend/Config.pm`. With `-i` and Interchange running in the foreground, the
message is printed directly to the console and the log write is skipped. When
`$Vend::Quiet` is in effect the directive is silently ignored.

Because it fires during config parsing, `Message` is especially useful inside
`ifdef`/`endif` conditional blocks to report which configuration path was
chosen.

The behavior is identical in global and catalog scope; only the log/console the
message reaches differs by context.

## Examples

Announce a traffic-tuning branch in `interchange.cfg`:

```
ifdef TRAFFIC =~ /low/i
Message Low traffic settings.
HouseKeeping 3
endif
```

Print an info-only, whitespace-trimmed notice to the console when loading the
admin UI:

```
Message -i -n Calling UI...
```

## See also

[log](../tags/log.md), [DisplayErrors](DisplayErrors.md),
[Suggest](Suggest.md), [Require](Require.md), the
[configuration](../guides/configuration.md) guide.

## Source

Parsed by `parse_message` in `lib/Vend/Config.pm`, which emits the text at
parse time via `logGlobal` (`lib/Vend/Util.pm`). Registered in both
`global_directives()` and `catalog_directives()`.
