Gem::Specification.new do |s|

  s.name            = 'logstash-filter-duration'
  s.version         = '0.1.0'
  s.licenses        = ['Apache License (2.0)']
  s.summary         = "This filter will add a new field with the time interval in second from two given dates."
  s.description     = "This gem is a logstash plugin required to be installed on top of the Logstash core pipeline using $LS_HOME/bin/plugin install gemname. This gem is not a stand-alone program"
  s.authors         = ["Benoit Brayer"]
  s.email           = 'brayer.benoit@gmail.com'
  s.require_paths = ["lib"]

  # Files
  s.files = `git ls-files`.split($\)

  # Tests
  s.test_files = s.files.grep(%r{^(test|spec|features)/})

  # Special flag to let us know this is actually a logstash plugin
  s.metadata = { "logstash_plugin" => "true", "logstash_group" => "filter" }

  # Gem dependencies
  s.add_runtime_dependency 'logstash', '>= 1.4.2', '< 2.0.0'
  s.add_runtime_dependency 'logstash-patterns-core'

  s.add_development_dependency 'logstash-devutils'
end