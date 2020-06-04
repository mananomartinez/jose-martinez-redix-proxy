require 'socket'
require 'net/http'

class RedisProxyHelper

  REDIS_ADDRESS = ENV['REDIS_ADDRESS']
  REDIS_PORT = ENV['REDIS_PORT']
  PROXY_ADDRESS = ENV['PROXY_ADDRESS']
  PROXY_PORT = ENV['PROXY_PORT']
  
  def self.query_proxy(query)
    uri = URI("http://#{ENV['PROXY_ADDRESS']}:#{ENV['PROXY_PORT']}/#{query}")
    Net::HTTP.get(uri)
  end

  def self.populate_redis_multiple_keys(number_of_keys)
    (1..number_of_keys).each do | key_number |
      populate_redis("Key_#{key_number}", "Value_#{key_number}")
    end
  end

  def self.populate_redis(key, value)
    call_redis("SET #{key} #{value}")
  end

  def self.flush_redis
    call_redis('FLUSHALL')
  end

  def self.call_redis(command)
    `redis-cli -h #{ENV["REDIS_ADDRESS"]} -p #{ENV['REDIS_PORT']} #{command}`
  end

  def self.encode_redis_command(*cmd)
    resp_command = "*#{cmd.length}\r\n"
    cmd.each do |params|
      resp_command << "$#{params.bytesize}\r\n"
      resp_command << "#{params}\r\n"
    end
    resp_command
  end
end