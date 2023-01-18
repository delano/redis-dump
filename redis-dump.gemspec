# frozen_string_literal: true

require_relative "lib/redis/dump/version"

Gem::Specification.new do |spec|
  spec.name = "redis-dump"
  spec.version = Redis::Dump::VERSION
  spec.authors = ["delano"]
  spec.email = "delano@solutious.com"

  spec.summary = "Backup and restore your Redis data to and from JSON."
  spec.description = "Backup and restore your Redis data to and from JSON by database, key, or key pattern."
  spec.homepage = "https://rubygems.org/gems/redis-dump"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 2.7.5"

  spec.metadata["allowed_push_host"] = "https://rubygems.org/"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/delano/redis-dump"
  spec.metadata["changelog_uri"] = "https://github.com/delano/redis-dump/blob/main/CHANGES.txt"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files = Dir.chdir(__dir__) do
    `git ls-files -z`.split("\x0").reject do |f|
      (f == __FILE__) || f.match(%r{\A(?:(?:bin|test|spec|features)/|\.(?:git|circleci)|appveyor)})
    end
  end
  spec.bindir = "bin"
  spec.executables = spec.files.grep(%r{\Abin/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency("yajl-ruby",    ">= 0.1")
  spec.add_dependency("oj",           ">= 3.13.14")
  spec.add_dependency("redis",        ">= 4.0")
  spec.add_dependency("uri-redis",    ">= 1.0.0")
  spec.add_dependency("drydock",      ">= 0.6.9")
end
