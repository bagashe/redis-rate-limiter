#!/usr/bin/bash

# Assumes that redis-server is running on the same machine, listening to the default port.

# Set up configuration
redis-cli del api-access
redis-cli rpush api-access 100
redis-cli rpush api-access 3600
redis-cli rpush api-access 300

# Observe stdout as the available quota goes down and bottoms out at 0.
for i in {1..100}
do
	redis-cli --eval ./ratelimit.lua api-access 999 , `date +%s`
	redis-cli ttl api-access:999
	sleep 1
done

