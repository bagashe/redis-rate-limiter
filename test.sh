#!/usr/bin/bash

# Assumes that redis-server is running on the same machine, listening to the default port.

# Set up configuration
redis-cli del api-access
redis-cli rpush api-access 100
redis-cli rpush api-access 3600
redis-cli rpush api-access 300

echo "Test checking of available quota. Available quota should increase as we are not counting
events."
redis-cli --eval ./ratelimit.lua api-access 9999 , `date +%s` 10

for i in {1..100}
do
  redis-cli --eval ./ratelimit.lua api-access 9999 , `date +%s`
  sleep 1
done


# Observe stdout as the available quota goes down and bottoms out at 0.
echo "Test event counting and reduction in available quota."
for i in {1..100}
do
  redis-cli --eval ./ratelimit.lua api-access 999 , `date +%s` 1
  redis-cli ttl api-access:999
  sleep 1
done


