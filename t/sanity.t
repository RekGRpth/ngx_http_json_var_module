# vi:ft=

use lib 'lib';
use Test::Nginx::Socket;

plan tests => repeat_each() * 2 * blocks();

no_long_string();

run_tests();

__DATA__

=== TEST 1: json_var embeds a well-formed application/json post body raw, without escaping it
--- main_config
    load_module /usr/local/lib/nginx/ngx_http_json_var_module.so;
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
    load_module /usr/local/lib/nginx/ngx_http_json_var_module.so;
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
    load_module /usr/local/lib/nginx/ngx_http_json_var_module.so;
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
    load_module /usr/local/lib/nginx/ngx_http_json_var_module.so;
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
    load_module /usr/local/lib/nginx/ngx_http_json_var_module.so;
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
    load_module /usr/local/lib/nginx/ngx_http_json_var_module.so;
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
    load_module /usr/local/lib/nginx/ngx_http_json_var_module.so;
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
    load_module /usr/local/lib/nginx/ngx_http_json_var_module.so;
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
    load_module /usr/local/lib/nginx/ngx_http_json_var_module.so;
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
    load_module /usr/local/lib/nginx/ngx_http_json_var_module.so;
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
    load_module /usr/local/lib/nginx/ngx_http_json_var_module.so;
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
    load_module /usr/local/lib/nginx/ngx_http_json_var_module.so;
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


