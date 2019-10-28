# Ruby NYPL Platform API Client

Simple client for querying the NYPL Platform API.

## Version

> 1.0.0

## Using

1. Configure the client with Platform API credentials
2. Make requests

### Configuration

Example configuration:

```ruby
require 'nypl_platform_api_client'

client = NyplPlatformApiClient.new({
  base_url: "https://platform.nypl.org/api/v0.1/", # Defaults to ENV['PLATFORM_API_BASE_URL']
  client_id: "client-id", # Defaults to ENV['NYPL_OAUTH_ID']
  client_secret: "client-secret", # Defaults to ENV['NYPL_OAUTH_SECRET']
  oauth_url: "https://isso.nypl.org" # Defaults to ENV['NYPL_OAUTH_URL'],
  log_level: "debug" # Defaults to 'info'
})
```

### Requests

Example GET:

```ruby
bib = client.get 'bibs/sierra-nypl/12082323'
```

Example POST:

```ruby
new_job = client.post 'jobs', '', { 'Content-Type' => 'text/plain' }
```

## Contributing

This repo uses a single, versioned `master` branch.

 * Create feature branch off `master`
 * Compute next logical version and update `README.md`, `CHANGELOG.md`, & `nypl_platform_api_client.gemspec`
 * Create PR against `master`
 * After merging the PR, git tag `master` with new version number.

## Testing

```
bundle exec rspec
```
