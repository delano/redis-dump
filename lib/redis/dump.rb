unless defined?(RD_HOME)
  RD_HOME = File.expand_path(File.join(File.dirname(__FILE__), '..', '..') )
end

require 'redis'
require 'uri/redis'
require 'yajl'

class Redis
  class Dump
    unless defined?(Redis::Dump::VALID_TYPES)
      VALID_TYPES = ['string', 'set', 'list', 'zset', 'hash', 'none'].freeze
    end
    @host = '127.0.0.1'
    @port = 6379
    @debug = false
    @encoder = Yajl::Encoder.new
    @parser = Yajl::Parser.new
    @safe = true
    class << self
      attr_accessor :debug, :encoder, :parser, :safe, :host, :port
      def ld(msg)
        STDERR.puts "#{'%.4f' % Time.now.utc.to_f}: #{msg}" if @debug
      end
    end
    attr_accessor :dbs, :uri
    attr_reader :redis_connections
    def initialize(dbs=nil,uri="redis://#{Redis::Dump.host}:#{Redis::Dump.port}")
      @redis_connections = {}
      @uri = uri
      unless dbs.nil?
        @dbs = Range === dbs ? dbs : (dbs..dbs)
        @dbs = (@dbs.first.to_i..@dbs.last.to_i) # enforce integers
        open_all_connections
      end
    end
    def open_all_connections
      dbs.to_a.each { |db| redis(db) } unless dbs.nil?
    end
    def redis(db)
      redis_connections["#{uri}/#{db}"] ||= connect("#{uri}/#{db}")
    end
    def connect(this_uri)
      self.class.ld 'CONNECT: ' << this_uri
      Redis.connect :url => this_uri
    end
    
    # Calls blk for each key. If keys is nil, this will iterate over
    # every key in every open redis connection.
    # * keys (Array, optional). If keys is provided it must contain URI::Redis objects.
    def each_key(keys=nil, &blk)
      if keys.nil?
        @redis_connections.keys.sort.each do |redis_uri|
          self.class.ld ['---', "DB: #{redis_connections[redis_uri].client.db}", '---'].join($/)
          keys = redis_connections[redis_uri].keys
          keys.each do |key|
            blk.call redis_connections[redis_uri], key
          end
        end
      else
        keys.each do |key|
          unless URI::Redis === key
            raise Redis::Dump::Problem, "#{key} must be a URI::Redis object"
          end
          redis_uri = key.serverid
          if redis_connections[redis_uri].nil?
            raise Redis::Dump::Problem, "Not connected to #{redis_uri}"
          end
          blk.call redis_connections[redis_uri], key.key
        end
      end
    end
    
    # See each_key
    def dump(keys=nil, &each_record)
      values = []
      each_key(keys) do |this_redis,key|
        info = Redis::Dump.dump this_redis, key
        self.class.ld " #{key} (#{info['type']}): #{info['size'].to_bytes}"
        encoded = self.class.encoder.encode info
        each_record.nil? ? (values << encoded) : each_record.call(encoded)
      end
      values
    end
    def report(&each_record)
      values = []
      each_key do |this_redis,key|
        info = Redis::Dump.report this_redis, key
        self.class.ld " #{key} (#{info['type']}): #{info['size'].to_bytes}"
        each_record.nil? ? (values << info) : each_record.call(info)
      end
      values
    end
    def load(string_or_stream, &each_record)
      count = 0
      Redis::Dump.ld " LOAD SOURCE: #{string_or_stream}"
      Redis::Dump.parser.parse string_or_stream do |obj|
        unless @dbs.member?(obj["db"].to_i)
          Redis::Dump.ld "db out of range: #{obj["db"]}"
          next
        end
        this_redis = redis(obj["db"])
        Redis::Dump.ld "load[#{this_redis.hash}, #{obj}]"
        if each_record.nil? 
          if Redis::Dump.safe && this_redis.exists(obj['key'])
            Redis::Dump.ld " record exists (no change)"
            next
          end
          Redis::Dump.set_value this_redis, obj['key'], obj['type'], obj['value'], obj['ttl']
        else
          each_record.call obj
        end
        count += 1
      end
      count
    end
    module ClassMethods
      def type(this_redis, key)
        type = this_redis.type key
        raise TypeError, "Unknown type: #{type}" if !VALID_TYPES.member?(type)
        type
      end
      def report(this_redis, key)
        info = { 'db' => this_redis.client.db, 'key' => key }
        info['type'] = type(this_redis, key)
        info['size'] = stringify(this_redis, key, info['type'], info['value']).size
        info['bytes'] = info['size'].to_bytes
        ld "report[#{this_redis.hash}, #{info}]"
        info
      end
      def dump(this_redis, key)
        info = { 'db' => this_redis.client.db, 'key' => key }
        info['ttl'] = this_redis.ttl key
        info['type'] = type(this_redis, key)
        info['value'] = value(this_redis, key, info['type'])
        info['size'] = stringify(this_redis, key, info['type'], info['value']).size
        ld "dump[#{this_redis.hash}, #{info}]"
        info
      end
      def set_value(this_redis, key, type, value, expire=nil)
        t ||= type
        send("set_value_#{t}", this_redis, key, value)
        this_redis.expire key, expire if expire.to_s.to_i > 0
      end
      def value(this_redis, key, t=nil)
        t ||= type
        send("value_#{t}", this_redis, key)
      end
      def stringify(this_redis, key, t=nil, v=nil)
        t ||= type
        send("stringify_#{t}", this_redis, key, v)
      end
      
      def set_value_hash(this_redis, key, hash)
        hash.keys.each { |k|  this_redis.hset key, k, hash[k] }
      end
      def set_value_list(this_redis, key, list)
        list.each { |value|  this_redis.rpush key, value }
      end
      def set_value_set(this_redis, key, set)
        set.each { |value|  this_redis.sadd key, value }
      end
      def set_value_zset(this_redis, key, zset)
        zset.each { |pair|  this_redis.zadd key, pair[1].to_f, pair[0] }
      end
      def set_value_string(this_redis, key, str)
        this_redis.set key, str
      end
      def set_value_none(this_redis, key, str)
        # ignore
      end
      
      def value_string(this_redis, key)  this_redis.get key                                                       end
      def value_list  (this_redis, key)  this_redis.lrange key, 0, -1                                             end
      def value_set   (this_redis, key)  this_redis.smembers key                                                  end
      def value_zset  (this_redis, key)  this_redis.zrange(key, 0, -1, :with_scores => true).tuple                end
      def value_hash  (this_redis, key)  this_redis.hgetall(key)                                                  end
      def value_none  (this_redis, key)  ''                                                                       end
      def stringify_string(this_redis, key, v=nil)  (v || value_string(this_redis, key))                          end
      def stringify_list  (this_redis, key, v=nil)  (v || value_list(this_redis, key)).join                       end
      def stringify_set   (this_redis, key, v=nil)  (v || value_set(this_redis, key)).join                        end
      def stringify_zset  (this_redis, key, v=nil)  (v || value_zset(this_redis, key)).flatten.compact.join       end
      def stringify_hash  (this_redis, key, v=nil)  (v || value_hash(this_redis, key)).to_a.flatten.compact.join  end
      def stringify_none  (this_redis, key, v=nil)  (v || '')                                                     end
    end
    extend Redis::Dump::ClassMethods
    
    module VERSION
      def self.stamp
        @info[:STAMP].to_i
      end
      def self.owner
        @info[:OWNER]
      end
      def self.to_s
        [@info[:MAJOR], @info[:MINOR], @info[:PATCH], @info[:BUILD]].join('.')
      end
      def self.path
        File.join(RD_HOME, 'VERSION.yml')
      end
      def self.load_config
        require 'yaml'
        @info ||= YAML.load_file(path)
      end
      load_config
    end

    class Problem < RuntimeError
      def initialize(*args)
        @args = args.flatten.compact
      end
      def message() @args && @args.first end
    end
  end
end

class Array
  def chunk(number_of_chunks)
    chunks = (1..number_of_chunks).collect { [] }
    chunks.each do |a_chunk|
      a_chunk << self.shift if self.any?
    end
    chunks
  end
  alias / chunk
  def tuple(tuple_size=2)
    tuples = (1..(size/tuple_size)).collect { [] }
    tuples.each_with_index do |a_tuple,idx|
      tuple_size.times { a_tuple << self.shift } if self.any?
    end
    tuples
  end
end

class Numeric
  def to_ms
    (self*1000).to_i
  end

  # TODO: Use 1024?
  def to_bytes
    args = case self.abs.to_i
    when (1000)..(1000**2)
      '%3.2f%s' % [(self / 1000.to_f).to_s, 'KB']
    when (1000**2)..(1000**3)
      '%3.2f%s' % [(self / (1000**2).to_f).to_s, 'MB']
    when (1000**3)..(1000**4)
      '%3.2f%s' % [(self / (1000**3).to_f).to_s, 'GB']
    when (1000**4)..(1000**6)
      '%3.2f%s' % [(self / (1000**4).to_f).to_s, 'TB']
    else
      [self, 'B'].join
    end
  end
end
