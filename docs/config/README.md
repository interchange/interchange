# Configuration directives

Interchange is configured by directives read from two files: the
server-wide `interchange.cfg` and each catalog's `catalog.cfg`. This
directory documents all 273 built-in directives, one page each. See the
[configuration guide](../guides/configuration.md) for how the files are
loaded and how directive values are parsed, and
[catalog anatomy](../guides/catalog-anatomy.md) for how a catalog is laid out.

**Scope** is marked after each entry: **(G)** directive is read only from
`interchange.cfg` (global); **(C)** read only from `catalog.cfg` (per
catalog); **(B)** valid in both files. Where a name appears in both files
its page carries a `## Global` / `## Catalog` split.

## Server, daemon & process model

- [ChildLife](ChildLife.md) (G) -- Sets a maximum lifetime for a page-server child process, after which it exits and is replaced.
- [HammerLock](HammerLock.md) (G) -- Sets the maximum number of seconds Interchange will wait to acquire a session lock before deciding the lock is stale and forcing it.
- [HouseKeeping](HouseKeeping.md) (G) -- Sets how often, in seconds, the Interchange server wakes up to do periodic maintenance -- checking for reconfigure requests, hung processes, and scheduled work.
- [HouseKeepingCron](HouseKeepingCron.md) (G) -- Schedules Interchange-aware periodic work with a crontab-style specification, replacing the default fixed housekeeping cycle.
- [LockType](LockType.md) (G) -- Selects the file-locking method Interchange uses for its lock operations.
- [MaxRequestsPerChild](MaxRequestsPerChild.md) (G) -- Sets how many requests a single Interchange server process handles before it exits and is respawned.
- [MaxServers](MaxServers.md) (G) -- Caps the number of Interchange page-serving processes that run at once.
- [PIDcheck](PIDcheck.md) (G) -- Sets how long a request-handling child may run before the housekeeping routine kills it.
- [PIDfile](PIDfile.md) (G) -- Names the file that holds the process ID of the master Interchange server.
- [PreFork](PreFork.md) (G) -- Runs the server in pre-fork mode, where a pool of child processes is started ahead of time and waits for client connections.
- [PreForkSingleFork](PreForkSingleFork.md) (G) -- Makes pre-fork mode start each pool server with one `fork()` instead of two.
- [StartServers](StartServers.md) (G) -- Sets how many page-server processes Interchange preforks when it runs in [PreFork](PreFork.md) mode.

## Sockets, links & request protocol

- [SocketFile](SocketFile.md) (G) -- Names the Unix-domain socket file(s) Interchange creates for communication with the web-server link program (`vlink`/`tlink`) and other local clients.
- [SocketPerms](SocketPerms.md) (G) -- Sets the Unix filesystem permissions on the [SocketFile](SocketFile.md) Unix-domain socket that Interchange creates.
- [SocketReadTimeout](SocketReadTimeout.md) (G) -- Sets how many seconds Interchange waits for data to arrive on a client socket before giving up on that read.
- [IPCsocket](IPCsocket.md) (G) -- Names the Unix-domain socket file the Interchange server creates for inter-process control (IPC) communication, such as reconfigure and status requests from command-line tools.
- [Inet_Mode](Inet_Mode.md) (G) -- Controls whether the Interchange server opens an INET-domain (TCP) socket and listens on a port.
- [Unix_Mode](Unix_Mode.md) (G) -- Controls whether the Interchange server listens on a Unix-domain socket.
- [TcpHost](TcpHost.md) (G) -- Lists the hosts allowed to connect to the Interchange server when it runs in Inet (TCP) mode.
- [TcpMap](TcpMap.md) (G) -- Lists the host addresses and TCP ports the Interchange server binds to when running in Inet mode.
- [VendURL](VendURL.md) (C) -- Sets the base URL of the catalog's link program -- the entry point through which all Interchange page requests are routed.
- [SecureURL](SecureURL.md) (C) -- Sets the base URL Interchange uses to build links to itself when a page must be served over a secure (HTTPS) connection.
- [PostURL](PostURL.md) (C) -- Sets the catalog URL used as the form-action target for POST submissions, letting POST requests take a different path than GET requests.
- [SecurePostURL](SecurePostURL.md) (C) -- Sets the base URL Interchange uses for secure (HTTPS) form submissions built with the `[process]` tag.
- [ProcessPage](ProcessPage.md) (C) -- Names the virtual page that receives form submissions and searches -- the form-processor target.
- [UrlSepChar](UrlSepChar.md) (G) -- Sets the character Interchange uses to separate parameters in the URLs it generates.
- [VarName](VarName.md) (B) -- Remaps Interchange variable names to shorter or arbitrary names in the URLs Interchange generates and reads.
- [AcceptRedirect](AcceptRedirect.md) (G) -- Enables Interchange to honor HTTP redirects sent by the front-end web server, so that an `ErrorDocument` handler can hand an unresolved URL to Interchange for processing.
- [RedirectCache](RedirectCache.md) (C) -- Names a directory into which Interchange writes the static output of pages that the web server redirected to it because a static file was missing.
- [Environment](Environment.md) (G) -- Names the environment variables Interchange should copy from the calling CGI link program into each request's environment.
- [TolerateGet](TolerateGet.md) (G) -- Makes Interchange also parse the query-string (GET) parameters of a POST request, instead of only the POST body.
- [EnableJSONPost](EnableJSONPost.md) (G) -- Lets Interchange accept request bodies posted with a JSON content type, decoding the JSON into request variables.
- [UnpackJSON](UnpackJSON.md) (G) -- Controls whether a JSON POST body whose top level is an object is unpacked into individual CGI variables.
- [DowncaseVarname](DowncaseVarname.md) (G) -- Forces the names of selected incoming CGI variables to lowercase as requests are parsed.
- **URL** (C) -- alias for [VendURL](VendURL.md); the two names are interchangeable in `catalog.cfg`.

