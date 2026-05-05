# Copilot Instructions: Secure Bidding App (Frontend)

## Critical: No AI Co-Author Trailers

**Hard Rule:** Never include any AI co-author trailer in commit messages. If a
commit message contains `Co-authored-by: Copilot` or any AI co-author trailer,
remove it immediately before committing.

The developer is the sole author. Commit messages should reflect this clearly.

## Weekly Scope Gate (Hard Rule)

1. Never work ahead of the weekly professor requirements.
2. Keep future-facing skills and UI patterns available as references, but only
   apply them when that week's spec explicitly requires them.
3. At the start of each task, map requirements to the smallest relevant feature
   set.
4. If a requested implementation is outside current week scope, defer it and
   document it as future roadmap work only.
5. Reference each week's specification: See `.github/weekly-specifications/week-N.md`
6. Use the reference repo (https://github.com/ISS-Security/tyto2026-app) as an
   architectural guide but do not exceed specified scope.

## Project Type: Ruby/Roda Web App (Not a Separate Frontend)

This is a **server-rendered web frontend** built with Roda (same framework as the
API). It is a thin presentation layer over the Secure Bidding API; the API holds
the database and enforces authorization. This app handles:

- Session management (cookie-based)
- Login/logout flows
- Form rendering with Slim templates
- Flash messages for errors/notices
- Role-based UI (show/hide buttons based on roles)

## Backend: Secure Bidding API Reference

The app consumes a Ruby/Roda REST API at `http://localhost:3000/api/v1`.

### Core API Endpoints (Week 1 Relevant)

**Authentication (Future):**
- Authentication and authorization not yet implemented in API
- All current endpoints are open (auth comes in Week 1 of app)

**Accounts:**
- `GET /api/v1/accounts` - List all accounts
- `GET /api/v1/accounts/:id` - Fetch account
- `POST /api/v1/accounts` - Create account
- `PATCH /api/v1/accounts/:id` - Update account
- `GET /api/v1/accounts/search` - Search by email/phone
- `GET /api/v1/accounts/:id/system_roles` - List user roles
- `POST /api/v1/accounts/:id/system_roles` - Assign system role

**Projects:**
- `GET /api/v1/projects` - List projects
- `GET /api/v1/projects/:id` - Fetch project details
- `POST /api/v1/projects` - Create project
- `GET /api/v1/projects/:id/memberships` - List project team
- `POST /api/v1/projects/:id/memberships` - Add team member
- `POST /api/v1/projects/:id/bids` - Create bid for project

**Bid Submissions:**
- `GET /api/v1/bid_submissions` - List all bid submissions
- `GET /api/v1/bid_submissions/:id` - Fetch bid submission
- `POST /api/v1/bid_submissions` - Create bid submission
- `GET /api/v1/projects/:id/bid_submissions` - List bids for project

**Payments:**
- `POST /api/v1/payments` - Create payment record
- `GET /api/v1/payments/:id` - Fetch payment details
- `PATCH /api/v1/payments/:id` - Update payment (e.g., mark as paid)

### Data Model Summary

- **Account**: User with username, email (encrypted), phone (encrypted), roles
- **Project**: Bidding project with title, budget_cents
- **BidSubmission**: Encrypted bid for a project (contractor_alias, plaintext_bid)
- **ProjectMembership**: Account assigned to project with role (e.g., bidder, owner)
- **Payment**: Payment record for bid submission access/viewing

## Project Skills and Rules

### 1. Feature Branch Workflow

**Rule:** Never work directly from `main`/`master`.

Before any edits, check the current branch: `git branch --show-current`

If on `main` or `master`, create/switch to a feature branch immediately.

**When to use:** At the start of every new feature.

**Workflow:**
1. Create a branch named for the feature (example: `1-authenticated-sessions`)
2. Implement and test on that branch only
3. Create a pull request for review before merging

### 2. Controller/Service/View Architecture (Roda Pattern)

**Rule:** Maintain strict separation of concerns.

- **Controllers** (`app/controllers/`): HTTP request handlers (Roda-based)
  - Define routes with `route` and `routing` blocks
  - Delegate business logic to services
  - Render views with `view` or redirect with `routing.redirect`
  - Store user data in `session[:current_account]`
  
- **Services** (`app/services/`): Business logic and API integration
  - Handle all HTTP calls to backend API
  - Raise descriptive errors on API failures
  - Return parsed, validated data to controllers
  - Examples: `AuthenticateAccount`, `CreateBidSubmission`

- **Views** (`app/presentation/views/`): Slim templates
  - Use Slim for HTML rendering
  - Include layout template: `layout.slim`
  - Use partials for reusable components (prefix with `_`)
  - Conditionally render based on `@current_account` for role-based UI

**Pattern:**
```
# app/controllers/auth.rb
route('auth') do |routing|
  routing.post 'login' do
    account = AuthenticateAccount.new(App.config).call(...)
    session[:current_account] = account
    routing.redirect '/'
  end
end

# app/services/authenticate_account.rb
class AuthenticateAccount
  def call(username:, password:)
    response = @client.post('/auth/authenticate', {...})
    response['attributes']
  end
end
```

### 3. API Integration Patterns

**Rule:** Isolate all API calls in service modules using `ApiClient`.

**When to use:** Before adding any feature that fetches or posts data.

**Pattern:**
```ruby
# app/services/api_client.rb
class ApiClient
  def get(path, params: {})
    parse(HTTP.get(url(path)))
  end

  def post(path, body)
    parse(HTTP.post(url(path), json: body))
  end
end

# app/services/some_service.rb
class SomeService
  def initialize(config)
    @client = ApiClient.new(config)
  end

  def call
    @client.post('/api/v1/endpoint', { key: 'value' })
  end
end
```

- Always check response status before parsing JSON
- Raise `ApiClient::ApiError` with status and message on non-2xx responses
- Return parsed JSON on success
- Keep error handling in the service layer
- Catch service errors in controllers and set flash messages

### 4. Session and Authentication

**Rule:** Use `Rack::Session::Cookie` for signed, encrypted cookies.

**When to use:** When storing user data between requests.

**Pattern:**
```ruby
# config/environments.rb
use Rack::Session::Cookie,
    expire_after: ONE_MONTH,
    secret: config.SESSION_SECRET

# In controllers
session[:current_account] = account  # Store on login
@current_account = session[:current_account]  # Access user
session[:current_account] = nil  # Clear on logout
```

- Never store passwords in session
- Store only non-sensitive account info (username, email, roles)
- Set `@current_account` in route handler for use in views
- Use `require_login!(routing)` helper to guard routes

### 5. Flash Messages

**Rule:** Use Roda's flash plugin for error/notice messages.

**When to use:** After form submission, login, logout, or error conditions.

**Pattern:**
```ruby
# In controller
flash[:error] = 'Login failed'
flash[:notice] = 'Welcome back!'
flash.now[:error] = 'Display immediately without redirect'

# In view (app/presentation/views/flash_bar.slim)
- if flash[:error]
  div class="alert alert-danger"
    = flash[:error]
- if flash[:notice]
  div class="alert alert-success"
    = flash[:notice]
```

### 6. Build and Development Commands

**Rule:** Keep build and test commands simple and consistent with the API.

**Core commands:**
```bash
bundle install              # Install dependencies
bundle exec rackup -p 9292 # Start dev server (localhost:9292)
bundle exec rake spec       # Run tests (when added)
```

Before committing:
```bash
bundle exec rake spec       # Run tests
```

### 7. Role-Based UI Patterns

**Rule:** Hide/show UI elements based on roles without enforcing authorization
(API enforces; app only shows appropriate UI).

**Pattern:**
```slim
- if @current_account
  - if system_roles_of(@current_account).include?('admin')
    button Delete User

- else
  a href="/auth/login" Login
```

Helpers (in controller):
```ruby
def system_roles_of(current_account)
  current_account&.dig('include', 'system_roles') || []
end

def admin?(current_account)
  system_roles_of(current_account).include?('admin')
end
```

### 8. Markdown Linting

**Rule:** After editing any `.md` file, always run markdown linting before finishing.

```bash
npx markdownlint-cli2 "**/*.md" "#node_modules" 2>&1
```

### 9. Commit Authorship

**Rule:** Commit only after tests pass, keep message short/meaningful, NEVER add
any AI co-author trailer, and ask whether to push.

**Workflow:**
1. Run `bundle exec rake spec` to ensure all checks pass
2. Stage files: `git add .`
3. Create commit with short, meaningful message: `git commit -m "Add login form and session handling"`
4. Ask the developer: "Ready to push to remote?"

**Hard Stop:** If draft message contains `Co-authored-by: Copilot` or any AI
co-author trailer, remove it immediately before presenting or running commit.

### 10. Delivery Checkpoint

**Rule:** At end of weekly implementation, run full test suite, prepare staged
commit, and ask developer to execute final push.

**Checklist:**
- [ ] All tests pass: `bundle exec rake spec`
- [ ] No console errors in manual testing
- [ ] Flash messages display correctly
- [ ] No unresolved TODO comments
- [ ] Commit message is clear and short
- [ ] No AI co-author trailers in commit
- [ ] Developer executes commit manually
- [ ] Developer decides whether to push

## Architecture

This is a Roda-based web frontend for the Secure Bidding API.

### Directory Structure

```
app/
├── controllers/              # Roda route handlers
│   ├── app.rb              # Main app + root routes
│   └── auth.rb             # /auth/login, /auth/logout
├── services/               # Business logic and API calls
│   ├── api_client.rb       # HTTP client wrapper
│   ├── authenticate_account.rb
│   ├── create_account.rb
│   └── ...
├── presentation/
│   ├── views/              # Slim templates
│   │   ├── layout.slim     # Main layout template
│   │   ├── nav.slim        # Navigation bar
│   │   ├── flash_bar.slim  # Flash messages
│   │   ├── home.slim       # Home page
│   │   ├── login.slim      # Login form
│   │   └── account.slim    # Account overview
│   ├── assets/             # CSS/JS
│   │   └── style.css
│   └── public/             # Static files
│       └── logo.png
config/
├── environments.rb         # App config, session setup
└── secrets.example.yml     # Secrets template
spec/                       # Tests (when added)
require_app.rb             # Bulk require helper
config.ru                  # Rack entry point
Gemfile                    # Dependencies
```

### Dependencies (Core)

- `roda` - Web framework
- `slim` - Template engine
- `rack-session` - Cookie-based sessions
- `http` - HTTP client for API calls
- `figaro` - Environment variable management
- `rbnacl` - Cryptography (via Secure Bidding API integration)

Development gems:

- `puma` - Application server
- `pry` - Interactive console
- `bundler-audit` - Security vulnerability scanning
- `rubocop` - Linter

Test gems:

- `rack-test` - HTTP testing helpers
- `minitest` - Test framework

### Environment Variables

Create `.env` equivalent in `config/secrets.yml` (copy from
`config/secrets.example.yml`):

```yaml
development:
  API_URL: http://localhost:3000/api/v1
  APP_URL: http://localhost:9292
  SESSION_SECRET: <generate with `rake generate:session_secret`>
```

Do NOT commit `config/secrets.yml` with real secrets.

## API Startup and Testing

Before running the frontend, ensure the backend is running:

```bash
# Terminal 1: Backend (from secure-bidding-api/)
bundle install
cp config/secrets-example.yml config/secrets.yml
mkdir -p app/db/store
bundle exec rake db:migrate
bundle exec rake db:seed
bundle exec rackup -p 9292

# Terminal 2: Frontend (from secure-bidding-app/)
bundle install
cp config/secrets.example.yml config/secrets.yml
bundle exec rake generate:session_secret
# paste the printed value into config/secrets.yml
bundle exec rackup -p 9292
```

Visit `http://localhost:9292/` in your browser.

To verify API is accessible:
```bash
curl http://localhost:9292/
# Expected: Home page HTML
```

## Key Conventions

### Naming

- Use snake_case for file names: `authenticate_account.rb`, `auth.rb`
- Use CamelCase for class names: `AuthenticateAccount`, `ApiClient`
- Use snake_case for methods and variables: `current_account`, `authenticate_user`
- Routes use lowercase: `/auth/login`, `/account/username`

### Code Organization

- One service class per file
- One controller module per route namespace
- Keep templates small; extract partials for reusability
- Use descriptive variable names

### Error Handling

- Services raise `ApiClient::ApiError` on API failures
- Controllers catch errors and set flash messages
- Controllers return appropriate HTTP status codes (400 on form error, 401 on auth failure)

### Response Patterns

- Success: Render view or redirect with `flash[:notice]`
- Validation failure: Re-render form with `flash.now[:error]` and 400 status
- Authorization failure: Redirect to login with `flash[:error]`
- API error: Display error message in flash

## Current Focus

- Week 1: Authenticated sessions, login/logout, role-based UI
- Follow weekly specifications: `.github/weekly-specifications/week-N.md`
- Use reference repo as architectural guide
- Never exceed current week's scope

## Future Capability Skills (Reference Only)

These will be created and used only when weekly specs require them:

- `.github/skills/encryption-ui.md` (Display/input for encrypted bids)
- `.github/skills/role-based-authorization.md` (Project-scoped roles)
- `.github/skills/payment-flow.md` (Payment integration)
- `.github/skills/bid-submission-flow.md` (Full bid lifecycle)

## References

- API Repo: <https://github.com/EAA-IMAGINATION/secure-bidding-api>
- Frontend Repo: <https://github.com/EAA-IMAGINATION/secure-bidding-app>
- Reference Web App: <https://github.com/ISS-Security/tyto2026-app/tree/1-authenticated-sessions>
- Weekly Assignments: `.github/weekly-specifications/week-N.md`

---

**Last Updated:** 2026-05-04  
**Status:** Updated for Roda/Ruby web app architecture  
**Next Step:** See `.github/weekly-specifications/week-1.md` for implementation
