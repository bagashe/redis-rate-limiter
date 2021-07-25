--[[
A lua script extension for Redis that provides smooth, configurable & space-efficient rate limiting.

Configuration example:
	key = "api-access"
 	value = {"1000", "3600", "300"}
Each `actor` will be rate limited to `1000` `api-access` events per `3600 seconds`. Once the limit
is reached, the `actor` will be locked out for `300 seconds`. Note that the rate limit applies over
a rolling window.


This rate-limiting solution -
1. Does not use buckets & does not enumerate events. So it is space-efficient. It stores everything
in a three-tuple for each `actor`,`event` pair.
2. Uses a simple linear decay function to compute available quota. So it is blazing fast.
3. Can be easily configured to rate limit over a few seconds or a few hours or a few days.

Usage:
  evalsha <SHA> 2 api-access <actor-id> <current-timestamp-seconds-since-epoch>

The script returns the available quota as a fraction. So when the rate limit is reached, it
returns "0".

Performance:
  Measured on processor: Intel® Core™ i7-8550U CPU @ 1.80GHz × 8
	Using:
	  redis-benchmark -n 100000 evalsha <SHA> api-access `shuf -i 200-300 -n 1`, `date +%s`
	Results:
		116550.12 requests per second with 99% of them being served in under 0.6 ms

	Caveat: Client and server were running on the same host. Even so, it proves that performance of
this Lua script should not be an issue.

--]]

local config_identifier = KEYS[1]
local actor_identifier = KEYS[2]
local timestamp = tonumber(ARGV[1])

local config = redis.call('lrange', config_identifier, 0, -1)
if not next(config) then
	return redis.error_reply("No config found for event type - "..config_identifier)
end

local max_allowed = tonumber(config[1])
local over_interval = tonumber(config[2])
local lockout_interval = tonumber(config[3])

local t1 = tonumber(ARGV[1])
local y = nil

local key = config_identifier..":"..actor_identifier
local tuple = redis.call('lrange', key, 0, -1)
-- Tuple format = {last_updated_score, last_updated_timestamp, last_blocked_timestamp}

if not next(tuple) then
	y = 1
	redis.call('rpush', key, y)
	redis.call('rpush', key, t1)
	redis.call('rpush', key, 0)
else
	y = tonumber(tuple[1])
	local t0 = tonumber(tuple[2])
	local b = tonumber(tuple[3])

	if t1 - b > lockout_interval then
	-- If not in the lockout interval since the last block
		y = y - (max_allowed / over_interval) * (t1 - t0)

		if y < 0 then
			y = 0
		end

		y = y + 1

		if y > max_allowed then
			y = max_allowed
			-- Set t1 as the last_blocked_timestamp
		  redis.call('lset', key, 2, t1)
		end

		redis.call('lset', key, 0, y)
		redis.call('lset', key, 1, t1)
	end
end

return tostring(1.0 - y / max_allowed)
