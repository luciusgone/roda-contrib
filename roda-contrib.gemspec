# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'roda/contrib/version'

Gem::Specification.new do |spec|
  spec.name          = 'roda-contrib'
  spec.version       = RodaContrib::VERSION
  spec.authors       = ['luciusgone']
  spec.email         = ['luciusgone@gmail.com']

  spec.summary       = 'Small collection of my personal plugins for Roda'
  spec.description   = spec.summary
  spec.homepage      = 'https://github.com/luciusgone/roda-contrib'
  spec.license       = 'MIT'

  spec.files         = `git ls-files -z`.split("\x0").reject do |f|
    f.match(%r{^(test|spec|features|bin)/})
  end
  spec.bindir        = 'exe'
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  spec.add_development_dependency 'bundler', '~> 1.14'
  spec.add_development_dependency 'rake', '~> 10.0'
  spec.add_development_dependency 'rspec', '~> 3.0'
  spec.add_development_dependency 'rack-test'
  spec.add_development_dependency 'rack_csrf'

  spec.add_dependency 'roda'
end
