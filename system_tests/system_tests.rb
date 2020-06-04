require 'minitest/autorun'
require 'mocha/minitest'
require 'concurrent'
require_relative './helpers/redis_proxy_helper'

describe "Redis Proxy System Tests" do

  describe "basic usage test" do
    before do
      @key = "Key"
      @value = "Redis_value"
      RedisProxyHelper.populate_redis(@key, @value)
      puts 'Basic usage test'
    end

    describe "call proxy and get a valid response" do
      it "should call the proxy and get back an expected result" do
        result = RedisProxyHelper.query_proxy(@key)
        expect(result).must_equal(@value)
      end
    end

    after do
      RedisProxyHelper.flush_redis
    end
  end

  describe "tests for cache item expiration" do
    before do
      @key = "Key"
      @value = "Redis_value"
      RedisProxyHelper.populate_redis(@key, @value)
      puts 'Cache item expiration test'
    end

    it "call proxy obtain a value, wait for a 10 seconds and query again to retrieve from redis after it expires" do
      wait_time_seconds = 10
      result = RedisProxyHelper. query_proxy(@key)
      expect(result).must_equal(@value)

      sleep(wait_time_seconds)

      result = RedisProxyHelper.query_proxy(@key)
      expect(result).must_equal(@value)
    end

    it "call proxy obtain a value, wait for a 20 seconds and query again to retrieve from redis after it expires" do
      wait_time_seconds = 20
      result = RedisProxyHelper.query_proxy(@key)
      expect(result).must_equal(@value)

      sleep(wait_time_seconds)

      result = RedisProxyHelper. query_proxy(@key)
      expect(result).must_equal(@value)
    end

    after do
      RedisProxyHelper.flush_redis
    end
  end

  describe "stress test for fixed key size and LRU eviction" do
    before do
      @number_of_keys = 100
      RedisProxyHelper.populate_redis_multiple_keys(@number_of_keys)
      puts 'Cache size and eviction test'
    end

    it "call proxy to obtain 100 different values" do
      (1..@number_of_keys).each do | key_number |
        result = RedisProxyHelper. query_proxy("Key_#{key_number}")
        expect(result).must_equal("Value_#{key_number}")
      end
    end

    after do
      @number_of_keys = 0
      RedisProxyHelper.flush_redis
    end
  end

  describe "stress test for parallel requests" do
    before do
      @number_of_keys = 1000

      RedisProxyHelper.populate_redis_multiple_keys(@number_of_keys)
      puts 'Concurrent requests tests'
    end

    it "call proxy with 100 concurrent requests." do
      concurrent_requests = 100
      results = Concurrent::Array.new
      results = concurrent_calls(concurrent_requests, @number_of_keys)
      expect(results.compact.uniq.count).must_equal(@number_of_keys)
    end

    it "call proxy with 500 concurrent requests." do
      concurrent_requests = 500
      results = concurrent_calls(concurrent_requests, @number_of_keys)
      expect(results.compact.uniq.count).must_equal(@number_of_keys)
    end

    it "call proxy with 1000 concurrent requests." do
      concurrent_requests = 1000
      results = concurrent_calls(concurrent_requests, @number_of_keys)
      expect(results.compact.uniq.count).must_equal(@number_of_keys)
    end

    after do
      @number_of_keys = 0
      RedisProxyHelper.flush_redis
    end
  end

  def concurrent_calls(concurrent_requests, number_of_keys)
    results = Concurrent::Array.new
    begin
      pool = Concurrent::FixedThreadPool.new(concurrent_requests)
      (1..number_of_keys).each do |key_number|
        pool.post do
          result =  RedisProxyHelper.query_proxy("Key_#{key_number}")
          if result.nil?
            puts "Key_#{key_number} failed"
          end
          results << result
        end
      end
      pool.shutdown
      #wait for termination
      while !pool.shutdown?
        sleep(1)
      end
      results
    rescue Concurrent::RejectedExecutionError=>e
      puts e
    end
  end
end
