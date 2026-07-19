# hash2acl

Serializes an option-hash string into an Interchange ACL string
(`key=value,key=value`); the inverse of [acl2hash](acl2hash.md). Used
internally by the ACL widget.

## Syntax

    [value name=field filter="hash2acl"]
    [filter hash2acl]TEXT[/filter]

## Description

The filter takes an option-hash representation, parses it with
`Vend::Util::get_option_hash`, and re-emits it as a flat, comma-separated
`key=value` list with keys sorted. During emission each key has its literal
commas and equals signs encoded as numeric HTML entities (`,` → `&#44;`,
`=` → `&#61;`) so they do not collide with the list delimiters.

Processing details, straight from the code:

- Leading and trailing whitespace and any NUL (`\0`) characters are stripped
  from the input first.
- If `get_option_hash` cannot parse the input into a hash, the *original*
  input (before trimming) is returned unchanged.
- Keys are output in sorted order.

This filter is specific to the ACL widget and the
[table-editor](../admin-tags/table-editor.md); it is marked `Visibility
private` and is not normally used by hand. It does not need to be selected
explicitly for the widget to work.

## Examples

Given an option-hash string, hash2acl produces a sorted ACL string:

    [filter hash2acl]edit=1 view=1[/filter]

produces (keys sorted):

    edit=1,view=1

## See also

- [acl2hash](acl2hash.md)
- [acl (widget)](../widgets/acl.md)
- [table-editor](../admin-tags/table-editor.md)

## Source

Defined in `code/Filter/hash2acl.filter`; the routine calls
`Vend::Util::get_option_hash` in `lib/Vend/Util.pm`.
