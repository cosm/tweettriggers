namespace :tweettriggers do
  namespace :dev do
    task :copy_conf_files do
      Dir.glob(File.expand_path(File.join(__FILE__, "..", "..", "config", "*-sample.yml"))).each do |file|
        newfile = file.gsub('-sample', '')
        unless File.exist?(newfile)
          puts "Copying #{file} to #{newfile}"
          FileUtils.cp(file, newfile)
        end
      end
    end
  end
end
