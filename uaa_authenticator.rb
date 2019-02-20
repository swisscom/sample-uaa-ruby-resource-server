require 'rest-client'
require 'json'

class UaaAuthenticator
  def initialize(app, options = {})
    @app = app
    @logger = options.fetch(:logger)
    @check_token_endpoint = options.fetch(:check_token_endpoint)
    @user_info_endpoint = options.fetch(:user_info_endpoint)
    @client_id = options.fetch(:client_id)
    @client_secret = options.fetch(:client_secret)
  end

  def call(env)
    # first, obtain JWT access token from Authorization header
    access_token = extract_access_token_from_env(env)

    # if we have a token, validate it on the UAA using check_token endpoint (/introspect endpoint would work, too)
    if access_token && check_token_response = check_token(access_token)
      env['uaa.access_token'] = access_token
      env['uaa.check_token_response'] = check_token_response

      # also query the user's attributes using the /userinfo endpoint.
      # be aware that if we're doing this it also validates the token, so we could actually get rid of the /check_token call above
      # however, we keep it in the sample to show end users what attributes they would get from the different endpoints.
      env['uaa.user_info'] = user_info(access_token)
      @app.call(env)
    else
      Rack::Response.new([], 401, {}).finish
    end
  end

  def extract_access_token_from_env(env)
    env['HTTP_AUTHORIZATION'] && env['HTTP_AUTHORIZATION'][/Bearer ([a-zA-Z0-9\-_\.]+)/i, 1]
  end

  def check_token(token)
    begin
      JSON.parse(
          RestClient::Request.execute(
              method: :post,
              url: @check_token_endpoint,
              user: @client_id,
              password: @client_secret,
              payload: {
                  token: token
              })
      )
    rescue RestClient::BadRequest => e
      @logger.warn "Token validation failed: #{e.response}"
      nil
    end
  end

  def user_info(token)
    JSON.parse(
        RestClient::Request.execute(
            method: :get,
            url: @user_info_endpoint,
            headers: {
                'Authorization' => "Bearer #{token}"
            }
        ))
  end
end