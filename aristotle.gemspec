$:.push File.expand_path("../lib", __FILE__)

# Maintain your gem's version:
require "aristotle/version"

# Describe your gem and declare its dependencies:
Gem::Specification.new do |s|
  s.name        = "aristotle"
  s.version     = Aristotle::VERSION
  s.authors     = ["Gk Parish-Philp", "Michael Ferguson"]
  s.email       = ["gk@gkparishphilp.com"]
  s.homepage    = "http://www.groundswellenterprises.com"
  s.summary     = "A analytics engine for rails"
  s.description = "A analytics engine for rails"
  s.license     = "MIT"

  s.files = Dir["{app,config,db,lib}/**/*", "MIT-LICENSE", "Rakefile", "README.md"]

  s.add_dependency "rails", ">= 5.1.4"
	s.add_dependency "acts-as-taggable-array-on", "0.5.1"

  s.add_development_dependency "sqlite3"
end
