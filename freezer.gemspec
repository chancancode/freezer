# -*- encoding: utf-8 -*-
lib = File.expand_path('../lib/', __FILE__)
$:.unshift lib unless $:.include?(lib)

Gem::Specification.new do |s|
  s.name        = 'freezer'
  s.version     = '0.5.0'
  s.platform    = Gem::Platform::RUBY
  s.authors     = ["Godfrey Chan"]
  s.email       = ["godfreykfc@gmail.com"]
  s.homepage    = "https://github.com/chancancode/freezer"
  s.summary     = ""
  s.description = ""

  s.required_rubygems_version = ">= 1.3.6"

  s.files        = Dir.glob("{lib,vendor}/**/*") + %w(README.md CHANGELOG.md LICENSE)
  s.require_path = 'lib'

  s.add_dependency 'activesupport', '>= 3.2.4'
  s.add_dependency 'activerecord', '>= 3.2.4'
  s.add_dependency 'activerecord-postgres-hstore', '>= 0.4.0'
end