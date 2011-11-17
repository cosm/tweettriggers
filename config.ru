require 'bundler'
Bundler.require
$LOAD_PATH << File.expand_path(File.dirname(__FILE__))
require 'app'
run Sinatra::Application
