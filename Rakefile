require "rubygems"
require "rake"
require "rake/clean"
require "rdoc/task"

task :default => ["build"]
CLEAN.include [ 'pkg', 'rdoc' ]
name = "redis-dump"

$:.unshift File.join(File.dirname(__FILE__), 'lib')
require "redis/dump"
version = Redis::Dump::VERSION.to_s

begin
  require "jeweler"
  Jeweler::Tasks.new do |s|
    s.version = version
    s.name = name
    s.summary = "Backup and restore your Redis data to and from JSON."
    s.description = s.summary
    s.email = "delano@solutious.com"
    s.homepage = "http://github.com/delano/redis-dump"
    s.authors = ["Delano Mandelbaum"]

    s.add_dependency("yajl-ruby",    ">= 0.1")
    s.add_dependency("redis",        ">= 4.0")
    s.add_dependency("uri-redis",    ">= 0.4.0")
    s.add_dependency("drydock",      ">= 0.6.9")

    s.license = "MIT"

    s.signing_key = File.join('/mnt/gem/', 'gem-private_key.pem')
    s.cert_chain  = ['gem-public_cert.pem']
  end
  Jeweler::GemcutterTasks.new
rescue LoadError
  puts "Jeweler (or a dependency) not available. Install it with: sudo gem install jeweler"
end

require 'rake/testtask'
Rake::TestTask.new do |t|
  t.libs = ["lib", "test"]
end

extra_files = %w[LICENSE.txt THANKS.txt CHANGES.txt ]
RDoc::Task.new do |rdoc|
  rdoc.rdoc_dir = "rdoc"
  rdoc.title = "#{name} #{version}"
  rdoc.generator = 'hanna' # gem install hanna-nouveau
  rdoc.main = 'README.rdoc'
  rdoc.rdoc_files.include("README*")
  rdoc.rdoc_files.include("bin/*.rb")
  rdoc.rdoc_files.include("lib/**/*.rb")
  extra_files.each { |file|
    rdoc.rdoc_files.include(file) if File.exists?(file)
  }
end


