require 'net/http'
require 'json'

class UaaAuthenticator
  HTTP_OPEN_TIMEOUT = 10
  HTTP_READ_TIMEOUT = 60

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
    response = post_form(@check_token_endpoint, { token: token }, basic_auth: [@client_id, @client_secret])
    if response.is_a?(Net::HTTPBadRequest)
      @logger.warn "Token validation failed: #{response.body}"
      return nil
    end
    JSON.parse(ensure_success!(response).body)
  end

  def user_info(token)
    response = get(@user_info_endpoint, 'Authorization' => "Bearer #{token}")
    JSON.parse(ensure_success!(response).body)
  end

  private

  def post_form(url, form, basic_auth:)
    uri = URI(url)
    request = Net::HTTP::Post.new(uri)
    request.basic_auth(*basic_auth)
    request.set_form_data(form)
    perform(uri, request)
  end

  def get(url, headers)
    uri = URI(url)
    request = Net::HTTP::Get.new(uri)
    headers.each { |name, value| request[name] = value }
    perform(uri, request)
  end

  def perform(uri, request)
    request['Accept'] = 'application/json'
    Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == 'https',
                    open_timeout: HTTP_OPEN_TIMEOUT, read_timeout: HTTP_READ_TIMEOUT) do |http|
      http.request(request)
    end
  end

  def ensure_success!(response)
    return response if response.is_a?(Net::HTTPSuccess)

    raise "UAA request failed with HTTP #{response.code}: #{response.body}"
  end
end
