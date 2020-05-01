require 'omniauth/strategies/oauth2'
require 'omniauth-slack/refinements'
require 'omniauth-slack/slack'
require 'omniauth-slack/data_methods'
require 'omniauth-slack/omniauth/auth_hash'
require 'thread'
require 'uri'

module OmniAuth
  #using Slack::OmniAuthRefinements
  using Slack::OAuth2Refinements
  
  module Strategies
    class Slack < OmniAuth::Strategies::OAuth2
      include OmniAuth::Slack::DataMethods
    
      class AuthHash < OmniAuth::Slack::AuthHash;
      end
    
      debug{"#{self} setting up default options"}
      
      # Master list of authorization options handled by omniauth-slack.
      AUTH_OPTIONS = %w(redirect_uri scope team team_domain )
      
      # Default strategy name.
      option :name, 'slack'
      
      # Options that can be passed with provider authorization URL.
      option :authorize_options, AUTH_OPTIONS - %w(team_domain)
      
      # Options allowed to pass from omniauth /auth/<provider> URL
      # to provider authorization URL.
      option :pass_through_params, ['team']
      
      # TODO: Should this be in DataMethods module?
      #       Maybe, since you almost always want a default of 0
      #       and since the method is defined in DataMethods.
      option :preload_data_with_threads, 0
      
      # Define additional data-methods to be called on
      # successful authorization.
      option :additional_data
      
      # Describes which data-methods are gated. Only these data-methods
      # can be controlled by the :dependencies option.
      # 
      # This is generally not a setting that the user should be changing.
      # The user should adjust the :dependencies option instead.
      option :dependency_filter, /^api_/
      
      # Describes which data-methods are called and in what order.
      # Gated data-methods that are ommitted from this list (by the user)
      # will not be called.
      option :dependencies

      # OAuth2::Client options.
      option :client_options, {
          site: 'https://slack.com',
          authorize_url: '/oauth/v2/authorize',
          token_url: '/api/oauth.v2.access',
          auth_scheme: :basic_auth
      }
      
      # Authorization token-exchange API call options.
      option :auth_token_params, {
        mode: :query,
        param_name: 'token'
      }
      
      # User ID is not guaranteed to be globally unique across all Slack users.
      # The combination of user ID and team ID, on the other hand, is guaranteed
      # to be globally unique.
      uid { "#{user_id}-#{team_id}" }

      # Gathers access_token and awarded scopes.
      credentials do
        {
          token_type: access_token['token_type'],
          scope: access_token['scope'],
          scopes: access_token.all_scopes
        }
      end

      # Gathers a myriad of possible data returned from omniauth-slack /api/oauth.access call.
      info do        
        num_threads, method_names = options.preload_data_with_threads
        if num_threads.to_i > 0
          preload_data_with_threads(num_threads.to_i, method_names || dependencies + options.additional_data.to_h.keys)
        end
     
        # Start with only what we can glean from the authorization response.
        hash = OmniAuth::Slack::Hashy.new(
          name: user_name,
          email: user_email,
          user_id: user_id,
          team_id: team_id,
          team_name: team_name,
          team_domain: team_domain,
          team_image: team_image,
          team_email_domain: team_email_domain,
          nickname: nickname,
          image: image
        )

        # Disabled to manually define info.
        # TODO: This might be obsoldete now?
        #apply_data_methods(hash)

        # Adds data from api_users_info and/or api_users_profile, if allowed by scope and other settings.
        unless skip_info?
          %w(first_name last_name phone skype avatar_hash real_name real_name_normalized).each do |key|
            hash[key.to_sym] = (
              api_users_info['user'].to_h['profile'] ||
              api_users_profile['profile']
            ).to_h[key]
          end

          %w(deleted status color tz tz_label tz_offset is_admin is_owner is_primary_owner is_restricted is_ultra_restricted is_bot has_2fa).each do |key|
            hash[key.to_sym] = api_users_info['user'].to_h[key]
          end
        end
        
        hash
      end # info

      # Gathers additiona API calls, user-defined additional_data method responses, and raw Slack API responses.
      extra do
        {
          # scopes_requested: (env['omniauth.params'] && env['omniauth.params']['scope']) || \
          #   (env['omniauth.strategy'] && env['omniauth.strategy'].options && env['omniauth.strategy'].options.scope),
          scopes_requested: scopes_requested,
          web_hook_info: web_hook_info,
          bot_info: access_token['bot'] || api_bots_info['bot'],
          access_token_hash: access_token.to_hash,
          #identity: @identity,
          identity: @api_users_identity,
          user_info: @api_users_info,
          user_profile: @api_users_profile,
          team_info: @api_team_info,
          additional_data: get_additional_data,
          raw_info: raw_info
        }
      end
      
      # Adds user-defined additional_data methods to this
      # class and to OmniAuth::Slack::AccessToken class.
      def self.define_additional_data(definitions={})
        return if @additional_data_defined
        if !definitions.to_h.empty?
          definitions.each do |k,v|
            data_method(k, v)
            OmniAuth::Slack::OAuth2::AccessToken.data_method(k, v)
          end
          @additional_data_defined = 1
        end
      end


      # Overrides OmniAuth::Oauth2#authorize_params so that
      # specified params can be passed on to Slack authorization GET request.
      # See https://github.com/omniauth/omniauth/issues/390
      def authorize_params
        super.tap do |prms|
          params_digest = prms.hash
          debug{"Using authorize_params #{prms}"}
          prms.merge!(request.params.keep_if{|k,v| pass_through_params.reject{|o| o.to_s == 'team_domain'}.include?(k.to_s)})
          log(:debug, "Modified authorize_params #{prms}") if prms.hash != params_digest
          session['omniauth.authorize_params'] = prms
        end
      end
      
      # Overrides OmniAuth callback phase to extract session var
      # for omniauth.authorize_params into env (this is how omniauth does this).
      def callback_phase #(*args)
        # This technique copied from OmniAuth::Strategy (this is how they do it for the other omniauth objects).
        env['omniauth.authorize_params'] = session.delete('omniauth.authorize_params')
                
        # This is trying to help move additiona_data definition away from user-action.
        self.class.define_additional_data(options.additional_data)
        
        result = super
      end
      
      # Overrides OmniAuth::Strategies::OAuth2#client to define custom behavior.
      #
      # * Logs API requests with OmniAuth.logger.
      # * Adds API responses to @raw_info hash.
      # * Sets auth site uri with custom subdomain (if provided).
      #
      # Returns instance of custom OmniAuth::Slack::OAuth2::Client.
      #
      def client
        #new_client = super
        
        # Simple override to use our custom subclassed OAuth2::Client instead.
        # The Client.new call is lifted directly from OmniAuth::Strategies::OAuth2.
        new_client = OmniAuth::Slack::OAuth2::Client.new(options.client_id, options.client_secret, deep_symbolize(options.client_options))
               
        # Set client#subdomain with custom team_domain, if exists and allowed.
        new_client.subdomain = (pass_through_params.include?('team_domain') && request.params['team_domain']) ? request.params['team_domain'] : options.team_domain
        
        # Put the raw_info in a place where the Client will update it for each API request.
        new_client.history = raw_info
        
        debug{"Strategy #{self} using Client #{new_client}"}
        
        new_client
      end
      
      # Drops query_string from callback_url to prevent some errors in call to /api/oauth.access.
      def callback_url
        full_host + script_name + callback_path
      end

      
      private
      
      # Gets and decodes :pass_through_params option.
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
      
      # Runs/calls/compiles results from additional_data definitions.
      def get_additional_data
        if false && skip_info?
          {}
        else
          options.additional_data.to_h.inject({}) do |hash,tupple|
            hash[tupple[0].to_s] = send(tupple[0].to_s)
            hash
          end
        end
      end

      def user_id
        # access_token['user_id'] || access_token['user'].to_h['id'] || access_token['authorizing_user'].to_h['user_id']
        access_token.user_id
      end
      
      def team_id
        # access_token['team_id'] || access_token['team'].to_h['id']
        access_token.team_id
      end

      def web_hook_info
        #return {} unless access_token.key? 'incoming_webhook'
        access_token['incoming_webhook']
      end


      # The data_method class method takes a name, hash, and/or block.
      # The block is evaluated in the context of the new DataMethod instance.
      # Use the DSL methods within the block to construct the DataMethod instance.
      # See data_methods.rb for available DSL methods.
                    
      data_method :user_name, info_key: 'name', storage: :user_name, source: [
        {name: 'access_token', code: 'user_name'},
        {name: 'api_users_identity', code: "self['user'].to_h.fetch('name',nil)"},
        {name: 'api_users_info', code: "fetch('user',{}).to_h['real_name']"},
        {name: 'api_users_profile', code: "fetch('profile',{}).to_h['real_name']"}
      ]
      
      data_method :user_email, info_key: 'email', storage: :user_email, source: [
        {name: 'access_token', code: "user_email"},
        {name: 'api_users_identity', code: "self['user'].to_h.fetch('email',nil)"},
        {name: 'api_users_info', code: "fetch('user',{}).to_h['profile'].to_h['email']"},
        {name: 'api_users_profile', code: "fetch('profile',{}).to_h['email']"}
      ]
      
      data_method :image do
        source(:access_token) { self['user'].to_h.find{|k,v| k.to_s[/image_/]}.to_a[1] }
        source(:api_users_identity){ self['user'].to_h.find{|k,v| k.to_s[/image_/]}.to_a[1] }
        source(:api_users_info) { self['user'].to_h['profile'].to_h.find{|k,v| k.to_s[/image_/]}.to_a[1] }
        source(:api_users_profile) { self['profile'].to_h.find{|k,v| k.to_s[/image_/]}.to_a[1] }
      end
      
      data_method :team_name do
        source(:access_token) { team_name }
        source(:api_users_identity){ self['team'].to_h['name'] }
        source(:api_team_info) { self['team'].to_h['name'] }
      end
      
      data_method :team_domain do
        source(:access_token) { self['team'].to_h['domain'] }
        source(:api_users_identity) { self['team'].to_h['domain'] }
        source(:api_team_info) { self['team'].to_h['domain'] }
      end
      
      data_method :team_image do
        source(:access_token) { self['team'].to_h.find{|k,v| k.to_s[/image_/]}.to_a[1] }
        source(:api_users_identity) { self['team'].to_h.find{|k,v| k.to_s[/image_/]}.to_a[1] }
        source(:api_team_info) { self['team'].to_h['icon'].to_h.find{|k,v| k.to_s[/image_/]}.to_a[1] }
      end
      
      # Team_info is apparently the only source for this data,
      # so it will be called every cycle, regardless of whether the data is there or not.
      # TODO: Consider disabling this, or add has_scope? capabillties to source objects.
      data_method :team_email_domain do
        condition { false }
        source(:api_team_info) { self['team'].to_h['email_domain'] }
      end
                  
      data_method :nickname do
        source(:api_users_info) { deep_find 'display_name' }
        source(:api_users_info) { deep_find 'name' }
        source(:api_users_profile) { deep_find 'display_name' }
      end

      data_method :api_users_identity,
        scope: {classic:'identity.basic', identity:'identity:read:user'},
        storage: :api_users_identity,
        condition: proc{ true },
        default_value: {},
        source: [
          {name: 'access_token', code: proc{ get('/api/users.identity', headers: {'X-Slack-User' => user_id}).parsed }}
        ]

      data_method :api_users_info do
        default_value AuthHash.new
        scope classic: 'users:read', team: 'users:read'
        source :access_token do
          get('/api/users.info', params: {user: user_id}, headers: {'X-Slack-User' => user_id}).to_auth_hash
        end
      end

      data_method :api_users_profile do
        default_value AuthHash.new
        scope classic: 'users.profile:read', team: 'users.profile:read'
        source :access_token do
          get('/api/users.profile.get', params: {user: user_id}, headers: {'X-Slack-User' => user_id}).to_auth_hash
        end
      end      

      data_method :api_team_info do
        scope classic: 'team:read', team:'team:read'
        default_value Hash.new
        source :access_token do
          get('/api/team.info').parsed
        end
      end
      
      data_method :api_bots_info do
        scope classic: 'users:read', team: 'users:read'
        condition { !is_app_token? }
        default_value Hash.new
        source :access_token do
          get('/api/bots.info').parsed
        end
      end
      
      # API call to get user permissions for workspace token.
      # This used to be needed, but its functionality is now in AcessToken.
      #
      # Returns [<id>: <resource>]
      #      
      # data_method :api_apps_permissions_users_list do
      #   default_value {}
      #   condition proc { is_app_token? }
      #   source :access_token, 'apps_permissions_users_list(user_id)'
      # end 

      # This hash is handed to the access-token, which in turn fills it with API response objects.
      def raw_info
        @raw_info ||= {}
      end

      # Is this a workspace app token?
      def is_app_token?
        access_token.is_app_token?
      end
      
      def scopes_requested
        # omniauth.authorize_params is a custom enhancement to omniauth for omniauth-slack.
        env['omniauth.authorize_params'].to_h['scope']
      end

      def has_scope?(*args)
        access_token.has_scope?(*args)
      end
      
      # Copies the api_* data-methods to AccessToken.
      data_methods.each{|k,v| OmniAuth::Slack::OAuth2::AccessToken.data_method(k, v) if k.to_s[default_options.dependency_filter]}
      
    end # Slack
  end # Strategies
end # OmniAuth

