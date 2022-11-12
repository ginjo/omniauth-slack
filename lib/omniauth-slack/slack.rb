require 'uri'
require 'omniauth-slack/refinements'
require 'omniauth-slack/oauth2/client'
require 'omniauth-slack/oauth2/access_token'

require 'rack'
require 'json'

module OmniAuth
  module Slack

    # Build an access token from access-token-hash or from token-string.
    def self.build_access_token(client_id, client_key, token_string_or_hash)
      client = OmniAuth::Slack::OAuth2::Client.new(
        client_id,
        client_key,
        OmniAuth::Strategies::Slack.default_options.client_options.to_h.map{|k,v| [k.to_sym, v]}.to_h
      )

      access_token = case
        when token_string_or_hash.is_a?(String)
          OmniAuth::Slack::OAuth2::AccessToken.new(client, token_string_or_hash)
        when token_string_or_hash.is_a?(Hash)
          OmniAuth::Slack::OAuth2::AccessToken.from_hash(client, token_string_or_hash)
      end

      access_token
    end


    # Rack middleware to verify incoming slack request signature.
    #
    #   use OmniAuth::Slack::VerifySlackSignature
    #
    #   ENV ... TODO: Complete this section of required env variables.
    #   or consider having accepting a config block in the 'use' call.
    #
    class VerifySlackSignature
      include OmniAuth::Slack::Debug

      attr_accessor :app_id, :signing_secret

      def initialize(app)
        @app             = app
        @app_id          = nil
        @signing_secret  = nil

        middleware_instance = self

        if block_given?
          # Can set app_id and signing_secret from here.
          yield(middleware_instance)
        end
      end

      def call(env)
        @env = env
        @logger = logger = OmniAuth.logger

        debug{"calling middleware"}

        env['rack.input'].rewind
        body_string = env['rack.input'].read
        env['rack.input'].rewind

        debug{"VerifySlackSignature body_string: #{body_string}"}

        body_hash =
          begin
            body_string && JSON.load(body_string)
          rescue
            {}
          end

        if body_hash.to_a.size == 0
          debug{"not detecting JSON body"}
          pass

        else
          api_app_id      = body_hash['api_app_id']
          slack_signature = env['HTTP_X_SLACK_SIGNATURE']
          slack_timestamp = env['HTTP_X_SLACK_REQUEST_TIMESTAMP']

          if ! [api_app_id, slack_signature, slack_timestamp].all?
            logger.debug("(slack) VerifySlackSignature not detecting incoming Slack request")
            pass

          elsif signing_secret.to_s.empty?
            logger.info("(slack) VerifySlackSignature missing signing_secret")
            pass

          elsif app_id && app_id.to_s != api_app_id.to_s
            logger.info("(slack) VerifySlackSignature app_id mismatch")
            pass

          else
            computed_signature = 'v0=' + OpenSSL::HMAC.hexdigest(OpenSSL::Digest.new('sha256'), signing_secret, "v0:#{slack_timestamp}:#{body_string}").to_s
            rslt = (slack_signature == computed_signature)

            if rslt
              logger.info("(slack) VerifySlackSignature: #{rslt}")
            else
              logger.info("(slack) VerifySlackSignature: #{rslt}  (slack: #{slack_signature}, computed: #{computed_signature})")
            end

            pass rslt
          end
        end
      end

      def pass(result = nil)
        @env['omniauth.slack.verification'] = result
        debug{"set env omniauth.slack.verification to: #{result}"}
        @app.call(@env)
      end

    end  # VerifySlackSignature

  end
end
