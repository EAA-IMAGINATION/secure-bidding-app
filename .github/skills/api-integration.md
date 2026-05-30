# API Integration Skill

## When to use

- Before adding any feature that fetches or posts data to the backend

## Rule

Isolate all HTTP calls in service classes using `ApiClient`.

## Pattern

```ruby
class ApiClient
  def get(path, params: {})
    parse(HTTP.get(url(path)))
  end

  def post(path, body)
    parse(HTTP.post(url(path), json: body))
  end
end

class SomeService
  def initialize(config)
    @client = ApiClient.new(config)
  end

  def call
    @client.post('/api/v1/endpoint', { key: 'value' })
  end
end
```

## Error handling

- Check response status before parsing JSON
- Raise `ApiClient::ApiError` with status and message on non-2xx
- Controllers catch service errors and set flash messages
- Never call the API directly from controllers or views
