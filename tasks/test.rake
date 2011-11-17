if [:development, :test].include?(settings.environment)
  require 'rspec/core/rake_task'

  namespace :test do
    desc "Run all specs"
    RSpec::Core::RakeTask.new(:rspec)

    desc "Run all tests"
    task :all do
      Rake::Task["test:rspec"].invoke
    end
  end

  task :test => ['test:all']
end
