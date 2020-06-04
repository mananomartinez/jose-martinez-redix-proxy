require 'net/telnet'

##
# Class to centralize communications with a Redis instance.
# This class uses the RESP protocol to query for data and transforms the information
# returned a simple string to the caller.
#
# An StandardError is raised if there are problems communicating with the redis instance.
# Nil is returned if there is the key used to query returned no matches in Redis

class RedisClient
  def initialize(address, port)
    begin
      @telnet = Net::Telnet.new("Host" => address,
                                 "Port"=> port,
                                 "Timeout" => 10)
    rescue Exception=>e
      raise StandardError.new("Could not connect with redis instance: #{e.message}")
    end
  end

  # Entry point for querying information from a Redis instance
  #
  # @param key [String] key used to query the Redis instance
  # @return [String] the matching value found in Redis or nil if no match was found
  def read(key)
    response = call_redis(key)
    decoded_response = decode_redis_response(response)
    unless decoded_response.nil?
      return decoded_response.chomp
    end
  end

  # Handle communication with Redis through simple TCP socket
  #
  # @param key [String] key used to query the Redis instance
  # @return [String] the matching value found in Redis or nil RESP equivalent if no match was found
  def call_redis(key)
    begin
      resp_query = "GET #{key}"
      @telnet.cmd(resp_query) { |response| @telnet.close; return response }
    rescue Exception=>e
      raise StandardError.new("There was a problem querying redis: #{e.message}")
    end
  end

  # Convert a command and its parameter list (i.e. 'GET' & key) into a RESP command
  #
  # @param cmd [String array] array of command and parameter to encode
  # @return [String] the equivalent RESP command for command and parameters
  def encode_redis_command(*cmd)
    resp_command = "*#{cmd.length}\r\n"
    cmd.each do |params|
      resp_command << "$#{params.bytesize}\r\n"
      resp_command << "#{params}\r\n"
    end
    resp_command
  end

  # Convert data from RESP format into a
  # raises StandardException if response contains an error message
  #
  # @param response [String array] array of command and parameter to encode
  # @return [String] the plain value returned from Redis or nil
  def decode_redis_response(response)
    raise StandardError.new(response) if response.start_with?('-')
    return nil if response == "$-1"

    if response.start_with?(':')
      response.scan(/\d+/).first.to_i
    else
      response.lines[1]
    end
  end
end