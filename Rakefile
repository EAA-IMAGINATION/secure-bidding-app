# frozen_string_literal: true

require 'bundler/setup'

namespace :generate do
  task :session_secret do
    require 'securerandom'
    secret = SecureRandom.random_bytes(32)
    encoded = Base64.strict_encode64(secret)
    puts "SESSION_SECRET=#{encoded}"
    puts "\nAdd this to config/secrets.yml"
  end
end

namespace :run do
  task :dev do
    system 'bundle exec rackup -p 9292'
  end
end

task :spec do
  system(
    'bundle exec ruby -I lib:spec '\
    'spec/api_client_spec.rb '\
    'spec/app_spec.rb '\
    'spec/auth_spec.rb '\
    'spec/authenticate_account_spec.rb'
  )
end

task default: :spec
