# OutputCookieHook

Names a subroutine to run just before Interchange assembles the outgoing
`Set-Cookie` headers, letting you add, change, or clear cookies programmatically.
Reach for it when cookie output must depend on runtime logic that plain
directives cannot express.

**Scope:** catalog (`catalog.cfg`)

## Syntax

    OutputCookieHook  name

A single [Sub](Sub.md) or [GlobalSub](GlobalSub.md) name, stored as-is (no
parser). Default: empty (no hook).

## Description

While building the response, `lib/Vend/Server.pm` looks up the named routine --
first among catalog [Sub](Sub.md)s, then among [GlobalSub](GlobalSub.md)s -- and
calls it with no arguments before the cookie headers are generated:

```perl
if (my $sub = $Vend::Cfg->{Sub}{$Vend::Cfg->{OutputCookieHook}}
              || $Global::GlobalSub->{$Vend::Cfg->{OutputCookieHook}}
) {
    $sub->();
}
```

The routine runs in the request context, so it can inspect the session and set
`$::Instance->{Cookies}` to add or modify cookies for this response. Merely
setting `OutputCookieHook` also causes Interchange to emit cookie output for the
request even when it otherwise would not, so the hook is always given a chance to
run.

## Examples

Register a catalog subroutine that stamps a preference cookie (in
`catalog.cfg`):

```
Sub set_pref_cookie
    sub {
        Vend::Util::set_cookie('prefs', $Vend::Session->{scratch}{prefs}, undef);
        return;
    }
EndSub

OutputCookieHook set_pref_cookie
```

## See also

[Cookies](Cookies.md), [CookieName](CookieName.md),
[CookieDomain](CookieDomain.md), [SuppressCachedCookies](SuppressCachedCookies.md),
[Sub](Sub.md), [GlobalSub](GlobalSub.md), the
[sessions](../guides/sessions.md) guide.

## Source

Parsed with no parser (raw string) in `lib/Vend/Config.pm`; consumed via
`$Vend::Cfg->{OutputCookieHook}` in `lib/Vend/Server.pm`.
