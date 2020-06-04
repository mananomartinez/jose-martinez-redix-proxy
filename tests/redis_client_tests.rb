require "minitest/autorun"
require 'mocha/minitest'
require_relative "../src/redis_client.rb"
require 'net/telnet'

describe "RedisClient" do
  let (:redis_address) { 'localhost' }
  let (:redis_port) { 1234 }
  let (:command) { 'GET' }
  let (:key_string) { 'hello' }
  let (:key_integer) { 'number' }
  let (:key_value_string) { 'world' }
  let (:key_value_integer) { 99 }
  let (:valid_response) { "$#{key_value_string.length}\r\n#{key_value_string}\r\n" }
  let (:valid_respone_integer) { ":#{key_value_integer}\r\n" }

  let (:redis_command_expected ) { "*2\r\n$3\r\n#{command}\r\n$5\r\nworld\r\n" }
  let (:error_response) { '-ERROR failed'}
  let (:key_not_found_response) { '$-1'}
  let (:telnet) { mock() }
  let (:redis_client) {  }

  before do
    Net::Telnet.stubs(:new).returns(telnet)
    @redis_client = RedisClient.new(redis_address, redis_port)
  end

  describe "read" do
    before do
      telnet.stubs(:cmd).with(anything).returns(valid_response)
    end

    it "should return a valid response" do
      resp_command = @redis_client.read(key_string)
      expect(resp_command).must_equal(key_value_string)
    end
  end

  describe "decode_redis_response" do
    it "should return a valid string response" do
      parsed_value = @redis_client.decode_redis_response(valid_response)
      expect(parsed_value.strip).must_equal(key_value_string)
    end

    it "should return a valid integer response" do
      parsed_value = @redis_client.decode_redis_response(valid_respone_integer)
      expect(parsed_value).must_equal(key_value_integer)
    end

    it "should raise an exception when redis returns error" do
      assert_raises StandardError do
        @redis_client.decode_redis_response(error_response)
      end
    end

    it "should raise an exception when redis returns error" do
      assert_nil(@redis_client.decode_redis_response(key_not_found_response))
    end
  end
end