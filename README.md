⚠   **NOTICE**: You are viewing the README of the **master** branch of the **ginjo** fork of the **omniauth-slack** gem.
This document may refer to features not yet released. Conversely (inversely?) this branch may contain features  and changes not yet documented.

To view current or previous releases:

| Version | Release Date | README |
| --- | --- | --- |
| v2.5.0 (ginjo) | 2020-06-17 | https://github.com/ginjo/omniauth-slack/blob/v2.5.0/README.md |
| v2.4.1 (ginjo) | 2018-09-18 | https://github.com/ginjo/omniauth-slack/blob/v2.4.1/README.md |
| v2.4.0 (ginjo) | 2018-08-28 | https://github.com/ginjo/omniauth-slack/blob/v2.4.0/README.md |
| v2.3.0 ([kmrshntr](https://github.com/kmrshntr)) | 2016-01-06 | https://github.com/kmrshntr/omniauth-slack/blob/master/README.md |


# OmniAuth Slack, a Ruby Gem

The omniauth-slack gem contains the Slack OAuth2 strategy for [OmniAuth](https://github.com/omniauth/omniauth) and supports
the Slack [OAuth2 v2 API](https://api.slack.com/authentication/oauth-v2)
and the Slack OAuth2 v1 API.

This Gem supports Slack v2 API bot and user tokens, as well as v1 API workspace apps and tokens.
Slack "classic" apps and tokens should also work but are not fully tested.

Omniauth-slack does not enforce a Ruby version constraint. The Gem will work with Ruby versions 2.3 through 2.6.x. Older versions of Ruby may work but are not tested. Ruby version 2.7.x may work but is not yet tested.


## Before You Begin

OmniAuth Slack is implemented through the OmniAuth gem, so you should familiarize yourself with the basics of [OmniAuth](https://github.com/intridea/omniauth).

OmniAuth Slack authorizes Slack users on behalf of a defined Slack application. If you don't already have an application defined on Slack, sign into the [Slack application dashboard](https://api.slack.com/applications) and create an application. Take note of your API keys.

While you're in the application settings, add a Redirect URL to your application (under the `OAuth2 & Permissions` section), something simple like `http://localhost:3000/` or `https://myslackapp.com/`. The URL doesn't have to be accessible to the public internet, but it should be accessible to your development machine.


## Using This Strategy

First start by adding this gem to your Gemfile:

  ```ruby
    gem 'ginjo-omniauth-slack', require:'omniauth-slack'
  ```

Or specify the latest HEAD (development) version from the ginjo repository:

  ```ruby
    gem 'ginjo-omniauth-slack', require:'omniauth-slack', git: 'https://github.com/ginjo/omniauth-slack'
  ```

Next, tell OmniAuth about this provider.

For a **[Rails](https://rubyonrails.org)** app, your `config/initializers/omniauth.rb` file should look like this:

  ```ruby
    Rails.application.config.middleware.use OmniAuth::Builder do
      provider :slack, 'API_KEY', 'API_SECRET', scope: 'string-of-scopes'
    end
  ```

Replace `'API_KEY'` and `'API_SECRET'` with the relevant values you obtained from the Slack application setup. Replace `'string-of-scopes'` with a space-separated string of Slack API scopes.


For a **[Sinatra](http://sinatrarb.com/)** app:     <span name="sinatra-app" id="sinatra-app"></span>

  ```ruby
    require 'sinatra'
    require 'omniauth-slack'

    use OmniAuth::Builder do |env|
      provider :slack,
        ENV['SLACK_OAUTH_KEY_WS'],
        ENV['SLACK_OAUTH_SECRET_WS'],
        scope: 'string-of-scopes'
    end
  ```


If you are using **[Devise](https://github.com/plataformatec/devise)** then it *should* look like this:

  ```ruby
    Devise.setup do |config|
      # other stuff...

      config.omniauth :slack, ENV['SLACK_APP_ID'], ENV['SLACK_APP_SECRET'], scope: 'string-of-scopes'

      # other stuff...
    end
  ```


To manually install and require the gem:

  ```bash
    # shell
    gem install ginjo-omniauth-slack
  ```

  ```ruby
    # ruby
    require 'omniauth-slack'
  ```


## Scopes
Slack lets you choose from a number of [scopes](https://api.slack.com/scopes) supporting one or more of the **classic**, **workspace**, and **v2** apps and token types.

**Important:** You cannot request both identity scopes and non-identity scopes in a single authorization request, within the same scope field (`scope` or `user_scope`).

If you need to combine *Add to Slack* scopes with those used for *Sign in with Slack*,
you may want to configure two providers:

  ```ruby
    provider :slack, 'API_KEY', 'API_SECRET', name: :sign_in_with_slack, scope: 'identity.basic'
    provider :slack, 'API_KEY', 'API_SECRET', scope: 'team:read,users:read,identify,bot'
  ```

Use the first provider to sign users in and the second to add the application, and deeper capabilities, to their team.

The [Sign-in-with-Slack](https://api.slack.com/docs/sign-in-with-slack) approval flow handles quick authorization of users with minimally scoped requests. Deeper scope authorizations are acquired with further passes through the authorization cycle.

This works because Slack scopes are additive: Once you successfully authorize a scope, the token will possess that scope forever, regardless of what flow or scopes are requested at future authorizations (removal of scope requires revocation of the token or uninstallation of the Slack app from the team).


## v2 API scope fields

The Slack v2 API allows two different scope fields in the authorization request.

* Scopes passed in the `scope` field are requesting a bot token.
* Scopes passed in the `user_scope` field are requesting a user token.

There must be at least one scope listed in either of the fields
for most (but not all) v2 API requests.

The rule mentioned [above](#scopes), "... don't mix identity scopes with other scopes..," applies to v2 API requests as well, however only for the `user_scope` field. The `scope` field in the v2 API does not accept identity scopes.


<!-- *TODO: fix or build this.*
  See *Advanced Techniques* for alternatives to handle multiple sets of scopes and progressive permissions.
-->

## Options

Options for omniauth-slack are specified in the provider block, as shown [above](#user-content-sinatra-app),
and all are optional except for `scope` and/or `user_scope`.


Some of these options can also be given at runtime in the authorization request url
(see [**pass\_through\_params**](#pass_through_params) below).

More information on provider and authentication options can be found in omniauth-slack's supporting gems [omniauth](https://github.com/omniauth/omniauth), [oauth2](https://github.com/oauth-xx/oauth2), and [omniauth-oauth2](https://github.com/omniauth/omniauth-oauth2).


### :scope *and/or* :user_scope => space-delimited-string-of-scopes
*required*

  ```ruby
    :scope => 'string-of-space-separated-scopes'
  
    # and/or (v2 API only)
    :user_scope => '...'
  ```

Specify the scopes for the authorization request.


### team: string
*optional*

### team_domain: string
*optional*

  ```ruby
    :team => 'team-id',
    
    # and/or
    
    :team_domain => 'my_team_domain'
  ```
Requests authentication against a specific team.


> If you don't pass a team param, the user will be allowed to choose which team they are authenticating against. Passing this param ensures the user will auth against an account on that particular team.

If you need to ensure that the users are authenticating against a specific team_id, you can pass the `:team` option in your provider block:

  ```ruby
    provider :slack, 'API_KEY', 'API_SECRET', scope: 'identify,read,post', team: 'XXXXXXXX'
  ```

If the user is not already signed in to the Slack team specified, they will be given an option to select a team first.

Another (possibly undocumented) way to specify team is by passing in the `:team_domain` parameter.
In contrast to setting `:team`, setting `:team_domain` will force authentication against the specified team (credentials permitting of course), even if the user is not signed in to that team.
However, if the user is already signed in to that team, specifying the `:team_domain` alone will not let the user skip the Slack authorization dialog, as is possible when you specify `:team`.

Sign in behavior with team settings and signed in state can be confusing. Here is a breakdown based on Slack documentation and observations while using omniauth-slack.


#### Team settings and sign in state vs Slack OAuth2 behavior. 

| Setting and state | Will authenticate against specific team | Will skip authorization approval<br>-<br>*The elusive unobtrusive<br>[Sign in with Slack](https://api.slack.com/docs/sign-in-with-slack)* |
| --- | :---: | :---: |
| using `:team`, already signed in | :small_blue_diamond: | :small_blue_diamond: |
| using `:team`, not signed in |   | :small_blue_diamond: |
| using `:team_domain`, already signed in | :small_blue_diamond: |   |
| using `:team_domain`, not signed in | :small_blue_diamond: |   |
| using `:team` and `:team_domain`, already signed in | :small_blue_diamond: | :small_blue_diamond: |
| using `:team` and `:team_domain`, not signed in |   | :small_blue_diamond: |
| using no team parameters |   |   |

*Slack's authorization process will only skip the authorization approval step, if in addition to the above settings and state, ALL of the following conditions are met:*

* Token has at least one identity scope previously approved.
* Current authorization is requesting at least one identity scope.
* Current authorization is not requesting any scopes that the token does not already have.
* Current authorization is not requesting any non-identity scopes (but it's ok if the token already has non-identity scopes).


### redirect_uri: string
String *optional*

  ```ruby
    :redirect_uri => 'https://<defaults-to-the-app-origin-host-and-port>/auth/slack/callback'
  ```

*This setting overrides the `:callback_path` setting.*

Set a custom redirect URI in your app, where Slack will redirect-to with an authorization code.
The redirect URI, whether default or custom, MUST match a registered redirect URI in [your app settings on api.slack.com](https://api.slack.com/apps).


### callback_path: string
*optional*

  ```ruby
    :callback_path => '/auth/slack/callback'
  ```

*This setting is ignored if `:redirect_uri` is set.*

Set a custom callback path (path only, not the full URI) for Slack to redirect-to with an authorization code. This will be appended to the default redirect URI only. If you wish to specify a custom redirect URI with a custom callback path, just include both in the `:redirect_uri` setting.


### skip_info: boolean
*optional*

  ```ruby
    :skip_info => false
  ```

Skip building the `InfoHash` section of the `AuthHash` object.

If set, only a single api request will be made for each authorization. The response of that authorization request may or may not contain user and email data.


### pass_through_params: array-of-strings
*optional*

Options for `scope`, `team`, `team_domain`, and `redirect_uri` can also be given at runtime via the query string of the omniauth-slack authorization endpoint URL `/auth/slack?team=...`. The `scope`, `team`, and `redirect_uri` query parameters will be passed directly through to Slack in the OAuth2 GET request:

  ```ruby
   https://slack.com/oauth/authorize?scope=identity.basic,identity.email&team=team-id&redirect_uri=https://different.subdomain/different/callback/path
  ```

The `team_domain` query parameter will be inserted into the authorization GET request
as a subdomain `https://team-domain.slack.com/oauth/authorize`.

**NOTE:** Allowing `redirect_uri`, `scope`, or `team_domain` to be passed to Slack from your application's public interface (`https://myapp.com/auth/slack?scope=...`) is a potential security risk. As of omniauth-slack version 2.5.0, the default is to NOT allow `scope`, `redirect_uri`, or `team_domain` pass-through options at runtime, *unless* they are listed in the `:pass_through_params` option. The `team` param is allowed to pass through as a default.

To block all pass-through options.

  ```ruby
    provider :slack, KEY, SECRET, pass_through_params:nil
  ```
    
To allow all pass-through options.

  ```ruby
    provider :slack, KEY, SECRET, pass_through_params: %w(team scope redirect_uri team_domain)
  ```
  

### client_options: hash-of-client-options
*optional*

Client options control the behavior of the `OAuth2::Client`, which handles the
http requests and redirects during the OmniAuth OAuth2 cycle.
Here is the current default `client_options`.

  ```ruby
    option :client_options, {
      site: 'https://slack.com',
      authorize_url: '/oauth/v2/authorize',
      token_url: '/api/oauth.v2.access',
      auth_scheme: :basic_auth,
      raise_errors: false, # MUST be false to allow Slack's get-token response from v2 API.
      history: Array.new,
    }
  ```

Generally, you can leave this option alone, but there is one case where you need it:
If you want to use **Slack's v1 (legacy, classic, whatever) API**, you need to change
the authorization and token endpoints.

To switch to **Slack v1 API**, change to these options within `client_options`:

    authorize_url: '/oauth/authorize',
    token_url: '/api/oauth.access',


## Slack v2 API
Slack is recommending the [v2 API](https://api.slack.com/authentication/oauth-v2)
for all new Slack apps.
This gem supports Slack's v2 API and its associated tokens and apps.
The v2 API endpoints are now the default in omniauth-slack.

The omniauth-slack gem does not put a version constraint on the OAuth2 gem, so as to
remain compatible with installations using earlier versions of OAuth2
(and not needing Slack's v2 API). However, use of omniauth-slack with Slack's new API
requires a minimum version of the OAuth2 gem.

#### Using omniauth-slack with Slack's v2 API requires OAuth2 gem version 1.4.4+

Make sure your application is loading the OAuth2 gem version 1.4.4+.
In most cases, Bundler and the gem dependency tree will sort this out for you.
But some gems or gem combinations may install an older OAuth2 gem. If so,
try something like this in your Gemfile:

  ```ruby
    gem 'oauth2', '~> 1.4.4'
    
    # or
    
    gem 'oauth2', '>= 1.4.4'
  ```

#### The reason behind this
Tokens returned from the v2 API may not always conform to the OAuth2 spec,
and therefore may raise errors in the OAuth2 gem during the callback phase,
even if the token response from Slack's v2 API is successful from Slack's point of view.

To avoid this issue, the omniauth-slack strategy `client_options` must be set
with `{raise_errors: false}`, which will only have the desired effect
on the OAuth2 gem version 1.4.4 and above.
This `raise_errors` option is now the default in the omniauth-slack gem.


## Access Tokens

While the core OAuth2 access-token is a simple string, the OAuth2 gem packages it along with other data returned from the `/api/oauth.access` call, as an AccessToken instance. The AccessToken contains everything you need to make Slack API requests: the actual token string, the expiration data (if any), the team, user, scope, and an OAuth2::Client instance with the API key and secret.

The AccessToken generated by omniauth-slack also has additional features, such as `has_scope?(list-of-scopes)`, which queries the token's awarded scopes. This is handy for Slack Workspace apps and their multi-dimensional scopes, but it works for any Slack token type.

#### Storage
Use the `AccessToken#to_hash` method to prepare the token for serialization and storage in a database. This method strips off all unnecessary objects and leaves just the data.

#### Retrieval
When you want to reconstitute the access-token from a stored hash or string, use the `OmniAuth::Slack::OAuth2::AccessToken.from_hash` method. Or use omniauth-slack's convenience method:

`access_token = OmniAuth::Slack.build_access_token(key, secret, access_token_string_or_hash)`

#### Usage

Once you have a valid AccessToken instance, you can do things like:

  ```ruby
    access_token.get('/api/apps.permissions.users.list')

    access_token.refresh

    access_token.post('/api/chat.postMessage', params: {channel: channel_id, text: message})
  ```
    
To extract data from the API response, call `parsed` on the response object.

  ```ruby
    access_token.get('/api/channels.list').parsed['channels']

    # => [{'id' => 1, 'name' => ...}, {'id' => ...}]
  ```


## The Auth Hash

Each Successful OmniAuth authorization places an
[AuthHash](https://github.com/omniauth/omniauth/wiki/Auth-Hash-Schema) object in the environment `env['omniauth.auth']`.
The AuthHash is just an enhanced hash object containing data from the [OAuth2](https://github.com/oauth-xx/oauth2)
response received from the get-token API call made during the OmniAuth callback phase.
See OmniAuth's documentation for the AuthHash schema definition.

With the growing number of multi-dimensional data structures for the various token response objects,
mapping of response data to the `AuthHash` object has become increasingly complex.
To establish a meaningful mapping that serves the downstream application's needs, the functionality
and goals of the application need to be considered.

The omniauth-slack gem will now copy the access-token hash to the AuthHash `info` section,
but it will no longer be mapping specific data points from the access-token
to specific fields in the AuthHash `info` section (other than `info` fields that are 'required'
by the OmniAuth::AuthHash schema spec).

Application developers are welcome to define their own **`info`** section directly within the omniauth-slack strategy.
And the same customization can be done for any of the top-level AuthHash sections.

  ```ruby
    class OmniAuth::Strategies::Slack
      info do
        # Should return a hash object.
        # Will be called during the callback-phase.
        # Will be evaluated in the context of the strategy instance.
        # Strategy options are available in this context.
        # Current access_token (assuming it was successful) is available in this context.
      end
    end
  ```
  
If you want to build your own `info` section *and* have it appended to omniauth-slack's default
`info` section, then subclass the strategy and use that subclass as your `OmniAuth` provider.

  ```ruby
    class MyCustomStrategy < OmniAuth::Strategies::Slack
      info do
        # Should return a hash object.
        # Will be called during the callback-phase.
        # Will be evaluated in the context of the strategy instance.
        # Strategy options are available in this context.
        # Current access_token (assuming it was successful) is available in this context.
      end
    end
    
    # ...
    
    use OmniAuth::Builder do
      provider MyCustomStrategy, SLACK_OAUTH_KEY, SLACK_OAUTH_SECRET, scope: ...
    end
  ```

The **`credentials`** section of the AuthHash will contain the access-token string, the awarded
scopes, and any other essential authentication information returned in the OAuth2 response.

The **`extra`** section contains two hash keys:
* `:scopes_requested` hash, which are the scopes requested during the current authorization.
* `:raw_info` hash, which contains the raw response object from any API calls made during the callback phase.


## The OAuth2 Cycle

The OAuth2 cycle is a three-way dance between the user's browser, the OAuth2 provider (Slack API), and the application server (your Slack App). It should work this way for any OAuth2 provider, including Slack.

1. The user/browser makes a request to `https://slack.com/oauth/authorize`, passing the application's client-id, requested-scopes, and optionally state, team-id, and redirect-uri. Slack then runs the user through the authorization dialogs.

2. Upon successful authorization, Slack redirects the browser to the application's callback url (or redirect_uri in Slack's terms) with a short-lived authorization code, for example:

   `https://yourapp.com/auth/slack/callback?code=ABCDE87364`
   
3. Omniauth-slack intercepts this request and exchanges the code, via Slack API, for a valid access-token.
   
And that's it. Control is then given to your application's `/auth/slack/callback` action.

The next step would be the application storing the access-token, maybe making additional API requests, and then rendering a page to the browser or redirecting to another action. In a working app, a session would store a reference to the token, and the token would be stored in a database. Then for every request from that user, a valid access-token would be accessible and usable to make further API requests.


## The OAuth2 Cycle with OmniAuth Slack

While the browser experience may appear simple, there's quite a lot happening behind
the scenes in the omniauth-oauth2 library that omniauth-slack is derived from.
Omiauth-slack is Rack middleware loaded in the stack behind your main app,
and it handles the [above](#the-oauth2-cycle) sequence(s) before your application receives the request(s).

So lets run through the cycle again and take a closer look.

0.
    1.  The user/browser makes a request to your application at `http://yourapp.com/auth/slack`. This URI could be the href of your signin-with-slack or add-to-slack button.
      
        Your application's server-side code doesn't need to know about this endpoint, and it doesn't need to define an action for it. Omniauth-slack middleware recognizes this URI as the authorization request.
        
    2.  Omniauth-slack intercepts this request, considers local configuration, stores some data in a session variable, and then redirects the browser, with the necessary data embedded in the URI params, to Slack's authorization URI.
    
        OmniAuth calls this the **request phase**, and your application sees none of it.
   
1.
    1. Having been redirected by omniauth-slack, the browser makes an authorization request to `https://slack.com/oauth/authorize`, passing the application's client-id, requested-scopes, and optionally state, team-id, and redirect-uri. This request contains everything Slack needs to authenticate the user and authorize access to Slack's API functions and data.

    2. Slack leads the user through any dialogs necessary to complete the authorization.
    
       Depending on the setup, the requested (and awarded) scopes and permissions, and Slack's internal logic, this cycle could appear as a series of dialogs or as a simple request/response. If identity scopes were requested (signin-with-slack flow), and a team-id was passed in the params, *and* the given scopes were previously authorized, Slack may grant authorization without requiring the user to click on any dialogs at all.
       
       Meanwhile, the application server and omniauth-slack are patiently waiting and have no idea what Slack, or the user, are doing at this point.

2. Upon successful authorization, Slack redirects the browser to the application's callback url (or redirect_uri) with a short-lived authorization code, for example:

   `https://yourapp.com/auth/slack/callback?code=ABCDE87364`.
   
   Your application needs to define an endpoint for `/auth/slack/callback`, but omniauth-slack does all of its work before your app even sees the request.
   
3.  1. Omniauth-slack intercepts this request, and exchanges the authorization code for a valid access-token by making an API request to `https://slack.com/api/oauth.access`.

       The `oauth.access` response contains an access-token (and possibly other data) which omniauth-slack stores in the Rack `env` for later use by your application.
   
       OmniAuth refers to this part of the process as the **callback phase**, and you don't see any of it (Rack middleware magic).

    2. Rack then passes this callback request to your app, and you are at the logical beginning of whatever action you defined for `/auth/slack/callback`.
    
       There is a lot of data available in the request `env['omniauth.auth']` and `env['omniauth.strategy']`. There are also other env variables defined by omniauth and omniauth-slack. See the gem docs for more about those.
   

       At this point, you will likely want to grab the `env['omniauth.auth']` hash and the `env['omniauth.strategy'].access_token` object. Use the access-token to make further API requests, or store the token and auth_hash for later retrieval.
       
       <!-- *TODO: Fix this reference to 'below'*: -->
       
       See the note about access-tokens below.
       

## Slack Workspace Apps
This gem provides support for Slack's [Workspace apps](https://api.slack.com/workspace-apps-preview) (now legacy). There are some important differences between Slack's classic apps and the new Workspace apps. The main points to be aware of when using omniauth-slack with Workspace Apps are:

  * Workspace app tokens are issued as a single token per team. There are no user or bot tokens. All Workspace app API calls are made with the Workspace token. Calls that act on behalf of a user or bot are made with the same token.

  * The available api calls and the scopes required to access them are different in Workspace apps.
  
  * The `AuthHash.credentials.scopes` value, returned from a successful authentication, is a hash with each value containing an array of scopes. The usual `scope` key will not have a value.


## OmniAuth Slack Basic Examples

<!-- *TODO: Clean this sentence up, or fix the reference to 'below':* -->

Don't forget to set up your Slack app on [api.slack.com](https://api.slack.com/apps).

### Sinatra Example

Create a Sinatra project directory, then add these files.

#### simple_app.rb

  ```ruby
    require 'omniauth-slack'
    require 'sinatra'
    require 'yaml'

    enable :sessions
  
    # optional
    #set :port, '9292'
    #set :bind, '0.0.0.0'

    use OmniAuth::Builder do
      provider :slack, SLACK_OAUTH_KEY, SLACK_OAUTH_SECRET, scope:'identity:read:user'
    end

    get '/auth/slack/callback' do
      content_type 'text/yaml'
      { auth_hash:    env['omniauth.auth'],
        access_token: env['omniauth.strategy'].access_token
      }.to_yaml
    end
  ```
#### Gemfile

  ```ruby
    source 'https://rubygems.org'
    gem 'ginjo-omniauth-slack'   #, git:'https://github.com/ginjo/omniauth-slack'
    gem 'sinatra'
    gem 'puma'
  ```

Put those in their respective files, fill in your Slack OAuth2 credentials, then launch.

    bundle install
    bundle exec ruby super_simple.rb

Then point your browser to

    http://<host-and-port-recognized-in-slack-redirect-uri-list>/auth/slack

When a successful authorization cycle completes, your browser should end up with a yaml representation of the auth_hash and access_token objects. What happens next is entirely up to your application.

### Rails Example

Create a rails project, then add or modify these files. Note that this is not necessarily the best way to do this in a production system. It's just a demonstration of the bare necessities to get omniauth-slack working in Rails.

#### config/initializers/middleware.rb
    
  ```ruby
    require 'omniauth-slack'

    Rails.application.config.middleware.use OmniAuth::Builder do
      provider :slack, SLACK_OAUTH_KEY, SLACK_OAUTH_SECRET, scope:'identity:read:user'
    end
  ```   
#### app/controllers/auth_controller.rb
    
  ```ruby
    class AuthController < ApplicationController
      def callback
        render plain: { access_token: request.env['omniauth.strategy'].access_token.to_hash,
          auth_hash:  request.env['omniauth.auth']
        }.to_yaml
      end
    end
  ```
#### config/routes.rb

  ```ruby
    get 'auth/slack/callback', to: 'auth#callback'
  ```
#### Gemfile

  ```ruby
    gem 'ginjo-omniauth-slack'   #, git:'https://github.com/ginjo/omniauth-slack'
  ```
Don't forget to fill in your Slack API credentials. Then start up Rails, and point your browser to

    http://<host-and-port-recognized-in-slack-redirect-uri-list>/auth/slack
    
When a successful authorization cycle completes, your browser should end up with a yaml representation of the auth_hash and access_token objects. What happens next is entirely up to your application.


## Advanced / Experimental

* Deep debug with `ENV['OMNIAUTH_SLACK_DEBUG']=true`.
  Will output a LOT of detailed TRACE log items.
  Only use this for debugging during development.

* An optional `OmniAuth::Slack::VerifySlackSignature` middleware class handles signature
  verification for incoming Slack requests. This is helpful if you receive Slack
  events in your application.
  
  ```ruby
    # In your rack middleware setup file.
  
    use OmniAuth::Slack::VerifySlackSignature do |config|
      config.app_id          = ENV['SLACK_APP_ID']
      config.signing_secret  = ENV['SLACK_SIGNING_SECRET']
    end
    
    # When legitimate incoming Slack request is received by your app:
    env['omniauth.slack.verification'] == true

    # When illegitimate incoming Slack request is received by your app:
    env['omniauth.slack.verification'] == false
    
    # When any other request is received by your app:
    env['omniauth.slack.verification'] == nil
    
  ```


## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request

