# mv_* form and CGI control variables

The lowercase `mv_*` namespace is a set of reserved CGI/form field names that
control how Interchange processes a submitted form: which action to run, how to
search, how to add items to the cart, and where to go next. You do not declare
them in configuration — you place them in forms (usually with the
[form](../guides/forms.md) family of tags) or on links, and the server acts on
them when the request arrives.

This page is a categorized index. The full behavior of each variable is
documented in the guide for its subsystem:

- form processing and actions — the [forms](../guides/forms.md) guide
- searching — the [search](../guides/search.md) guide
- carts and checkout — the [cart-and-checkout](../guides/cart-and-checkout.md)
  guide
- payments — the [payments](../guides/payments.md) guide

Do not confuse these with the uppercase `MV_*` variables, which are
behavior-modifying catalog/global settings you *do* declare in configuration —
see the [variables index](README.md).

## Form actions and dispatch

These drive the form-processing dispatcher (`lib/Vend/Dispatch.pm`).

| Variable | Purpose |
| --- | --- |
| `mv_action` | Names the action (URL action path) the request invokes. |
| `mv_todo` | The action verb for a submitted form (`refresh`, `submit`, `return`, `set`, `checkout`, ...). |
| `mv_doit` | Fallback action verb used when `mv_todo` is not set. |
| `mv_click` | Names one or more click routines (a `mv_click` "button") to run before the action. |
| `mv_check` | Names extra processing to run on the submission, like a named `mv_todo` hook. |
| `mv_nextpage` | Page to display after successful processing. |
| `mv_successpage` | Page to display on success (overrides `mv_nextpage` for success). |
| `mv_failpage` | Page to display when processing or validation fails. |
| `mv_orderpage` | Page to display for the ordering step. |
| `mv_form_profile` | Names the order-check profile to validate the form against. |
| `mv_individual_profile` | Per-field profile companion to `mv_form_profile`. |
| `mv_order_profile` | Names the profile used to validate a checkout. |
| `mv_arg` | Argument(s) passed to the invoked action. |
| `mv_nextpage`/`mv_ui` | UI/admin dispatch flags used by the admin interface. |
| `mv_session_id` | The session identifier carried with the request. |
| `mv_data_table`, `mv_data_key`, `mv_data_fields`, `mv_data_function`, `mv_data_file` | The table-editor set: which table, key, fields, and operation a form update performs. |

Fields whose names look like `mvNN_key` (a numeric infix) are gathered into
multi-value arrays by the dispatcher, which is how repeated form rows map to a
single logical field.

## Search

These are read by the search engine (`lib/Vend/Scan.pm` and the search back
ends). Each has a per-search meaning documented in the
[search](../guides/search.md) guide.

| Variable | Purpose |
| --- | --- |
| `mv_searchspec` | The search string (what to look for). |
| `mv_search_field` | The field(s) to search in. |
| `mv_search_file` | The file to search (text search). |
| `mv_searchtype` | The search type (`text` or `db`). |
| `mv_matchlimit` | Number of results per results page. |
| `mv_return_fields` | Fields to return for each match. |
| `mv_sort_field`, `mv_sort_option` | Result sort field(s) and options. |
| `mv_column_op`, `mv_numeric`, `mv_case`, `mv_substring_match`, `mv_negate`, `mv_orsearch`, `mv_coordinate` | Match operators controlling how each field is compared. |
| `mv_dict_look`, `mv_dict_end`, `mv_dict_limit`, `mv_dict_order`, `mv_dict_fold` | Dictionary/range (binary) search controls. |
| `mv_search_page` | Page used to display results. |
| `mv_search_label` | Label under which to store results (for multiple searches on a page). |
| `mv_search_immediate` | Run the search immediately rather than deferring. |
| `mv_more_matches`, `mv_more_id`, `mv_more_alpha`, `mv_more_decade`, `mv_more_permanent` | Controls for the "more" (paged results) list. |
| `mv_first_match`, `mv_next_pointer` | Paging pointers into a result set. |
| `mv_cache_key`, `mv_cache_price` | Search/result caching keys. |
| `mv_match_limit` | Historic spelling; the current engine uses `mv_matchlimit`. |
| `mv_no_session_id` | Suppress adding the session ID to generated search URLs. |

## Order and checkout processing

These control adding items to the cart and running an order. See the
[cart-and-checkout](../guides/cart-and-checkout.md) guide.

| Variable | Purpose |
| --- | --- |
| `mv_order_item` | The SKU(s) to add to the cart. |
| `mv_order_quantity` | Quantity for the added item(s). |
| `mv_item_option` | Option/variant selection(s) for the added item(s). |
| `mv_cartname` | Which cart to operate on (default is the main cart). |
| `mv_separate_items` | Order each item on its own cart line. |
| `mv_order_number` | The generated order number for a placed order. |
| `mv_order_route` | The route(s) to run when the order is submitted. |
| `mv_order_report` | The report page/template for the order. |
| `mv_shipmode` | Selected shipping mode. |
| `mv_handling` | Selected handling mode. |
| `mv_discount` | Item discount specification. |
| `mv_email` | Customer email captured with the order. |
| `mv_mi`, `mv_si`, `mv_ib`, `mv_pc` | Cart line addressing used by order lists — master-item index, sub-item index, cart (item body) name, and the price/quantity modifier code. |

## Payment and credit card

Submitted at checkout and consumed by the payment layer
(`lib/Vend/Order.pm`, `lib/Vend/Payment.pm`). See the
[payments](../guides/payments.md) guide.

| Variable | Purpose |
| --- | --- |
| `mv_credit_card_number` | Card number (not stored in the session; encrypted for the charge). |
| `mv_credit_card_type` | Card type (visa, mc, ...). |
| `mv_credit_card_exp_month`, `mv_credit_card_exp_year`, `mv_credit_card_exp_all` | Card expiry components. |
| `mv_credit_card_cvv2` | Card verification value (not stored in the session). |
| `mv_credit_card_info` | The assembled, encrypted card block. |
| `mv_credit_card_valid` | Result of card validation. |
| `mv_transaction_id` | Gateway transaction identifier. |

The template that assembles `mv_credit_card_info` is controlled by
[MV_CREDIT_CARD_INFO_TEMPLATE](MV_CREDIT_CARD_INFO_TEMPLATE.md). For security,
`mv_credit_card_number` and `mv_credit_card_cvv2` are on the dispatcher's ignore
list, so they are never written into the visitor's session.

## Notes

This index lists the commonly used control variables; the set is large and
some entries are specific to particular tags or admin pages. Treat the linked
guides as the authoritative, worked-example documentation for each variable.

## Source

Processed primarily in `lib/Vend/Dispatch.pm` (form actions), `lib/Vend/Scan.pm`
and the search back ends (search), and `lib/Vend/Order.pm` /
`lib/Vend/Payment.pm` (order and payment).
