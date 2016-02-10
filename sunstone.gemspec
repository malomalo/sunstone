require File.expand_path("../lib/sunstone/version", __FILE__)

Gem::Specification.new do |s|
  s.name        = "sunstone"
  s.version     = Sunstone::VERSION
  s.authors     = ["Jon Bracy"]
  s.email       = ["jonbracy@gmail.com"]
  s.homepage    = "http://sunstonerb.com"
  s.summary     = %q{A library for interacting with REST APIs}
  s.description = %q{A library for interacting with REST APIs. Similar to ActiveResource}

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]

  # Developoment 
  s.add_development_dependency 'rake'
  s.add_development_dependency 'rdoc'
  s.add_development_dependency 'sdoc'
  s.add_development_dependency 'bundler'
  s.add_development_dependency 'minitest'
  s.add_development_dependency 'minitest-reporters'
  s.add_development_dependency 'mocha'
  s.add_development_dependency 'faker'
  s.add_development_dependency 'factory_girl'
  s.add_development_dependency 'webmock'
  s.add_development_dependency 'sdoc-templates-42floors'

  # Runtime
  s.add_runtime_dependency 'msgpack'
  s.add_runtime_dependency 'wankel'
  s.add_runtime_dependency 'cookie_store'
  s.add_runtime_dependency 'arel', '~> 7.0'
  s.add_runtime_dependency 'activesupport', '>= 5.0.0.beta2'
  s.add_runtime_dependency 'activemodel', '>= 5.0.0.beta2'
  s.add_runtime_dependency 'activerecord', '>= 5.0.0.beta2'
end
