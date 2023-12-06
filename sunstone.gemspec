require File.expand_path("../lib/sunstone/version", __FILE__)

Gem::Specification.new do |s|
  s.name        = "sunstone"
  s.version     = Sunstone::VERSION
  s.authors     = ["Jon Bracy"]
  s.email       = ["jonbracy@gmail.com"]
  s.homepage    = "http://sunstonerb.com"
  s.summary     = %q{A library for interacting with REST APIs}
  s.description = %q{A library for interacting with REST APIs. Similar to ActiveResource}

  s.files         = Dir["LICENSE", "README.rdoc", "lib/**/*", "ext/**/*"]
  s.require_paths = ["lib"]
  s.required_ruby_version = '>= 2.6'

  # Developoment 
  s.add_development_dependency 'rake'
  s.add_development_dependency 'rdoc'
  # s.add_development_dependency 'sdoc'
  s.add_development_dependency 'bundler'
  s.add_development_dependency 'minitest'
  s.add_development_dependency 'minitest-reporters'
  s.add_development_dependency 'mocha'
  s.add_development_dependency 'faker'
  s.add_development_dependency 'factory_bot'
  s.add_development_dependency 'webmock'
  #s.add_development_dependency 'sdoc-templates-42floors'
  s.add_development_dependency 'rgeo'
  s.add_development_dependency 'simplecov'
  s.add_development_dependency 'byebug'
  s.add_development_dependency 'activesupport', '>= 7.0.6'
  
  # Runtime
  s.add_runtime_dependency 'msgpack'
  s.add_runtime_dependency 'cookie_store'
  s.add_runtime_dependency 'activerecord', '>= 7.0.6'
  s.add_runtime_dependency 'arel-extensions', '>= 7.0.1'
  s.add_runtime_dependency 'activerecord-filter', '>= 7.0.0'
end
