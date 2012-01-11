require 'redis/dump'

# The test instance of redis must be running:
# $ redis-server try/redis-server.conf

@uri_base = "redis://127.0.0.1:6371"

Redis::Dump.debug = false
Redis::Dump.safe = true

## Connect to DB
@rdump = Redis::Dump.new 0..1, @uri_base
@rdump.redis_connections.size
#=> 2

## Populate
3.times { |idx| @rdump.redis(0).set "gloria:#{idx}", "gloria_value[#{idx}]" }  # yp.ca
4.times { |idx| @rdump.redis(0).set "pamela:#{idx}", "pamela_value[#{idx}]" }  # soap web service
2.times { |idx| @rdump.redis(1).set "nikola:#{idx}", "nikola_value[#{idx}]" }  # m.yp.ca log analyzer
[@rdump.redis(0).keys.size, @rdump.redis(1).keys.size]
#=> [7, 2]

## Generate a list of keys
@keys = @rdump.redis(0).keys('*gloria*').collect { |key| URI.parse "#{@uri_base}/0/#{key}" }
@keys.push *@rdump.redis(1).keys('*nikola*').collect { |key| URI.parse "#{@uri_base}/1/#{key}" }
@keys.size
#=> 5

## Dump these specific keys
@rdump.dump('*gloria*').sort
#=> ['{"db":0,"key":"gloria:0","ttl":-1,"type":"string","value":"gloria_value[0]","size":15}','{"db":0,"key":"gloria:1","ttl":-1,"type":"string","value":"gloria_value[1]","size":15}','{"db":0,"key":"gloria:2","ttl":-1,"type":"string","value":"gloria_value[2]","size":15}']


## Dump none existent keys (NOT SUPPORTED AS OF 0.3.0)
unknown_keys = [URI.parse("#{@uri_base}/0/unknownkey1"), URI.parse("#{@uri_base}/1/unknownkey2")]
@rdump.dump(unknown_keys).sort
##=> ['{"db":0,"key":"unknownkey1","ttl":-1,"type":"none","value":"","size":0}', '{"db":1,"key":"unknownkey2","ttl":-1,"type":"none","value":"","size":0}']


Redis::Dump.safe = true
db0 = Redis::Dump.new 0..1, @uri_base
db0.redis(0).flushdb
db0.redis(1).flushdb