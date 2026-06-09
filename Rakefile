# frozen_string_literal: true

require 'bundler/setup'
require 'fileutils'
require 'securerandom'
require 'base64'

SESSION_SECRET_BYTES = 64

namespace :generate do
  task :session_secret do
    require 'securerandom'
    secret = SecureRandom.random_bytes(SESSION_SECRET_BYTES)
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

  task :signing_key do
    require 'rbnacl'
    signing_key = RbNaCl::SigningKey.generate
    verify_key = signing_key.verify_key
    puts "SIGNING_KEY=#{Base64.strict_encode64(signing_key.to_bytes)}"
    puts " VERIFY_KEY=#{Base64.strict_encode64(verify_key.to_bytes)}"
    puts "\nAdd SIGNING_KEY to the app secrets and VERIFY_KEY to the API secrets"
  end
end

namespace :url do
  desc 'Generate SRI integrity hash for a URL (argument: URL=...)'
  task :integrity do
    url = ENV.fetch('URL', nil)
    abort 'Usage: rake url:integrity URL=https://example.com/script.js' if url.to_s.strip.empty?

    sha384 = `curl -L -s #{url} | openssl dgst -sha384 -binary | openssl enc -base64 -A`.strip
    puts "sha384-#{sha384}"
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
    redis_url = ENV.fetch('REDIS_URL', nil)
    redis_url = ENV.fetch('REDISCLOUD_URL', nil) if redis_url.to_s.strip.empty?

    abort 'Set REDIS_URL or REDISCLOUD_URL before running session:wipe' if redis_url.to_s.strip.empty?

    require 'redis'

    Redis.new(url: redis_url).flushdb
    puts "Cleared Redis session store at #{redis_url}"
  end
end

task :spec do
  system(
    'bundle exec ruby -I lib:spec -e "ARGV.each { |file| load file }" ' \
    'spec/api_client_spec.rb ' \
    'spec/admin_users_spec.rb ' \
    'spec/assign_system_role_spec.rb ' \
    'spec/app_spec.rb ' \
    'spec/auth_spec.rb ' \
    'spec/authenticate_account_spec.rb ' \
    'spec/registration_spec.rb ' \
    'spec/reset_password_spec.rb ' \
    'spec/security_features_spec.rb ' \
    'spec/signed_message_spec.rb ' \
    'spec/client_side_security_spec.rb ' \
    'spec/account_profile_spec.rb ' \
    'spec/my_projects_spec.rb ' \
    'spec/fetch_projects_spec.rb'
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
      "SESSION_SECRET: #{Base64.strict_encode64(SecureRandom.random_bytes(SESSION_SECRET_BYTES))}"
    end

    File.write(target, text)
    puts "Prepared #{target} (APP_URL set to 9293, SESSION_SECRET generated if needed)"
  end

  Rake::Task['run:dev'].invoke
end
