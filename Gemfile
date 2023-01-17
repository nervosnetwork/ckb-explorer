source "https://rubygems.org"
git_source(:github) { |repo| "https://github.com/#{repo}.git" }

ruby "3.1.2"

gem "net-smtp"
gem "net-imap"
gem "net-pop"
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
# gem "ckb-sdk-ruby", git: "git@github.com:ShiningRay/ckb-sdk-ruby.git", require: "ckb", branch: "move_to_-rbsecp256k1"
gem "ckb-sdk-ruby", git: "https://github.com/nervosnetwork/ckb-sdk-ruby.git", require: "ckb", tag: "v0.103.0"

# Redis
gem "hiredis" # , "~> 0.6.3"
gem "redis" # , "~> 4.2.0"

gem "digest-crc"

# Backgroud Jobs

group :production, :staging, :development do
  gem "sidekiq"
  # fixed sidekiq7 bug.
  gem "sidekiq-statistic", github: "dougmrqs/sidekiq-statistic", branch: "fix-problem-with-sidekiq-7"
  gem "sidekiq-cron", github: "serprex/sidekiq-cron", branch: "master"

  gem "sidekiq-unique-jobs"
  gem "sidekiq-status"
  gem "sidekiq-failures"
end

# bulk insertion of data into database using ActiveRecord
gem "activerecord-import"

gem "fast_jsonapi"

gem "kaminari"

gem "ruby-progressbar", require: false

gem "with_advisory_lock"

gem "nokogiri", ">= 1.11.0.rc4"

gem "benchmark_methods", require: false
gem "sentry-ruby"
gem "sentry-rails"
gem "sentry-sidekiq"
gem "newrelic_rpm"

# Deployment
gem "rack-attack"

group :development, :test do
  # Call 'byebug' anywhere in the code to stop execution and get a debugger console
  gem "pry"
  gem "pry-rails"
  # gem "pry-nav"
end

group :test do
  gem "simplecov", require: false
  gem "minitest-reporters"
  gem "shoulda-context"
  gem "shoulda-matchers"
  gem "vcr"
  gem "webmock"
  gem "database_cleaner"
  gem "mocha"
  gem "factory_bot_rails"
  #  gem "faker", git: "https://github.com/faker-ruby/faker.git", branch: "master"
  gem "faker", git: "https://github.com/faker-ruby/faker.git", branch: "main"
  gem "codecov", require: false
end

group :development do
  gem "listen", ">= 3.0.5"
  # Spring speeds up development by keeping your application running in the background. Read more: https://github.com/rails/spring
  gem "spring"
  gem "spring-watcher-listen"
  gem "rubocop", require: false
  gem "rubocop-rails", require: false
  gem "rubocop-performance", require: false
  gem "awesome_print", require: false
  gem "annotate"
  gem "solargraph"
end

# Windows does not include zoneinfo files, so bundle the tzinfo-data gem
gem "tzinfo-data", platforms: [:mingw, :mswin, :x64_mingw, :jruby]
gem "redis-objects"
gem "pagy"
gem "http"
gem "rack-cache"
gem "dalli"
