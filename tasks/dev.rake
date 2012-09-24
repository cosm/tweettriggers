namespace :dev do
  desc "Set up everything needed for a Development environment"
  task :bootstrap do
    Rake::Task["tweettriggers:dev:copy_conf_files"].invoke
    puts "Bootstrap Complete"
  end
end
