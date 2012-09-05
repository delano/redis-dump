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
    describe "zset" do
      context "with one value" do
        before do
          @rdump.redis(0).zadd 'redis_dump:zsetkey', 100, "value_0"
        end

        it 'should have values' do
          @values = @rdump.dump
          Yajl::Parser.parse @values.first do |obj|
            obj["value"].should_not be_empty
            obj['value'].should eq([["value_0", 100.0]])
          end
        end
      end

      context "with many value" do
        before do
          5.times { |idx| @rdump.redis(0).zadd 'redis_dump:zsetkey', idx.zero? ? 100 : 100*idx, "value_#{idx}" }
        end

        it 'should have values' do
          @values = @rdump.dump
          Yajl::Parser.parse @values.first do |obj|
            obj["value"].should_not be_empty
            obj['value'].should eq([["value_0", 100.0], ["value_1", 100.0], ["value_2", 200.0], ["value_3", 300.0], ["value_4", 400.0]])
          end
        end
      end
    end
  end
end
