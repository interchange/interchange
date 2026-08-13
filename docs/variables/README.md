# Special variables

Interchange has two reserved variable namespaces that change how the server
behaves. This directory documents both.

- **`MV_*` (uppercase)** — behavior-modifying *variables*. You set most of them
  with a `Variable` line in `interchange.cfg` (global scope) or `catalog.cfg`
  (catalog scope); a few are maintained by the server at runtime and are
  read-only. Each has its own page here.
- **`mv_*` (lowercase)** — CGI/form *control* fields that steer form
  processing, searching, and ordering. These are not configured; they are
  submitted with requests. They share a single categorized overview:
  [mv-form-variables](mv-form-variables.md).

Reference a variable on a page with the [var](../tags/var.md) tag or the
`@_NAME_@` (catalog) / `@@NAME@@` (global) interpolation forms. The scope noted
on each page tells you where to set it. Related concepts live in the
[templating](../guides/templating.md) and
[configuration](../guides/configuration.md) guides.

## Runtime variables (set by the server; read-only)

| Variable | Purpose |
| --- | --- |
| [MV_PAGE](MV_PAGE.md) | Relative path of the current page, without suffix. |
| [MV_PREV_PAGE](MV_PREV_PAGE.md) | Relative path of the previous page, without suffix. |
| [MV_FILE](MV_FILE.md) | Filename of the most recently returned content. |
| [MV_SUBJECT](MV_SUBJECT.md) | Subject of the special page being interpolated. |

## Server and process

| Variable | Purpose |
| --- | --- |
| [MV_SESSION_READ_RETRY](MV_SESSION_READ_RETRY.md) | Retries when reading a session file (default 5). |
| [MV_BAD_LOCK](MV_BAD_LOCK.md) | Work around broken file locking so `-stop` works. |
| [MV_GETPPID_BROKEN](MV_GETPPID_BROKEN.md) | Use `syscall(64)` for the parent PID on threaded Linux Perl. |
| [MV_DOLLAR_ZERO](MV_DOLLAR_ZERO.md) | Base process name shown in `ps`/`top`. |

## Encoding and internationalization

| Variable | Purpose |
| --- | --- |
| [MV_UTF8](MV_UTF8.md) | Treat file, database, and response data as UTF-8. |
| [MV_HTTP_CHARSET](MV_HTTP_CHARSET.md) | Charset declared in the HTTP response. |
| [MV_EMAIL_CHARSET](MV_EMAIL_CHARSET.md) | Charset declared on outgoing email. |
| [MV_HTML4_COMPLIANT](MV_HTML4_COMPLIANT.md) | Join URL parameters with `&amp;`. |

## Security and user accounts

| Variable | Purpose |
| --- | --- |
| [MV_NO_CRYPT](MV_NO_CRYPT.md) | Disable crypt/MD5 password hashing (legacy). |
| [MV_USERDB_REMOTE_USER](MV_USERDB_REMOTE_USER.md) | Let any logged-in user override ACLs. |

## Page assembly

| Variable | Purpose |
| --- | --- |
| [MV_AUTOLOAD](MV_AUTOLOAD.md) | Text prepended to every top-level page. |
| [MV_AUTOEND](MV_AUTOEND.md) | Text appended to every top-level page. |

## Search

| Variable | Purpose |
| --- | --- |
| [MV_DEFAULT_SEARCH_DB](MV_DEFAULT_SEARCH_DB.md) | Default an unqualified search to the database. |
| [MV_DEFAULT_SEARCH_FILE](MV_DEFAULT_SEARCH_FILE.md) | Default file for text searches. |
| [MV_DEFAULT_SEARCH_TABLE](MV_DEFAULT_SEARCH_TABLE.md) | Default table for database searches. |
| [MV_DEFAULT_MATCHLIMIT](MV_DEFAULT_MATCHLIMIT.md) | Default results per page (default 50). |

## Product options, components, menus

| Variable | Purpose |
| --- | --- |
| [MV_OPTION_TABLE](MV_OPTION_TABLE.md) | Table holding product option data (default `options`). |
| [MV_OPTION_TABLE_MAP](MV_OPTION_TABLE_MAP.md) | Remap option field names to your columns. |
| [MV_COMPONENT_DIR](MV_COMPONENT_DIR.md) | Directory for component files. |
| [MV_COMPONENT_TABLE](MV_COMPONENT_TABLE.md) | Table for component definitions (default `component`). |
| [MV_MENU_DIRECTORY](MV_MENU_DIRECTORY.md) | Directory for menu files (default `include/menus`). |
| [MV_TREE_TABLE](MV_TREE_TABLE.md) | Table for hierarchical menu data (default `tree`). |

## Tax and geography

