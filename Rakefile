# frozen_string_literal: true

require 'bundler/gem_tasks'

desc 'Generate a secure session secret'
task 'generate:session_secret' do
  require 'base64'
  secret = Base64.urlsafe_encode64(SecureRandom.random_bytes(48))
  puts "Add this to config/secrets.yml under the desired environment:"
  puts "  SESSION_SECRET: #{secret}"
end

desc 'Run the app in development'
task 'run:dev' do
  system 'bundle exec rackup -p 9292'
end

desc 'Run tests'
task :spec do
  system 'bundle exec ruby -I lib:spec spec/*_spec.rb'
end

task default: :spec
