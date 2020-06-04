require 'socket'
require 'json'
require 'concurrent'
require_relative './cache_controller'

##
# Class that starts a new server to listen for incoming client requests for data in the cache.
#
# If the PROXY_ADDRESS and PROXY_PORT environment variables are set, the server will be bound to that
# address and port. Otherwise, the server will be bound using default values (i.e. 0.0.0.0 and 9090)
#
# All requests made to this server are handled in parallel. That is, subsequent client requests will
# be made to wait until the last client call is processed.
#
# Nil is returned if there is the key provided returned no matches in the cache or Redis
class WebServer
  SERVER_ADDRESS = ENV["PROXY_ADDRESS"] || '0.0.0.0'
  SERVER_PORT = ENV["PROXY_PORT"] || '9090'

  def initialize(global_expiry,
                 fixed_key_limit,
                 redis_host,
                 redis_port,
                 threads)

    raise StandardError.new("No address set for the proxy.") if SERVER_ADDRESS.nil?
    raise StandardError.new("No port set for the proxy.") if SERVER_PORT.nil?

    @pool = Concurrent::FixedThreadPool.new(threads)
    @server = TCPServer.open(SERVER_PORT)
    CacheController.init_controller(global_expiry, fixed_key_limit, redis_host, redis_port)

    puts "Started server at #{SERVER_ADDRESS}:#{SERVER_PORT}...."
  end

  # Start the server and listen for client requests indefinitely
  # returns result from cache to the calling client but the method will not return
  def start_server
    loop do
      socket = @server.accept
      @pool.post do
        request = socket.gets
        unless request.nil?
          response = fetch_data(request)
          socket.print  build_response(response)
          socket.print "\r\n"
          socket.print response[:message]
        end
        socket.close
      end
    end
  end

  private

  # Parses client request and executes query into the CacheController
  #
  # @param request [String] data provided by the client request
  # @return [String] a value found in cache or redis instance. Nil if no match was found in either
  def fetch_data(request)
    request_array = request.split(" ")
    method = request_array[0]
    key = request_array[1].split("/")[1]
    response = {}
    unless key.nil? || method != 'GET'
      begin
        value = CacheController.fetch(key)

        if value.nil?
          response = { status_code: 204, status_message: 'No Content',message: '', bytesize: 0 }
        else
          response = { status_code: 200, status_message: 'OK', message: value, bytesize: value.bytesize }
        end
      rescue Exception=>e
        response ={ status_code: 500, status_message: 'Internal Server Error', message: e.message, bytesize: e.message.nil? ? 0 : e.message.bytesize }
      end
    else
      message = "HTTP method #{method} for route /#{key} not supported at this time"
      response = { status_code: 404, status_message: 'Not Found', message: message.to_json, bytesize: message.bytesize }
    end
    return response
  end

  # Utility method to construct an HTTP response for the calling client request
  #
  # @param request [Hash] list of values to build the client response
  # @return [String] HTTP response that contains pertinent information about the result of the query.
  def build_response(response)
    "HTTP/1.1 #{response[:status_code]} #{response[:status_message]}\r\n" +
        "Content-Type: text/plain\r\n" +
        "Content-Length: #{response[:bytesize]}\r\n" +
        "Connection: close\r\n"
  end
end
