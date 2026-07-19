# AutoEnd

Names code -- subroutines or Interchange Tag Language (ITL) -- to run
automatically at the end of every request, after the page has been parsed
and just before the transaction finishes. Reach for it for per-request
cleanup or teardown that must happen no matter which page was served.

**Scope:** catalog (`catalog.cfg`)

## Syntax

    AutoEnd  name ...
    AutoEnd  ITL-or-code-block

Same value syntax as `Autoload`: a comma/space-separated list of
`Sub`/`GlobalSub` names, or a single block of code. Named subroutines are
called; other text is interpolated as ITL. The directive accumulates.
Default: empty.

## Description

`AutoEnd` is the end-of-request counterpart to `Autoload`. It is
registered as a cleanup handler in `lib/Vend/Config.pm`, which runs
`run_macro` (in `lib/Vend/Dispatch.pm`) on the configured value during the
request's cleanup phase -- after all page parsing has completed. Aside
from when it runs, it behaves the same as `Autoload`; the return value of
the code is discarded.

## Examples

Run a cleanup subroutine at the end of every request. In `catalog.cfg`:

```
AutoEnd my_cleanup
```

Log the finishing time of each request with inline Perl:

```
AutoEnd  [perl] Vend::Util::logError("done " . scalar localtime); return; [/perl]
```

## Notes

`Autoload` runs the equivalent code at the *start* of a request; use
`AutoEnd` when the work must happen after the page is built (for example
releasing a resource acquired in `Autoload`).

## See also

[Autoload](Autoload.md), [Preload](Preload.md), [Sub](Sub.md), [GlobalSub](GlobalSub.md), the
[perl-embedding](../guides/perl-embedding.md) guide.

## Source

Parsed by `parse_routine_array` in `lib/Vend/Config.pm`; dispatched as a
cleanup by the `AutoEnd` handler in `lib/Vend/Config.pm`, which calls
`run_macro` in `lib/Vend/Dispatch.pm`.
