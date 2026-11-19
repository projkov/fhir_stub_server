# frozen_string_literal: true

require 'bundler/gem_tasks'
require 'rspec/core/rake_task'
require 'rubocop/rake_task'
require 'reek/rake/task'

RSpec::Core::RakeTask.new(:spec)

RuboCop::RakeTask.new(:rubocop)

Reek::Rake::Task.new(:reek) do |task|
  task.source_files = 'lib/**/*.rb'
end

# Flay's and flog's own Rake tasks are not used: FlayTask reads the score before
# analysing (always 0), FlogTask crashes when lib/ has no methods yet.
desc 'Fail on any duplicated code in lib/ above flay\'s default mass'
task :flay do
  require 'flay'
  flay = Flay.run(%w[lib])
  flay.analyze
  next if flay.total.zero?

  flay.report
  abort "Flay found duplication: score #{flay.total} > 0"
end

desc 'Fail when a method in lib/ scores above 20 in flog'
task :flog do
  require 'flog_cli'
  flog = FlogCLI.new(continue: true, quiet: true, methods: true)
  flog.flog(*Dir['lib/**/*.rb'])
  name, score = flog.max_method
  abort "Flog score for #{name} is too high: #{score.round(1)} > 20" if score&.>(20)
end

desc 'Type-check lib/ against sig/ with Steep'
task :steep do
  sh 'steep check'
end

desc 'Run all code quality tools'
task quality: %i[rubocop reek flay flog steep]

task default: %i[spec quality]
