# coding: utf-8
require File.expand_path('../lib/omniauth-slack/version', __FILE__)

Gem::Specification.new do |spec|
  spec.name          = 'ginjo-omniauth-slack'
  spec.version       = OmniAuth::Slack::VERSION
  spec.authors       = ['kimura', 'ginjo']
  spec.email         = ['kimura@enigmo.co.jp', 'wbr@mac.com']
  spec.description   = %q{OmniAuth strategy for Slack}
  spec.summary       = %q{OmniAuth strategy for Slack, based on OAuth2 and OmniAuth}
  spec.homepage      = 'https://github.com/ginjo/omniauth-slack.git'
  spec.license       = 'MIT'

  spec.files         = `git ls-files`.split($/)
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ['lib']

  spec.add_runtime_dependency 'omniauth', '~> 1.2'
  spec.add_runtime_dependency 'omniauth-oauth2', '>= 1.4.0'

  spec.add_development_dependency 'bundler', '>= 1.11.2'
  spec.add_development_dependency 'rake'
  spec.add_development_dependency 'minitest'
  spec.add_development_dependency 'mocha'
end
