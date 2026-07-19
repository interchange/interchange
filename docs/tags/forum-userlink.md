# forum-userlink

Return a display name for a discussion-forum poster. Given a username (and
whether the post was anonymous), it resolves the friendliest available label —
a user-database handle, a first name, the raw username, or an anonymous
fallback. It is the helper [forum](forum.md) uses to label each post, exposed as
a tag you can call yourself.

## Syntax

    [forum-userlink username=joe]
    [forum-userlink name="Guest" anon=1]

Standalone tag (no end tag). Returns the resolved display name.

## Attributes

| Attribute  | Default | Description |
|------------|---------|-------------|
| `username` | none    | Login/user key to look up in the `userdb` table. |
| `name`     | none    | Name to show for an anonymous or usernameless poster. |
| `anon`     | none    | If true, treat the poster as anonymous. |

Positional order: none (`PosNumber 0`). The tag declares `addAttr`, so it
receives all attributes as one hash — the same shape as a forum row record.

## Description

The tag decides the display name as follows:

1. If `anon` is true, or no `username` is given, it returns `name` if provided,
   otherwise the `FORUM_ANON_NAME` catalog variable, otherwise the literal
   `Anonymous Coward`.
2. Otherwise it looks up the `userdb` table for that `username`: first the
   `handle` column, then the `fname` column. It returns the first non-empty one,
   falling back to the raw `username` if neither is set.

Because [forum](forum.md) passes each thread record straight to this routine,
the record's `username`, `name`, and `anon` members line up with the tag's
attributes. Called on its own, supply those attributes explicitly.

## Examples

Show the handle (or name) for a known user:

    Posted by [forum-userlink username=joe]

If `joe`'s `userdb` `handle` is `Joe D.`, this returns:

    Posted by Joe D.

An anonymous poster falls back to the configured anonymous name:

    [forum-userlink anon=1]

returns the `FORUM_ANON_NAME` variable, or `Anonymous Coward` if that variable
is unset.

## See also

- [forum](forum.md), [userdb](userdb.md), [data](data.md)
- Concepts: [user database](../guides/user-database.md)

## Source

Defined in `code/UserTag/forum.tag` as an inline Routine, alongside the
[forum](forum.md) tag.
