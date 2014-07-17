# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)

Gem::Specification.new do |spec|
  spec.name          = "database_fork"
  spec.version       = '0.0.3'
  spec.authors       = ["the-architect"]
  spec.email         = ["marcel.scherf@epicteams.com"]
  spec.summary       = %q{Fork your database}
  spec.description   = %q{Fork your database}
  spec.homepage      = "http://github.com/"
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0")
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 1.6"
  spec.add_development_dependency "rake"
end