| Variable | Purpose |
| --- | --- |
| [MV_COUNTRY_FIELD](MV_COUNTRY_FIELD.md) | Values field holding the country code (order checks). |
| [MV_COUNTRY_TABLE](MV_COUNTRY_TABLE.md) | Country tax table (default `country`). |
| [MV_COUNTRY_TAX_FIELD](MV_COUNTRY_TAX_FIELD.md) | Country tax field (default `tax`). |
| [MV_STATE_TABLE](MV_STATE_TABLE.md) | State tax table (default `state`). |
| [MV_STATE_TAX_FIELD](MV_STATE_TAX_FIELD.md) | State tax field (default `tax`). |
| [MV_TAX_TYPE_FIELD](MV_TAX_TYPE_FIELD.md) | State tax type/name field (default `tax_name`). |
| [MV_TAX_CATEGORY_FIELD](MV_TAX_CATEGORY_FIELD.md) | Product tax-category field (default `tax_category`). |
| [MV_VALID_STATE](MV_VALID_STATE.md) | Override the valid US state list. |
| [MV_VALID_PROVINCE](MV_VALID_PROVINCE.md) | Override the valid Canadian province list. |
| [MV_STATE_REQUIRED](MV_STATE_REQUIRED.md) | Countries that require a state value. |
| [MV_ZIP_REQUIRED](MV_ZIP_REQUIRED.md) | Countries that require a postal code. |

## Shipping and order display

| Variable | Purpose |
| --- | --- |
| [MV_SHIP_MODIFIERS](MV_SHIP_MODIFIERS.md) | Extra item modifiers exposed to shipping. |
| [MV_SHIP_ADDRESS_TEMPLATE](MV_SHIP_ADDRESS_TEMPLATE.md) | Override the formatted-address template. |
| [MV_CREDIT_CARD_INFO_TEMPLATE](MV_CREDIT_CARD_INFO_TEMPLATE.md) | Override the encrypted card-info template. |
| [MV_ERROR_STD_LABEL](MV_ERROR_STD_LABEL.md) | Override the `error` tag's standard label markup. |

## Email

| Variable | Purpose |
| --- | --- |
| [MV_MAILFROM](MV_MAILFROM.md) | Default sender address for SMTP mail. |
| [MV_SMTPHOST](MV_SMTPHOST.md) | SMTP server host. |
| [MV_HELO](MV_HELO.md) | HELO string for SMTP. |
| [MV_EMAIL_INTERCEPT](MV_EMAIL_INTERCEPT.md) | Redirect all outgoing mail to a fixed address. |

## Miscellaneous

| Variable | Purpose |
| --- | --- |
| [MV_FORTUNE_COMMAND](MV_FORTUNE_COMMAND.md) | Command run by the `fortune` tag. |

## Payment

The core, gateway-independent payment variables have their own pages. Because
Interchange resolves payment parameters through `charge_param()`, **any**
payment parameter can also be supplied as a variable named `MV_PAYMENT_<NAME>`;
gateway-specific parameters are documented with each module under
[../payments/](../payments/README.md).

| Variable | Purpose |
| --- | --- |
| [MV_PAYMENT_MODE](MV_PAYMENT_MODE.md) | Selects the payment gateway/route. |
| [MV_PAYMENT_ID](MV_PAYMENT_ID.md) | Merchant/account identifier. |
| [MV_PAYMENT_SECRET](MV_PAYMENT_SECRET.md) | Gateway password/shared secret. |
| [MV_PAYMENT_CURRENCY](MV_PAYMENT_CURRENCY.md) | Currency code for charges. |
| [MV_PAYMENT_PRECISION](MV_PAYMENT_PRECISION.md) | Decimal precision of the amount (default 2). |
| [MV_PAYMENT_TEST](MV_PAYMENT_TEST.md) | Put the gateway in test mode. |

## Form and CGI control variables

The lowercase `mv_*` request-control fields (form actions, search, ordering,
payment fields) are indexed together in
[mv-form-variables](mv-form-variables.md).

## Removed and renamed variables

The following `MV_*` variables appear in historic documentation (the Akopia
`icvariables` manual and the xmldocs reference) but are **not consulted by the
current code**. They are listed here for upgraders; do not set them expecting an
effect.

| Variable | Status |
| --- | --- |
| `MV_PAYMENT_SERVER` | Removed. The old gateway-address variable; current gateway modules read a `host` parameter instead, i.e. `MV_PAYMENT_HOST` (see [MV_PAYMENT_MODE](MV_PAYMENT_MODE.md) for the `charge_param` mechanism). |
| `MV_CURRENCY` | Removed. Currency display is handled by locale settings and the `currency` filter/tag; no code reads this variable. |
| `MV_STATE_FIELD` | Removed. No current code reads it; state handling uses the order-check routines and [MV_STATE_REQUIRED](MV_STATE_REQUIRED.md) / [MV_VALID_STATE](MV_VALID_STATE.md). |
| `MV_DHTML_BROWSER` | Removed. The old DHTML browser-detection flag; no current code reads it. |
| `MV_ECML_FIELD_MAP` | Removed. The old ECML (Electronic Commerce Modeling Language) field map; no current code reads it. |

Additional advanced/internal `MV_*` names exist in the code (for example the
many gateway-specific `MV_PAYMENT_*` parameters, and `MV_COMPONENT_CACHE`,
`MV_ONFLY_FIELDS`, `MV_SU_KEY`). These are documented in context with the
subsystem or gateway that uses them rather than as standalone pages here.
