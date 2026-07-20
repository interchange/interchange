# if

Conditionally includes or excludes a block of a page based on a test against
an Interchange value — a form value, session flag, scratch variable, database
field, file test, cart contents, and more. It is the primary branching
construct of the Interchange Tag Language (ITL); reach for it whenever page
output should depend on the current state.

## Syntax

    [if type term]BODY[/if]
    [if type term op compare]BODY[/if]
    [if !type term op compare]BODY[/if]
    [if type="type" term="field" op="op" compare="value"]BODY[/if]

Container tag (has an end tag). The body may include the optional sub-blocks
[then](else.md), [elsif](elsif.md), [else](else.md), and the conditional-join
tags [and](and.md) and [or](or.md):

    [if type term op compare]
    [then]  output when the test is true  [/then]
    [elsif type term op compare]  tested only if the [if] failed  [/elsif]
    [else]  output when everything above failed  [/else]
    [/if]

The selected branch is re-interpolated (reparsed) by default, so ITL inside
the chosen branch runs.

## Attributes

| Attribute | Default | Description |
|-----------|---------|-------------|
| `type`    | (none)  | The kind of thing to test (see the test-type list below). |
| `term`    | (none)  | What to look up within that type (a field name, key, etc.). |
| `op`      | (none)  | Comparison operator; omit to test the value for truth. |
| `compare` | (none)  | Right-hand side of the comparison. |

Positional order: `type`, `term`, `op`, `compare`.

Aliases: `base` for `type`; `comp` and `condition` for `compare`; `operator`
for `op`. Any of the Perl comparison operators (`eq`, `ne`, `lt`, `gt`,
`le`, `ge`, `==`, `!=`, `<`, `>`, `<=`, `>=`, `=~`, `!~`) may also be written
in place — Interchange treats them as an implicit `op` so
`[if value name =~ /^A/]` parses correctly.

## Description

