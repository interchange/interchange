# SessionExpire

Sets how long an idle session may live before Interchange treats it as expired.
Reach for it to tune how quickly abandoned carts and session data are discarded.

**Scope:** catalog (`catalog.cfg`)

## Syntax

    SessionExpire  interval

A time interval such as `20 minutes`, `1 hour`, or `2 days`. A bare number is
seconds. Default: `1 hour`.

## Description

Visitors close their browsers or wander off without telling the server, so
Interchange detects a "dead" session by the gap between requests. When more than
`SessionExpire` seconds have passed since a session was last touched, that
session is considered expired: its data is dropped and, on the next request, a
new session begins.

Expiration is evaluated when sessions are read and during periodic housekeeping.
For Redis sessions the interval is also applied as the key's time-to-live.

## Examples

Expire sessions after twenty minutes of inactivity:

```
SessionExpire  20 minutes
```

Keep sessions for a full day:

```
SessionExpire  1 day
```

## Notes

If [CookieLogin](CookieLogin.md) is enabled you can safely set a short
`SessionExpire`: a returning visitor whose browser still holds the login cookie
is logged back in on the next request. Their cart and session values are reset,
however, since the old session has been discarded.

Do not confuse this with `SaveExpire`, which governs how long saved (persistent)
data such as a remembered cart is kept.

## See also

[SessionType](SessionType.md), [SessionDatabase](SessionDatabase.md),
[SessionLockFile](SessionLockFile.md), [CookieLogin](CookieLogin.md),
[Cookies](Cookies.md), the [sessions](../guides/sessions.md) guide.

## Source

Parsed by `parse_time` in `lib/Vend/Config.pm`. Consumed in
`lib/Vend/Session.pm` (`session_check`) and `lib/Vend/SessionRedis.pm`
(key expiry).
