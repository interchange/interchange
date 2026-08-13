# AddDirective

Registers a new catalog configuration directive at server startup, so that
`catalog.cfg` files may use a directive name that is not built in. Reach
for it when an add-on or custom module needs its own configuration setting
without patching Interchange's source.

**Scope:** global (`interchange.cfg`)

## Syntax

    AddDirective  DirectiveName  [parser]  [default]

- `DirectiveName` -- the new directive's name.
- `parser` (optional) -- the name of a parse routine *without* the
  `parse_` prefix (for example `hash`, `yesno`, `array`). If omitted or
  given literally as `undef`, no parser runs and the raw string value is
  stored as written.
- `default` (optional) -- the directive's default value; `undef` or an
  empty value means no default.

Default: empty (no directives added).

## Description

Each `AddDirective` line appends a `[name, parser, default]` entry to the
global list `$Global::AddDirective`. That list is appended to the result
of `catalog_directives()` at runtime, so the new directive is parsed and
stored for every catalog exactly like a built-in one, reachable as
`$Vend::Cfg->{DirectiveName}`.

If you name a parser, that parse routine must already be defined when the
`AddDirective` line is read, because it cannot be referenced before it
exists. It may be one of the built-in `parse_*` routines in
`lib/Vend/Config.pm`, or one you define first as a `GlobalSub` named
`parse_<parser>`. Definitions in `interchange.cfg` must therefore appear
*before* the `AddDirective` line that uses them.

Directly editing `lib/Vend/Config.pm` to add a directive is discouraged
for upgrade portability; `AddDirective` is the supported extension point.

## Examples

Add a directive that reuses the built-in `hash` parser:

```
Require       module  Vend::Swish
Variable      swish   Vend::Swish
AddDirective  Swish   hash
```

Add a directive with a custom parser defined as a `GlobalSub`:

```
GlobalSub <<EOS
sub declare_extra_config {
	package Vend::Config;
	sub parse_docroot {
		my ($var, $value) = @_;
		unless ( -d $value ) { $@ = errmsg("Directory $value: $!") }
		if ($@) { config_warn($@) }
		return $value;
	}
}
EOS

AddDirective DocRoot docroot "/var/www"
```

Catalogs may then write, for example, `Swish key value` or
`DocRoot /srv/site` in their `catalog.cfg`.

## Notes

The built-in parser name `boolean` is a *boolean list*, not a true
boolean: it stores each listed word as a key set true in a hash, so
membership tests read as true/false. A genuine yes/no value uses the
`yesno` parser.

`DeleteDirective` is the complementary global directive that suppresses a
directive.

## See also

[DeleteDirective](DeleteDirective.md), [UserTag](UserTag.md), [CodeDef](CodeDef.md), [GlobalSub](GlobalSub.md), [Sub](Sub.md), the
[configuration](../guides/configuration.md) guide.

## Source

Parsed by `parse_directive` in `lib/Vend/Config.pm`; the accumulated list
in `$Global::AddDirective` is appended by `catalog_directives()` in the
same file.
