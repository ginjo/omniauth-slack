# :markup: tomdoc

require 'omniauth/strategies/oauth2'
require 'omniauth-slack/refinements'
require 'omniauth-slack/slack'
require 'omniauth-slack/omniauth/auth_hash'
require 'thread'
require 'uri'

module OmniAuth
  using Slack::OAuth2Refinements

  module Strategies

    # This is the OmniAuth strategy for Slack.
    # It is used as Rack middleware.
    #
    #     use OmniAuth::Builder do
    #       provider :slack, OAUTH_KEY, OAUTH_SECRET, options...
    #     end
    #
    class Slack < OmniAuth::Strategies::OAuth2
      include OmniAuth::Slack::Debug


      ###  Options  ###

      # Master list of authorization options handled by omniauth-slack.
      # See below for redirect_uri.
      #
      AUTH_OPTIONS = %i(scope user_scope team team_domain)

      debug{"#{self} setting up default options"}

      # Default strategy name
      option :name, 'slack'

      # Options that can be passed with provider authorization URL.
      option :authorize_options, AUTH_OPTIONS - %i(team_domain)

      # OAuth2::Client options.
      option :client_options, {
        access_token_class: OmniAuth::Slack::OAuth2::AccessToken,
        auth_scheme: :basic_auth,
        authorize_url: '/oauth/v2/authorize',
        history: Array.new,
        raise_errors: false, # MUST be false to allow Slack's get-token response from v2 API.
        site: 'https://slack.com',
        token_url: '/api/oauth.v2.access',
      }

      # Authorization token-exchange API call options.
      option :auth_token_params, {
        mode: :query,
        param_name: 'token'
      }


      ###  Omniauth Slack custom options  ###

      # redirect_uri does not need to be in authorize_options,
      # since it inserted anyway by omniauth-oauth2 during both
      # the request (authorization) phase and the callback (get-token) phase.
      # The magic of redirect_uri actually happens in the callback_url method.
      option :redirect_uri

      # Options allowed to pass from omniauth /auth/<provider> URL
      # to provider authorization URL.
      option :pass_through_params, %i(team)


      ###  Data  ###

      # User ID is not guaranteed to be globally unique across all Slack users.
      # The combination of user ID and team ID, on the other hand, is guaranteed
      # to be globally unique.
      #
      uid { access_token&.uid }


      # Gathers access_token and awarded scopes for :credentials section of AuthHash.
      #
      credentials do
        {
          token_type: access_or_user_token&.token_type,
          scope: access_or_user_token&.scope,
          scopes: access_or_user_token&.all_scopes,
          token: access_or_user_token&.token
        }
      end

      # Gathers a myriad of possible data returned from omniauth-slack /api/oauth.access call,
      # for `:info` section of AuthHash.
      # :markup: markdown
      #
      # You an modify the info hash from your application.
      # This example adds a users_info API request and response.
      # Note that this will automatically store Client request history,
      # if enabled. You do not need to link the auth-hash raw-info to
      # the Client history array (See notes in OmniAuth::Slack::OAuth2::Client).
      #
      # Example:
      #
      #   class OmniAuth::Strategies::Slack
      #     original_info = info.dup
      #     info do
      #       {
      #         access_token: instance_exec(&original_info),
      #         users_info: access_token.get('/api/users.info', params: {user: access_token.user_id}, headers: {'X-Slack-User' => (access_token.user_id)}).parsed
      #       }
      #     end
      #   end
      #
      info do
        {
          name: access_token.user_name
        }
        .merge access_token.to_hash
      end

      # Defines a section for all additional data to be
      # included with the AuthHash instance.
      #
      # for :extra section of AuthHash.
      #
      extra do
        {
          scopes_requested: scopes_requested,
          raw_info: raw_info
        }
      end


      ###  Instance Methods  ###

      # Wraps OmniAuth::Oauth2#authorize_params so that specified params
      # can be passed on to Slack authorization GET request.
      # See https://github.com/omniauth/omniauth/issues/390
      #
      def authorize_params
        super.tap do |prms|
          params_digest = prms.hash
          debug{"Using omniauth authorize_params #{prms}"}
          debug{"Considering request.params #{request.params}"}
          debug{"Considering pass_through_params #{pass_through_params}"}
          filtered_ptp = pass_through_params.reject{|o| o.to_s == 'team_domain'}
          filtered_rp  = request.params.reject{|k,v| !filtered_ptp.any?{|ptp| ptp.to_s == k.to_s}}
          debug{"Filtered request params #{filtered_rp}"}
          prms.merge! filtered_rp
          log(:debug, "Using modified authorize_params #{prms}") if prms.hash != params_digest
          session['omniauth.authorize_params'] = prms
        end
      end

      # Pre-sets env vars for super.
      #
      # OmniAuth callback phase to extract session var for
      # omniauth.authorize_params into env (this is how omniauth does this).
      #
      def callback_phase #(*args)
        # This technique copied from OmniAuth::Strategy,
        # (this is how they do it for other omniauth objects).
        env['omniauth.authorize_params'] = session.delete('omniauth.authorize_params')
        super
      end

      # Returns OmniAuth::Slack::AuthHash
      #
      # Super result is converted to plain hash first,
      # so AuthHash can do its recursive build magic.
      #
      def auth_hash
        OmniAuth::Slack::AuthHash.new super.to_hash
      end

      # Uses `OmniAuth::Slack::OAuth2::Client` to handle Slack-specific features.
      #
      # * Logs API requests with OmniAuth.logger.
      # * Allows passthrough of Slack team_domain.
      # * Enables/disables Client instance history.
      # * Allows use of OmniAuth::Slack::OAuth2::AccessToken.
      #
      # Returns instance of OmniAuth::Slack::OAuth2::Client.
      #
      def client
        @client ||= (
          team_domain = (pass_through_params.include?('team_domain') && request.params['team_domain']) ? request.params['team_domain'] : options.team_domain
          new_client = OmniAuth::Slack::OAuth2::Client.new(options.client_id, options.client_secret, deep_symbolize(options.client_options.merge({subdomain:team_domain})))

          debug{"Strategy #{self} using Client #{new_client} with callback_url #{callback_url}"}

          new_client
        )
      end

      # Dropping query_string from the default OmniAuth callback_url prevents
      # some errors in call to /api/oauth.[v2.]access.
      #
      def callback_url
        options.redirect_uri || full_host + script_name + callback_path
      end

      ### Possibly obsolete
      #
      #   def user_id
      #     # access_token['user_id'] || access_token['user'].to_h['id'] || access_token['authorizing_user'].to_h['user_id']
      #     access_or_user_token&.user_id
      #   end
      #
      #   def team_id
      #     access_token&.team_id
      #   end

      # Gets and decodes :pass_through_params option.
      #
      def pass_through_params
        ptp = [options.pass_through_params].flatten.compact
        case
          when ptp[0].to_s == 'all'
            options.pass_through_params = AUTH_OPTIONS
          when ptp[0].to_s == 'none'
            []
          else
            ptp
        end
      end

      # Parsed data returned from /slack/oauth.[v2.]access api call.
      #
      # Where does this actually go? Where is it used?
      #
      # Simplifying this to just 'access_token.to_hash' does not appear to
      # have any noticeable negative effect.
      #
      # Possibly obsolete
      #
      #   def auth
      #     @auth ||= access_token.to_hash
      #   end

      # Points to client @history, which is filled with API response objects.
      #
      def raw_info
        @raw_info ||= access_token.client.history
        debug{"Retrieved raw_info (size #{@raw_info.size}) (object_id #{@raw_info.object_id})"}
        @raw_info
      end

      # Gets 'authed_user' sub-token from main access token.
      #
      def user_token
        access_token&.user_token
      end

      # Gets main access_token, if valid, otherwise gets user_token, if valid.
      # Handles Slack v1 and v2 API (v2 is non-conformant with OAUTH2 spec).
      def access_or_user_token
        if access_token&.token
          access_token
        elsif user_token
          user_token
        else
          access_token
        end
      end

      def scopes_requested
        # omniauth.authorize_params is an enhancement to omniauth functionality for omniauth-slack.
        out = {
          scope: env['omniauth.authorize_params'].to_h['scope'],
          user_scope: env['omniauth.authorize_params'].to_h['user_scope']
        }

        debug{"scopes_requested: #{out}"}
        return out
      end

    end # Slack
  end # Strategies
end # OmniAuth