## Paths & directories

- [ConfDir](ConfDir.md) (C) -- Names the catalog's "config" directory, where Interchange keeps runtime control and status files.
- [ConfigDir](ConfigDir.md) (B) -- Sets the default directory searched for files referenced with the `<file` notation in configuration files.
- [CounterDir](CounterDir.md) (C) -- Sets the base directory under which the [counter](../tags/counter.md) tag and other counter files are stored when their filename is not absolute.
- [OfflineDir](OfflineDir.md) (C) -- Names the directory that holds the "offline" copies of database source files used by the offline database-build process.
- [PageDir](PageDir.md) (C) -- Names the directory that holds a catalog's Interchange pages.
- [PermanentDir](PermanentDir.md) (C) -- Names the directory where Interchange stores the result files for saved ("more") searches that are marked permanent.
- [ProductDir](ProductDir.md) (C) -- Names the directory that holds the catalog's database source and data files.
- [RunDir](RunDir.md) (B) -- Names the directory where Interchange keeps runtime control files -- the server-wide reconfigure, restart, and jobs-queue flags and status files.
- [ScratchDir](ScratchDir.md) (C) -- Names the directory where Interchange writes transient working files -- cached searches, retired session IDs, and other short-lived scratch data.
- [SpecialPageDir](SpecialPageDir.md) (C) -- Names the directory that holds a catalog's special pages -- the fallback error and system pages Interchange serves when a request cannot be satisfied normally.
- [TemplateDir](TemplateDir.md) (B) -- Names extra directories that Interchange searches for pages when a page is not found in the catalog's own [PageDir](PageDir.md).
- **DataDir** (C) -- alias for [ProductDir](ProductDir.md); the two names are interchangeable in `catalog.cfg`.

## Catalog registration & config mechanics

- [Catalog](Catalog.md) (G) -- Registers a catalog -- a complete Interchange store or application -- with the server, mapping its name, base directory, and web link-program path so requests can reach it.
- [SubCatalog](SubCatalog.md) (G) -- Registers a subcatalog -- a catalog that shares another catalog's code base and configuration, overriding only the directives that differ.
- [AddDirective](AddDirective.md) (G) -- Registers a new catalog configuration directive at server startup, so that `catalog.cfg` files may use a directive name that is not built in.
- [DeleteDirective](DeleteDirective.md) (G) -- Disables named configuration directives so they are ignored when catalog configuration is parsed.
- [Replace](Replace.md) (C) -- Resets a named directive to its default before the current (sub)catalog's own settings are applied, so an accumulating directive starts fresh rather than adding to the base catalog's value.
- [Require](Require.md) (B) -- Asserts that a named capability -- a Perl module, subroutine, tag, file, or executable -- is present, and aborts startup if it is not.
- [Suggest](Suggest.md) (B) -- Checks that a capability or resource is present and logs a **warning** if it is not, without aborting startup.
- [Capability](Capability.md) (G) -- Tests for the presence of a global subroutine, tag, Perl module, file, or executable at startup and quietly records the result, without warning or aborting if the item is missing.
- [ConfigAllAfter](ConfigAllAfter.md) (G) -- Names configuration files that Interchange reads for *every* catalog, after all of that catalog's own configuration files.
- [ConfigAllBefore](ConfigAllBefore.md) (G) -- Names configuration files that Interchange reads for *every* catalog, before that catalog's own configuration files.
- [ConfigDatabase](ConfigDatabase.md) (B) -- Points Interchange at a database table whose rows supply configuration directives that would otherwise live in `catalog.cfg`.
- [ConfigParseComments](ConfigParseComments.md) (B) -- Formerly controlled whether hash-prefixed configuration meta-directives (`#include`, `#ifdef`, `#ifndef`) were interpreted or treated as plain comments.
- [ParseVariables](ParseVariables.md) (C) -- Controls whether configuration-directive values have their variable references interpolated as the config file is read.
- [Feature](Feature.md) (C) -- Installs a named *feature* -- a reusable bundle of configuration and files -- into the current catalog.
- [FeatureDir](FeatureDir.md) (G) -- Names the directory that holds installable Interchange *features* -- bundles of configuration and files that a catalog pulls in with the [Feature](Feature.md) directive.
- [Profile](Profile.md) (C) -- Defines a named set of directive overrides that can be switched on at runtime with the [profile](../tags/profile.md) tag.
- [FullUrl](FullUrl.md) (G) -- Includes the request hostname when Interchange decides which catalog a request belongs to.
- [FullUrlIgnorePort](FullUrlIgnorePort.md) (G) -- Strips the port number from the hostname when [FullUrl](FullUrl.md) catalog selection is in effect.

## Variables, code & tags

