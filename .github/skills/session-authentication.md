# Session and Authentication Skill

## When to use

- When storing user state between requests or implementing login/logout

## Rule

Use `Rack::Session::Cookie` for signed, encrypted session cookies.

## Pattern

```ruby
# config/environments.rb
use Rack::Session::Cookie,
    expire_after: ONE_MONTH,
    secret: config.SESSION_SECRET

# Controller
session[:current_account] = account   # on login
@current_account = session[:current_account]
session[:current_account] = nil       # on logout
```

## Constraints

- Never store passwords in session
- Store only non-sensitive account info (username, email, roles)
- Guard protected routes with `require_login!(routing)`
