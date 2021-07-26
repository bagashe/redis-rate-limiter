#!/usr/bin/bash

# Assumes that redis-server is running on the same machine, listening to the default port.

# Set up configuration
redis-cli del api-access
redis-cli rpush api-access 100
redis-cli rpush api-access 3600
redis-cli rpush api-access 300

THREADS=$(nproc)
let THREADS=THREADS-1

SHA=`redis-cli SCRIPT LOAD "$(cat ratelimit.lua)"`
echo $SHA

redis-benchmark -n 1000000 -r 1000 --threads $THREADS evalsha $SHA api-access __rand_int__ , `date +%s`