- [Variable](Variable.md) (B) -- Defines a named Interchange variable holding a piece of text -- a URL, an email address, a snippet of HTML, a configuration flag.
- [VariableDatabase](VariableDatabase.md) (C) -- Loads Interchange [Variable](Variable.md) values from a database table instead of from `Variable` lines in `catalog.cfg`.
- [AutoVariable](AutoVariable.md) (B) -- Copies the current values of named configuration directives into the Variable space, so a page can read a directive's value as `__VariableName__`.
- [DirConfig](DirConfig.md) (C) -- Populates a hash-valued directive (usually [Variable](Variable.md)) from a directory of files, using each file's name as the key and its contents as the value.
- [Member](Member.md) (C) -- Overrides the value of named catalog variables for logged-in users.
- [GlobalSub](GlobalSub.md) (G) -- Defines a named Perl subroutine, registered globally, that pages and other code can call.
- [Sub](Sub.md) (C) -- Defines a named Perl subroutine belonging to a catalog, callable from embedded Perl ([perl] and [mvasp] blocks) and from event hooks such as [SpecialSub](SpecialSub.md).
- [SpecialSub](SpecialSub.md) (C) -- Registers catalog Perl subroutines as handlers for specific Interchange events -- a missing page, session creation, credit-card type detection, shipping and weight callouts, and more.
- [UserTag](UserTag.md) (B) -- Defines a custom Interchange Tag Language (ITL) tag -- an extension tag you can call from pages like any built-in tag.
- [CodeDef](CodeDef.md) (B) -- A general-purpose code mapper: it registers a Perl routine (or a scalar or list attribute) against a named slot in one of Interchange's extensible subsystems -- action maps, filters, widgets, order checks, search operators, and more.
- [ActionMap](ActionMap.md) (B) -- Defines or overrides an Interchange *action* -- a named handler that runs when its name appears as the first component of a request path.
- [FormAction](FormAction.md) (B) -- Defines or overrides a *form action* -- a named handler selected by the `mv_action`/`mv_click`/`mv_doit` variable when a form is submitted to the `process` page.
- [Autoload](Autoload.md) (C) -- Names code -- subroutines or Interchange Tag Language (ITL) -- to run automatically near the start of every request, before the page or action is determined.
- [AutoEnd](AutoEnd.md) (C) -- Names code -- subroutines or Interchange Tag Language (ITL) -- to run automatically at the end of every request, after the page has been parsed and just before the transaction finishes.
- [Preload](Preload.md) (C) -- Names routines to run at the very start of every request, before session, path, robot, and cookie handling.
- [AccumulateCode](AccumulateCode.md) (G) -- Fetches Interchange tag and code definitions on demand from a `CodeRepository` instead of loading everything at startup, copying each used piece into an accumulated directory as it is needed.
- [CodeRepository](CodeRepository.md) (G) -- Names a directory of system code (tags and [CodeDef](CodeDef.md) definitions) that Interchange draws from on demand, compiling only the pieces a running catalog actually uses.
- [TagDir](TagDir.md) (G) -- Names the directories Interchange scans at startup for code-declaration files -- tags, filters, widgets, order checks, action maps, and other `CodeDef` definitions.
- [TagGroup](TagGroup.md) (G) -- Defines named groups of code declarations (tags, filters, widgets, and other symbols) so that whole sets can be included or excluded at once with [TagInclude](TagInclude.md).
- [TagInclude](TagInclude.md) (G) -- Selects which discovered tags (and other code declarations) are actually compiled into the running server.

## Database

- [Database](Database.md) (B) -- Registers a database table for use with Interchange -- naming it, pointing at its source file, and declaring its format -- and sets per-table parameters.
- [DatabaseAuto](DatabaseAuto.md) (C) -- Discovers the tables in a live SQL database and registers every one of them with Interchange automatically, saving you from writing a [Database](Database.md) line per table.
- [DatabaseAutoIgnore](DatabaseAutoIgnore.md) (C) -- Sets a regular expression that excludes matching table names from [DatabaseAuto](DatabaseAuto.md) discovery.
- [DatabaseDefault](DatabaseDefault.md) (C) -- Sets default parameters applied to every [Database](Database.md) table defined afterward, so you write shared settings (such as SQL credentials) once instead of repeating them per table.
- [AcrossLocks](AcrossLocks.md) (G) -- Forces every configured database to be opened for real at the start of each page request, instead of Interchange's default of handing out a fast placeholder and opening the table only when it is first used.
- [HotDBI](HotDBI.md) (G) -- Names the catalogs whose DBI database connections should be kept open and cached between page requests instead of being reconnected each time.
- [FileDatabase](FileDatabase.md) (C) -- Lets Interchange fall back to a database table for file contents when a file is not found on disk.
- [TableRestrict](TableRestrict.md) (C) -- Restricts database searches on a table to rows whose named column matches a value from the current session, emulating per-user database views for rows tied to the current user.
- [CategoryField](CategoryField.md) (C) -- Names the database column that holds a product's category.
- [DescriptionField](DescriptionField.md) (C) -- Names the products-table column that holds a product's description.
- [ProductFiles](ProductFiles.md) (C) -- Lists the database tables that together act as the catalog's logical `products` database.
- [NoImport](NoImport.md) (C) -- Names database tables that Interchange must never automatically import from their text source files.
- [NoImportExternal](NoImportExternal.md) (C) -- Disables automatic import of external (SQL and LDAP) database tables from their text source files.
- [NoExport](NoExport.md) (C) -- Names database tables that Interchange must never automatically re-export to their text source files.
- [NoExportExternal](NoExportExternal.md) (C) -- Disables automatic re-export of external (SQL and LDAP) database tables back to their text source files.
- **DefaultTables** (C) -- alias for [ProductFiles](ProductFiles.md); the two names are interchangeable in `catalog.cfg`.

## Sessions, cookies & users

