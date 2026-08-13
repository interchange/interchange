# Security

Interchange runs code that page editors, not just server administrators,
are allowed to write; it takes credit cards; and it hands every visitor a
session that must not be stealable. This chapter is about the mechanisms
that keep those three facts from becoming three vulnerabilities: the
**Safe compartment** that constrains catalog Perl, the global/catalog
**trust boundary**, credit-card encryption, session-hijack countermeasures,
form and request hardening, and locking down the reconfigure/admin paths.
It explains what each protection does, its default, and how to loosen it
only where you must.

Two adjacent chapters cover neighboring ground and are not repeated here:
[Embedded Perl](perl-embedding.md) documents the embedding mechanisms
themselves (`[perl]`, `[calc]`, `UserTag`, `GlobalSub`), and
[Sessions](sessions.md) covers session storage and expiry. This chapter
is the security-focused view of the same machinery.

## The trust model

Interchange assumes the person who edits pages and `catalog.cfg` is *not*
necessarily the person who administers the server. A page author should be
able to embed logic without being handed the ability to read
`/etc/passwd`, run `system()`, or overwrite the server binary. That
assumption produces one bright line:

- **Catalog level** (`catalog.cfg`, pages, components, order profiles):
  Perl runs inside a restricted **Safe compartment**. Dangerous
  operations are trapped.
- **Global level** (`interchange.cfg`: [GlobalSub](../config/GlobalSub.md),
  global [UserTag](../config/UserTag.md), the shipped tags in
  `code/UserTag/*.tag`): Perl runs unrestricted, with the full power of the
  account the daemon runs as.

Everything below is either a consequence of that line or a separate
perimeter (encryption, sessions, admin auth) layered on top of it. Write
catalog code as if Safe is always on, because by default it is.

## The Safe compartment

Embedded catalog Perl — [perl](../tags/perl.md), [calc](../tags/calc.md),
`[PREFIX-calc]`, [Sub](../config/Sub.md) routines, order-check and
order-profile expressions — is compiled and run through a `Safe.pm`
compartment. Interchange wraps `Safe` in `Vend::Safe`
(`lib/Vend/Safe.pm`), which returns a UTF-8-ready compartment; the
compartment is built and its opcode mask set in `lib/Vend/Interpolate.pm`:

    $ready_safe = new Vend::Safe;
    $ready_safe->trap(qw/:base_io/);
    $ready_safe->untrap(qw/sort ftfile/);

`Safe` works by **opcode masking**: each Perl operation compiles to an
opcode, and the compartment refuses to run opcodes that are trapped. The
practical effect is that catalog Perl cannot open files, run external
programs, `require` modules, fork, access the symbol table outside its
own package, or otherwise reach off the compartment. It *can* do
arithmetic, string work, regex, hash/array manipulation, and call the tag
and data methods Interchange shares in (`$Tag`, `$Values`, `$Db`, and the
rest — see [Embedded Perl](perl-embedding.md) for the full object list).

Two directives tune the mask, both global (`interchange.cfg`):

| Directive | Default | Effect |
|-----------|---------|--------|
| [SafeTrap](../config/SafeTrap.md) | `:base_io` | opcodes/tag-groups to **forbid** |
| [SafeUntrap](../config/SafeUntrap.md) | `ftfile sort` | opcodes to **re-allow** |

`SafeUntrap` is applied after `SafeTrap` and wins on conflict. The stock
configuration traps the `:base_io` group (file reads/writes and the like)
but untraps `sort` (needed for `sort { ... }` with a comparator sub) and
`ftfile` (the `-f` file-test operator). Opcode and group names come from
Perl's `Opcode` module (`perldoc Opcode`).

When Safe blocks an opcode, the offending block returns empty and a line
like this lands in the catalog error log:

    Safe: 'system' trapped by operation mask

The fixes, in order of preference: restructure the code to avoid the
opcode; move the logic to a global [UserTag](../config/UserTag.md) or
[GlobalSub](../config/GlobalSub.md) that you have reviewed; or, as a last
resort and only for a specific opcode you understand, untrap it with
[SafeUntrap](../config/SafeUntrap.md). Untrapping `:filesys_read` to make
`-r` work is defensible; untrapping the ops that enable `open` or `system`
gives every page author the server's full privileges and defeats the point
of the compartment.

