source 'https://rubygems.org'
ruby '2.4.1'

# Bundle edge Rails instead: gem 'rails', github: 'rails/rails'
gem 'rails', '5.0.2'
# Use postgresql as the database for Active Record
gem 'pg'
# Use SCSS for stylesheets
gem 'sass-rails'
# Use Uglifier as compressor for JavaScript assets
gem 'uglifier', '>= 1.3.0'
# Use CoffeeScript for .coffee assets and views
gem 'coffee-rails'
# See https://github.com/sstephenson/execjs#readme for more supported runtimes
# gem 'therubyracer', platforms: :ruby

# Use jquery as the JavaScript library
gem 'jquery-rails'
gem 'jquery-turbolinks'
# Turbolinks makes following links in your web application faster. Read more: https://github.com/rails/turbolinks
gem 'turbolinks'
# Build JSON APIs with ease. Read more: https://github.com/rails/jbuilder
gem 'jbuilder', '~> 2.0'
# bundle exec rake doc:rails generates the API under doc/api.
gem 'sdoc', '~> 0.4.0', group: :doc

# Use ActiveModel has_secure_password
# gem 'bcrypt', '~> 3.1.7'

# Use Unicorn as the app server
# gem 'unicorn'

# Use Capistrano for deployment
# gem 'capistrano-rails', group: :development

gem 'ruby-trello'
gem 'chronic'
gem 'picky'
gem 'slack-ruby-client'
gem 'devise'
gem 'omniauth'
gem "omniauth-google-oauth2"
gem 'twitter-bootstrap-rails'
gem 'workers'
gem 'nokogiri'
gem 'premailer-rails'
gem 'httparty'
gem 'googleauth'
gem 'google-api-client'
gem 'levenshtein-ffi', require: 'levenshtein'
gem 'airbrake'
gem 'roo'
gem 'lograge'
gem 'twitter'
gem 'redis'
gem 'redis-namespace'
gem 'sidekiq'
gem 'clockwork'
gem 'retries'

group :production do
  gem 'rails_12factor'
  gem 'puma'
  gem 'dalli'
  gem 'connection_pool'
end

group :development, :staging do
  gem 'letter_opener_web'
  gem 'listen'
end

group :development do
  gem 'web-console'
end

group :development, :staging, :test do
  # Call 'byebug' anywhere in the code to stop execution and get a debugger console
  gem 'byebug'

  # Spring speeds up development by keeping your application running in the background. Read more: https://github.com/rails/spring
  gem 'spring'

  gem 'dotenv-rails'
end
