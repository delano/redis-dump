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
    @chunk_size = 10000
    @with_optimizations = true
    class << self
      attr_accessor :debug, :encoder, :parser, :safe, :host, :port, :chunk_size, :with_optimizations
      def ld(msg)
        STDERR.puts "#%.4f: %s" % [Time.now.utc.to_f, msg] if debug
      end
      def memory_usage
        `ps -o rss= -p #{Process.pid}`.to_i # in kb
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
        @dbs.to_a.each { |db| redis(db) } # open_all_connections
      end
    end
    def redis(db)
      redis_connections["#{uri}/#{db}"] ||= connect("#{uri}/#{db}")
    end
    def connect(this_uri)
      #self.class.ld 'CONNECT: ' << this_uri
      Redis.connect :url => this_uri
    end
    
    def each_database
      @redis_connections.keys.sort.each do |redis_uri|
        yield redis_connections[redis_uri]
      end
    end
    
    # See each_key
    def dump filter=nil
      filter ||= '*'
      entries = []
      each_database do |redis|
        chunk_entries = []
        dump_keys = redis.keys(filter)
        dump_keys_size = dump_keys.size
        Redis::Dump.ld "Memory after loading keys: #{Redis::Dump.memory_usage}kb"
        dump_keys.each_with_index do |key,idx|
          entry, idxplus = key, idx+1
          #self.class.ld " #{key} (#{key_dump['type']}): #{key_dump['size'].to_bytes}"
          #entry_enc = self.class.encoder.encode entry
          if block_given?
            chunk_entries << entry
            process_chunk idx, dump_keys_size do |count|
              Redis::Dump.ld " dumping #{chunk_entries.size} (#{count}) from #{redis.client.id}"
              output_buffer = []
              chunk_entries.select! do |key| 
                type = Redis::Dump.type(redis, key)
                if self.class.with_optimizations && type == 'string' 
                  true
                else
                  output_buffer.push self.class.encoder.encode(Redis::Dump.dump(redis, key, type))
                  false
                end
              end
              unless output_buffer.empty?
                yield output_buffer 
              end
              unless chunk_entries.empty?
                yield Redis::Dump.dump_strings(redis, chunk_entries) { |obj| self.class.encoder.encode(obj) } 
              end
              output_buffer.clear
              chunk_entries.clear
            end
          else
            entries << self.class.encoder.encode(Redis::Dump.dump(redis, entry))
          end
        end
      end
      entries
    end
    
    def process_chunk idx, total_size
      idxplus = idx+1
      yield idxplus if (idxplus % self.class.chunk_size).zero? || idxplus >= total_size
    end
    private :process_chunk
    
    def report filter='*'
      values = []
      total_size, dbs = 0, {}
      each_database do |redis|
        chunk_entries = []
        dump_keys = redis.keys(filter)
        dump_keys_size = dump_keys.size
        dump_keys.each_with_index do |key,idx|
          entry, idxplus = Redis::Dump.report(redis, key), idx+1
          chunk_entries << entry
          process_chunk idx, dump_keys_size do |count|
            Redis::Dump.ld " reporting on #{chunk_entries.size} (#{idxplus}) from #{redis.client.id}"
            chunk_entries.each do |e|
              #puts record if obj.global.verbose >= 1
              dbs[e['db']] ||= 0
              dbs[e['db']] += e['size']
              total_size += e['size']
            end
            chunk_entries.clear
          end
        end
      end
      puts dbs.keys.sort.collect { |db| "  db#{db}: #{dbs[db].to_bytes}" }
      puts "total: #{total_size.to_bytes}"
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
        #Redis::Dump.ld "load[#{this_redis.hash}, #{obj}]"
        if each_record.nil? 
          if Redis::Dump.safe && this_redis.exists(obj['key'])
            #Redis::Dump.ld " record exists (no change)"
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
        #ld "report[#{this_redis.hash}, #{info}]"
        info
      end
      def dump(this_redis, key, type=nil)
        type ||= type(this_redis, key)
        info = { 'db' => this_redis.client.db, 'key' => key }
        info['ttl'] = this_redis.ttl key
        info['type'] = type
        info['value'] = value(this_redis, key, info['type'])
        info['size'] = stringify(this_redis, key, info['type'], info['value']).size
        #ld "dump[#{this_redis.hash}, #{info}]"
        info
      end
      def dump_strings(this_redis, keys)
        vals = this_redis.mget *keys
        idx = -1
        keys.collect { |key|
          idx += 1
          info = { 
            'db' => this_redis.client.db, 'key' => key,
            'ttl' => this_redis.ttl(key), 'type' => 'string',
            'value' => vals[idx].to_s, 'size' => vals[idx].to_s.size
          }
          block_given? ? yield(info) : info
        }
      end
      def set_value(this_redis, key, type, value, expire=nil)
        t ||= type
        send("set_value_#{t}", this_redis, key, value)
        this_redis.expire key, expire if expire.to_s.to_i > 0
      end
      def value(this_redis, key, t=nil)
        send("value_#{t}", this_redis, key)
      end
      def stringify(this_redis, key, t=nil, v=nil)
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
        [@info[:MAJOR], @info[:MINOR], @info[:PATCH]].join('.')
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
