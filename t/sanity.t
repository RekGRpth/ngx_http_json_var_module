# vi:ft=

use lib 'lib';
use Test::Nginx::Socket;

plan tests => repeat_each() * 2 * blocks();

no_long_string();

run_tests();

__DATA__

=== TEST 1: json_var embeds a well-formed application/json post body raw, without escaping it
--- main_config
    load_module /etc/nginx/modules/ngx_http_json_var_module.so;
--- config
    location /echo {
        json_var $log {
            post $json_post_vars;
        }
        return 200 $log;
    }
--- request eval
'POST /echo
' . '{"a":1,"b":[1,2,3],"c":{"d":"e"},"g":true,"h":null}'
--- more_headers
Content-Type: application/json
--- response_body chomp
{"post":{"a":1,"b":[1,2,3],"c":{"d":"e"},"g":true,"h":null}}


=== TEST 2: json_post_vars is null when the body is not valid JSON despite the Content-Type
--- main_config
    load_module /etc/nginx/modules/ngx_http_json_var_module.so;
--- config
    location /echo {
        json_var $log {
            post $json_post_vars;
        }
        return 200 $log;
    }
--- request eval
'POST /echo
' . 'not json at all'
--- more_headers
Content-Type: application/json
--- response_body chomp
{"post":null}


=== TEST 3: json_post_vars is null for a body engineered to break out of a surrounding JSON structure
--- main_config
    load_module /etc/nginx/modules/ngx_http_json_var_module.so;
--- config
    location /echo {
        json_var $log {
            post $json_post_vars;
        }
        return 200 $log;
    }
