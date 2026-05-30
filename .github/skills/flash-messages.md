# Flash Messages Skill

## When to use

- After form submission, login, logout, or error conditions

## Rule

Use Roda's flash plugin for user feedback.

## Pattern

```ruby
# Controller
flash[:error] = 'Login failed'
flash[:notice] = 'Welcome back!'
flash.now[:error] = 'Show immediately without redirect'
```

```slim
/ app/presentation/views/flash_bar.slim
- if flash[:error]
  div.alert.alert-danger = flash[:error]
- if flash[:notice]
  div.alert.alert-success = flash[:notice]
```

- Use `flash.now` when re-rendering a form on validation failure
- Use `flash[:key]` with redirects for post-redirect-get flows
