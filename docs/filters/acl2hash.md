# acl2hash

Converts an Interchange access-control-list (ACL) string into a Perl hash
literal, dropping any entries flagged for deletion. Used by the admin
`acl` widget.

## Syntax

    [filter acl2hash]ACL_STRING[/filter]
    [value name=field filter="acl2hash"]

`acl2hash` takes no arguments. It is a private, widget-specific filter; you
would not normally invoke it directly.

## Description

The filter turns the value submitted by the `acl` widget into the hash
form Interchange stores. It:

1. Trims leading and trailing whitespace, commas, and NUL characters.
2. Returns the value unchanged if it already looks like a hash literal
   (matches `^\{.*\}$`).
3. Otherwise parses the remaining `key=value` pairs with
   `Vend::Util::get_option_hash`.
4. Deletes any pair whose value contains the letter `d` (the "delete"
   flag), and any pair with an empty key.
5. Serializes the resulting hash with `uneval` and returns it.

If parsing yields no usable pairs, the filter returns the empty hash
literal `{}`.

This filter is specific to the ACL widget and generally should not be used
elsewhere. The widget does not require the filter to be selected in order
to operate within the [table-editor](../admin-tags/table_editor.md).

## Examples

    [filter acl2hash]a=r b=rw c=d[/filter]

produces a hash literal in which `c` has been dropped (its value `d` marks
it for deletion), for example:

    {'a' => "r",'b' => "rw",}

The order of the keys in the serialized output is not significant.

## See also

- [hash2acl](hash2acl.md)
- [acl](../widgets/acl.md) widget

## Source

Defined in `code/Filter/acl2hash.filter`. Parsing uses
`Vend::Util::get_option_hash` and serialization uses `uneval_it`, both in
`lib/Vend/Util.pm`.
