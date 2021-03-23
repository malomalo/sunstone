# Sunstone

Sunstone is an [ActiveRecord](https://rubygems.org/gems/activerecord) adapter for quering
APIs conforming to [Standard API](https://github.com/waratuman/standardapi).

Configuration
-------------

### Rails

Add `sunstone` to your Gemfile:

```ruby
gem 'sunstone'
```

Update `config/database.yml`"

```yaml
development:
  adapter: sunstone
  url: https://mystanda.rd/api
  api_key: ..optional..
  user_agent: ..optional..
```

### Standalone ActiveRecord

Initialize the connection on `ActiveRecord::Base` or your abstract model (`ApplicationRecord` for example)

```ruby
ActiveRecord::Base.establish_connection(
  adapter: 'sunstone',
  url: 'https://mystanda.rd/api'
)
```

Usage
-----

Mention fitler / etc...

TODO:
=====
Make `cookie_store` and optional
stream building model instances with wankel
