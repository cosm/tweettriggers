namespace :dev do
  desc "Set up everything needed for a Development environment"
  task :bootstrap => ["tweettriggers:dev:copy_conf_files"] do
    puts "Bootstrap Complete"
  end
end
