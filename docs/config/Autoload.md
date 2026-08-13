# Autoload

Names code -- subroutines or Interchange Tag Language (ITL) -- to run
automatically near the start of every request, before the page or action
is determined. Reach for it for per-request setup: rewriting the requested
page, adjusting session state, or applying policy on every hit.

**Scope:** catalog (`catalog.cfg`)

## Syntax

    Autoload  name ...
    Autoload  ITL-or-code-block

A comma/space-separated list of `Sub`/`GlobalSub` names, or a single block
of code. A word matching a subroutine name is called; a `name-profile`
token runs an order/search profile; anything else is interpolated as ITL.
The directive accumulates. Default: empty.

## Description

Catalog `Autoload` code is dispatched on each request by the Autoload
handler in `lib/Vend/Config.pm`, which calls `run_macro` (in
`lib/Vend/Dispatch.pm`) on the configured value. It runs early -- after
session setup and locale selection but before page parsing and before the
action or page name is resolved -- so it can influence which page is
served. The return value of the code is discarded.

Because catalog configuration directives are re-instantiated per request,
`Autoload` code may temporarily modify `$Config` (and other directives)
for the current request without the change persisting.

## Examples

Run a defined global subroutine on every request. In `interchange.cfg`:

```
GlobalSub <<EOR
  sub simple_gsub {
    open OUT, "> /tmp/out";
    print OUT scalar localtime, "\n";
    close OUT;
  }
EOR
```

In `catalog.cfg`:

```
Autoload simple_gsub
```

Redirect all requests for `public/` pages to `private/`:

```
Autoload  [perl] $CGI->{mv_nextpage} =~ s:^public/:private/:; [/perl]
```

Serve a different flypage to one browser by editing the live config:

```
Autoload <<EOA
[perl]
  if ($Session->{browser} =~ /opera/i) {
    $Config->{Special}->{flypage} = 'opera_flypage';
  }
[/perl]
EOA
```

## Notes

`Autoload` runs at the *start* of a request; `AutoEnd` runs equivalent
code at the *end*. `Preload` is a related global-macro hook that runs even
earlier in dispatch. A special sub named by
`SpecialSub autoload_inspect` can veto/short-circuit the Autoload chain.

## See also

[AutoEnd](AutoEnd.md), [Preload](Preload.md), [Sub](Sub.md), [GlobalSub](GlobalSub.md), [SpecialSub](SpecialSub.md), the
[perl-embedding](../guides/perl-embedding.md) and
[catalog-anatomy](../guides/catalog-anatomy.md) guides.

## Source

Parsed by `parse_routine_array` in `lib/Vend/Config.pm`; dispatched per
request by the `Autoload` handler in `lib/Vend/Config.pm`, which calls
`run_macro` in `lib/Vend/Dispatch.pm`.
