require 'sinatra'
require 'rack/cors'
require 'json'
require 'logger'
require_relative 'uaa_authenticator'

logger = Logger.new(STDERR)

service = JSON.parse(ENV['VCAP_SERVICES'] || '{}').values.flatten.first{|service|service['tags'].include 'oauth2'}
raise 'please bind UAA service to app' if service.nil?

use UaaAuthenticator, logger: logger,
    check_token_endpoint: service['credentials']['checkTokenEndpoint'], user_info_endpoint: service['credentials']['userInfoEndpoint'],
    client_id: service['credentials']['clientId'], client_secret: service['credentials']['clientSecret']

set :logging, logger

get '/env' do
  content_type :json

  {
      check_token_response: env['uaa.check_token_response'],
      user_info: env['uaa.user_info']
  }.to_json
end
