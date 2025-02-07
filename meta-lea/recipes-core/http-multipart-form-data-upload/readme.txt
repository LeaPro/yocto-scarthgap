taken from example code @ https://www.boutell.com/cgic/

curl --trace=curl.trace -F http-multipart-form-data-upload=Submit -F file=@readme.txt http://192.168.1.185/http-multipart-form-data-upload.cgi

curl -v -F http-multipart-form-data-upload=Submit -F 'file=@cgic207.tar.gz' http://192.168.1.185/http-multipart-form-data-upload.cgi



CORS support requested by OutsideSource:

in lighttpd.conf:

$HTTP["url"] !~ "^/static/" {
    server.error-handler-404 = "/index.html"
    setenv.add-response-header = ( "Cache-Control" => "no-cache",
      "Access-Control-Allow-Origin" => "*", 
      "Access-Control-Allow-Headers" => "accept, origin, x-requested-with, content-type, x-transmission-session-id",
      "Access-Control-Expose-Headers" => "X-Transmission-Session-Id",
      "Access-Control-Allow-Methods" => "GET, POST, OPTIONS"
    )
}


wap@boyd:~/LEA/yocto-hardknott/build-beagleboneblack/postBuild$ curl -vv -X OPTIONS http://192.168.100.144/http-multipart-form-data-upload.cgi=Submit -H "Access-Control-Request-Method: POST" -H "Access-Control-Request-Headers: content-type" -H "Origin: https://xxxreqbin.com"
*   Trying 192.168.100.144:80...
* TCP_NODELAY set
* Connected to 192.168.100.144 (192.168.100.144) port 80 (#0)
> OPTIONS /http-multipart-form-data-upload.cgi=Submit HTTP/1.1
> Host: 192.168.100.144
> User-Agent: curl/7.68.0
> Accept: */*
> Access-Control-Request-Method: POST
> Access-Control-Request-Headers: content-type
> Origin: https://xxxreqbin.com
> 
* Mark bundle as not supporting multiuse
< HTTP/1.1 200 OK
< Allow: OPTIONS, GET, HEAD, POST
< Cache-Control: no-cache
< Access-Control-Allow-Origin: *
< Access-Control-Allow-Headers: accept, origin, x-requested-with, content-type, x-transmission-session-id
< Access-Control-Expose-Headers: X-Transmission-Session-Id
< Access-Control-Allow-Methods: *
< Content-Length: 0
< Date: Tue, 03 Aug 2021 20:33:38 GMT
< Server: lighttpd/1.4.59
< 
* Connection #0 to host 192.168.100.144 left intact
