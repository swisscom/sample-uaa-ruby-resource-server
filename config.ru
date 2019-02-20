require_relative 'app'

if ENV['ALLOWED_CORS_ORIGIN']
  use Rack::Cors do
    allow do
      origins /#{ENV['ALLOWED_CORS_ORIGIN']}/
      resource '*', headers: :any, methods: :any
    end
  end
end

run Sinatra::Application