A few structural guarantees are worth naming:

- **You cannot call Perl from inside Perl to escape.** `tag_perl` returns
  `undef` immediately if it is already running inside the compartment
  (`$MVSAFE::Safe`), so a `[perl]` inside a Safe context cannot spawn an
  unrestricted one.
- **RPC/JSON contexts cannot interpolate Perl at all.** When
  `$Vend::NoInterpolate` is set (the RPC path), any attempt to run
  `[perl]`/ITL is refused and logged at `alert` level.

## Crossing the boundary on purpose

Sometimes catalog code legitimately needs full Perl — to talk to a
filesystem, call a module, or run a report. The escape hatch is deliberate
and gated by one global directive.

[AllowGlobal](../config/AllowGlobal.md) (global; default empty) names the
catalogs whose Perl may run unrestricted:

    # interchange.cfg
    Catalog  strap  /var/lib/interchange/strap  /strap
    AllowGlobal  strap

With that in place, a block can request full Perl:

    [perl global=1]
        # runs outside Safe -- only honored for AllowGlobal catalogs
        return `hostname`;
    [/perl]

If the catalog is not listed in `AllowGlobal`, `global=1` is silently
ignored and the block still runs in Safe. The decision is made in
`tag_perl`: a block goes global only when it asks (`global=1`, or the
catalog sets [PerlAlwaysGlobal](../config/PerlAlwaysGlobal.md)) **and**
`$Global::AllowGlobal->{$catalog}` is true.

Related knobs, all requiring trust in the catalog:

- [PerlAlwaysGlobal](../config/PerlAlwaysGlobal.md) — every `[perl]` in the
  catalog is global by default (still requires `AllowGlobal`).
- [PerlNoStrict](../config/PerlNoStrict.md) — global blocks run without
  `use strict`.
- [AdminSub](../config/AdminSub.md) — marks a named
  [GlobalSub](../config/GlobalSub.md) so it is callable *only* from
  `AllowGlobal` catalogs; a non-trusted catalog's `[perl subs=1]` never
  sees it.

The security posture: grant `AllowGlobal` only to catalogs whose
`catalog.cfg` and page tree you control as tightly as you control
`interchange.cfg`. On a shared server hosting other people's catalogs,
withholding `AllowGlobal` is what keeps one tenant out of another's files.

## Displaying untrusted ITL: `[restrict]`

The Safe compartment constrains *Perl*, not *tags*. A tag like
[file](../tags/file.md) or [mvasp](../tags/mvasp.md), or a `global=1`
`[perl]` embedded in text you got from a user, is dangerous regardless of
Safe. If you must interpolate text of uncertain origin — a stored template,
a user-submitted snippet — wrap it in `[restrict]`, which selectively
disables tags for the duration of a block (`$Routine{restrict}` in
`lib/Vend/Parse.pm`):

    [restrict]
        [include somefile]      <- refused and logged
        [value greeting]        <- also refused under deny policy
    [/restrict]

`[restrict]` takes:

- `enable="tag1 tag2"` — the whitelist of tags still permitted
- `disable="tag1 tag2"` — a blacklist
- `policy=allow|deny` — `deny` (default) forbids every tag except those in
  `enable`; `allow` permits every tag except those in `disable`
- `log=all|once|none` — how loudly to log refused tags

A refused tag produces no output and logs `Restricted tag (...) attempted
during restriction ...`. Use the default deny policy and an explicit
`enable` list for anything genuinely untrusted; `policy=allow` is only
appropriate when you are excluding a known-bad handful.

