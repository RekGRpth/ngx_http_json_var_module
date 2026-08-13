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

