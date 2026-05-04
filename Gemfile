# frozen_string_literal: true

source 'https://rubygems.org'
ruby File.read('.ruby-version').strip

# Web framework & templating
gem 'roda', '~>3.0'
gem 'slim'
gem 'rack-session', '~>2.0'

# Configuration & secrets
gem 'figaro', '~>1.2'

# HTTP client for API calls
gem 'http', '~>5.1'

# Security & encoding
gem 'rbnacl', '~>7.1'
gem 'base64'

# Server
gem 'puma', '~>7.0'

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
end
