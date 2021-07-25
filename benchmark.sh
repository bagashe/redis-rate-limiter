#!/bin/sh

SHA=`redis-cli SCRIPT LOAD "$(cat ratelimit.lua)"`
echo $SHA

redis-benchmark -n 100000 evalsha $SHA api-access `shuf -i 200-300 -n 1`, `date +%s`
