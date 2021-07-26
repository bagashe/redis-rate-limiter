local config_identifier = KEYS[1]
local actor_identifier = KEYS[2]

local config = redis.call('lrange', config_identifier, 0, -1)
if not next(config) then
  return redis.error_reply("No config found for event type - "..config_identifier)
end

local max_allowed = tonumber(config[1])
local over_interval = tonumber(config[2])
local lockout_interval = tonumber(config[3])
local expire_in = over_interval + lockout_interval

local t1 = tonumber(ARGV[1])
local bump_counter = 0
if nil ~= ARGV[2] then
  bump_counter = tonumber(ARGV[2])
end

local y = nil

local key = config_identifier..":"..actor_identifier
local tuple = redis.call('lrange', key, 0, -1)
-- Tuple format = {last_updated_score, last_updated_timestamp, last_blocked_timestamp}

if not next(tuple) then
  y = bump_counter
  if bump_counter > 0 then
    -- Update tuple only if an event has occurred.
    redis.call('rpush', key, y)
    redis.call('rpush', key, t1)
    redis.call('rpush', key, 0)
    redis.call('expire', key, expire_in)
  end
else
  y = tonumber(tuple[1])
  local t0 = tonumber(tuple[2])
  local b = tonumber(tuple[3])

  if t1 - b > lockout_interval then
    -- If not in the lockout interval since the last block
    -- Decay the old score (at t0) using the configured slope to compute the current value.
    y = y - (max_allowed / over_interval) * (t1 - t0)
    y = math.max(y, 0) -- Score cannot drop below 0.

    if bump_counter > 0 then
      -- Update tuple only if an event has occurred.
      y = y + bump_counter

      if y >= max_allowed then
        y = max_allowed -- Score cannot go above max_allowed.
        -- Set t1 as the last_blocked_timestamp
        redis.call('lset', key, 2, t1)
      end

      redis.call('lset', key, 0, y)
      redis.call('lset', key, 1, t1)
      redis.call('expire', key, expire_in)
    end
  end
end

return tostring(1.0 - y / max_allowed)
