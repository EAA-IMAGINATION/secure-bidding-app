# Role-Based UI Skill

## When to use

- When showing or hiding UI elements based on user roles

## Rule

The app controls visibility only; the API enforces authorization.

## Pattern

```slim
- if @current_account
  - if admin?(@current_account)
    button Delete User
- else
  a href="/auth/login" Login
```

```ruby
def system_roles_of(current_account)
  current_account&.dig('include', 'system_roles') || []
end

def admin?(current_account)
  system_roles_of(current_account).include?('admin')
end
```

- Define role helpers in the controller module
- Never rely on hidden UI alone for security — API must reject unauthorized actions
