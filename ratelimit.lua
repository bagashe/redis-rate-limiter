local config_identifier = KEYS[1]
local actor_identifier = KEYS[2]

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
