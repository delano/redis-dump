# encoding: UTF-8

require 'spec_helper'

describe Redis::Dump do

  before do
    Redis::Dump.debug = false
    Redis::Dump.safe = true
    @rdump = Redis::Dump.new 0
  end

  it 'should have one connection' do
    @rdump.redis_connections.size.should eq(1)
  end

  describe 'dump' do

    describe 'set' do
      before do
        @rdump.redis(0).set 'redis_dump:stringkey', 'stringvalue'
      end
      context 'without expire' do
        it 'should have value' do
          Yajl::Parser.parse @rdump.dump.first do |obj|
            obj['key'].should eq('redis_dump:stringkey')
            obj['value'].should_not be_empty
            obj['value'].should eq('stringvalue')
          end
        end
      end
      context 'with expire' do
        before do
          @rdump.redis(0).expire 'redis_dump:stringkey', 100
        end
        it 'should have ttl' do
          Yajl::Parser.parse @rdump.dump.first do |obj|
            obj['key'].should eq('redis_dump:stringkey')
            obj['value'].should_not be_empty
            obj['value'].should eq('stringvalue')
            obj['ttl'].should eq(100)
          end
        end
      end
    end

    describe 'zset' do
      context 'with one value' do
        before do
          @rdump.redis(0).zadd 'redis_dump:zsetkey', 100, 'value_0'
        end

        it 'should have values' do
          Yajl::Parser.parse @rdump.dump.first do |obj|
            obj['key'].should eq('redis_dump:zsetkey')
            obj['value'].should_not be_empty
            obj['value'].should eq([['value_0', 100.0]])
          end
        end
      end

      context 'with many value' do
        before do
          5.times { |idx| @rdump.redis(0).zadd 'redis_dump:zsetkey', idx.zero? ? 100 : 100*idx, "value_#{idx}" }
        end

        it 'should have values' do
          Yajl::Parser.parse @rdump.dump.first do |obj|
            obj['key'].should eq('redis_dump:zsetkey')
            obj['value'].should_not be_empty
            obj['value'].should eq([['value_0', 100.0], ['value_1', 100.0], ['value_2', 200.0], ['value_3', 300.0], ['value_4', 400.0]])
          end
        end
      end
    end

    describe 'hset' do
      before do
        @rdump.redis(0).hset 'redis_dump:hashkey', 'field_a', 'value_a'
        @rdump.redis(0).hset 'redis_dump:hashkey', 'field_b', 'value_b'
        @rdump.redis(0).hset 'redis_dump:hashkey', 'field_c', 'value_c'
      end

      it 'should have good value' do
        Yajl::Parser.parse @rdump.dump.first do |obj|
          obj['key'].should eq('redis_dump:hashkey')
          obj['value'].should_not be_empty
          obj['value'].should eq({"field_a"=>"value_a", "field_b"=>"value_b", "field_c"=>"value_c"})
        end
      end
    end

    describe 'rpush' do
      before do
        3.times { |idx| @rdump.redis(0).rpush 'redis_dump:listkey', "value_#{idx}" }
      end

      it 'should have good value' do
        Yajl::Parser.parse @rdump.dump.first do |obj|
          obj['key'].should eq('redis_dump:listkey')
          obj['value'].should_not be_empty
          obj['value'].should eq(["value_0", "value_1", "value_2"])
        end
      end
    end

    describe 'set' do
      before do
        4.times { |idx| @rdump.redis(0).sadd 'redis_dump:setkey', "value_#{idx}" }
      end

      it 'should have good value' do
        Yajl::Parser.parse @rdump.dump.first do |obj|
          obj['key'].should eq('redis_dump:setkey')
          obj['value'].should_not be_empty
          obj['value'].should eq(["value_3", "value_0", "value_1", "value_2"])
        end
      end
    end

  end
end