A second, quieter protection covers data that merely *contains* bracket
syntax. When a value tag emits data from the database or session, `ed()`
in `lib/Vend/Interpolate.pm` escapes `[` to `&#91;` so a stored string like
`[calc]...[/calc]` is displayed, not executed. The
[safe_data](../pragmas/safe_data.md) pragma (or a tag's `safe_data=1`)
turns that escaping off — do so only for data you trust to contain
intentional ITL.

## File access: NoAbsolute and FileControl

Tags that read or write files ([file](../tags/file.md), `[include]`,
mail-template reads, `[write]`) funnel through `allowed_file()` in
`lib/Vend/File.pm`. Two directives govern what they may touch.

[NoAbsolute](../config/NoAbsolute.md) (global; default `No`) forbids
catalog file operations from using absolute paths or `../` escapes outside
the catalog directory. It is one of the first things to turn on:

    # interchange.cfg
    NoAbsolute  Yes

With `NoAbsolute` set, a path that is absolute or climbs out of the catalog
is checked against per-catalog read/write permission and, failing that,
refused with a logged violation:

    Can't use file 'somefile' with NoAbsolute set

[FileControl](../config/FileControl.md) adds fine-grained, per-path rules
(a coderef or intrinsic check) at both global and catalog scope; a global
`FileControl` cannot be overridden by a catalog. Note that the
`$Vend::superuser` state bypasses *catalog* file controls but not *global*
ones, so global `FileControl`/`NoAbsolute` remain the backstop.

## Sessions and hijack protection

A session id is a bearer token: whoever presents it *is* that session.
[Sessions](sessions.md) covers what a session holds and how it is stored;
the security question is how Interchange keeps a stolen or guessed id from
being usable.

**Host binding.** By default a session is honored only from the client
address that created it. In the id-resolution step (`RESOLVEID` in
`lib/Vend/Dispatch.pm`), the request's `REMOTE_ADDR` is compared against
the session's stored `ohost` (or `shost` for the TLS side); a mismatch on a
non-cookie id throws the session away and issues a fresh one. This means an
id lifted from a URL is useless from a different IP.

[WideOpen](../config/WideOpen.md) (catalog; default `No`) disables that
check entirely — every request with a valid id is honored regardless of
origin address:

    # catalog.cfg -- weakens session security; use only when forced
    WideOpen  Yes

Turn it on only when clients legitimately change address between requests
(proxy pools, some mobile carriers) *and* you protect payment data by other
means. Softer alternatives loosen without removing the check:
[DomainTail](../config/DomainTail.md) compares only the network tail of the
hostname, and [IpHead](../config/IpHead.md) compares only a leading portion
of the IP — sized for proxy farms where the last octet varies.
[TrustProxy](../config/TrustProxy.md) tells Interchange which upstream
proxies to believe when deriving the real client address.

**Cookie hardening.** The session cookie should carry the usual flags.
Interchange sets them from `lib/Vend/Server.pm`:

- [SessionCookieSecure](../config/SessionCookieSecure.md) (catalog;
  default `No`) adds `Secure` to the cookie on TLS requests, so it is never
  sent over plain HTTP.
- The [set_httponly](../pragmas/set_httponly.md) pragma adds `HttpOnly`,
  keeping the cookie out of JavaScript's reach.
- The [set_samesite](../pragmas/set_samesite.md) pragma sets the
  `SameSite` attribute (`Lax`, `Strict`, or `None`) as a CSRF mitigation.

[CookiePattern](../config/CookiePattern.md) constrains the characters
accepted in an incoming id (default `[-\w:.]+`), so a malformed or injected
id value is rejected before it is used.

**Robot and flood lockout.** Runaway clients — scrapers, credential
stuffers, misbehaving bots — are handled by two limits.
[RobotLimit](../config/RobotLimit.md) (catalog; default `0` = off) caps how
many pages one session may fetch without pausing:

    # catalog.cfg
    RobotLimit  100

Exceeding it (with less than a 30-second pause, adjustable via
[Limit](../config/Limit.md) `lockout_reset_seconds`) triggers
`do_lockout()` in `lib/Vend/Error.pm`, which:

1. runs the `SpecialSub lockout` hook if you defined one (a true return
   cancels the lockout);
2. runs [LockoutCommand](../config/LockoutCommand.md) (global) with the
   client IP substituted for `%s` — typically a firewall/`iptables` call;
3. rewrites the catalog's `VendURL`/`SecureURL` to `http://127.0.0.1` so
   every generated link points the offender back at itself.

Admin sessions are exempt. Separately, an IP that requests too many *new*
sessions in a short window draws a `403 Forbidden` (`count_ip()`), with the
ban lasting `Limit robot_expire` days (default 1). Well-behaved crawlers
should be *classified*, not locked out: list them in
[RobotUA](../config/RobotUA.md)/[RobotIP](../config/RobotIP.md)/[RobotHost](../config/RobotHost.md)
(the shipped `robots.cfg`) so they share one throwaway session instead of
bloating the store. [DNSBL](../config/DNSBL.md) can additionally screen
against blocklists.

## Credit-card handling and encryption

The safest card data is the data you never store. Interchange's default
posture is to encrypt card details as soon as they arrive and hand off to a
[payment](payments.md) gateway, keeping nothing in the clear.

**Automatic capture.** [CreditCardAuto](../config/CreditCardAuto.md)
(catalog; default `No`), when a form submits an `mv_credit_card_number`,
runs `encrypt_standard_cc()` (`lib/Vend/Order.pm`) during dispatch. That
routine:

- validates the expiration date and rejects expired cards;
- runs the **LUHN-10** checksum (`luhn()`), except for UnionPay numbers
  (`/^62/`, which do not use LUHN) or when `mv_credit_card_force` is set;
- builds a masked reference of the form `41**1111` for display/receipts;
- encrypts the full card block with `pgp_encrypt()`;
- populates `mv_credit_card_info` (the ciphertext) and the non-secret
  `mv_credit_card_*` values, and **deletes the raw number** from the
  values.

So after capture, `$Values->{mv_credit_card_info}` holds ciphertext and the
plaintext number is gone. `scrub()` (called on login and related UserDB
events) further removes card fields from persisted values so they never
reach the session store.

**The encryption pipeline.** `pgp_encrypt()` shells out to an external
program selected by [EncryptProgram](../config/EncryptProgram.md):

| Scope | Default |
|-------|---------|
| Global (`interchange.cfg`) | first of `gpg`, `pgpe`, `none` found on the box |
| Catalog (`catalog.cfg`) | inherits the global value; `none` disables |

The command name is recognized and its options are appended
automatically — you configure only the program (optionally with a path):

    # catalog.cfg
    EncryptProgram  gpg
    EncryptKey      orders@example.com

`gpg` becomes `gpg --batch --always-trust -e -a -r 'orders@example.com'`;
`pgpe` and `pgp` are handled similarly. The recipient comes from
[EncryptKey](../config/EncryptKey.md). The plaintext is streamed to the
program through a temporary file under [ScratchDir](../config/ScratchDir.md)
and the ciphertext read back; a command containing `;` or `|` is rejected
outright. Setting `EncryptProgram none` (or leaving `EncryptKey` empty)
disables encryption and card capture fails loudly rather than storing
plaintext.

> **Historic-doc contradiction.** Older documentation described `%p` and
> `%f` placeholders (password, temporary-file name) that you could put in
> the `EncryptProgram` command line. The current `pgp_encrypt`
> implementation performs **no such substitution** — it recognizes the
> `gpg`/`pgpe`/`pgp` program name and appends the options and recipient
> itself. Configure the program name only; `%p`/`%f` do nothing. See
> [EncryptProgram](../config/EncryptProgram.md).

**Whole-order encryption.** Distinct from per-field card encryption,
[PGP](../config/PGP.md) (catalog) encrypts the *entire* interpolated order
report before it is mailed (`$body = pgp_encrypt($body) if
$Vend::Cfg->{PGP}` in `mail_order`), so the operations mailbox receives
ciphertext. It uses the same `EncryptProgram`/`EncryptKey` machinery.

The strap demo wires this together through the order route's
`encrypt`/`encrypt_program` attributes; see
[Carts and checkout](cart-and-checkout.md) and [Payments](payments.md) for
the route side.

## Passwords in the user database

Account passwords live in the [UserDB](user-database.md) table and should
never be stored in the clear. `lib/Vend/UserDB.pm` supports several hash
schemes, selected by [UserDB](../config/UserDB.md) options:

| Scheme | Option | Notes |
|--------|--------|-------|
| `crypt()` | `crypt` (the historical default) | system `crypt`, 2-char salt |
| MD5 | `md5` | unsalted digest — weak, legacy only |
| salted MD5 | `md5_salted` | `hash:salt`, Zen Cart compatible |
| SHA1 | `sha1` | needs `Digest::SHA` |
| **bcrypt** | `bcrypt` | needs `Digest::Bcrypt` + `Crypt::Random`; **preferred** |

Bcrypt is the recommendation for new deployments. It uses a work factor
(`BCOST`, default cost 13), pads the input to bcrypt's 72-byte window
(`brpad`), and supports an optional server-side `bcrypt_pepper` mixed into
the padding so a leaked database alone is not enough to mount an offline
attack. A minimal catalog setup:

    # catalog.cfg
    UserDB  default  crypt   bcrypt
    UserDB  default  bcrypt_pepper  "some-long-server-only-secret"

Two operational features matter for security:

- **Promotion.** With `UserDB ... promote 1`, a successful login whose
  stored hash uses a weaker scheme (or a lower bcrypt cost) is transparently
  re-hashed to the current scheme and written back. This lets you migrate an
  existing `crypt`/`md5`/`sha1` table to bcrypt organically as users log in,
  with no password reset. The `$2c$`/`$2m$`/`$2n$`/`$2s$` cipher prefixes
  record the pre-digested origin so old hashes can even be bcrypted
  wholesale ahead of time.
- **Login guards.** Login refuses a blank stored password outright, enforces
  minimum username/password lengths (`USERMINLEN`/`PASSMINLEN`) and a
  username character whitelist, and logs every failure. The submitted
  password is hashed with the stored salt and compared to the stored hash;
  the plaintext is never persisted.

Login attempts and failures are written to the catalog log; set
`UserDB ... log_failed 1` to also record failed access-control checks.
See [User accounts](user-database.md) for account lifecycle,
`CookieLogin`/"remember me", and access-control tables.

## Form and request hardening

Form submissions are attacker-controlled input; several mechanisms keep
them from doing more than intended.

**What a form may set.** By default a submitted form writes its fields into
the visitor's values. [FormIgnore](../config/FormIgnore.md) lists CGI
variables that must *never* be copied into values — use it to protect
fields your logic trusts (prices, flags, internal keys) from being set by a
crafted request:

    # catalog.cfg
    FormIgnore  mv_todo  credit_limit

For anything a form is allowed to *do*, prefer **order profiles** and the
`mv_form_profile` mechanism (validated, server-defined submissions) over
trusting `mv_todo`/`mv_click` values directly. The
[require_order_profile](../pragmas/require_order_profile.md) pragma makes a
profile mandatory. Order profiles and checks are covered in
[Carts and checkout](cart-and-checkout.md) and the
[order-check reference](../order-checks/README.md).

**Echoing user input.** Container-tag output is reparsed for ITL by
default (`reparse=1` — see the
[no_default_reparse](../pragmas/no_default_reparse.md) pragma), so a page
that emits a CGI value from inside `[calc]` or `[perl]` hands the visitor
an injection point: a submitted value of `[perl]...[/perl]` comes back
out of the tag and is *executed* on the reparse pass. This is not
hypothetical — the shipped admin page `quick_question.html` was
exploitable exactly this way, giving unauthenticated remote code
execution until it was fixed in August 2026 (see
[Upgrading](upgrading.md)). When a tag must echo request data, disable
the second pass and neutralize markup: `reparse=0` on the emitting tag,
the `entities` filter on the value, and — for admin pages — an
`[if-mm super]` gate. For longer untrusted text, use `[restrict]`
(described earlier).

**Header injection.** Any user data that could end up in an HTTP response
header — a redirect target, a bounce URL — is passed through
`header_data_scrub()` (`lib/Vend/Util.pm`), which strips CR/LF and their
`%0d`/`%0a` encodings to block HTTP response-splitting. This applies
automatically to generated redirect and `href` values.

**SQL.** Parameterized [query](../tags/query.md) placeholders (`?`) are the
correct way to build SQL from user input; never interpolate `[cgi ...]`
straight into a statement. The
[filter_sql_no_backslash](../pragmas/filter_sql_no_backslash.md) pragma
adjusts quoting behavior for backends where backslash is not an escape.
See [Databases](databases.md) and [Search](search.md).

**Forcing HTTPS.** Pages that carry sensitive data should be reachable only
over TLS:

- [AlwaysSecure](../config/AlwaysSecure.md) /
  [AlwaysSecureGlob](../config/AlwaysSecureGlob.md) list the pages that
  Interchange serves over the [SecureURL](../config/SecureURL.md) base.
- [ExtraSecure](../config/ExtraSecure.md) (catalog; default `No`) goes
  further and *refuses* non-HTTPS access to those pages
  (`lib/Vend/Page.pm`) rather than silently allowing it.
- [SecurePostURL](../config/SecurePostURL.md) sets the base for secure form
  posts.

    # catalog.cfg
    AlwaysSecure  ord/checkout login
    ExtraSecure   Yes

## Admin and reconfigure lockdown

The catalog reconfigure path (`ctl reconfig`, the `mv_check`/reconfigure
URL) and other protected operations are gated by `check_security()` in
`lib/Vend/Util.pm`. Three catalog directives control who may invoke them,
and at least one must be set or protected operations are disabled entirely:

| Directive | Guards by |
|-----------|-----------|
| [Password](../config/Password.md) | a `crypt`-ed password that must match |
| [MasterHost](../config/MasterHost.md) | a regex of hostnames/IPs allowed |
| [RemoteUser](../config/RemoteUser.md) | a required HTTP `REMOTE_USER` |

    # catalog.cfg -- restrict reconfigure to the local host
    MasterHost  127\.0\.0\.1|localhost

Every failed or unauthorized attempt is logged at `warning` level to the
global log with the remote address, user agent, and script name, giving
you an audit trail. If none of the three is set, Interchange logs
"secure operations disabled" and refuses the reconfigure rather than
running it unauthenticated.

For the admin UI itself, prefer UserDB-backed authentication with an
access-control table (`MV_USERDB_ACL_TABLE`/`MV_USERDB_ACL_COLUMN`) over
HTTP basic auth, and keep the admin pages under `ExtraSecure`. The
[Promiscuous](../config/Promiscuous.md) directive (default `No`) — which
would let one catalog reach into another's databases — should stay off
unless you specifically need cross-catalog access and trust every catalog
involved.

## A baseline checklist

For a production catalog, the defensible baseline is:

- `NoAbsolute Yes` globally; grant [AllowGlobal](../config/AllowGlobal.md)
  only to catalogs you fully control.
- Leave the Safe compartment's defaults alone; untrap opcodes only for a
  named, understood need.
- `bcrypt` password hashing with a `bcrypt_pepper`; `promote 1` to migrate
  legacy hashes.
- `EncryptProgram gpg` + `EncryptKey`, or a real-time gateway, so card
  numbers are never stored in the clear; `CreditCardAuto Yes`.
- Cookie flags on: [SessionCookieSecure](../config/SessionCookieSecure.md),
  [set_httponly](../pragmas/set_httponly.md),
  [set_samesite](../pragmas/set_samesite.md).
- Host binding left on (no [WideOpen](../config/WideOpen.md) unless forced);
  [RobotLimit](../config/RobotLimit.md) and
  [LockoutCommand](../config/LockoutCommand.md) set for abuse.
- Sensitive pages under [AlwaysSecure](../config/AlwaysSecure.md) +
  [ExtraSecure](../config/ExtraSecure.md).
- Reconfigure locked with [MasterHost](../config/MasterHost.md) and/or
  [Password](../config/Password.md).
- `[restrict]` around any ITL of uncertain origin; leave
  [safe_data](../pragmas/safe_data.md) off for untrusted data.

## See also

- [Embedded Perl](perl-embedding.md) — the Safe compartment from the
  page-author side; `AllowGlobal` policy in practice
- [Sessions](sessions.md) — session storage, ids, and expiry
- [User accounts](user-database.md) — accounts, login, and access control
- [Carts and checkout](cart-and-checkout.md),
  [Payments](payments.md) — order routes, profiles, and gateways
- [Configuration](configuration.md) — how directives are parsed and scoped
- [Logging and debugging](logging-debugging.md) — reading the security
  log lines this chapter mentions
- Config reference: [AllowGlobal](../config/AllowGlobal.md),
  [SafeTrap](../config/SafeTrap.md), [SafeUntrap](../config/SafeUntrap.md),
  [NoAbsolute](../config/NoAbsolute.md),
  [EncryptProgram](../config/EncryptProgram.md),
  [WideOpen](../config/WideOpen.md), [RobotLimit](../config/RobotLimit.md)
