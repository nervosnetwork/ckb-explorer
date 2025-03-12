source "https://rubygems.org"
git_source(:github) { |repo| "https://github.com/#{repo}.git" }

ruby "3.1.2"

gem "net-imap"
gem "net-pop"
gem "net-smtp"
# Bundle edge Rails instead: gem 'rails', github: 'rails/rails'
gem "rails", "~> 7.0.4"
# Use postgresql as the database for Active Record
gem "pg", ">= 0.18", "< 2.0"
# Use Puma as the app server
gem "puma" # , "~> 4.3.12", require: false
# Build JSON APIs with ease. Read more: https://github.com/rails/jbuilder
# gem 'jbuilder', '~> 2.5'
# Use Redis adapter to run Action Cable in production
# gem 'redis', '~> 4.0'
# Use ActiveModel has_secure_password
# gem 'bcrypt', '~> 3.1.7'

# Use ActiveStorage variant
# gem 'mini_magick', '~> 4.8'

# Use Capistrano for deployment
# gem 'capistrano-rails', group: :development

# Reduces boot times through caching; required in config/boot.rb
gem "bootsnap" # , ">= 1.1.0", require: false

# Use Rack CORS for handling Cross-Origin Resource Sharing (CORS), making cross-origin AJAX possible
gem "rack-cors", require: "rack/cors"

# config ENV by dotenv
gem "dotenv-rails"

# manage environment specific settings by config
gem "config"

# CKB SDK
gem "ckb-sdk-ruby", git: "https://github.com/nervosnetwork/ckb-sdk-ruby.git", require: "ckb"

# Redis
gem "digest-crc"
gem "hiredis" # , "~> 0.6.3"
gem "hiredis-client"
gem "redis" # , "~> 4.2.0"

# Background Jobs
gem "rufus-scheduler"
gem "sidekiq"
gem "sidekiq-unique-jobs"
# bulk insertion of data into database using ActiveRecord
gem "activerecord-import"

gem "fast_jsonapi"
gem "jbuilder"

gem "kaminari"

# to optimize the huge pages query. e.g. query records from 10000th page.
gem "fast_page"

gem "ruby-progressbar", require: false

gem "with_advisory_lock"

gem "newrelic_rpm"
gem "sentry-rails"
gem "sentry-ruby"
gem "sentry-sidekiq"

gem "bigdecimal"

# Deployment
gem "rack-attack"

group :development, :test do
  # Call 'byebug' anywhere in the code to stop execution and get a debugger console
  gem "factory_bot_rails"
  gem "faker"
  gem "pry"
  gem "pry-byebug"
  gem "pry-rails"
  # gem "pry-nav"
end

group :test do
  gem "database_cleaner"
  gem "database_cleaner-active_record"
  gem "minitest-reporters"
  gem "mocha"
  gem "shoulda-context"
  gem "shoulda-matchers"
  gem "simplecov", require: false
  gem "simplecov-cobertura"
  gem "vcr"
  gem "webmock"
end

group :development do
  gem "listen", ">= 3.0.5"
  # Spring speeds up development by keeping your application running in the background. Read more: https://github.com/rails/spring
  gem "annotate"
  gem "awesome_print", require: false
  gem "rubocop", require: false
  gem "rubocop-performance", require: false
  gem "rubocop-rails", require: false
  gem "spring"
  gem "spring-watcher-listen"
end

# Windows does not include zoneinfo files, so bundle the tzinfo-data gem
gem "after_commit_everywhere"
gem "dalli"
gem "http"
gem "kredis"
gem "pagy"
gem "rack-cache"
gem "redis-objects", ">= 2.0.0.beta"
gem "tzinfo-data", platforms: %i[mingw mswin x64_mingw jruby]

gem "async-websocket", "~> 0.22.1", require: false
gem "ecdsa"
gem "jwt"

gem "active_interaction", "~> 5.3"
gem "bitcoinrb", require: "bitcoin"
gem "paranoia"
