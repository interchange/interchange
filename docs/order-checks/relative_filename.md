# relative_filename

Checks that a field's value is safe to use as a relative filename -- neither
an absolute path nor a `.`/`..` traversal reference.

## Syntax

    FIELD=relative_filename [message]

Used as the check name in an order-profile line. There is no shipped strap
demo profile using `relative_filename`; a minimal example against an
uploaded-file-destination field:

    upload_name=relative_filename Please enter a valid relative file name.

## Description

The value passes if it contains at least one non-whitespace character, is
not exactly `.` or `..`, and `Vend::File::absolute_or_relative` reports it
as neither an absolute path nor a path containing `../`/`..\` traversal
segments. This check exists to validate merchant-supplied paths (for
example, a destination for an admin file operation or an uploaded file
name) before they are used to build a real filesystem path. If no custom
`message` is given, the failure text is `filename not relative`.

## Examples

Reject an unsafe path before writing an uploaded file:

    upload_name=relative_filename

Require it with a custom message:

    template_file=relative_filename Please choose a file within the catalog directory.

## See also

[regex](regex.md), [error](../tags/error.md),
[OrderProfile](../config/OrderProfile.md),
the [cart and checkout](../guides/cart-and-checkout.md) guide.

## Source

Defined in `code/OrderCheck/relative_filename.oc`. The routine takes
`($ref, $name, $value, $code)` and tests the value with
`Vend::File::absolute_or_relative` (`lib/Vend/File.pm`).