- [Cookies](Cookies.md) (C) -- Controls whether Interchange sends an HTTP session cookie to the browser and reads it back to track the shopper's session.
- [CookieDomain](CookieDomain.md) (C) -- Sets the `domain=` attribute of Interchange's session cookie so that servers sharing a common domain also share one session.
- [CookieLogin](CookieLogin.md) (C) -- Lets a returning visitor be logged in automatically from credentials saved in a browser cookie.
- [CookieName](CookieName.md) (C) -- Sets the name of the cookie Interchange reads to recover a visitor's session ID.
- [CookiePattern](CookiePattern.md) (C) -- Sets the regular expression Interchange uses to extract the session ID from the value of the browser's session cookie.
- [InternalCookie](InternalCookie.md) (C) -- Controls whether Interchange keeps managing its own IP-address cookie when a custom [CookieName](CookieName.md) is in use.
- [SessionCookieSecure](SessionCookieSecure.md) (C) -- Controls whether Interchange marks the session-ID cookie as `secure` when the current request arrived over HTTPS.
- [SaveExpire](SaveExpire.md) (C) -- Sets how long Interchange's persistent cookies -- those other than the session-ID cookie -- remain valid.
- [OutputCookieHook](OutputCookieHook.md) (C) -- Names a subroutine to run just before Interchange assembles the outgoing `Set-Cookie` headers, letting you add, change, or clear cookies programmatically.
- [SuppressCachedCookies](SuppressCachedCookies.md) (C) -- When enabled, stops Interchange from sending session cookies (and from writing the session) on pages that are marked cacheable, so a cached page behaves the same whether it is served from cache or freshly generated.
- [Mall](Mall.md) (G) -- Scopes session cookies to the current catalog's URL path instead of the whole domain.
- [SessionType](SessionType.md) (C) -- Selects the storage backend Interchange uses for user sessions.
- [SessionDB](SessionDB.md) (C) -- Names the database or server that holds sessions when [SessionType](SessionType.md) is `DBI` or `Redis`.
- [SessionDBCompression](SessionDBCompression.md) (C) -- Enables transparent compression of session data stored in DBI or Redis session backends.
- [SessionDatabase](SessionDatabase.md) (C) -- Sets the filesystem location Interchange uses for file-based and DBM-based sessions.
- [SessionExpire](SessionExpire.md) (C) -- Sets how long an idle session may live before Interchange treats it as expired.
- [SessionHashLength](SessionHashLength.md) (C) -- Sets how many characters name each subdirectory level Interchange uses to store file-based sessions.
- [SessionHashLevels](SessionHashLevels.md) (C) -- Sets how many nested subdirectory levels Interchange uses to spread file-based sessions across the filesystem.
- [SessionLockFile](SessionLockFile.md) (C) -- Names the lock file Interchange uses to serialize access to file and DBM sessions.
- [History](History.md) (C) -- Sets how many of a visitor's most recent page requests Interchange keeps in the session history.
- [IpHead](IpHead.md) (G) -- Qualifies user sessions by only the leading portion of the client's IP address instead of the whole address.
- [IpQuad](IpQuad.md) (G) -- Sets how many leading octets ("dot-quads") of the client IPv4 address are used to qualify a session when [IpHead](IpHead.md) is enabled.
- [FallbackIP](FallbackIP.md) (C) -- Gives a cookieless visitor a session anyway, by deriving the session ID from their IP address and browser.
- [ScratchDefault](ScratchDefault.md) (C) -- Defines initial values for scratch variables that Interchange assigns to every new session.
- [ValuesDefault](ValuesDefault.md) (C) -- Sets default entries in every user session's values space, used until the user (or a login) overrides them.
- [UserDB](UserDB.md) (C) -- Defines named *profiles* that control Interchange's built-in user database system -- customer logins, account creation, saved carts, address books, and access control.
- [UserControl](UserControl.md) (C) -- Switches the catalog's user-database operations from the standard `Vend::UserDB` module to the enhanced `Vend::UserControl` module.

## Security & access control

