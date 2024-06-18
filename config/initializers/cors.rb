# Be sure to restart your server when you modify this file.

# Avoid CORS issues when API is called from the frontend app.
# Handle Cross-Origin Resource Sharing (CORS) in order to accept cross-origin AJAX requests.

# Read more: https://github.com/cyu/rack-cors

# Rails.application.config.middleware.insert_before 0, Rack::Cors do
#   allow do
#     origins 'example.com'
#
#     resource '*',
#       headers: :any,
#       methods: [:get, :post, :put, :patch, :delete, :options, :head]
#   end
# end

Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    origins ["https://explorer.nervos.org",
             "https://pudge.explorer.nervos.org",
             "http://localhost:3000",
             /\Ahttps:\/\/ckb-explorer-.*.magickbase.vercel.app\z/] +
      ENV["PARTNER_DOMAINS"].to_s.split(",").map(&:strip).map { |x| x.start_with?("/") ? Regexp.new(x[1..-2]) : x }
    resource "*", headers: :any, methods: %i[get post put head options]
  end
end
