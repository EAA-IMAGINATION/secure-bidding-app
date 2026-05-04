# Week 1 Specification: Authenticated Sessions & Role-Based UI

## Assignment Overview

Build a server-rendered web frontend (Roda + Slim) that implements user
authentication, cookie-based sessions, flash messages, and role-based UI
rendering. The app integrates with the Secure Bidding API.

**Reference Implementation:** https://github.com/ISS-Security/tyto2026-app/tree/1-authenticated-sessions

## Requirements

### 1. Create a Client Interface Web Application

#### 1.1 Layout Template with Navigation

- **File:** `app/presentation/views/layout.slim`
- **Content:**
  - DOCTYPE and HTML structure
  - Link to Bootstrap 5.3 CSS (via Bootswatch CDN)
  - Navigation bar rendered via `render :nav`
  - Flash message bar rendered via `render :flash_bar`
  - Main content area with `yield`
  - Bootstrap JS bundle from CDN

#### 1.2 Navigation Bar

- **File:** `app/presentation/views/nav.slim`
- **Logged Out (default):**
  - "Home" link
  - "Login" link
  - "Register" link (disabled, coming soon)
- **Logged In:**
  - "Home" link
  - "Projects" link (if implementing)
  - Username dropdown with:
    - "Account" link
    - "Logout" link

#### 1.3 Home Page

- **File:** `app/presentation/views/home.slim`
- **Content:**
  - Welcome message (different for logged in vs. logged out users)
  - Call-to-action button(s) appropriate to state

#### 1.4 Login Page

- **File:** `app/presentation/views/login.slim`
- **Form:**
  - Username input field
  - Password input field
  - Submit button labeled "Login"
  - Centered layout (3-column grid with 6-column content)

#### 1.5 Account Overview Page

- **File:** `app/presentation/views/account.slim`
- **Display:**
  - Username
  - Email (from API response)
  - System roles (comma-separated or as badges)
  - Link to update account (future weeks)
  - Logout link

### 2. Login/Logout & Session Management

#### 2.1 Controllers

- **Main App Controller** (`app/controllers/app.rb`)
  - Define root route (GET /)
  - Set `@current_account = session[:current_account]` in all routes
  - Include `require_login!(routing)` helper for protected routes
  - Render layout and views

- **Auth Controller** (`app/controllers/auth.rb`)
  - **GET /auth/login** - Render login form
  - **POST /auth/login** - Accept username/password, call service, set session
  - **GET /auth/logout** - Clear session, redirect to home with notice

#### 2.2 Services

- **ApiClient** (`app/services/api_client.rb`)
  - GET, POST, PUT, DELETE methods
  - Parse JSON responses
  - Raise `ApiClient::ApiError` on non-2xx status
  - Include status code and body in error

- **AuthenticateAccount** (`app/services/authenticate_account.rb`)
  - Accept username and password
  - Call API (future: when auth endpoint exists in API)
  - For now: Query GET /api/v1/accounts and validate password locally
     (This is a placeholder; real auth will come from API endpoint)
  - Return account attributes + roles on success
  - Raise `UnauthorizedError` on failure

#### 2.3 Session Storage

- **Location:** `Rack::Session::Cookie` in `config/environments.rb`
- **Expiration:** 30 days (ONE_MONTH constant)
- **Secret:** Loaded from `config/secrets.yml` (SESSION_SECRET)
- **Content:** `session[:current_account]` contains:
  - `id` (UUID)
  - `username` (string)
  - `email` (string, decrypted by API)
  - `include` (nested object with roles)

### 3. Flash Messages

#### 3.1 Setup

- Use Roda's built-in flash plugin: `plugin :flash`
- Flash middleware already included in reference implementation

#### 3.2 Flash Bar View

- **File:** `app/presentation/views/flash_bar.slim`
- **Display:**
  - Bootstrap alert-danger for `flash[:error]`
  - Bootstrap alert-success for `flash[:notice]`
  - Each with appropriate icon (optional)

#### 3.3 Controller Usage

- **Login success:** `flash[:notice] = "Welcome back #{account['username']}!"`
- **Login failure:** `flash.now[:error] = "Username and password did not match our records"`
- **Logout:** `flash[:notice] = "You've been logged out"`
- **Unauthorized (protected route):** `flash[:error] = "Please log in to continue"`

### 4. Role-Based UI Functionality

#### 4.1 Helper Methods (in App controller)

```ruby
def system_roles_of(current_account)
  current_account&.dig('include', 'system_roles') || []
end

def admin?(current_account)
  system_roles_of(current_account).include?('admin')
end

def require_login!(routing)
  return if @current_account
  flash[:error] = 'Please log in to continue'
  routing.redirect '/auth/login'
end
```

