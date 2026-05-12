# frozen_string_literal: true

source 'https://rubygems.org'
ruby File.read('.ruby-version').strip

# Web framework & templating
gem 'rack-session', '~>2.0'
gem 'roda', '~>3.0'
gem 'slim'

# Configuration & secrets
gem 'figaro', '~>1.2'

# HTTP client for API calls
gem 'http', '~>5.1'

# Security & encoding
gem 'base64'
gem 'rbnacl', '~>7.1'

# Server
gem 'puma', '~>7.0'
gem 'rackup'

# Development utilities
gem 'pry'

group :development do
  gem 'bundler-audit'
  gem 'rake'
  gem 'rubocop'
  gem 'rubocop-performance'
end

group :development, :test do
  gem 'rack-test'
  gem 'rerun'
end

group :test do
  gem 'minitest'
  gem 'webmock'
end
