## Module:

### Directives:

    Syntax:	 json_var $variable { ... }
    Default: ——
    Context: http, server, location

Creates a new variable whose value is a dumped json containing the items listed within the block.
Parameters inside the `json_var` block specify a field that should be included in the resulting json.
Each parameter has to contain two arguments - key and value.
The value can contain nginx variables.

If a field's value is exactly one of the embedded variables listed below, it is embedded as a raw
json value instead of being escaped as a json string. Fields whose value is empty are omitted from
the resulting json.

A nested location that does not declare its own `json_var` block inherits the fields of the closest
enclosing location that does.

### Embedded Variables:

Module supports embedded variables:

    $json_response_headers

returns response headers already set by the time the variable is evaluated, as dumped json.
Directives that run before headers are finalized (such as building a response body with `return`)
will only see headers set earlier in the same phase; reference it from a later directive (for
example a subsequent `add_header`) to see headers added before it.

    $json_headers

returns request headers as dumped json

    $json_cookies

returns cookies as dumped json

    $json_get_vars

returns get variables as dumped json

    $json_post_vars

returns post variables as dumped json (only in case of application/x-www-form-urlencoded,
application/json or multipart/form-data; for application/json the request body must be valid json,
otherwise the variable is null). The request body is only read if `$json_post_vars` is referenced
as a field inside a `json_var` block somewhere in the enclosing `http` block; if no `json_var`
block anywhere in that `http` block references it, using it directly (`return`, `log_format`, ...)
sees the request body as already discarded and the variable is null.

A header, cookie, get variable or post variable that appears more than once is rendered as a json
array of its values instead of a single string.
