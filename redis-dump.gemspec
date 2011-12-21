# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "redis/version"

Gem::Specification.new do |s|
  s.name        = "redis-dump"
  s.version     = RedisDump::VERSION
  s.authors     = ["Delano Mandelbaum", "Leif Gensert"]
  s.email       = ["delano@solutious.com"]
  s.homepage    = "http://github.com/delano/redis-dump"
  s.summary     = "Backup and restore your Redis data to and from JSON."
  s.description = s.summary

  s.rubyforge_project = s.name

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]

  s.add_runtime_dependency("yajl-ruby",    ">= 0.1")
  s.add_runtime_dependency("redis",        ">= 2.0")
  s.add_runtime_dependency("uri-redis",    ">= 0.4.0")
  s.add_runtime_dependency("drydock",      ">= 0.6.9")
end