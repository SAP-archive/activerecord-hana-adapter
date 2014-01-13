# -*- encoding: utf-8 -*-
require File.expand_path('../lib/activerecord-hana-adapter/version', __FILE__)

Gem::Specification.new do |gem|
  gem.authors       = ["Thomas Augsten, Eyk Kny"]
  gem.email         = ["t.augsten@sap.com, eyk.kny@sap.com"]
  gem.description   = %q{ActiveRecord-ODBC apapter for HANA}
  gem.summary       = %q{Activerecord-ODBC apapter for HANA}
  gem.homepage      = ""

  gem.files         = `git ls-files`.split($\)
  gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.name          = "activerecord-hana-adapter"
  gem.require_paths = ["lib"]
  gem.version       = Activerecord::Hana::Adapter::VERSION

  gem.add_dependency('ruby-odbc', '>= 0.99992')
  gem.add_dependency('activerecord', '>= 3.2.0')
end
