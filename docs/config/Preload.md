# Preload

Names routines to run at the very start of every request, before session,
path, robot, and cookie handling. Reach for it when you must influence those
early decisions -- for example to skip session creation for some URLs.

**Scope:** catalog (`catalog.cfg`)

## Syntax

    Preload  name ...
    Preload  <<EOR
    sub { ... }
    EOR

A comma- or whitespace-separated list of [GlobalSub](GlobalSub.md) or
[Sub](Sub.md) names, or a single inline `sub { ... }` block. Entries
accumulate into an ordered list, so multiple `Preload` lines add more
routines. Default: empty.

## Description

`Preload` is like [Autoload](Autoload.md) -- both run catalog routines
around request processing -- but `Preload` fires at the earliest possible
stage, before Interchange has set up the session, resolved the path,
classified the robot, or processed cookies. That makes it the place to
change those decisions: adjust the incoming CGI values, force or suppress a
session, tweak authorization, and so on. The list is executed by
`run_macro` in `lib/Vend/Dispatch.pm` at the top of each request.

Because it runs before the session exists, code here works with the raw
request (`$CGI::values`, `$CGI::path_info`) rather than session-scoped data.

## Examples

Skip session creation for a few public URL prefixes. In `interchange.cfg`
(or a global file) define the routine:

```
GlobalSub <<EOR
sub skip_session {
    $CGI::values{mv_tmp_session} = 1
        if $CGI::path_info =~ m{\A/(?:aboutus|contact|info)};
    return;
}
EOR
```

Then in `catalog.cfg`:

```
Preload skip_session
```

Now requests whose path begins with `aboutus`, `contact`, or `info` are
served without allocating a session.

## See also

[Autoload](Autoload.md), [AutoEnd](AutoEnd.md), [GlobalSub](GlobalSub.md),
[Sub](Sub.md), the [sessions](../guides/sessions.md) guide.

## Source

Parsed by `parse_routine_array` in `lib/Vend/Config.pm`; consumed via
`$Vend::Cfg->{Preload}` (through `run_macro`) in `lib/Vend/Dispatch.pm`.