--- request eval
'POST /echo
' . '{"a":1},"admin":true,"x":{"a"'
--- more_headers
Content-Type: application/json
--- response_body chomp
{"post":null}


=== TEST 4: json_post_vars is null for a valid JSON value followed by trailing garbage
--- main_config
    load_module /etc/nginx/modules/ngx_http_json_var_module.so;
--- config
    location /echo {
        json_var $log {
            post $json_post_vars;
        }
        return 200 $log;
    }
--- request eval
'POST /echo
' . '{"a":1}extra'
--- more_headers
Content-Type: application/json
--- response_body chomp
{"post":null}


=== TEST 5: an injection attempt cannot inject a sibling key into the surrounding json_var output
--- main_config
    load_module /etc/nginx/modules/ngx_http_json_var_module.so;
--- config
    location /echo {
        json_var $log {
            post $json_post_vars;
            marker ok;
        }
        return 200 $log;
    }
--- request eval
'POST /echo
' . '{"a":1},"admin":true,"x":{"a"'
--- more_headers
Content-Type: application/json
--- response_body chomp
{"post":null,"marker":"ok"}


=== TEST 6: a location without json_post_vars is unaffected by a sibling location that uses it
--- main_config
    load_module /etc/nginx/modules/ngx_http_json_var_module.so;
--- config
    location /plain {
        return 200 plain;
    }
    location /echo {
        json_var $log {
            post $json_post_vars;
        }
        return 200 $log;
    }
--- request
GET /plain
--- response_body chomp
plain


=== TEST 7: a file-backed post body survives json_post_vars being evaluated twice (json_var's length + data passes)
--- main_config
    load_module /etc/nginx/modules/ngx_http_json_var_module.so;
--- config
    location /echo {
        client_body_buffer_size 1;
        json_var $log {
            post $json_post_vars;
        }
        return 200 $log;
    }
--- request eval
'POST /echo
' . '{"a":1,"b":"' . ('x' x 4000) . '"}'
--- more_headers
Content-Type: application/json
--- response_body eval
'{"post":{"a":1,"b":"' . ('x' x 4000) . '"}}'


=== TEST 8: json_post_vars parses application/x-www-form-urlencoded with a trailing charset parameter
--- main_config
    load_module /etc/nginx/modules/ngx_http_json_var_module.so;
--- config
    location /echo {
        json_var $log {
            post $json_post_vars;
        }
        return 200 $log;
    }
--- request
POST /echo
foo=bar&baz=qux
--- more_headers
Content-Type: application/x-www-form-urlencoded; charset=UTF-8
--- response_body chomp
{"post":{"foo":"bar","baz":"qux"}}


=== TEST 9: json_post_vars parses a standard multipart/form-data body
--- main_config
    load_module /etc/nginx/modules/ngx_http_json_var_module.so;
--- config
    location /echo {
        json_var $log {
            post $json_post_vars;
        }
        return 200 $log;
    }
--- request eval
"POST /echo\n" .
"--TESTBOUNDARY123\r\n" .
"Content-Disposition: form-data; name=\"foo\"\r\n" .
"\r\n" .
"bar\r\n" .
"--TESTBOUNDARY123\r\n" .
"Content-Disposition: form-data; name=\"baz\"\r\n" .
"\r\n" .
"qux\r\n" .
"--TESTBOUNDARY123--\r\n"
--- more_headers
Content-Type: multipart/form-data; boundary=TESTBOUNDARY123
--- response_body chomp
{"post":{"foo":"bar","baz":"qux"}}


=== TEST 10: json_post_vars accepts a boundary parameter with no space after the semicolon
--- main_config
    load_module /etc/nginx/modules/ngx_http_json_var_module.so;
--- config
    location /echo {
        json_var $log {
            post $json_post_vars;
        }
        return 200 $log;
    }
--- request eval
"POST /echo\n" .
"--TESTBOUNDARY123\r\n" .
"Content-Disposition: form-data; name=\"foo\"\r\n" .
"\r\n" .
"bar\r\n" .
"--TESTBOUNDARY123--\r\n"
--- more_headers
Content-Type: multipart/form-data;boundary=TESTBOUNDARY123
--- response_body chomp
{"post":{"foo":"bar"}}


=== TEST 11: json_post_vars accepts a quoted boundary value
--- main_config
    load_module /etc/nginx/modules/ngx_http_json_var_module.so;
--- config
    location /echo {
        json_var $log {
            post $json_post_vars;
        }
        return 200 $log;
    }
--- request eval
"POST /echo\n" .
"--TESTBOUNDARY123\r\n" .
"Content-Disposition: form-data; name=\"foo\"\r\n" .
"\r\n" .
"bar\r\n" .
"--TESTBOUNDARY123--\r\n"
--- more_headers
Content-Type: multipart/form-data; boundary="TESTBOUNDARY123"
--- response_body chomp
{"post":{"foo":"bar"}}


=== TEST 12: json_post_vars falls back to {} instead of erroring when multipart/form-data has no boundary parameter
--- main_config
    load_module /etc/nginx/modules/ngx_http_json_var_module.so;
--- config
    location /echo {
        json_var $log {
            post $json_post_vars;
        }
        return 200 $log;
    }
--- request eval
"POST /echo\n" . "irrelevant body"
--- more_headers
Content-Type: multipart/form-data; charset=utf-8
--- response_body chomp
{"post":{}}


=== TEST 13: json_cookies trims all leading spaces from a cookie name, not just one
--- main_config
    load_module /etc/nginx/modules/ngx_http_json_var_module.so;
--- config
    location /echo {
        return 200 $json_cookies;
    }
--- request
GET /echo
--- more_headers
Cookie: a=1;   b=2
--- response_body chomp
{"a":"1","b":"2"}


=== TEST 14: json_cookies handles a cookie pair with no '=' without corrupting parsing
--- main_config
    load_module /etc/nginx/modules/ngx_http_json_var_module.so;
--- config
    location /echo {
        return 200 $json_cookies;
    }
--- request
GET /echo
--- more_headers
Cookie: bar=baz; foo
--- response_body chomp
{"bar":"baz","foo":""}


=== TEST 15: $json_post_vars used directly (outside json_var) still sees the body when json_var uses it elsewhere in the http block
--- main_config
    load_module /etc/nginx/modules/ngx_http_json_var_module.so;
--- config
    location /direct {
        return 200 $json_post_vars;
    }
    location /viajsonvar {
        json_var $log {
            post $json_post_vars;
        }
        return 200 $log;
    }
--- request eval
'POST /direct
' . '{"a":1}'
--- more_headers
Content-Type: application/json
--- response_body eval
'{"a":1}'


=== TEST 16: json_headers dumps request headers as json
--- main_config
    load_module /etc/nginx/modules/ngx_http_json_var_module.so;
--- config
    location /echo {
        return 200 $json_headers;
    }
--- request
GET /echo
--- more_headers
X-Custom: myvalue
--- response_body_like: "Host":"[^"]+".*"X-Custom":"myvalue"


=== TEST 17: json_headers renders a repeated request header as a json array
--- main_config
    load_module /etc/nginx/modules/ngx_http_json_var_module.so;
--- config
    location /echo {
        return 200 $json_headers;
    }
--- request
GET /echo
--- more_headers
X-Dup: 1
X-Dup: 2
--- response_body_like: "X-Dup":\["1","2"\]


=== TEST 18: json_response_headers dumps response headers already set earlier in the same filter chain
--- main_config
    load_module /etc/nginx/modules/ngx_http_json_var_module.so;
--- config
    location /echo {
        add_header X-Test myvalue always;
        add_header X-Log $json_response_headers always;
        return 200 ok;
    }
--- request
GET /echo
--- response_headers_like
X-Log: ^\{"X-Test":"myvalue","Date":"[^"]+","Content-Type":"text/plain"\}$


=== TEST 19: json_get_vars url-decodes query string values and handles a bare key
--- main_config
    load_module /etc/nginx/modules/ngx_http_json_var_module.so;
--- config
    location /echo {
        return 200 $json_get_vars;
    }
--- request
GET /echo?a=hello%20world&b=x+y&c=%3D&bare
--- response_body chomp
{"a":"hello world","b":"x y","c":"=","bare":null}


=== TEST 20: json_get_vars renders a repeated query parameter as a json array
--- main_config
    load_module /etc/nginx/modules/ngx_http_json_var_module.so;
--- config
    location /echo {
        return 200 $json_get_vars;
    }
--- request
GET /echo?a=1&a=2
--- response_body chomp
{"a":["1","2"]}


=== TEST 21: json_var embeds $json_headers raw, not just json_post_vars
--- main_config
    load_module /etc/nginx/modules/ngx_http_json_var_module.so;
--- config
    location /echo {
        json_var $log {
            h $json_headers;
        }
        return 200 $log;
    }
--- request
GET /echo
--- more_headers
X-Custom: myvalue
--- response_body_like: ^\{"h":\{"Host":"[^"]+".*"X-Custom":"myvalue".*\}\}$


=== TEST 22: json_post_vars is null for a zero-length body
--- main_config
    load_module /etc/nginx/modules/ngx_http_json_var_module.so;
--- config
    location /echo {
        json_var $log {
            post $json_post_vars;
        }
        return 200 $log;
    }
--- request eval
'POST /echo
'
--- more_headers
Content-Type: application/json
Content-Length: 0
--- response_body chomp
{"post":null}


=== TEST 23: json_post_vars falls back to {} for an unsupported Content-Type
--- main_config
    load_module /etc/nginx/modules/ngx_http_json_var_module.so;
--- config
    location /echo {
        json_var $log {
            post $json_post_vars;
        }
        return 200 $log;
    }
--- request eval
'POST /echo
' . 'hello'
--- more_headers
Content-Type: text/plain
--- response_body chomp
{"post":{}}


=== TEST 24: json_post_vars parses a multipart field with extra Content-Disposition parameters
--- main_config
    load_module /etc/nginx/modules/ngx_http_json_var_module.so;
--- config
    location /echo {
        json_var $log {
            post $json_post_vars;
        }
        return 200 $log;
    }
--- request eval
"POST /echo\n" .
"--TESTBOUNDARY123\r\n" .
"Content-Disposition: form-data; name=\"file\"; filename=\"test.txt\"\r\n" .
"Content-Type: text/plain\r\n" .
"\r\n" .
"filecontent\r\n" .
"--TESTBOUNDARY123--\r\n"
--- more_headers
Content-Type: multipart/form-data; boundary=TESTBOUNDARY123
--- response_body chomp
{"post":{"file":"filecontent"}}


=== TEST 25: json_var rejects a second block for the same location
--- main_config
    load_module /etc/nginx/modules/ngx_http_json_var_module.so;
--- config
    location /echo {
        json_var $log1 { a b; }
        json_var $log2 { c d; }
        return 200 ok;
    }
--- request
GET /echo
--- must_die
--- error_log
is duplicate


=== TEST 26: json_var rejects a variable name without a leading $
--- main_config
    load_module /etc/nginx/modules/ngx_http_json_var_module.so;
--- config
    location /echo {
        json_var log { a b; }
        return 200 ok;
    }
--- request
GET /echo
--- must_die
--- error_log
invalid variable name


=== TEST 27: a nested location without its own json_var inherits the parent's fields
--- main_config
    load_module /etc/nginx/modules/ngx_http_json_var_module.so;
--- config
    location /outer {
        json_var $log {
            a hello;
        }
        location /outer/inner {
            return 200 $log;
        }
    }
--- request
GET /outer/inner
--- response_body chomp
{"a":"hello"}


=== TEST 28: json_post_vars correctly assembles a body that arrives across two reads
--- main_config
    load_module /etc/nginx/modules/ngx_http_json_var_module.so;
--- config
    location /echo {
        json_var $log {
            post $json_post_vars;
        }
        return 200 $log;
    }
--- raw_request eval
["POST /echo HTTP/1.1\r
Host: localhost\r
Content-Type: application/json\r
Content-Length: 20\r
Connection: close\r
\r
{\"a\":1,\"b\":",
"22222222}"]
--- raw_request_middle_delay: 0.5
--- response_body chomp
{"post":{"a":1,"b":22222222}}


