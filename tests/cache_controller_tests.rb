require "minitest/autorun"
require 'mocha/minitest'
require_relative "../src/cache_controller.rb"
require_relative "../src/redis_client.rb"

describe "CacheController" do
  let (:redis_client) { mock(); }

  let (:global_expiry) { 10 }
  let (:fixed_key_limit) { 10 }
  let (:redis_host) { 'fakehost' }
  let (:redis_port) { 80 }

  let (:key_valid_1) { 'hello_1' }
  let (:redis_value_1) { 'world_1' }
  let (:key_valid_2) { 'hello_2' }
  let (:redis_value_2) { 'world_2' }
  let (:key_valid_3) { 'hello_3' }
  let (:redis_value_3) { 'world_3' }
  let (:key_invalid) { 'invalid' }

  before do
    CacheController.init_controller(global_expiry, fixed_key_limit, redis_host, redis_port)
    RedisClient.stubs(:new).returns(redis_client)
  end

  describe "fetch" do
    it "should return a new value from redis, not cache" do
      # redis_client must be called only once to populate the empty cache
      stub_redis_read(redis_value_1).once

      expect(CacheController.cache_keys_length).must_equal(0)
      expect(CacheController.fetch(key_valid_1)).must_equal(redis_value_1)
      expect(CacheController.cache_keys_length).must_equal(1)
    end

    it "should return nil if key not found in cache or redis" do
      # redis_client must be called only once and return nil
      stub_redis_read(nil).once

      expect(CacheController.cache_keys_length).must_equal(0)
      assert_nil(CacheController.fetch(key_valid_1))
    end

    it "should return a new value from cache, not redis" do
      # redis_client will only be called once for fetching the value
      # after initial population of the cache
      stub_redis_read(redis_value_1).once
      expect(CacheController.fetch(key_valid_1)).must_equal(redis_value_1)
      expect(CacheController.cache_keys_length).must_equal(1)

      #make another query to verify that the redis is not called again
      expect(CacheController.fetch(key_valid_1)).must_equal(redis_value_1)
      expect(CacheController.cache_keys_length).must_equal(1)
    end

    it "should query redis with expired cache element" do
      # redis client should be called twice because of element expiration
      stub_redis_read(redis_value_1).twice

      #query redis to populate cache with 1 element
      expect(CacheController.fetch(key_valid_1)).must_equal(redis_value_1)
      expect(CacheController.cache_keys_length).must_equal(1)

      # return time of expiration when querying for time.
      expire_time = Time.now.to_i + (global_expiry * 1000)
      Time.stubs(:now).returns(expire_time)

      expect(CacheController.fetch(key_valid_1)).must_equal(redis_value_1)
      expect(CacheController.cache_keys_length).must_equal(1)
    end

    it "should cause an eviction when the cache is full" do
      # Initialize cache capacity to 2 items
      CacheController.init_controller(10, 2, redis_host, redis_port)

      #populate cache with 2 elements and validate they are returned by the proxy.
      stub_redis_read(redis_value_1).once
      expect(CacheController.fetch(key_valid_1)).must_equal(redis_value_1)

      stub_redis_read(redis_value_2).once
      expect(CacheController.fetch(key_valid_2)).must_equal(redis_value_2)
      expect(CacheController.cache_keys_length).must_equal(2)

      #query for a 3rd element
      stub_redis_read(redis_value_3).once
      expect(CacheController.fetch(key_valid_3)).must_equal(redis_value_3)

      #verify that only 2 elements exist in the cache
      expect(CacheController.cache_keys_length).must_equal(2)
    end
  end

  describe "update_cache" do
    it "should add new key to cache" do
      stub_redis_read(key_valid_1).returns(redis_value_1).once

      #cache must be empty
      expect(CacheController.cache_keys_length).must_equal(0)
      CacheController.update_cache(key_valid_1)

      #cache should have one element
      expect(CacheController.cache_keys_length).must_equal(1)
    end

    it "should not add new key to cache if redis returns nil" do
      stub_redis_read(nil).once

      #check for empty cache
      expect(CacheController.cache_keys_length).must_equal(0)
      CacheController.update_cache(key_invalid)

      #check cache remains empty after updating with invalid key
      expect(CacheController.cache_keys_length).must_equal(0)
    end
  end

  describe "evict" do
    it "should evict 1 value" do
      # populate cache with 2 elements
      CacheController.add_to_cache(key_valid_1,redis_value_1)

      #ensure a different time stamp
      sleep(1)
      CacheController.add_to_cache(key_valid_2,redis_value_2)
      CacheController.evict()

      # validate there's only one element in the cache
      expect(CacheController.cache_keys_length).must_equal(1)
    end

    it "should evict only 1 value if 2 values have same last_access_time" do
      # ensure that two elements have the same time stamp
      current_time = Time.now
      Time.stubs(:now).returns(current_time)
      CacheController.add_to_cache(key_valid_1,redis_value_1)
      CacheController.add_to_cache(key_valid_2,redis_value_2)

      CacheController.evict()
      # one element should remain in the cache
      expect(CacheController.cache_keys_length).must_equal(1)
    end
  end
  
  def stub_redis_read(return_value)
    redis_client.stubs(:read).returns(return_value)
  end
end