- [AllowGlobal](AllowGlobal.md) (G) -- Names the catalogs that are allowed to run Perl with the full permissions of the Interchange server, outside the restricted `Safe` compartment.
- [AdminSub](AdminSub.md) (C) -- Restricts named global subroutines so that only trusted catalogs -- those listed in the global `AllowGlobal` directive -- may call them.
- [PerlAlwaysGlobal](PerlAlwaysGlobal.md) (G) -- Names the catalogs whose embedded Perl should always be compiled and run globally -- outside the restricted `Safe` compartment -- even for tags that would normally use the sandbox.
- [PerlNoStrict](PerlNoStrict.md) (G) -- Names the catalogs whose embedded Perl is compiled without `use strict`.
- [SafeTrap](SafeTrap.md) (G) -- Lists the Perl opcodes to *trap* (forbid) inside the `Safe` compartment that Interchange uses to run embedded Perl and conditional expressions.
- [SafeUntrap](SafeUntrap.md) (G) -- Lists the Perl opcodes to *untrap* (re-enable) inside the `Safe` compartment that Interchange uses to run embedded Perl and conditional expressions.
- [NoAbsolute](NoAbsolute.md) (G) -- Forbids catalog pages and tags from reading files by absolute path.
- [CatalogUser](CatalogUser.md) (G) -- Assigns a would-be Unix username to a catalog for permission checks on files accessed by absolute path.
- [SetGroup](SetGroup.md) (C) -- Switches the Unix primary group Interchange runs under while serving a given catalog.
- [FileControl](FileControl.md) (B) -- Maps a file or directory path to a Perl routine that decides, per access, whether Interchange may read or write it.
- [MasterHost](MasterHost.md) (C) -- Restricts protected operations -- reconfiguration, protected databases, and administrative functions -- to clients whose host name or IP matches a pattern.
- [RemoteUser](RemoteUser.md) (C) -- Names the value the web server's `REMOTE_USER` variable must hold before Interchange will allow a catalog reconfigure or other secure operation.
- [Password](Password.md) (C) -- Sets the encrypted password that authorizes protected catalog operations, most notably remote reconfiguration and access under [RemoteUser](RemoteUser.md).
- [UserDatabase](UserDatabase.md) (C) -- Names the database table Interchange consults to verify passwords for HTTP Basic authentication.
- [ReadPermission](ReadPermission.md) (C) -- Sets who may read the files Interchange creates -- the read side of the umask it applies to generated session, cache, and data files.
- [WritePermission](WritePermission.md) (C) -- Controls the write bits on files Interchange creates -- whether they are writable only by the server's own user, by its group, or by everyone.
- [AlwaysSecure](AlwaysSecure.md) (C) -- Lists pages that must be served over a secure (HTTPS) connection, so that links Interchange generates to them use `SecureURL`.
- [AlwaysSecureGlob](AlwaysSecureGlob.md) (C) -- Marks pages as secure-only by wildcard pattern rather than by exact name, so whole directories or prefixes are served over HTTPS.
- [ExtraSecure](ExtraSecure.md) (C) -- Blocks non-HTTPS access to pages listed under [AlwaysSecure](AlwaysSecure.md).
- [WideOpen](WideOpen.md) (C) -- Disables the IP-address check that ties a session to the client that created it.
- [Promiscuous](Promiscuous.md) (C) -- Allows the [value](../tags/value.md) tag to emit raw HTML from user-supplied values instead of HTML-encoding it.
- [DNSBL](DNSBL.md) (G) -- Lists real-time DNS blocklist servers that Interchange queries to decide whether to reject a client by IP address.

## Order & checkout

- [Route](Route.md) (C) -- Defines a named *order route* -- a set of keyed attributes describing one way to process a submitted order (email it, log it, write it to tables, hand it to a payment service, and so on).
- [RouteDatabase](RouteDatabase.md) (C) -- Names a database table from which order-route attributes can be read at run time, so routes may be maintained as data rather than only in `catalog.cfg`.
- [DirectiveDatabase](DirectiveDatabase.md) (C) -- Loads catalog configuration directives from a database table at config time.
- [OrderProfile](OrderProfile.md) (C) -- Names the files that hold order-profile definitions -- the ordered checks and default settings applied when a form is submitted with a chosen profile.
- [Profiles](Profiles.md) (G) -- Loads files of order- and search-profile definitions and makes them available to every catalog on the server.
- [OrderReport](OrderReport.md) (C) -- Names the template file used to build the plain order report that is mailed to the store when a simple (non-route) order is placed.
- [OrderCounter](OrderCounter.md) (C) -- Names the file that holds and increments the running order number.
- [OrderCleanup](OrderCleanup.md) (C) -- Registers one or more subroutines to run after an order is placed, to tidy up whatever the checkout process left behind.
- [OrderLineLimit](OrderLineLimit.md) (C) -- Caps the number of separate line items a cart may hold.
- [AsciiTrack](AsciiTrack.md) (C) -- Names a file to which a formatted copy of each completed order report is appended, giving you a plain-text running log of orders.
- [Accounting](Accounting.md) (C) -- Configures the pluggable accounting back end that Interchange calls when customer and order data should be pushed into external accounting software (for example SQL-Ledger).
- [CartTrigger](CartTrigger.md) (C) -- Names Perl subroutines to invoke whenever the contents of a shopping cart change through Interchange's standard order processing.
- [CartTriggerQuantity](CartTriggerQuantity.md) (C) -- Controls whether a change to an existing cart item's quantity fires the subroutines named in [CartTrigger](CartTrigger.md).
- [ItemAction](ItemAction.md) (C) -- Maps a product code to a Perl subroutine that Interchange runs against each matching cart line when the cart is updated.
- [AutoModifier](AutoModifier.md) (C) -- Declares item attributes (modifiers) that Interchange fills in automatically from database columns when an item is added to the cart.
- [UseModifier](UseModifier.md) (C) -- Declares the item attributes (modifiers) that may be attached to each line item in the shopping cart, such as `size` or `color`.
- [SeparateItems](SeparateItems.md) (C) -- Controls whether ordering more than one of the same item adds a separate cart line for each, rather than bumping the quantity on a single line.
- [FractionalItems](FractionalItems.md) (C) -- Allows non-integer quantities in the shopping cart.
- [OnFly](OnFly.md) (C) -- Enables "on-the-fly" additions to the shopping cart -- items that are built from form data at add time instead of being looked up in a product table.
- [Options](Options.md) (C) -- Defines the named option types available to the item-options subsystem, and sets per-type configuration.
- [OptionsAttribute](OptionsAttribute.md) (C) -- Names the cart-line attribute that records which option type an item uses.
- [OptionsEnable](OptionsEnable.md) (C) -- Turns on Interchange's item-options subsystem and names the table and/or column that says which option type a product uses.
- [MaxQuantityField](MaxQuantityField.md) (C) -- Names database columns that hold the maximum order quantity allowed per item.
- [MinQuantityField](MinQuantityField.md) (C) -- Names a database column that holds the minimum order quantity required per item.
- **Profiles** (C) -- at catalog scope, an alias for [OrderProfile](OrderProfile.md); the global [Profiles](Profiles.md) directive is a separate directive with its own page.

