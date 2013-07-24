require 'rspec/core/rake_task'
RSpec::Core::RakeTask.new(:spec)
task :default => :spec

require 'rdoc/task'
desc 'Generate documentation for the rude_q plugin.'
RDoc::Task.new do |rdoc|
  rdoc.rdoc_dir = 'rdoc'
  rdoc.title    = 'RudeQ'
  rdoc.options << '--line-numbers' << '--inline-source'
  rdoc.rdoc_files.include('README')
  rdoc.rdoc_files.include('lib/**/*.rb')
end
