# get-url

Fetch the contents of a remote URL from within a page and return the
response body. Reach for it when a page or job needs to pull data from
another web service or site at render time.

## Syntax

    [get-url URL]
    [get-url url="URL" method=GET strip=1]

Standalone tag (no end tag). The tag body is interpolated as Interchange
Tag Language (ITL) before the request is made. The returned response body
is inserted into the page as-is (it is not reparsed as ITL).

## Attributes

| Attribute      | Default   | Description |
|----------------|-----------|-------------|
| `url`          | *(none)*  | The URL to fetch, including protocol (`http://`, `https://`, `ftp://`). Required. |
| `method`       | `GET`     | HTTP method; upper-cased before use. `POST` and `PUT` send a request body. |
| `timeout`      | *(none)*  | Request timeout, passed through `time_to_seconds` (so `30`, `2 min`, etc. are accepted). |
| `useragent`    | *(none)*  | Value for the outgoing `User-Agent` header. |
| `form`         | *(none)*  | A hash/parameter set that is form-encoded and used as the request content. |
| `content`      | *(none)*  | Raw request content. For `POST`/`PUT` it becomes the body; otherwise it is appended to the URL as a query string. |
| `content_type` | `application/x-www-form-urlencoded` | Content type used when a body is sent. |
| `headers`      | *(none)*  | Extra request headers, one `Name: value` pair per line. |
| `authuser`     | *(none)*  | Username for HTTP Basic authentication (used with `authpass`). |
| `authpass`     | *(none)*  | Password for HTTP Basic authentication. |
| `strip`        | *(none)*  | When true, strip everything up to and including `<body>` and everything from `</body>` on, leaving only the body markup. |
| `scratch`      | *(none)*  | If set, store the result in the named scratch variable and return nothing instead of emitting the body. |

Positional order: `url`.

## Description

`[get-url]` builds an `LWP::UserAgent` request and returns the response
content. On a successful response the response body is returned. On failure
the tag returns the literal string `Failed - ` followed by the HTTP status
line (for example `Failed - 404 Not Found`), so check the result rather
than assuming success.

The request is assembled as follows:

- `method` selects the HTTP verb (default `GET`).
- `form` is form-encoded (via `Vend::Interpolate::escape_form`) and used as
  the request content.
- For `POST` and `PUT`, `content` is sent as the request body with
  `content_type`. For other methods, `content` is appended to the URL as a
  query string (joined with `?` or `&` as appropriate).
- `headers` is split on line breaks; each `Name: value` line is added to the
  request.
- `authuser`/`authpass` add HTTP Basic authentication.

If `strip` is set, only the markup between `<body>` and `</body>` is kept.
If `scratch` is set, the content is stored in that scratch variable and the
tag returns the empty string.

## Examples

Fetch a page and insert it inline:

    [get-url http://demo.icdevgroup.org/]

Fetch a page but keep only its body markup:

    [get-url url="http://demo.icdevgroup.org/" strip=1]

Post form data to an API and stash the response for later use:

    [get-url
        url="https://api.example.com/lookup"
        method=POST
        form="`{ sku => '19-202', qty => 2 }`"
        scratch=api_result
    ]
    Result: [scratch api_result]

Add a custom header and a timeout:

    [get-url
        url="https://api.example.com/status"
        headers="Accept: application/json"
        timeout="10 sec"
    ]

## Notes

- Requires the `LWP::UserAgent` Perl module (and, for `https`, an SSL
  backend such as `LWP::Protocol::https`).
- Because the tag makes a blocking network call during page rendering, a
  slow or unreachable host delays the page. Set `timeout` and prefer running
  bulk fetches from a [jobs](../guides/jobs.md) page rather than a
  customer-facing page.
- A failed request returns text beginning with `Failed - `, not an empty
  string, so guard against inserting that into visible output.

## See also

- [tag](tag.md) and [mvasp](mvasp.md) for other ways to run server-side
  logic in a page
- [Jobs guide](../guides/jobs.md) for running fetches on a schedule

## Source

Defined in `code/UserTag/get_url.tag` (registers the tag `get-url`).
Implemented by an inline Routine using `LWP::UserAgent`.
