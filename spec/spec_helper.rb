# encoding: UTF-8

require File.expand_path('../../lib/redis/dump.rb',  __FILE__)

RSpec.configure do |config|
  def clean_redis
    keys = Redis.current.keys("redis_dump:*")
    Redis.current.del(*keys) if keys.any?
  end

  config.before(:suite) do
    clean_redis
  end

  config.after(:suite) do
    clean_redis
  end
end