## Payment & encryption

- [CreditCardAuto](CreditCardAuto.md) (C) -- Enables automatic encryption of credit card information submitted with an order.
- [EncryptKey](EncryptKey.md) (C) -- Specifies the default key (or key holder identity) used when Interchange encrypts data such as credit card numbers.
- [EncryptProgram](EncryptProgram.md) (B) -- Selects the external program Interchange uses to encrypt data such as credit card numbers.
- [PGP](PGP.md) (C) -- Enables automatic PGP/GPG encryption of the complete order report before it is mailed.

## Shipping & tax

- [Shipping](Shipping.md) (C) -- Defines named shipping modes and their settings in `catalog.cfg`, as an alternative (or complement) to the flat shipping file.
- [CustomShipping](CustomShipping.md) (C) -- Supplies an SQL `select` query that returns the rows Interchange uses to compute shipping costs, replacing the flat-file shipping table with a database query.
- [DefaultShipping](DefaultShipping.md) (C) -- Sets the shipping mode a new session starts with, by initializing the `mv_shipmode` value.
- [UpsZoneFile](UpsZoneFile.md) (C) -- Names the file of region-specific UPS zone data used to look up a shipping zone from the customer's postal code.
- [SalesTax](SalesTax.md) (C) -- Selects how Interchange calculates sales tax on an order: from a lookup table keyed by form fields, from a VAT-style multi-rate table, or from an Interchange Tag Language (ITL) expression.
- [SalesTaxFunction](SalesTaxFunction.md) (C) -- Supplies custom Perl that returns the sales-tax rate table, overriding the built-in table lookup.
- [NonTaxableField](NonTaxableField.md) (C) -- Names the product-table column that marks an item as exempt from sales tax.
- [TaxInclusive](TaxInclusive.md) (C) -- Treats displayed product prices as already including tax, so Interchange backs the tax out of the price instead of adding it on top.
- [TaxShipping](TaxShipping.md) (C) -- Names the shipping modes whose shipping cost is itself taxable, so tax is charged on shipping as well as on goods.
- [Levy](Levy.md) (C) -- Defines a named **levy** -- a charge added to an order, such as sales tax, shipping, handling, or a custom fee -- as a set of keyed settings.
- [Levies](Levies.md) (C) -- Lists which defined [Levy](Levy.md) sections are active for the catalog -- that is, which order-level charges (sales tax, shipping, handling, custom fees) the levy engine actually computes.

## Pricing & discounts

- [CommonAdjust](CommonAdjust.md) (C) -- Defines the catalog-wide default for Interchange's chained ("atom-based") pricing scheme -- the sequence of database lookups and adjustments used to compute an item's price.
- [PriceField](PriceField.md) (C) -- Names the database column Interchange reads an item's price from.
- [PriceDefault](PriceDefault.md) (C) -- Names the price field to use in a chained-pricing lookup when the field part of a `table:field:key` reference is left blank.
- [PriceDivide](PriceDivide.md) (C) -- Sets the number every raw price is divided by to get the displayed amount.
- [PriceCommas](PriceCommas.md) (C) -- Controls whether formatted prices include the locale's thousands separator.
- [DiscountSpacesOn](DiscountSpacesOn.md) (C) -- Enables the "discount spaces" feature, which lets a catalog keep several independent sets of discounts and switch between them per request or per cart.
- [DiscountSpaceVar](DiscountSpaceVar.md) (C) -- Lists the CGI variables checked, once per request, to decide which discount space is active.

## Search

- [Glimpse](Glimpse.md) (C) -- Points Interchange at the `glimpse` search binary and its options, enabling Glimpse-based full-text search for the catalog.
- [QueryCache](QueryCache.md) (C) -- Configures the query cache, a facility that stores the results of selected searches in a database table and serves them back over a lightweight URL (typically for AJAX callers) without building a full session.
- [SearchProfile](SearchProfile.md) (C) -- Names files that contain reusable search profile definitions.
- [MoreDB](MoreDB.md) (C) -- Stores search "more" paging data in a database session table instead of files in the scratch directory.
- [MoreDBTable](MoreDBTable.md) (C) -- Names the database table used to store search paging data when [MoreDB](MoreDB.md) is enabled.
- [NoSearch](NoSearch.md) (C) -- Names the database tables (or file names) that Interchange-style searches are not allowed to run against.
- [AllowRemoteSearch](AllowRemoteSearch.md) (C) -- Whitelists the database tables that a search submitted from the browser is allowed to target through the `mv_search_file` parameter.

## Page display & templating

