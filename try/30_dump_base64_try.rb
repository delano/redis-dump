require 'redis/dump'
require 'pry'

# The test instance of redis must be running:
# $ redis-server try/redis.conf

@uri_base = "redis://127.0.0.1:6371"

Redis::Dump.debug = false
Redis::Dump.safe = true
Redis::Dump.with_base64 = true

## Connect to DB
@rdump = Redis::Dump.new 0..1, @uri_base
@rdump.redis_connections.size
#=> 2

## Populate
@rdump.redis(0).set 'stringkey1', 'stringvalue1'
@rdump.redis(0).set 'stringkey2', 'stringvalue2'
@rdump.redis(0).keys.size
#=> 2

## Is base64 encoded
@values = @rdump.dump
@values[0]
#=> "{\"db\":0,\"key\":\"stringkey1\",\"ttl\":-1,\"type\":\"string\",\"value\":\"c3RyaW5ndmFsdWUx\\n\",\"size\":12}"

## Can dump
@values = @rdump.dump
@values.size
#=> 2

# Clear DB 0
db0 = Redis::Dump.new 0, @uri_base
db0.redis(0).flushdb
db0.redis(0).keys.size
#=> 0

## Can load data
@rdump.load @values.join
@rdump.redis(0).keys.size
#=> 2

## Is base64 decoded
stringkey = @rdump.redis(0).get('stringkey1')
#=> 'stringvalue1'

# Clear DB 0
db0 = Redis::Dump.new 0, @uri_base
db0.redis(0).flushdb
db0.redis(0).keys.size
#=> 0

Redis::Dump.safe = true
db0 = Redis::Dump.new 0, @uri_base
db0.redis(0).flushdb

