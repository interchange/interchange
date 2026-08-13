# file_navigator

Render an interactive file browser for the catalog directory tree: a list of
files and folders with links to upload, download, view, edit, and delete
them, plus a text/filename search. It is part of the administrative UI
toolset (loaded only when the admin UI is enabled), not a storefront tag; it
powers the admin file manager.

## Syntax

    [file_navigator]
    [file_navigator initial_dir="logs/survey" no_up=1 edit_only=1]

Standalone tag that emits HTML.

## Attributes

| Attribute       | Default | Description |
|-----------------|---------|-------------|
| `initial_dir`   |         | Directory to start in; also stored as the session's current directory. |
| `top_of_tree`   | `.`     | Highest directory the "parent" link will ascend to. |
| `no_up`         |         | Suppress the "parent directory" link. |
| `no_new_file`   |         | Suppress the "(new file)" upload entry. |
| `no_dirs`       |         | Do not list subdirectories. |
| `edit_only`     |         | Show edit links only for `.htm`/`.html` files. |
| `edit_all`      |         | Show edit links for every file. |
| `edit_page`     | `content_editor` | Admin page used for the edit link. |
| `edit_form`     | `ui_name=~FN~&ui_type=page` | Query string for the edit link. |
| `view_href`     | `<admin>/do_view` | Admin page used for the view link. |
| `view_form`     | `mv_arg=~FN~` | Query string for the view link. |
| `base_url`      | UI base (`admin`) | Base admin path for the generated links. |
| `details`       | session/CGI | If true, show a permissions/owner/date detail line per file. |
| `template`      |         | Wrapper applied to each row (`%s` is the row HTML). |
| `parent_directory_message` | `parent directory` | Label for the up link. |

Positional order: a directory `mask` is accepted as the first parameter but
is **ignored** — see Notes.

## Description

The tag lists the current directory (tracked per session as `ui_cwd`) and
returns an HTML block: one line per entry, with small icon links. For files
the links are download, optional delete, upload-over, view, and edit; for
directories the link changes into that directory. A "(new file)" row and a
"parent directory" row are added unless suppressed.

Navigation and actions are driven by CGI parameters the generated links set:
`action=chdir` with a `dir` changes directory (validated against Interchange's
file-access rules), and `action=find` runs a search. The search matches
either file names or file contents (regular expression) under the current
directory, skipping `session`/`tmp` and refusing files over a megabyte.

Delete links are only rendered when the current admin user passes an
[if_mm](if_mm.md) permission check (`advanced`, `delete_files`), so the file
manager respects UI access control.

With `details` on, each row gains a `ls -l`-style line: permission string,
owner, group, and modification time.

## Examples

A minimal file browser rooted at a specific log directory, with no parent
link and no new-file row:

    [file_navigator initial_dir="logs/survey" no_up=1 no_new_file=1]

An HTML-page editor view that lists only editable pages and wraps each row
in a table cell:

    [file_navigator
        edit_only=1
        template="<tr><td>%s</td></tr>"]

## Notes

- The positional directory mask is overwritten with `*` at the top of the
  routine, so passing a mask has no effect; scope the listing with
  `initial_dir` / `top_of_tree` instead. This is a quirk of the current
  implementation.
- The generated markup uses admin icon images (`up.gif`, `folder.gif`, and
  so on) that ship with the admin UI, so the tag is really only meaningful
  inside the admin.

## See also

- [file_info](file_info.md) — details about a single file
- [if_mm](if_mm.md) — the permission checks gating delete links
- The [admin UI guide](../guides/admin-ui.md)

## Source

Defined in `code/UI_Tag/file_navigator.coretag`. Implemented by the inline
Routine in that file.
