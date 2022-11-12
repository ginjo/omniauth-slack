# :markup: tomdoc

require 'oauth2/access_token'
require 'omniauth-slack/refinements'
require 'omniauth-slack/debug'

module OmniAuth
  module Slack
    using StringRefinements
    using OAuth2Refinements

    module OAuth2

      # This is an enhanced subclass of OAuth2::AccessToken.
      # It handles Slack-specific data and behavior, and it also adds
      # a scope-query method has_scope?
      #
      # The AccessToken object is built with the hash returned from the get-token API request
      # or is passed in manually via AccessToken.from_hash() or OmniAuth::Slack::build_access_token.
      #
      # The original hash from the API can always be found at AccessToken#params.
      # As a convenience, you can call '[]' on the params hash by sending
      # the method and args directly to the access-token object.
      #
      #     my_token['ok']      --> true
      #     my_token['app_id']  --> A012345678
      #
      # The AccessToken instance provides getter methods for top-level data points
      # of the returned token hash. See define_getters call below for more convenience methods.
      #
      # See Slack's documentation for the different types of tokens available.
      #
      # * https://api.slack.com/methods/oauth.access
      # * https://api.slack.com/methods/oauth.v2.access
      #
      class AccessToken < ::OAuth2::AccessToken
        include OmniAuth::Slack::Debug

        # Creates simple getter methods to pull specific data from the raw token hash.
        def self.define_getters(ary_of_words)
          ary_of_words.each do |word|
            obj, atrb = word.split('_')
            define_method(word) do
              rslt = (
                params[word] ||
                params && params[obj] && params[obj][atrb]
              )
              debug { "Simple getter '#{word}' rslt: #{rslt}" }
              rslt
            end
          end
        end

        define_getters %w(
          app_id
          authorizing_user
          enterprise
          installer_user
          scope
          team
          team_id
          team_name
          team_domain
          user
        )

        # Check's the token hash 'ok' field.
        #
        # Returns true or false, representing the success status of the token response.
        #
        def ok?
          params['ok'] == true ||
          params['ok'].to_s[/true/i] ||
          false
        end

        # Intercepts super to return nil instead of an empty string.
        #
        # Returns the token string or nil.
        #
        def token
          rslt = super
          rslt.to_s == '' ? nil : rslt
        end

        # Inspects the token and determines token type.
        #
        # Returns a string representing token type.
        #
        def token_type
          params['token_type'] ||
          case
            when
              params['token_type'] == 'user' ||
              @token.to_s[/xoxp/]; 'user'
            when
              params['token_type'] == 'bot' ||
              @token.to_s[/xoxb/]; 'bot'
            when
              params['token_type'] == 'app' ||
              @token.to_s[/xoxa/]; 'app'
            when
              @token.to_s[/xoxr/]; 'refresh'
          end
        end

        # Compares given token type with actual token_type.
        #
        # Returns true if given type matches actual token_type, otherwise false.
        #
        def token_type?(*_type)
          #debug{"'#{_type}'"}
          [_type].flatten.any? do |t|
            token_type.to_s == t.to_s
          end || false
        end

        # Converts 'authed_user' hash (of Slack v2 oauth flow) to AccessToken object.
        #
        # Returns an AccessToken instance or nil.
        #
        def user_token
          @user_token ||= (
            if token_type?('user')
              self
            elsif params['authed_user']
              rslt = self.class.from_hash(client, params['authed_user']).tap do |t|
                t.params['token_type'] = 'user'
                t.params['team_id'] = team_id
              end
            end
          )
        end
        alias_method :authed_user, :user_token

        # Gets the AccessToken person-user-id if it exists.
        #
        # Returns string or nil.
        #
        def user_id
          rslt = (
            # classic token.
            params['user_id'] ||
            # from sub-token in 'authed_user'
            params['authed_user'].to_h['id'] ||
            # workspace-app token with attached user.
            params['user'].to_h['id'] ||
            # workspace-app token with authorizing user.
            params['authorizing_user'].to_h['user_id'] ||
            # workspace-app token with installer user.
            params['installer_user'].to_h['user_id'] ||
            # user-id from authed_user hash.
            params['id'] #||
            # v2 api bot token, as a last resort.
            #params['bot_user_id']
          )
          debug { rslt }
          rslt
        end

        # Gets the AccessToken unique user-team-id combo, if it can be determined.
        #
        # Returns string or nil.
        #
        def uid
          rslt = (user_id && team_id) ? "#{user_id}-#{team_id}" : nil
          debug { rslt }
          rslt
        end

        # Gets user_name from wherever it can be found in the returned token,
        # regardless of what type of token is returned.
        #
        # Returns string or nil.
        #
        def user_name
          params['user_name'] ||
          # from sub-token in 'authed_user'
          params['authed_user'].to_h['name'] ||
          # workspace-app token with attached user.
          params['user'].to_h['name'] ||
          # from authed_user hash.
          params['name'] ||
          # workspace token with authorizing user.
          params['authorizing_user'].to_h['name'] ||
          # workspace token with installer user.
          params['installer_user'].to_h['name'] ||
          # more workspace token possibilities.
          to_auth_hash.deep_find('nickname') ||
          to_auth_hash.deep_find('real_name')
        end

        # Gets bot_user_id if it exists.
        #
        # Returns string or nil.
        #
        def bot_user_id
          params['bot_user_id']
        end

        # Gets the app_user_id if it exists.
        #
        # Returns string or nil.
        #
        def app_user_id
          params['app_user_id']
        end

        # Experimental, converts this AccessToken instance to an AuthHash object.
        #
        # Returns OmniAuth::Slack::AuthHash instance.
        #
        def to_auth_hash
          Module.const_get('::OmniAuth::Slack::AuthHash').new(params)
        end

        # Compiles scopes awarded to this AccessToken.
        #
        # Returns hash of scope arrays where *key* is scope section
        # and *value* is Array of scopes.
        #
        def all_scopes
          @all_scopes ||= (
            case
              when ! params['scope'].to_s.empty?
                {'classic' => params['scope'].words}
              when params['scopes'].to_h.any?
                params['scopes']
            end
          )
        end
        alias_method :scopes, :all_scopes

        # Match a given set of scopes against this token's awarded scopes,
        # classic and workspace token compatible.
        #
        # If the scope-query is a string, it will be interpreted as a Slack Classic App
        # scope string {classic: scope-query-string}, even if the token is a v2 token.
        #
        # The keywords need to be symbols, so any hash passed as an argument
        # (or as the entire set of args) should have symbolized keys!
        #
        # freeform_array    - [*Array, nil] default: [], array of scope query hashes or string(s).
        #
        # :query            - [Hash, Array, nil] default: nil, a single scope-query Hash (or Array of Hashes).
        #
        # :logic            - [String, Symbol] default: 'or' [:or | :and] logic for the scope-query.
        #                     Applies to a single query hash.
        #                     The reverse logic is applied to an array of query hashes.
        #
        # :user             - [String] (nil) default: nil, user_id of the Slack user to query against.
        #                       Leave blank for non-user queries.
        #
        # :base             - [Hash] default: nil, a set of scopes to query against
        #                       defaults to the awarded scopes on this token.
        #
        # freeform_hash     - [**Hash] default: {}, interpreted as single scope query hash.
        #
        def has_scope?(*freeform_array, query: nil, logic:'or', user:nil, base:nil, **freeform_hash)
          #OmniAuth.logger.debug({freeform_array:freeform_array, freeform_hash:freeform_hash, query:query, logic:logic, user:user, base:base})
          debug{{freeform_array:freeform_array, freeform_hash:freeform_hash, query:query, logic:logic, user:user, base:base}}

          query ||= case
            #when simple_string; {classic: simple_string}
            when freeform_array.any?; freeform_array
            when freeform_hash.any?; freeform_hash
          end
          return unless query

          query = [query].flatten if query.is_a?(Array) || query.is_a?(String)

          user ||= user_id
          debug{"using user '#{user}' and query '#{query}'"}

          is_identity_query = case query
            when Hash
              query.keys.detect{|k| k.to_s == 'identity'}
            when Array
              query.detect{ |q| q.is_a?(Hash) && q.keys.detect{|k| k.to_s == 'identity'} }
          end

          base ||= case
            when user && is_identity_query
              #debug{"calling all_scopes(user=#{user}) to build base-scopes"}
              all_scopes(user)
            else
              #debug{"calling all_scopes to build base-scopes"}
              all_scopes
          end

          #debug{{freeform_array:freeform_array, freeform_hash:freeform_hash, query:query, logic:logic, user:user, base:base}}
          self.class.has_scope?(scope_query:query, scope_base:base, logic:logic)
        end

        # Matches the given scope_query against the given scope_base, with the given logic.
        #
        # This is classic and workspace token compatible.
        #
        # keywords      - All arguments are keyword arguments:
        #
        # :scope_query  - [Hash, Array of hashes] default: {}.
        #                 If scope_query is a string, it will be interpreted as {classic: scope-query-string}.
        #
        #                 key     - Symbol of scope type, can be:
        #                         [app_home|team|channel|group|mpim|im|identity|classic].
        #
        #                 value   - Array or String of individual scopes.
        #
        # :scope_base   - [Hash] defaul: {}, represents the set of scopes to query against.
        #
        # :logic        - [String, Symbol] default: or. One of [and|or].
        #                 Applies to a single query hash.
        #                 The reverse logic is applied to an array of query hashes.
        #
        # Examples
        #
        #   has_scope?(scope_query: {channel: 'channels:read chat:write'})
        #   has_scope?(scope_query: [{identity:'uers:read', channel:'chat:write'}, {app_home:'chat:write'}], logic:'and')
        #   has_scope?(scope_query: 'identity:users identity:team identity:avatar')
        #
        def self.has_scope?(scope_query:{}, scope_base:{}, logic:'or')
          debug{"class-level scope_query '#{scope_query}' scope_base '#{scope_base}' logic '#{logic}'"}
          _scope_query = scope_query.is_a?(String) ? {classic: scope_query} : scope_query
          _scope_query = [_scope_query].flatten

          # Converts array of unknown strings to uniform hash of classic:[array-of-scope-strings].
          if _scope_query.is_a?(Array)
            new_query = []
            classic_array = []
            _scope_query.each_with_index do |q,n|
              if q.is_a?(String)
                classic_array.concat(q.words)
                debug{"building classic_array with words from string '#{q.words}' to give: #{classic_array}"}
              else
                new_query << _scope_query[n]
              end
            end
            if classic_array.any?
              new_query.unshift({classic: classic_array.flatten.uniq})
            end
            _scope_query = new_query
          end

          _scope_base  = scope_base
          raise "scope_base must be a hash" unless (_scope_base.is_a?(Hash) || _scope_base.respond_to?(:to_h))

          out=false

          _logic = case
            when logic.to_s.downcase == 'or'; {outter: 'all?', inner: 'any?'}
            when logic.to_s.downcase == 'and'; {outter: 'any?', inner: 'all?'}
            else {outter: 'all?', inner: 'any?'}
          end
          debug{"_logic #{_logic.inspect}"}
          debug{"_scope_query #{_scope_query}"}

          _scope_query.send(_logic[:outter]) do |query|
            debug{"outter query: #{_scope_query.inspect}"}

            query.send(_logic[:inner]) do |section, scopes|
              test_scopes = case
                when scopes.is_a?(String); scopes.words
                when scopes.is_a?(Array); scopes
                else raise "Scope data must be a string or array of strings, like this {team: 'chat:write,team:read', channels: ['channels:read', 'chat:write']}"
              end

              test_scopes.send(_logic[:inner]) do |scope|
                debug{"inner query section: #{section.to_s}, scope: #{scope}"}
                out = _scope_base.to_h[section.to_s].to_a.include?(scope.to_s)
              end
            end
          end # scope_query.send outter-query
          debug{"output: #{out}"}
          return out
        end # self.has_scope?

      end # AccessToken
    end
  end
end
