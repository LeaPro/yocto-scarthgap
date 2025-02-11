#!/bin/bash
# see http://dev.iachieved.it/iachievedit/exploring-img-files-on-linux/

if [ $(id -u) != "0" ]; then
    echo "You must be root to run this script" >&2
    exit 1
fi

rm -rf tmp
mkdir -p tmp
unzip build.zip -d tmp
mv tmp/build/index.html index.html.lighttpd 
rm -rf web-ui-1.0
mkdir -p web-ui-1.0/www/pages
mv -t web-ui-1.0/www/pages tmp/build/*
rm -rf tmp
tar -czf web-ui-1.0.tar.gz web-ui-1.0
rm -rf web-ui-1.0
