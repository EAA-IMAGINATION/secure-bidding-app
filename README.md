# Secure Bidding App

A secure platform for transparent bidding on projects.
This is a server-rendered web frontend built with Roda and Slim.

## Quick Start

### Prerequisites

- Ruby 3.3.0 (see `.ruby-version`)
- Bundler
- The Secure Bidding API running on `http://localhost:3001/api/v1`

### Installation

1. Clone the repository:

   ```bash
   git clone https://github.com/EAA-IMAGINATION/secure-bidding-app.git
   cd secure-bidding-app
   ```

2. Install dependencies:

   ```bash
   bundle install
   ```

3. Setup secrets:

   ```bash
   cp config/secrets.example.yml config/secrets.yml
   bundle exec rake generate:session_secret
   ```

   Copy the generated secret into `config/secrets.yml` under the desired environment.

4. Start the application:
   ```bash
   bundle exec rackup -p 9292
   ```

Visit `http://localhost:9292/` in your browser.

## Development

### Running the Development Server

```bash
bundle exec rake start
```

Or:

```bash
bundle exec rake run:dev
```

The app will start on `http://localhost:9292`.

### Running Tests

```bash
bundle exec rake spec
```

### Console

For interactive debugging:

```bash
bundle exec pry -r ./require_app
```

## Architecture

This is a **thin presentation layer** over the Secure Bidding API. The app handles:

- Session management (cookie-based, 30-day expiration)
- User authentication and logout
- Form rendering with Slim templates
- Flash messages for errors and notices
- Role-based UI rendering (hiding/showing elements based on roles)

### Directory Structure

```
app/
├── controllers/             # Roda route handlers
│   ├── app.rb              # Main app + root routes
│   └── auth.rb             # Authentication routes
├── services/               # Business logic & API integration
│   ├── api_client.rb       # HTTP wrapper for backend API
│   └── authenticate_account.rb
└── presentation/
    ├── views/              # Slim templates
    │   ├── layout.slim     # Main layout
    │   ├── nav.slim        # Navigation bar
    │   ├── flash_bar.slim  # Flash messages
    │   ├── home.slim       # Home page
    │   ├── login.slim      # Login form
    │   └── account.slim    # Account page
    └── assets/
        └── style.css       # Custom styles

config/
├── environments.rb         # App configuration
└── secrets.example.yml     # Secrets template

spec/                       # Tests (when added)
require_app.rb             # Bulk require helper
config.ru                  # Rack entry point
Gemfile                    # Dependencies
README.md                  # This file
```

## Configuration

### Environment Variables (config/secrets.yml)

- `API_URL` - Backend API root URL (default: `http://localhost:3001/api/v1`)
- `APP_URL` - Frontend app URL (default: `http://localhost:9292`)
- `SESSION_SECRET` - Signed/encrypted session secret (generated with `rake generate:session_secret`; 64+ bytes)

### Rack Session Middleware

Sessions are stored in signed, encrypted cookies with a 30-day expiration.
Session data includes:

- `id` (user UUID)
- `username` (string)
- `email` (string, decrypted by API)
- `include` (nested object with `system_roles`)

## Features

### Week 1: Authenticated Sessions & Role-Based UI

- ✅ Layout with responsive navigation
- ✅ Login form with error handling
- ✅ Session-based authentication
- ✅ Logout functionality
- ✅ Account overview page
- ✅ Flash messages (errors & notices)
- ✅ Role-based UI rendering

See `.github/weekly-specifications/week-1.md` for detailed requirements.

## Dependencies

Core gems:

- `roda` - Web framework
- `slim` - Template engine
- `rack-session` - Cookie-based sessions
- `http` - HTTP client for API calls
- `figaro` - Environment configuration
- `rbnacl` - Cryptography

Development gems:

- `pry` - Interactive console
- `bundler-audit` - Security scanning
- `rubocop` - Linter
- `rake` - Task runner

## References

- **API Repository:** https://github.com/EAA-IMAGINATION/secure-bidding-api
- **Weekly Specifications:** `.github/weekly-specifications/`
- **Copilot Instructions:** `.github/copilot-instructions.md`

## License

[See LICENSE file]

---

**Status:** Week 1 implementation in progress  
**Branch:** `1-authenticated-sessions`
