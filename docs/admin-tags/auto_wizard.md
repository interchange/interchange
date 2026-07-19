# auto_wizard

Compile and run a multi-page "wizard" (a sequence of form screens with Back,
Next, and Finish navigation) from a compact text script in the tag body. Used
by the admin UI to drive surveys and step-by-step data-entry flows built on top
of [table_editor](table_editor.md). This tag is part of the Interchange admin
UI toolset (the tags in `code/UI_Tag/`, loaded when the admin UI feature is
enabled), not a storefront tag.

## Syntax

    [auto_wizard name=survey compile=1 run=1]
    SCRIPT
    [/auto_wizard]

    [auto_wizard name=survey show=1]

Container tag (has an end tag; the body is the wizard script). The return value
is HTML for the current wizard screen.

## Attributes

| Attribute        | Default        | Description |
|------------------|----------------|-------------|
| `name`           | CGI `wizard_name` | Name the wizard is stored under in the session. |
| `compile`        | not set        | Parse the body script into the session. `compile=auto` compiles only if the named wizard is not already in the session. |
| `run`            | see below      | Render the current screen. Defaults on when neither `run` nor `show` forces otherwise. |
| `show`           | see below      | Return the built output. With `compile=auto` it defaults on. |
| `scratch`        | not set        | Store the output in this scratch variable (and return it from there) instead of a temporary. |
| `db_id`          | not set        | `table:key` of a metadata record to build the wizard from instead of an inline script. |
| `row_template`   | built-in       | HTML template for each field row. |
| `title_scratch`  | `page_title`   | Scratch variable set to the current screen's title. |
| `banner_scratch` | `page_banner`  | Scratch variable set to the current screen's title. |
| `output_type`    | `default`      | How the final screen is handled: `survey_log`, `email_only`, `auto_bounce`, or default. |
| `output_fields`  | collected fields | Whitespace-separated field names to log or email. |
| `output_email`   | not set        | Destination address for emailed survey output. |
| `email_from`, `email_cc`, `email_subject`, `email_template` | see description | Email header and body controls for survey output. |

Positional order: `name`.

The tag declares `AddAttr`, so the many presentation options consumed by the
wizard (for example `intro_text`, `thanks_title`, `thanks_message`,
`table_width`, `left_width`, and the several `*_class` cell-styling options) are
read from the options hash. See the field list at the top of the source for the
complete set.

## Description

`[auto_wizard]` has two jobs: *compile* a script into a stored wizard
definition, and *run* the stored definition one screen at a time.

The body script is a line-oriented format. A leading `name: Title` line begins
the wizard; numbered `N: Title` lines start each screen; `final: Title` marks
the closing screen; and within a screen, `field: label` lines declare form
fields, with `type:`, `opt:`, and per-field modifier syntax controlling the
widgets. Screens can carry an `itl_condition:` or `perl_condition:` that is
evaluated to skip forward or backward. The compiled definition is stored in
`session->{auto_wizard}{name}`.

At run time the tag reads the CGI variables `wizard_page` and
`ui_wizard_action` (`Back`, `Next`, `Cancel`) to decide the current screen,
then hands the assembled options to [table_editor](table_editor.md) to render
the form. When the last screen is reached, the configured `output_type` action
runs: `survey_log` appends the collected values to a log file (and optionally
emails them), `email_only` and `auto_bounce` email or redirect, and the default
action shows a completion template.

With `compile=auto`, the tag compiles the script only the first time the wizard
is seen in the session and shows the current screen thereafter, which is the
usual way to embed a self-contained wizard on a page.

## Examples

A minimal two-question survey compiled and run in one call:

    [auto_wizard name=colors compile=auto]
    colors: Quick color survey
    intro_text: Tell us your preferences.

    1: Favorites
    fav_color: Favorite color
    fav_food: Favorite food

    final: Done
    [/auto_wizard]

Show the already-built output for a wizard without re-running it:

    [auto_wizard name=colors show=1]

## Notes

This is one of the most complex tags in the admin toolset, and much of its
behavior lives in the script grammar rather than in named attributes. The
lists above cover the attributes read directly by the tag; the full set of
recognized script directives (breaks, options, per-field modifiers, `db_id`
metadata expansion) is defined by the `compile_wizard` routine in the source
and is not exhaustively restated here.

Survey output writes to `logs/survey/NAME.txt` by default (overridable via the
`SURVEY_LOG_DIR` variable or `survey_file`), and the "already completed"
guard uses the user database file-ACL functions, so repeat submissions are
suppressed for logged-in users unless `output_repeated` is set.

## See also

- [table_editor](table_editor.md)
- [email_raw](../tags/email-raw.md)
- Concepts: [forms](../guides/forms.md), [admin UI](../guides/admin-ui.md)

## Source

Defined in `code/UI_Tag/auto_wizard.coretag` (registered as the tag
`auto-wizard`; ITL treats hyphen and underscore in tag names as equivalent).
Implemented by the inline Routine in that file, whose helpers include
`compile_wizard`, `wizard_url`, and the `survey_action` / `survey_genfinal`
dispatch tables.
