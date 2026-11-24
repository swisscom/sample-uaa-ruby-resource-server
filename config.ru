require 'uri'
require_relative 'app'

# ALLOWED_CORS_ORIGIN: comma-separated list of exact origins, e.g.
#   https://my-client.example.com,https://other-client.example.com:8443
# Patterns and wildcards are deliberately not supported.
def parse_cors_origins(value)
  value.split(',').map(&:strip).reject(&:empty?).map do |entry|
    uri = URI.parse(entry) rescue nil
    valid = uri && %w[http https].include?(uri.scheme) && uri.host &&
            [nil, '', '/'].include?(uri.path) && uri.query.nil? && uri.fragment.nil? && uri.userinfo.nil?
    abort("Invalid ALLOWED_CORS_ORIGIN entry '#{entry}': expected an exact origin like https://my-client.example.com") unless valid

    entry.delete_suffix('/').downcase
  end
end

if ENV['ALLOWED_CORS_ORIGIN'] && !ENV['ALLOWED_CORS_ORIGIN'].strip.empty?
  allowed_origins = parse_cors_origins(ENV['ALLOWED_CORS_ORIGIN'])
  use Rack::Cors do
    allow do
      origins(*allowed_origins)
      resource '*', headers: :any, methods: :any
    end
  end
end

run Sinatra::Application
