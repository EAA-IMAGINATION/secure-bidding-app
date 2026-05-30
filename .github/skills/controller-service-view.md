# Controller / Service / View Skill

## When to use

- When adding or modifying routes, services, or Slim templates

## Rule

Maintain strict separation: controllers route, services integrate, views render.

## Boundaries

| Layer | Location | Responsibility |
| --- | --- | --- |
| Controllers | `app/controllers/` | `route`/`routing` blocks, session, `view` or redirect |
| Services | `app/services/` | API calls, validation, raise on failure |
| Views | `app/presentation/views/` | Slim templates; partials prefixed with `_` |

## Pattern

```ruby
# Controller — delegate, don't implement business logic
routing.post 'login' do
  account = AuthenticateAccount.new(App.config).call(username:, password:)
  session[:current_account] = account
  routing.redirect '/'
end

# Service — isolate API interaction
class AuthenticateAccount
  def call(username:, password:)
    @client.post('/auth/authenticate', { username:, password: })
  end
end
```

- One service class per file; one controller module per route namespace
- Set `@current_account` in route handlers for views
- Use `require_login!(routing)` to guard protected routes
