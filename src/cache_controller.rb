require 'concurrent'
require_relative 'redis_client'
##
# Singleton class that provides access to a centralized cache used by the proxy.
# This class contains a 'global' cache storage object which the proxy can access only
# through the methods defined in the class.
#
# Communicates with a RedisClient class to populate the cache when a key is not
# already present in its cache.
#
# Enforces element expiry value set for the proxy and evicts elements using the
# Least-Recently-Used (LRU) algorithm when the cache has reached its defined capacity
#
# Nil is returned if there is the key provided returned no matches in the cache or Redis
class CacheController
  ONE_SECOND = 1000

  def self.init_controller(global_expiry,
                           fixed_key_limit,
                           redis_host,
                           redis_port)

    @global_expiry = global_expiry * ONE_SECOND
    @fixed_key_limit = fixed_key_limit
    @redis_host = redis_host
    @redis_port = redis_port

    @cache = nil
    @lock = Concurrent::ReadWriteLock.new
  end

  # Entry point for querying information from the cache.
  #
  # @param key [String] key used to query the cache
  # @return [String] the matching value found in cache or redis instance. Nil if no match was found in either
  def self.fetch(key)
    return "" if key.nil? || key.empty?
    if cache.key?(key) && (cache[key][:expiration_time] > Time.now.to_i)
      cache[key][:last_access_time] = Time.now.to_i
      @lock.with_read_lock do
        cache[key][:value]
      end
    else
      update_cache(key)
    end
  end

  # Called when key is not found in the cache and must query Redis.
  # Calls evict if the cache is full to clear memory for new element
  #
  # @param key [String] key used to query the cache
  # @return [String] the matching value found in cache or redis instance. Nil if no match was found in either
  def self.update_cache(key)
    redis_value = query_redis(key)
    unless redis_value.nil?
      evict if cache_keys_length == @fixed_key_limit
      add_to_cache(key, redis_value)
      return cache[key][:value]
    end
    redis_value
  end

  # Called when to create/replace an element in the cache.
  #
  # @param key [String] key to add to or update the cache
  # @param value [String] value associated with the key
  def self.add_to_cache(key, value)
    @lock.with_write_lock  do
      cache[key] = { value: value,
                     expiration_time: Time.now.to_i + @global_expiry,
                     last_access_time: Time.now.to_i }
    end
  end

  # Find the Least Recently Used item in the cache and remove it.
  def self.evict
    @lock.with_write_lock  do
      key_value_to_delete = cache.min_by { |item| item[1][:last_access_time] }
      cache.delete(key_value_to_delete[0])
    end
  end

  # Executes a query in Redis through a new RedisClient object
  #
  # @param key [String] key used to query the cache
  # @return [String] the matching value found in redis instance. Nil if no match was found.
  def self.query_redis(key)
    redis_client = RedisClient.new(@redis_host, @redis_port)
    redis_client.read(key)
  end

  # Utility method for querying the size of the cache.
  #
  # @return [Integer] the number of stored keys in the cache. 0 if cache is empty or uninitialized
  def self.cache_keys_length
    if @cache.nil?
      return 0
    else
      return cache.keys.length
    end
  end

  # Utility method for obtaining the cache object or initialize it to an empty hash
  #
  # @return [Hash] the cache object
  def self.cache
    @cache ||= Concurrent::Hash.new
  end

  # Traditionally, I would have made all non-externally called methods private.
  # To preserve my tests used for development, I decided not to
  #
  # private_class_method :update_cache
  # private_class_method :add_to_cache
  # private_class_method :evict
  private_class_method :query_redis
  private_class_method :cache
end