The first word after `[if` is the *type*, which selects where the *term* is
looked up. With no *op*/*compare*, the tag tests the looked-up value for Perl
truth (non-empty and not `0`). With an *op* and *compare*, it compares the
value against *compare*.

### Negation

Prefix the type with `!` to reverse the sense of the test:

    [if !value fname]No first name was entered.[/if]

`[if !type ...]` is exactly `[unless type ...]` (see [unless](unless.md)).

### Comparison operators

The string and numeric operators behave as in Perl:

    ==  numeric equal        eq  string equal
    !=  numeric not-equal     ne  string not-equal
    >   numeric greater       gt  string greater
    <   numeric less          lt  string less
    >=  numeric ge            ge  string ge
    <=  numeric le            le  string le
    =~  regex match          !~  regex non-match

Two further operators are recognized in the `op` position:

- `length` (alias `len`) — true when the value's length falls in a
  `min-max` range, e.g. `[if value zip length 5-10]`.
- `filter` — true when applying the named filter leaves the value unchanged,
  e.g. `[if value acct filter digits]` (true when `acct` is all digits).

### Test types

Except for `explicit`, `file`, `validcc`, `items`, and `ordered`, each type
looks up `term` in a particular Interchange namespace and returns its value
for comparison:

| Type | Looks up |
|------|----------|
| `value` (alias `evalue`) | A user form value, `$Values->{term}`. |
| `cgi` | A raw CGI variable, `$CGI::values{term}`. |
| `session` | A session variable, `$Session->{term}` (e.g. `logged_in`, `secure`, `browser`). |
| `scratch` | A scratch variable, `$Scratch->{term}`. |
| `scratchd` | Same as `scratch`, but deletes the scratch key after testing. |
| `tmp` | A temporary (`[tmp]`/`[tmpn]`) variable. |
| `variable` (alias `var`) | A catalog Variable, `$Variable->{term}`. |
| `global` | A global Variable, `$Global::Variable->{term}`. |
| `pragma` | A pragma setting, `$Pragma->{term}`. |
| `config` | A configuration directive, `$Vend::Cfg->{term}` (nested with `::`). |
| `data` | A database field: `term` is `table::column::key`. |
| `field` | A `products` field: `term` is `column::key`. |
| `discount` | Whether a discount exists for the item code in `term`. |
| `ordered` | Order status of an item; `[if ordered code cart attribute]`. |
| `items` | Number of items in a cart (`term` names the cart; default main). |
| `errors` / `warnings` | Count of session errors/warnings (all, or for `term`). |
| `file` | A file test on the path in `term` (see below). |
| `validcc` | `[if validcc number type exp_date]` — Luhn credit-card check. |
| `accessor` | Whether `term` is an accessory/modifier value. |
| `control` | A value in the current `[control]` block. |
| `env` | An environment variable. |
| `module-version` | The `$VERSION` of the Perl module named in `term`. |
| `explicit` | Evaluate arbitrary Perl (see below). |

A bare type with no match in this list is treated as a literal: `[if term]`
tests whether the literal string `term` is true, which is rarely what you
want — always name a type.

### File tests

`[if file PATH]` is true when `PATH` exists as a plain file (Perl's `-f`).
Append a single-letter Perl file-test operator for other checks:
`file-e` (exists), `file-d` (directory), `file-r` (readable),
`file-w` (writable), `file-x` (executable), `file-l` (symlink),
`file-s` (size), `file-M` (age in days modified), `file-A` (age accessed),
`file-T` (text), `file-B` (binary). `file-s`, `file-M`, and `file-A` return a
number you can compare:

    [if file-M error.log > 1]No errors logged in over a day.[/if]

### Explicit Perl tests

`[if explicit]` evaluates Perl and uses its return value as the condition.
Put the code either in a `[condition]...[/condition]` block inside the body,
or in the `compare` attribute:

    [if explicit]
    [condition]
        return 1 if '[value country]' =~ /^u\.?s\.?a?$/i;
        return 0;
    [/condition]
    You entered a US address.
    [else]
    You entered a non-US address.
    [/else]
    [/if]

The Perl runs in the catalog's Safe compartment. Because `compare` and
`[condition]` are evaluated as code, never interpolate raw user input into
them without quoting — a value beginning with `0` (like `0009`) is read as an
invalid octal and logs a `Bad if` error, and hostile input could inject code.
Wrap interpolated data in `q{...}` or a [filter](filter.md).

### [and] and [or]

Simple conjunctions are written as standalone [and](and.md) / [or](or.md)
tags immediately inside the `[if]` body. Each adds one more test that is
chained (short-circuit) with the preceding result:

    [if value name =~ /Mike/]
    [or value name =~ /Jean/]
    Your name is Mike or Jean.
    [/if]

For anything more elaborate, use `[if explicit]` or embedded Perl.

### [then], [elsif], [else]

`[then]...[/then]` is optional; the text between `[if ...]` and the first
sub-block is the "true" branch. Use an explicit `[then]` when nesting `[if]`
tags so Interchange can tell the branches apart. `[elsif]` blocks are tested
in order only after the `[if]` test fails; `[else]` is emitted when the
`[if]` and every `[elsif]` fail.

## Examples

Show a message only when the cart holds something (uses the strap main cart):

    [if items]You have [nitems] item(s) in your cart.[/if]

Greet a user by their entered first name, or prompt for it:

    [if value fname]
    Hello, [value fname]!
    [else]
    Please tell us your name.
    [/else]
    [/if]

Branch on a database field. This reads the `inventory` table from the strap
demo and warns when SKU `os28005` is out of stock:

    [if type=data term=inventory::quantity::os28005 op=<= compare=0]
    Sorry, this item is currently out of stock.
    [else]
    In stock.
    [/else]
    [/if]

Test a session flag set at login:

    [if session logged_in]
    Welcome back, [value fname].
    [else]
    <a href="[area login]">Sign in</a>
    [/else]
    [/if]

Chain two tests with `[and]`:

    [if value fname]
    [and value lname]
    Full name: [value fname] [value lname]
    [else]
    Please enter both your first and last name.
    [/else]
    [/if]

## Notes

`[if]` invalidates page caching, since its output depends on request state.

Named-attribute syntax is required when a comparison value itself contains
ITL: `[if value name =~ /[value b_name]/]` misparses, but
`[if type=value term=name op="=~" compare="/[value b_name]/"]` works. An
explicit test is usually clearer still.

An `op` written as `operator.tagname` runs the named tag on `compare` before
comparing — an advanced, rarely needed form.

## See also

[unless](unless.md), [and](and.md), [or](or.md), [else](else.md),
[elsif](elsif.md), [value](value.md), [data](data.md), [field](field.md),
[calc](calc.md), [perl](perl.md); the
[templating](../guides/templating.md) guide.

## Source

`[if]` is a parser built-in defined in `lib/Vend/Parse.pm` (`%Routine`,
mapped to `Vend::Interpolate::tag_self_contained_if`; the positional/embedded
form uses `Vend::Interpolate::tag_if`). The test logic and comparison
operators (`%cond_op`, `%file_op`) live in `Vend::Interpolate::conditional`
in `lib/Vend/Interpolate.pm`.
