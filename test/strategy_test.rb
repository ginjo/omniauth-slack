require 'helper'

class StrategyTest < StrategyTestCase
  include OAuth2StrategyTests
  
  test 'uses custom AuthHash subclass for auth_hash object' do
    ::OmniAuth::Strategy.class_eval do
      def auth_hash; {a:1, b:2}; end
    end
    assert_equal true, strategy.auth_hash.is_a?(OmniAuth::Slack::AuthHash)
  end
end

class ClientTest < StrategyTestCase
  test "has correct Slack site" do
    assert_equal "https://slack.com", strategy.client.site
  end

  test "has correct authorize url" do
    assert_equal "/oauth/v2/authorize", strategy.client.instance_eval{
      options[:authorize_url].is_a?(Proc) ? instance_eval(&options[:authorize_url]) : options[:authorize_url]
    }
  end

  test "has correct token url" do
    assert_equal "/api/oauth.v2.access", strategy.client.instance_eval{
      options[:token_url].is_a?(Proc) ? instance_eval(&options[:token_url]) : options[:token_url]
    }
  end

  test "has correct auth_scheme" do
    assert_equal :basic_auth, strategy.client.options[:auth_scheme]
  end
  
  test 'request logs api call' do
    # We need to manually stub the base #request method,
    # since we're testing the override in the subclassed Client.
    ::OAuth2::Client.class_eval do
      def request(*args)
        {'simple' => 'hash'}
      end
    end
    @client = strategy.client
    OmniAuth.logger.expects(:debug).with(){|*params| assert_match(/http:\/\/host\/api\/test.action/, params[0])}
    @client.request(:get, 'http://host/api/test.action')
  end
  
  test 'request adds api response to @history array' do
    # We need to manually stub the base #request method,
    # since we're testing the override in the subclassed Client.
    ::OAuth2::Client.class_eval do
      def request(*args)
        {'simple' => 'hash'}
      end
    end
    @client = strategy.client
    @client.history = []
    @client.request(:get, 'http://host/api/test.action')
    #assert_equal( {'test.action' => {'simple' => 'hash'}}, @client.history )
    #assert_equal( {'test.action' => {'simple' => 'hash'}}, strategy.send(:raw_info) )
    assert_equal( {'api_call' => 'test.action', 'response' => {'simple' => 'hash'}}, @client.history[0].to_h.tap{|r| r.delete('time')} )
    
  end
  
  test "transfers team_domain from strategy options to client.site uri" do
    @options = { :team_domain => 'subdomain' }
    assert_equal "https://subdomain.slack.com", strategy.client.site
  end
  
  test "transfers team_domain from request.params to client.site uri" do
    @options = {pass_through_params: 'team_domain' }
    @request.stubs(:params).returns({ 'team_domain' => 'subdomain2' })
    assert_equal "https://subdomain2.slack.com", strategy.client.site
  end
  
  test "transfers history option from strategy client_options to client.history" do
    @options = { :client_options => {history:[5]} }
    assert_equal [5], strategy.client.history
  end
end

class CallbackUrlTest < StrategyTestCase
  test "returns the default callback url" do
    url_base = "http://auth.request.com"
    @request.stubs(:url).returns("#{url_base}/some/page")
    strategy.stubs(:script_name).returns("") # as not to depend on Rack env
    assert_equal "#{url_base}/auth/slack/callback", strategy.callback_url
  end

  test "returns path from callback_path option" do
    @options = { :callback_path => "/auth/slack/done"}
    url_base = "http://auth.request.com"
    @request.stubs(:url).returns("#{url_base}/page/path")
    strategy.stubs(:script_name).returns("") # as not to depend on Rack env
    assert_equal "#{url_base}/auth/slack/done", strategy.callback_url
  end

  test "returns callback_url when setting script_name" do
    url_base = "http://auth.request.com"
    @request.stubs(:url).returns("#{url_base}/page/path")
    strategy.stubs(:script_name).returns("/foo") # as not to depend on Rack env
    assert_equal "#{url_base}/foo/auth/slack/callback", strategy.callback_url
  end
end

class UidTest < StrategyTestCase
  def setup
    super
    @access_token = stub("OmniAuth::Slack::OAuth2::AccessToken")
    #@access_token.stubs(:user_id).returns('U123')
    #@access_token.stubs(:team_id).returns('T456')
    strategy.stubs(:access_token).returns(@access_token)
  end

  test "returns the uid from access_token" do
    @access_token.stubs(:uid).returns("U123-T456")
    assert_equal "U123-T456", strategy.uid
  end
end

