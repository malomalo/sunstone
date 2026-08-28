# Sunstone

Sunstone is an [ActiveRecord](https://rubygems.org/gems/activerecord) adapter for
querying APIs that conform to [StandardAPI](https://github.com/waratuman/standardapi).

It lets you talk to a remote HTTP API using the ActiveRecord query interface you
already know — `where`, `order`, `limit`, `find`, associations, and persistence
(`create`/`update`/`destroy`) — while Sunstone translates those calls into
StandardAPI HTTP requests instead of SQL.

## Requirements

- Ruby >= 3.3
- ActiveRecord >= 8.0.1 (Rails 8.0 and 8.1)

## Installation

Add `sunstone` to your Gemfile:

```ruby
gem 'sunstone'
```

## Configuration

### Rails

Configure the connection in `config/database.yml`:

```yaml
development:
  adapter: sunstone
  url: https://my-api-key@mystanda.rd/api
```

The connection accepts the following options:

| Option        | Description                                                        |
| ------------- | ------------------------------------------------------------------ |
| `url`         | Sets `host`, `port`, `use_ssl`, and (from userinfo) `api_key`      |
| `host`        | API host (defaults to `127.0.0.1`)                                 |
| `port`        | API port (defaults to `80`, or `443` when `use_ssl`)              |
| `use_ssl`     | Connect over HTTPS (inferred from an `https://` url)               |
| `api_key`     | Token sent in the `Api-Key` request header                         |
| `user_agent`  | String prepended to Sunstone's own `User-Agent`                    |
| `ca_cert`     | Path to a CA certificate file (used when `use_ssl` is set)         |

`url` is a convenience that fills in the others, so this:

```yaml
  url: https://my-api-key@mystanda.rd:443/api
```

is equivalent to:

```yaml
  host: mystanda.rd
  port: 443
  use_ssl: true
  api_key: my-api-key
```

### Standalone ActiveRecord

Establish the connection on `ActiveRecord::Base` (or your abstract model, e.g.
`ApplicationRecord`):

```ruby
ActiveRecord::Base.establish_connection(
  adapter: 'sunstone',
  url: 'https://my-api-key@mystanda.rd/api'
)
```

## Usage

The models below are used throughout the examples:

```ruby
class Fleet < ApplicationRecord
  has_many :ships
end

class Ship < ApplicationRecord
  belongs_to :fleet
  has_and_belongs_to_many :sailors
end
```

### Querying

```ruby
Ship.find(42)                 # where: {id: 42}, limit: 1
Ship.all                      # GET /ships
Ship.where(id: 10)            # where: {id: 10}
Ship.where(fleet_id: nil)     # where: {fleet_id: nil}
Ship.where(id: [10, 12])      # id IN (10, 12)
Ship.order(:id)               # order: [{id: :asc}]
Ship.limit(5000)              # limit: 5000
```

`find_each` pages through the collection automatically:

```ruby
Ship.find_each { |ship| ... } # GET /ships in batches with limit/offset
```

Arel predicates are supported for comparisons and boolean logic:

```ruby
Ship.where(Ship.arel_table[:id].gt(10))
Ship.where(Ship.arel_table[:id].eq(10).or(Ship.arel_table[:name].eq('name')))
```

You can inspect the query a relation will send:

```ruby
Ship.where(id: 10).to_sql
# => "SELECT ships.* FROM ships WHERE ships.id = 10"
```

### Querying across associations

Pass a nested hash to filter on an associated resource:

```ruby
Ship.where(fleet: { id: 1 })              # belongs_to
Fleet.where(ships: { id: 1 })             # has_many
Ship.where(sailors: { id: 1 })            # has_and_belongs_to_many
Fleet.where(ships: { sailors: { id: 1 } }) # nested
```

### Aggregations

```ruby
Ship.count          # select: [{count: "*"}]  (GET /ships/calculate)
Ship.count(:id)     # select: [{count: "id"}]
Ship.sum(:weight)   # select: [{sum: "weight"}]
Ship.distinct       # distinct: true
```

### Eager loading

`eager_load` loads associations in a single request; `preload` issues a
separate request per association:

```ruby
Fleet.eager_load(ships: :sailors)  # one request, nested payload
Fleet.preload(ships: :sailors)     # a request per association
```

### Persistence

```ruby
fleet = Fleet.create(name: 'Armada Uno')   # POST   /fleets
ship  = Ship.find(1)
ship.update(name: 'Definant')              # PATCH  /ships/1
ship.destroy                               # DELETE /ships/1
```

Validation errors returned by the API (e.g. a `400` response) are written back
onto the record:

```ruby
fleet = Fleet.create(name: nil)
fleet.errors[:name] # => [...]  populated from the API response
```

Associations can be written through the parent, matching ActiveRecord's nested
attributes and `*_ids` conventions:

```ruby
# belongs_to — creates the fleet alongside the ship
Ship.create(name: 'Definant', fleet: Fleet.new(name: 'Armada Duo'))

# has_many — assign by id, by records, or clear
Fleet.create(name: 'Spanish Armada', ship_ids: [2])
fleet.update(ships: fleet.ships + [Ship.find(3)])
fleet.update(ships: [])   # clears the relation

# has_and_belongs_to_many
ship.update(sailors: [Sailor.find(1)])
```

### RPC

`rpc` declares a custom, non-CRUD action that maps to a `POST` on a member
endpoint. Any attributes the API returns are written back onto the record:

```ruby
class Ship < ApplicationRecord
  rpc :self_destruct
end

ship.self_destruct!   # POST /ships/:id/self_destruct
```

## Column types

Beyond the standard ActiveRecord types, the adapter registers:

- `array` — JSON-serialized arrays of any subtype
- `json`
- `uuid` — validated and cast as a UUID
- `binary` — Base64-encoded over the wire
- `datetime` — serialized as ISO 8601

Geospatial (GIS) support is opt-in. Require it to register the `geometry` /
`geography` (EWKB) types, which use [RGeo](https://rubygems.org/gems/rgeo):

```ruby
require 'sunstone/gis'
```

## License

Sunstone is released under the [MIT License](LICENSE).

## Changelog

See [CHANGELOG.md](CHANGELOG.md).
