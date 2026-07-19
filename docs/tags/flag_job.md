# flag_job

Sets or clears a server-side job flag, used to coordinate background
(`jobs`-group) processing. Reach for it inside a long-running job page to signal
progress or to check/clear a job token. This is an advanced, rarely-used tag
tied to the job-server machinery.

## Syntax

    [flag_job action]
    [flag_job action token]

Standalone tag (no end tag).

## Attributes

| Attribute | Default | Description |
|-----------|---------|-------------|
| `action`  | (none)  | The job-flag action to perform. |
| `token`   | (none)  | Optional job token the action operates on. |

Positional order: `action`, `token`. This tag takes only positional parameters
(no `addAttr`).

## Description

The tag maps to an inline routine that calls
`Vend::Server::flag_job($$, $Vend::Cat, $action, $token)`, passing the current
process id and catalog name along with your `action` and `token`. The behavior
of each action is defined entirely by `flag_job` in `lib/Vend/Server.pm`; the
tag itself is a thin pass-through and returns whatever that function returns.

Job flags are part of Interchange's background job subsystem (the `jobs`
server group), which runs catalog pages out of band from normal requests. Unless
you are writing such a job page, you will not need this tag.

## Examples

Set a job flag with a token from inside a job page:

    [flag_job set [cgi jobs_token]]

Positional action only:

    [flag_job check]

## Notes

- The exact set of valid actions and their effects live in
  `Vend::Server::flag_job`; consult that routine (and your Interchange server
  configuration) before relying on specific behavior. This page documents the
  tag interface, not the full job protocol.

## See also

- Guide: [Jobs](../guides/jobs.md)

## Source

Defined in `code/SystemTag/flag_job.coretag` (inline `Routine`). Delegates to
`Vend::Server::flag_job` in `lib/Vend/Server.pm`.