class CredentialsTest < StrategyTestCase
  def setup
    super
    @access_token = stub("OmniAuth::Slack::OAuth2::AccessToken")
    @access_token.stubs(:token)
    @access_token.stubs(:token_type)
    @access_token.stubs(:expires?)
    @access_token.stubs(:expires_at)
    @access_token.stubs(:refresh_token)
    @access_token.stubs(:[])
    @access_token.stubs(:params)
    @access_token.stubs(:is_app_token?)
    @access_token.stubs(:scope)
    @access_token.stubs(:scopes)
    @access_token.stubs(:all_scopes)
    @access_token.stubs(:user_token)
    strategy.stubs(:access_token).returns(@access_token)
  end

  test "returns a Hash" do
    assert_kind_of Hash, strategy.credentials
  end

  test "returns the token" do
    @access_token.stubs(:token).returns("123")
    assert_equal "123", strategy.credentials["token"]
  end
  
  test "returns the token_type" do
    @access_token.stubs(:token_type).returns('bot')
    assert_equal 'bot', strategy.credentials[:token_type]    
  end

  test "returns the expiry status" do
    @access_token.stubs(:expires?).returns(true)
    assert strategy.credentials["expires"]

    @access_token.stubs(:expires?).returns(false)
    refute strategy.credentials["expires"]
  end

  test "returns the refresh token and expiry time when expiring" do
    ten_mins_from_now = (Time.now + 600).to_i
    @access_token.stubs(:expires?).returns(true)
    @access_token.stubs(:refresh_token).returns("321")
    @access_token.stubs(:expires_at).returns(ten_mins_from_now)
    assert_equal "321", strategy.credentials["refresh_token"]
    assert_equal ten_mins_from_now, strategy.credentials["expires_at"]
  end

  test "does not return the refresh token when test is nil and expiring" do
    @access_token.stubs(:expires?).returns(true)
    @access_token.stubs(:refresh_token).returns(nil)
    assert_nil strategy.credentials["refresh_token"]
    refute_has_key "refresh_token", strategy.credentials
  end

  test "does not return the refresh token when not expiring" do
    @access_token.stubs(:expires?).returns(false)
    @access_token.stubs(:refresh_token).returns("XXX")
    assert_nil strategy.credentials["refresh_token"]
    refute_has_key "refresh_token", strategy.credentials
  end
end

# This test is no longer relevant, but if modified, it might still be useful.
#
# class SkipInfoTest < StrategyTestCase
# 
#   test 'info should not include extended info when skip_info is specified' do
#     @access_token = stub_everything("OmniAuth::Slack::OAuth2::AccessToken")
#     @options = { skip_info: true }
#     strategy.stubs(:access_token).returns(@access_token)
#     assert_equal %w(name email user_id team_name team_id image), strategy.info.keys.map(&:to_s)
#   end
# 
# end

class AuthorizeParamsTest < StrategyTestCase

  test 'returns OmniAuth::Strategy::Options hash' do
    assert_kind_of OmniAuth::Strategy::Options, strategy.authorize_params
  end
  
  test 'forwards oauth request params (redirect_uri scope team) to slack' do
    @options = {pass_through_params: %w(redirect_uri scope team)}
    strategy.request.params['scope'] = 'test-scope'
    strategy.request.params['team'] = 'test-team'
    strategy.request.params['redirect_uri'] = 'http://my-test-uri/auth/callback'
    assert_equal 'test-scope', strategy.authorize_params['scope']
    assert_equal 'test-team', strategy.authorize_params['team']
    assert_equal 'http://my-test-uri/auth/callback', strategy.authorize_params['redirect_uri']
  end
  
end

# class InitializeTest < StrategyTestCase
# end

class CallbackPhaseTest < StrategyTestCase
  def setup
    super
    strategy.stubs(:session).returns({'omniauth.authorize_params'=>{'team'=>'ABC123'}})
    strategy.stubs(:env).returns({})
    # Without this, OAuth2#callback_phase fails during these tests with csrf detected.
    strategy.stubs('fail!').returns(true)
  end
  
  test "sets env['omniauth.authorize_params'] with session['omniauth.authorize_params']" do
    strategy.callback_phase
    assert_equal( {'team'=>'ABC123'}, strategy.env['omniauth.authorize_params'] )
  end
end

class PassThroughParamsTest < StrategyTestCase
  test 'returns all AUTH_OPTIONS when given :all' do
    strategy.options.pass_through_params = :all
    assert_equal strategy.class::AUTH_OPTIONS, strategy.send(:pass_through_params)
  end
  
  test 'returns empty array when given :none' do
    strategy.options.pass_through_params = :none
    assert_equal [], strategy.send(:pass_through_params)
  end
  
  test "returns empty array when given nil" do
    strategy.options.pass_through_params = nil
    assert_equal [], strategy.send(:pass_through_params)
  end
  
  test "returns specific items when given specific items" do
    strategy.options.pass_through_params = %w(scope team_domain)
    assert_equal %w(scope team_domain), strategy.send(:pass_through_params)
  end
end

