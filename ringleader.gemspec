# -*- encoding: utf-8 -*-
require File.expand_path('../lib/ringleader/version', __FILE__)

Gem::Specification.new do |gem|
  gem.authors       = ["Nathan Witmer"]
  gem.email         = ["nwitmer@gmail.com"]
  gem.description   = %q{TCP application host and proxy server}
  gem.summary       = %q{Proxy TCP connections to an on-demand pool of configured applications}
  gem.homepage      = "https://github.com/aniero/ringleader"

  gem.files         = `git ls-files`.split($\)
  gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.name          = "ringleader"
  gem.require_paths = ["lib"]
  gem.version       = Ringleader::VERSION
  gem.required_ruby_version = "> 1.9.3"

  gem.add_dependency "celluloid", "~> 0.12.4"
  gem.add_dependency "celluloid-io", "~> 0.12.0"
  gem.add_dependency "reel", "~> 0.1.0"
  gem.add_dependency "trollop", "~> 1.16.2"
  gem.add_dependency "rainbow", "~> 1.1.4"
  gem.add_dependency "color", "~> 1.4.1"
  gem.add_dependency "sys-proctable", "~> 0.9.2"

  gem.add_development_dependency "rake"
  gem.add_development_dependency "rspec", "~> 2.11.0"
  gem.add_development_dependency "guard-rspec"
end
