require 'hashie'
require 'omniauth/auth_hash'

module OmniAuth
  module Slack
    class AuthHash < OmniAuth::AuthHash
      include Hashie::Extensions::DeepFind
    end
  end
end