- [SpecialPage](SpecialPage.md) (C) -- Maps Interchange's built-in "special" page roles (the basket, the search results page, the flypage, the various error pages) to the actual page files in your catalog.
- [AliasTable](AliasTable.md) (C) -- Names a database table that maps requested page paths to the real pages they should resolve to, letting you redirect or rewrite flypage-style URLs without a filesystem lookup.
- [DirectoryIndex](DirectoryIndex.md) (C) -- Names the default page Interchange tries when a request maps to a directory rather than a specific page.
- [HTMLsuffix](HTMLsuffix.md) (C) -- Sets the filename extension Interchange appends when it looks up a page on disk in the catalog's `pages/` directory.
- [PageTables](PageTables.md) (C) -- Lists database tables that Interchange should consult for page content before looking on disk.
- [PageTableMap](PageTableMap.md) (C) -- Maps the logical field names Interchange uses when reading pages from a database to the actual column names in your [PageTables](PageTables.md) tables.
- [PageSelectField](PageSelectField.md) (C) -- Names a `products` column that chooses which flypage template renders a given product.
- [Pragma](Pragma.md) (C) -- Sets the catalog-wide default value of an Interchange pragma -- a named switch that alters page-parsing and interpolation behavior.
- [XHTML](XHTML.md) (B) -- Makes Interchange emit XHTML-style self-closing tags -- adding the ` /` trailer to standalone elements it generates (`<br />`, `<img ... />`).
- [Filter](Filter.md) (C) -- Automatically runs named [filters](../filters/) over incoming CGI variables on every request, so their values are already cleaned up by the time your pages read them.
- [FormIgnore](FormIgnore.md) (C) -- Lists CGI variables that should *not* be copied from submitted form data into the Values space.
- [ImageDir](ImageDir.md) (C) -- Sets a base location that Interchange prepends to relative image paths found in a page's HTML.
- [ImageDirSecure](ImageDirSecure.md) (C) -- Sets the base location Interchange prepends to relative image paths when the page is being served over a secure (HTTPS) connection.
- [ImageDirInternal](ImageDirInternal.md) (C) -- Historically set the image base location used when Interchange's own built-in HTTP server served pages, rather than a front-end web server.
- [ImageAlias](ImageAlias.md) (C) -- Rewrites specific leading path fragments in image references on a served page, in the manner of a web-server `Alias`.
- [DeliverImage](DeliverImage.md) (C) -- Lets Interchange serve image files directly by redirecting to them under [ImageDir](ImageDir.md), before any session or database work happens.
- [MimeType](MimeType.md) (C) -- Maps filename extensions to MIME content types for files Interchange serves or mails.

## Internationalization

- [Locale](Locale.md) (B) -- Defines a named locale -- a set of key/value settings covering currency and number formatting plus message translations -- that Interchange can switch to at runtime.
- [LocaleDatabase](LocaleDatabase.md) (C) -- Loads locale settings for a catalog from a database table instead of (or in addition to) inline [Locale](Locale.md) directives.
- [DefaultLocale](DefaultLocale.md) (C) -- Names which of the catalog's configured locales is the default at startup.
- [ExecutionLocale](ExecutionLocale.md) (C) -- Sets the base system locale that Interchange re-applies on every page, so the daemon can never be left running under an unexpected locale.
- [UTF8](UTF8.md) (G) -- Enables server-wide UTF-8 handling: when on, Interchange treats configured character data as UTF-8 and applies encoding conversions.

## Logging & debugging

- [Logging](Logging.md) (G) -- Sets a verbosity threshold for extra request logging.
- [LogFile](LogFile.md) (C) -- Names the catalog's general-purpose log file -- the default destination for the [log](../tags/log.md) tag and other logged data.
- [LogTimeFormat](LogTimeFormat.md) (G) -- Sets the timestamp format used when Interchange writes entries to its logs.
- [ErrorFile](ErrorFile.md) (B) -- Names the log file that receives error messages.
- [ErrorDestination](ErrorDestination.md) (C) -- Routes selected error messages to their own log files, keyed by an error's tag or by its message text.
- [DisplayErrors](DisplayErrors.md) (B) -- Sends Interchange runtime errors to the visitor's browser in addition to the error log.
- [DebugFile](DebugFile.md) (G) -- Names the file that Interchange's `::logDebug()` output and (when enabled) Perl warnings are written to.
- [DebugHost](DebugHost.md) (C) -- Restricts `::logDebug()` output to requests coming from listed client IP addresses.
- [DebugTemplate](DebugTemplate.md) (G) -- Defines the format of each line written by `::logDebug()`, letting you prepend a timestamp and contextual fields (page, tag, host, and more) to the debug message.
- [DataTrace](DataTrace.md) (G) -- Sets the DBI trace level for Interchange's SQL database calls, sending the trace to the debug file.
- [ShowTimes](ShowTimes.md) (G) -- Adds process timing marks to the debug log at key points in request handling.
- [DumpAllCfg](DumpAllCfg.md) (G) -- Writes the fully expanded global server configuration to a file at startup, so you can see the effective `interchange.cfg` with all included files merged in.
- [DumpStructure](DumpStructure.md) (G) -- Writes the parsed data structure of the server and of each catalog to `.structure` files at configuration time, so you can inspect how every directive resolved.
- [Message](Message.md) (B) -- Prints a message to the console and the Interchange log while configuration is being read.
- [SysLog](SysLog.md) (G) -- Routes Interchange's global log output to the Unix system logger (syslog) instead of a flat file, and tunes the facility, tag, and per-level mapping used to do so.
- [CheckHTML](CheckHTML.md) (G) -- Names an external program that would validate a page's generated HTML, invoked where a page sets the `checkhtml` flag.
- [HitCount](HitCount.md) (G) -- Bumps a per-catalog counter file on every top-level access to the catalog.
- [TrackFile](TrackFile.md) (C) -- Names the user-tracking log file and, by being set, turns user tracking on.
- [TrackDateFormat](TrackDateFormat.md) (C) -- Sets the timestamp format used in the user-tracking log written by [TrackFile](TrackFile.md).
- [TrackPageParam](TrackPageParam.md) (C) -- Selects, per page, which CGI variables' values are written into the [TrackFile](TrackFile.md) user-tracking log.
- [UserTrack](UserTrack.md) (C) -- Controls whether Interchange emits the `X-Track` HTTP response header, which carries page-tracking data for the session.

## Email