#### 4.2 UI Rendering Based on Roles

- **Navigation:** Show account/logout only if logged in; show login if logged out
- **Account Page:** Only accessible to logged-in users
- **Future Routes:** Guard with `require_login!` and role checks

#### 4.3 Status Codes

- **200 OK** - Successful GET or form redirect
- **201 Created** - POST success (if implementing)
- **400 Bad Request** - Form validation error, re-render form
- **401 Unauthorized** - Not logged in when required
- **403 Forbidden** - Logged in but lacks role
- **404 Not Found** - Resource not found

## Environment Setup

### 1. Gemfile

Include:
- `roda` (~> 3.0)
- `slim` (template engine)
- `rack-session` (~> 2.0)
- `http` (~> 5.1) - for API calls
- `figaro` (~> 1.2) - environment variables
- `rbnacl` (~> 7.1) - cryptography
- `puma` (~> 7.0) - server
- Development: `pry`, `bundler-audit`, `rubocop`

### 2. Configuration Files

- `config/environments.rb` - App config, session middleware
- `config/secrets.example.yml` - Template for secrets
- `config/secrets.yml` - Actual secrets (git-ignored)
- `.gitignore` - Exclude secrets, logs, dependencies

### 3. Rake Tasks

- `bundle exec rake generate:session_secret` - Generate a secure SESSION_SECRET

### 4. Startup

```bash
bundle install
cp config/secrets.example.yml config/secrets.yml
bundle exec rake generate:session_secret
# Paste output into config/secrets.yml
bundle exec rackup -p 9292
```

## Testing Strategy

### Manual Testing Checklist

1. **Home Page**
   - [ ] Displays welcome message when logged out
   - [ ] Displays username when logged in
   - [ ] Links are appropriate (login vs. logout)

2. **Login Flow**
   - [ ] GET /auth/login renders form
   - [ ] POST /auth/login with valid credentials logs in
   - [ ] Session stores account data
   - [ ] Flash notice displays
   - [ ] Redirects to home

3. **Login Failure**
   - [ ] POST /auth/login with invalid credentials shows error
   - [ ] Flash error message displays
   - [ ] Status code is 400
   - [ ] Form is re-rendered

4. **Logout**
   - [ ] GET /auth/logout clears session
   - [ ] Redirects to login page
   - [ ] Flash notice displays

5. **Account Page (Logged In)**
   - [ ] GET /account/USERNAME displays account details
   - [ ] Shows username, email, roles
   - [ ] Only accessible when logged in (redirects if not)

6. **Role-Based UI**
   - [ ] Navigation shows different links when logged in vs. out
   - [ ] Admin users see admin-only options (future)

## Scope Boundaries (What's NOT in Week 1)

- ❌ User registration (Week 2+)
- ❌ Project CRUD operations (Week 2+)
- ❌ Bid submission forms (Week 3+)
- ❌ Payment integration (Week 3+)
- ❌ Encryption/decryption UI (Week 4+)
- ❌ API-side authentication (API Week 4+; App integrates after)
- ❌ Automated tests (add when spec requires)

## Notes

- **API Endpoint Placeholder:** The secure-bidding-api does not yet have a
  `/auth/authenticate` endpoint. For Week 1, implement a local validation
  or stub the authenticate service to always succeed for testing.
- **Reference Implementation:** The tyto2026-app repo shows the exact pattern;
  adapt it for bid-domain terminology (projects vs. courses, bids vs. enrollments).
- **Bootstrap Styling:** Use Bootstrap 5.3 classes for consistent UI (from Bootswatch CDN).
- **No Console Tests:** This week focuses on manual browser testing and HTTP checks.

## Deliverables

- [ ] Layout template with navigation (layout.slim, nav.slim)
- [ ] Home page (home.slim)
- [ ] Login page and form (login.slim)
- [ ] Account overview page (account.slim)
- [ ] Flash message bar (flash_bar.slim)
- [ ] Auth controller with login/logout routes
- [ ] App controller with root route
- [ ] AuthenticateAccount service
- [ ] ApiClient service
- [ ] config/environments.rb with session middleware
- [ ] config/secrets.example.yml template
- [ ] Rake task to generate session secret
- [ ] Manual testing verification (checklist above)
- [ ] .gitignore to exclude secrets
- [ ] All code committed with clear messages (no AI trailers)

---

**Branch Name:** `1-authenticated-sessions`  
**Reference Repo:** https://github.com/ISS-Security/tyto2026-app/tree/1-authenticated-sessions  
**Last Updated:** 2026-05-04
