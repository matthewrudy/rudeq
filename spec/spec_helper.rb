require 'rubygems'
require 'spec'
require 'active_record'

current_dir = File.dirname(__FILE__)
require "#{current_dir}/../lib/rude_q"
require "#{current_dir}/process_queue"
 
config = YAML::load(IO.read(current_dir + '/database.yml'))
ActiveRecord::Base.logger = Logger.new(current_dir + "/debug.log")
ActiveRecord::Base.establish_connection(config['rude_q_test'])
load(current_dir + "/schema.rb")