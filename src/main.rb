#!/usr/bin/env ruby
require 'optparse'
require_relative 'web_server'

##
# Entry point for the proxy-application.
# Parses and validates the list of argument provided and starts the server if validation passes.
class RedisProxy
  def self.parse(args)
    options = { cache_capacity: nil, cache_expiry: nil, redis_host_address: nil, redis_port: nil, threads: 10 }

    parser = OptionParser.new do |opts|
      opts.banner = "Usage: main.rb [options]"

      opts.on('-r', '--redis_host_address redis_host_address', 'Host address for Redis backing instance') do |redis_host_address|
        options[:redis_host_address] = redis_host_address
      end

      opts.on('-p', '--port port', 'Port for Redis backing instance') do |redis_port|
        options[:redis_port] = redis_port
      end

      opts.on('-e', '--expiry seconds', 'Seconds to expire items in cache') do |cache_expiry|
        options[:cache_expiry] = cache_expiry
      end

      opts.on('-c', '--capacity capacity', 'Capacity of keys in cache') do |cache_capacity|
        options[:cache_capacity] = cache_capacity
      end

      opts.on('-t', '--threads threads', 'Number of parallel requests to process at one time. 10 is default') do |threads|
        options[:threads] = threads
      end

      opts.on('-h', '--help', 'Displays Help') do
        puts opts
        exit
      end
    end

    begin
      parser.parse(args)
      validate_options(options)

      redis_host_address = options[:redis_host_address]
      redis_port = options[:redis_port].to_i
      global_expiry = options[:cache_expiry].to_i
      fixed_key_limit = options[:cache_capacity].to_i
      threads = options[:threads].to_i

      server = WebServer.new(global_expiry, fixed_key_limit, redis_host_address, redis_port, threads)
      server.start_server()
    rescue SignalException => e
      STDERR.puts "Server stopped"
    rescue Exception => e
      STDERR.puts "Exception encountered"
      STDERR.puts e.message unless e.message.nil?
      exit 1
    end
    options
  end

  # Validates that the arguments have been provided at start time.
  # Raises StandardError if one or more arguments have not been defined.
  #
  # @param options [Hash] dictionary of arguments
  def self.validate_options(options)
    missing_values = [ ]
    options.each do | key, value |
      if value.nil?
        missing_values <<  key
      end
    end
    unless missing_values.empty?
      message = "\nThe following options are missing: #{missing_values.join(', ')}.\n"
      raise StandardError.new(message)
    end
  end

  ARGV << '-h' if ARGV.empty?
  RedisProxy.parse(ARGV)
end
