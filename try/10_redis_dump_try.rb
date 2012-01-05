require 'redis/dump'

# The test instance of redis must be running:
# $ redis-server try/redis-server.conf

@uri_base = "redis://127.0.0.1:6371"

Redis::Dump.debug = false
Redis::Dump.safe = true

## Connect to DB
@rdump = Redis::Dump.new 0, @uri_base
@rdump.redis_connections.size
#=> 1

## Populate
@rdump.redis(0).set 'stringkey', 'stringvalue'
@rdump.redis(0).expire 'stringkey', 100
@rdump.redis(0).hset 'hashkey', 'field_a', 'value_a'
@rdump.redis(0).hset 'hashkey', 'field_b', 'value_b'
@rdump.redis(0).hset 'hashkey', 'field_c', 'value_c'
3.times { |idx| @rdump.redis(0).rpush 'listkey', "value_#{idx}" }
4.times { |idx| @rdump.redis(0).sadd 'setkey', "value_#{idx}" }
5.times { |idx| @rdump.redis(0).zadd 'zsetkey', idx.zero? ? 100 : 100*idx, "value_#{idx}" }
@rdump.redis(0).keys.size
#=> 5

## Can dump
@values = @rdump.dump
@values.size
#=> 5

# Clear DB 0
db0 = Redis::Dump.new 0, @uri_base
db0.redis(0).flushdb
db0.redis(0).keys.size
#=> 0

## Can load data
@rdump.load @values.join
@rdump.redis(0).keys.size
#=> 5

## DB 0 content matches previous dump content
values = @rdump.dump
values.sort
#=> @values.sort

## Won't load data in safe mode if records exist
@rdump.load @values.join
#=> 0

## Will load data if records exist and safe mode is disabled
Redis::Dump.safe = false
@rdump.load @values.join
#=> 5

Redis::Dump.safe = true
db0 = Redis::Dump.new 0, @uri_base
db0.redis(0).flushdb
