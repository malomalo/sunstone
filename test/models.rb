

WebMock::StubRegistry.instance.global_stubs.push(
  WebMock::RequestStub.new(:get, "http://example.com/ping").to_return(
    body: "pong"
  ),
  
  WebMock::RequestStub.new(:get, "http://example.com/tables").to_return(
    body: %w(ships fleets sailors).to_json
  ),
  
  WebMock::RequestStub.new(:get, "http://example.com/ships/schema").to_return(
    body: {
      id: {type: 'integer', primary_key: true, null: false, array: false},
      fleet_id: {type: 'integer', primary_key: false, null: true, array: false},
      name: {type: 'string', primary_key: false, null: true, array: false}
    }.to_json
  ),
  
  WebMock::RequestStub.new(:get, "http://example.com/fleets/schema").to_return(
    body: {
      id: {type: 'integer', primary_key: true, null: false, array: false},
      name: {type: 'string', primary_key: false, null: true, array: false}
    }.to_json
  ),
  
  WebMock::RequestStub.new(:get, "http://example.com/sailors/schema").to_return(
    body: {
      id: {type: 'integer', primary_key: true, null: false, array: false},
      name: {type: 'string', primary_key: false, null: true, array: false}
    }.to_json
  ),
  
  WebMock::RequestStub.new(:get, "http://example.com/sailors_ships/schema").to_return(
    body: {
      sailor_id: {type: 'integer', primary_key: false, null: false, array: false},
      ship_id: {type: 'integer', primary_key: false, null: true, array: false}
    }.to_json
  )
)

class ExampleRecord < ActiveRecord::Base
  self.abstract_class = true
end

ExampleRecord.establish_connection(
  adapter: 'sunstone',
  url: 'http://example.com'
)

class Fleet < ExampleRecord
  has_many :ships
end

class Ship < ExampleRecord
  belongs_to :fleet
  
  has_and_belongs_to_many :sailors
end

class Sailor < ExampleRecord
  has_and_belongs_to_many :sailors
end