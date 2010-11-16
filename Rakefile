require "rubygems"
require "rake"
require "rake/clean"
require 'yaml'

begin
  require 'hanna/rdoctask'
rescue LoadError
  require 'rake/rdoctask'
end
 
config = YAML.load_file("VERSION.yml")
task :default => ["build"]
CLEAN.include [ 'pkg', 'doc', '*gemspec' ]
name = "redis-dump"

begin
  require "jeweler"
  Jeweler::Tasks.new do |gem|
    gem.version = "#{config[:MAJOR]}.#{config[:MINOR]}.#{config[:PATCH]}"
    gem.name = "redis-dump"
    gem.rubyforge_project = gem.name
    gem.summary = "Backup and restore your Redis data to and from JSON."
    gem.description = gem.summary
    gem.email = "delano@solutious.com"
    gem.homepage = "http://github.com/delano/redis-dump"
    gem.authors = ["Delano Mandelbaum"]
    gem.add_dependency("yajl-ruby",    ">= 0.1")
    gem.add_dependency("redis",        ">= 2.0")
    gem.add_dependency("uri-redis",    ">= 0.4.0")
  end
  Jeweler::GemcutterTasks.new
rescue LoadError
  puts "Jeweler (or a dependency) not available. Install it with: sudo gem install jeweler"
end


Rake::RDocTask.new do |rdoc|
  version = "#{config[:MAJOR]}.#{config[:MINOR]}.#{config[:PATCH]}.#{config[:BUILD]}"
  rdoc.rdoc_dir = "doc"
  rdoc.title = "redis-dump #{version}"
  rdoc.rdoc_files.include("README*")
  rdoc.rdoc_files.include("LICENSE.txt")
  #rdoc.rdoc_files.include("bin/*.rb")
  rdoc.rdoc_files.include("lib/**/*.rb")
end


# Rubyforge Release / Publish Tasks ==================================

#about 'Publish website to rubyforge'
task 'publish:rdoc' => 'doc/index.html' do
  sh "scp -rp doc/* rubyforge.org:/var/www/gforge-projects/#{name}/"
end

#about 'Public release to rubyforge'
task 'publish:gem' => [:package] do |t|
  sh <<-end
    rubyforge add_release -o Any -a CHANGES.txt -f -n README.md #{name} #{name} #{@spec.version} pkg/#{name}-#{@spec.version}.gem &&
    rubyforge add_file -o Any -a CHANGES.txt -f -n README.md #{name} #{name} #{@spec.version} pkg/#{name}-#{@spec.version}.tgz 
  end
end



