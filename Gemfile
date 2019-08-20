source "https://rubygems.org"
git_source(:github) { |repo| "https://github.com/#{repo}.git" }

ruby "2.5.3"

# Bundle edge Rails instead: gem 'rails', github: 'rails/rails'
gem "rails", "~> 5.2.2", ">= 5.2.2.1"
# Use postgresql as the database for Active Record
gem "pg", ">= 0.18", "< 2.0"
# Use Puma as the app server
gem "puma", "~> 3.11"
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
gem "bootsnap", ">= 1.1.0", require: false

# Use Rack CORS for handling Cross-Origin Resource Sharing (CORS), making cross-origin AJAX possible
gem "rack-cors", require: "rack/cors"

# config ENV by dotenv
gem "dotenv-rails"

# manage environment specific settings by config
gem "config"

# daemons
gem "daemons", "~> 1.2", ">= 1.2.6"

# CKB SDK
gem "ckb-sdk-ruby", git: "https://github.com/nervosnetwork/ckb-sdk-ruby.git", require: "ckb", branch: "develop"

# Redis
gem "hiredis", "~> 0.6.1"
gem "redis", "~> 4.0", ">= 4.0.3"

# Sidekiq
gem "sidekiq", "~> 5.2", ">= 5.2.3"
gem "sidekiq-unique-jobs"
gem "sidekiq-failures"

# bulk insertion of data into database using ActiveRecord
gem "activerecord-import"

gem "fast_jsonapi"

gem "kaminari"

gem "ruby-progressbar", require: false

# Deployment
gem "mina", require: false
gem "mina-multistage", require: false
gem "newrelic_rpm"
gem "turnout"

group :development, :test do
  # Call 'byebug' anywhere in the code to stop execution and get a debugger console
  gem "pry"
  gem "pry-nav"
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
  gem "faker", git: "https://github.com/stympy/faker.git", branch: "master"
  gem "codecov", require: false
end

group :development do
  gem "listen", ">= 3.0.5", "< 3.2"
  # Spring speeds up development by keeping your application running in the background. Read more: https://github.com/rails/spring
  gem "spring"
  gem "spring-watcher-listen", "~> 2.0.0"
  gem "rubocop", require: false
  gem "rubocop-performance"
  gem "awesome_print"
  gem "annotate"
end

# Windows does not include zoneinfo files, so bundle the tzinfo-data gem
gem "tzinfo-data", platforms: [:mingw, :mswin, :x64_mingw, :jruby]
