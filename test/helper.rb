# Run all tests with
#   ruby -I./test test/test.rb
# or
#   rake test
# or run specific tests
#   ruby -I./test test/refinements_test.rb
#
$LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)
$LOAD_PATH.unshift File.expand_path('../support', __FILE__)

# Is specific require-bundler-setup needed?
#require 'bundler/setup'

require 'minitest/autorun'
# Must load after minitest-autorun.
require 'mocha/setup'

# Is explicit require-oauth2 still needed?
require 'oauth2'
require 'omniauth-slack'

# See below for require 'shared_examples' (needs to load after helpers).
#require 'shared_examples'



OmniAuth.config.test_mode = true
OmniAuth.logger.level = 1
ENV['OMNIAUTH_SLACK_DEBUG']='false'

module BlockTestHelper
  def test(name, &blk)
    method_name = "test_#{name.gsub(/\s+/, "_")}"
    raise "Method already defined: #{method_name}" if instance_methods.include?(method_name.to_sym)
    define_method method_name, &blk
  end
end

module CustomAssertions
  def assert_has_key(key, hash, msg = nil)
    msg = message(msg) { "Expected #{hash.inspect} to have key #{key.inspect}" }
    assert hash.has_key?(key), msg
  end

  def refute_has_key(key, hash, msg = nil)
    msg = message(msg) { "Expected #{hash.inspect} not to have key #{key.inspect}" }
    refute hash.has_key?(key), msg
  end
end

class TestCase < Minitest::Test
  extend BlockTestHelper
  include CustomAssertions
end

class StrategyTestCase < TestCase
  def setup
    @request = stub("Request")
    @request.stubs(:params).returns({})
    @request.stubs(:cookies).returns({})
    @request.stubs(:env).returns({})
    @request.stubs(:scheme).returns({})
    @request.stubs(:ssl?).returns(false)

    @client_id = "123"
    @client_secret = "53cr3tz"
    @options = {}
  end

  def strategy
    @strategy ||= begin
      args = [@client_id, @client_secret, @options].compact
      OmniAuth::Strategies::Slack.new(nil, *args).tap do |strategy|
        strategy.stubs(:request).returns(@request)
      end
    end
  end
end


## This needs to load after helpers.
require 'shared_examples'


## These are not used here anymore.

# Dir[File.expand_path("../support/**/*", __FILE__)].each(&method(:require))

# Dir[File.join("../", 'test', '*.rb')].each {|file| require file }

#require_relative 'support/shared_examples.rb'
#Dir[File.expand_path("../**/*.rb", __FILE__)].each(&method(:require))
