# frozen_string_literal: true

require 'bundler/setup'
require 'fileutils'
require 'securerandom'
require 'base64'

namespace :generate do
  task :session_secret do
    require 'securerandom'
    secret = SecureRandom.random_bytes(32)
    encoded = Base64.strict_encode64(secret)
    puts "SESSION_SECRET=#{encoded}"
    puts "\nAdd this to config/secrets.yml"
  end

  task :msg_key do
    require 'securerandom'
    key = SecureRandom.random_bytes(32)
    encoded = Base64.strict_encode64(key)
    puts "MSG_KEY=#{encoded}"
    puts "\nAdd this to config/secrets.yml or set as Heroku config var"
  end
end

namespace :run do
  task :dev do
    system 'bundle exec rackup -p 9292'
  end
end

namespace :session do
  desc 'Clear the Redis session store'
  task :wipe do
    redis_url = ENV['REDIS_URL']
    redis_url = ENV['REDISCLOUD_URL'] if redis_url.to_s.strip.empty?

    abort 'Set REDIS_URL or REDISCLOUD_URL before running session:wipe' if redis_url.to_s.strip.empty?

    require 'redis'

    Redis.new(url: redis_url).flushdb
    puts "Cleared Redis session store at #{redis_url}"
  end
end

task :spec do
  system(
    'bundle exec ruby -I lib:spec ' \
    'spec/api_client_spec.rb ' \
    'spec/create_account_spec.rb ' \
    'spec/app_spec.rb ' \
    'spec/auth_spec.rb ' \
    'spec/authenticate_account_spec.rb'
  )
end

task default: :spec

desc 'Install deps, prepare secrets, and start the dev server'
task :start do
  puts 'Running start: bundle install, prepare config/secrets.yml, then start dev server'

  abort 'bundle install failed' unless system('bundle install')

  example = 'config/secrets.example.yml'
  target = 'config/secrets.yml'

  if File.exist?(target)
    puts "#{target} already exists — skipping copy"
    text = File.read(target)
    new_text = text.gsub(%r{APP_URL:\s*http://localhost:9292}, 'APP_URL: http://localhost:9293')
    if new_text != text
      File.write(target, new_text)
      puts "Updated APP_URL to use 9293 in #{target}"
    end
  else
    FileUtils.mkdir_p(File.dirname(target))
    FileUtils.cp(example, target)
    puts "Copied #{example} -> #{target}"

    text = File.read(target)
    text.gsub!(%r{APP_URL:\s*http://localhost:9292}, 'APP_URL: http://localhost:9293')

    # Replace placeholder SESSION_SECRET entries like <use `rake generate:session_secret`>
    text.gsub!(/SESSION_SECRET:\s*<[^\n>]*>/) do
      "SESSION_SECRET: #{Base64.strict_encode64(SecureRandom.random_bytes(32))}"
    end

    File.write(target, text)
    puts "Prepared #{target} (APP_URL set to 9293, SESSION_SECRET generated if needed)"
  end

  Rake::Task['run:dev'].invoke
end