- [MailOrderTo](MailOrderTo.md) (C) -- Sets the email address that completed order reports are sent to.
- [SendMailProgram](SendMailProgram.md) (B) -- Selects the program (or method) Interchange uses to send email such as order receipts and administrative notices.
- [SMTPConfig](SMTPConfig.md) (B) -- Supplies the connection settings Interchange uses when sending mail through `Net::SMTP` -- the host, port, authentication, and TLS options.

## Jobs

- [Jobs](Jobs.md) (B) -- Configures Interchange's batch **jobs** facility -- scheduled or on-demand runs of catalog pages executed outside a normal web request.

## Robots & traffic

- [RobotHost](RobotHost.md) (G) -- Lists hostname patterns that mark a visitor as a crawler (search-engine robot) so Interchange can skip session overhead for it.
- [RobotIP](RobotIP.md) (G) -- Lists IP addresses, ranges, or patterns that mark a visitor as a crawler (search-engine robot) so Interchange can skip session overhead for it.
- [RobotUA](RobotUA.md) (G) -- Lists user-agent patterns that mark a visitor as a crawler (search-engine robot) so Interchange can skip session overhead for it.
- [RobotLimit](RobotLimit.md) (C) -- Caps how many pages a client may fetch in quick succession before Interchange treats it as an abusive robot and locks it out.
- [NotRobotUA](NotRobotUA.md) (G) -- Lists user-agent strings that must never be classified as robots (crawlers or search-engine spiders).
- [LockoutCommand](LockoutCommand.md) (G) -- Specifies a shell command Interchange runs to lock out a client that has tripped robot/abuse detection.
- [DomainTail](DomainTail.md) (G) -- Controls whether only the tail (top-level portion) of a client's hostname is used when qualifying a session by host.
- [CountrySubdomains](CountrySubdomains.md) (G) -- Teaches Interchange about country-code top-level domains (ccTLDs) so that [DomainTail](DomainTail.md)-based visitor qualification uses the correct registrable domain for hosts under those TLDs.
- [HostnameLookups](HostnameLookups.md) (G) -- Controls whether Interchange resolves each visitor's IP address to a DNS hostname.
- [TrustProxy](TrustProxy.md) (G) -- Designates IP addresses or hostnames as trusted HTTP proxies, so that for requests coming from them Interchange believes the `X-Forwarded-For` header and uses the forwarded client address as the remote host.
- [BounceReferrals](BounceReferrals.md) (C) -- Redirects an incoming GET request that carries an affiliate/source code to the same URL with the code removed, so the visible URL is clean after the first hit.
- [BounceReferralsRobot](BounceReferralsRobot.md) (C) -- Strips the affiliate/source code from a GET request's URL -- as `BounceReferrals` does -- but only when the request comes from a client identified as a robot.
- [BounceRobotSessionURL](BounceRobotSessionURL.md) (C) -- Redirects a robot's GET request that carries an explicit `mv_session_id` to the same URL with the session ID removed.
- [SourceCookie](SourceCookie.md) (C) -- Enables a cookie that persists the visitor's source (affiliate) name across visits, and sets that cookie's name, lifetime, and scope.
- [SourcePriority](SourcePriority.md) (C) -- Lists, in priority order, the CGI variables (and special sources) Interchange checks to find the visitor's source, or affiliate, name.

## Miscellaneous & integration

- [Limit](Limit.md) (C) -- Sets numeric and behavioral limits that tune assorted Interchange subsystems -- cart quantities, list-text truncation, DBM open retries, robot/session expiry, and more.
- [External](External.md) (B) -- Enables Interchange to export selected global and catalog values to a file that external programs (in PHP, Python, Ruby, and so on) can read to share sessions and configuration.
- [ExternalExport](ExternalExport.md) (B) -- Selects which Perl values Interchange writes to the external structure file when [External](External.md) export is enabled.
- [ExternalFile](ExternalFile.md) (G) -- Sets the path of the file Interchange writes when [External](External.md) export is enabled.
- [SOAP](SOAP.md) (B) -- Enables Interchange's SOAP RPC server.
- [SOAP_Enable](SOAP_Enable.md) (C) -- Turns on individual SOAP-RPC features for a catalog.
- [SOAP_Action](SOAP_Action.md) (C) -- Defines named handlers a catalog exposes to remote SOAP callers.
- [SOAP_Control](SOAP_Control.md) (B) -- Grants or denies access to individual SOAP-RPC features (fetching values and scratch, reading databases, running tags, invoking named actions) on a per-subject basis.
- [SOAP_Socket](SOAP_Socket.md) (G) -- Lists the sockets Interchange listens on for SOAP-RPC requests.
- [SOAP_Perms](SOAP_Perms.md) (G) -- Sets the Unix filesystem permissions on the SOAP-RPC socket file that Interchange creates when SOAP listens on a Unix-domain socket.
- [SOAP_StartServers](SOAP_StartServers.md) (G) -- Sets how many SOAP-RPC server processes Interchange starts to handle SOAP requests.
- [SOAP_MaxRequests](SOAP_MaxRequests.md) (G) -- Sets how many SOAP-RPC requests one SOAP server process handles before it exits and is respawned.

## Aliases

Four directive names are aliases for canonical directives and share their
behavior; each is listed above under its canonical directive's group:

- **URL** -> [VendURL](VendURL.md) (catalog)
- **DataDir** -> [ProductDir](ProductDir.md) (catalog)
- **DefaultTables** -> [ProductFiles](ProductFiles.md) (catalog)
- **Profiles** (catalog scope) -> [OrderProfile](OrderProfile.md); note the
  distinct global [Profiles](Profiles.md) directive of the same name.
