#!/usr/bin/env bash
set -euo pipefail

# Heroku setup script for Secure Bidding API and App
# Run this locally where you can authenticate with the Heroku CLI.
# Prompts for app names; leave blank to auto-generate.

ROOT_DIR=$(cd "$(dirname "$0")/.." && pwd)
API_DIR="$ROOT_DIR/../secure-bidding-api"
APP_DIR="$ROOT_DIR"

read -p "Heroku app name for API (leave blank to auto-generate): " API_APP
if [ -z "$API_APP" ]; then
  API_APP="secure-bidding-api-$(openssl rand -hex 3)"
fi

read -p "Heroku app name for App (leave blank to auto-generate): " APP_APP
if [ -z "$APP_APP" ]; then
  APP_APP="secure-bidding-app-$(openssl rand -hex 3)"
fi

echo "API app: $API_APP"
echo "App app: $APP_APP"

echo "Ensure you're logged into Heroku (heroku login). If not, please run 'heroku login' in another terminal and re-run this script."

# Create API app
heroku create "$API_APP" --remote "$API_APP" || true

# Provision Postgres for API with fallbacks
attempt_addon_create() {
  local app="$1"; shift
  for plan in "$@"; do
    echo "Attempting to provision addon plan: $plan"
    if heroku addons:create "$plan" --app "$app"; then
      echo "Provisioned $plan on $app"
      return 0
    else
      echo "Failed to provision $plan on $app; trying next option..."
    fi
  done
  echo "All provisioning attempts failed for app $app"
  return 1
}

# Try preferred then fallback plans
attempt_addon_create "$API_APP" "heroku-postgresql:hobby-dev" "heroku-postgresql:mini" "heroku-postgresql" || true

# Set production env for API
heroku config:set RACK_ENV=production --app "$API_APP"

# Deploy API: push current branch to Heroku main
pushd "$API_DIR"
  git fetch --all
  heroku git:remote -a "$API_APP"
  echo "Generating SESSION_SECRET for API"
  SESSION_SECRET=$(bundle exec rake generate:session_secret 2>/dev/null | sed -n 's/^SESSION_SECRET=//p')
  heroku config:set SESSION_SECRET="$SESSION_SECRET" --app "$API_APP"
  git push "$API_APP" HEAD:main
popd

# Create App
heroku create "$APP_APP" --remote "$APP_APP" || true

# Provision Redis for App with fallback (prefer RedisCloud 30MB)
attempt_addon_create "$APP_APP" "rediscloud:30" "heroku-redis:hobby-dev" "heroku-redis" || true

# Set config for App
API_URL="https://$API_APP.herokuapp.com/api/v1"
APP_URL="https://$APP_APP.herokuapp.com"

# Generate secrets for App
pushd "$APP_DIR"
  echo "Generating SESSION_SECRET and MSG_KEY for App"
  SESSION_SECRET=$(bundle exec rake generate:session_secret 2>/dev/null | sed -n 's/^SESSION_SECRET=//p')
  MSG_KEY=$(bundle exec rake generate:msg_key 2>/dev/null | sed -n 's/^MSG_KEY=//p')
  heroku config:set API_URL="$API_URL" APP_URL="$APP_URL" SESSION_SECRET="$SESSION_SECRET" MSG_KEY="$MSG_KEY" --app "$APP_APP"
  heroku git:remote -a "$APP_APP"
  git fetch --all
  git push "$APP_APP" HEAD:main
popd

echo "Deployment commands completed. Visit: $APP_URL and https://$API_APP.herokuapp.com"
