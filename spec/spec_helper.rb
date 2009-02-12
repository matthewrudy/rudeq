require 'rubygems'
require 'spec'
require 'active_record'

current_dir = File.dirname(__FILE__)
require "#{current_dir}/../lib/rude_q"
require "#{current_dir}/../lib/rude_q/worker"
require "#{current_dir}/../lib/rude_q/scope"
require "#{current_dir}/models/rude_queue"
require "#{current_dir}/models/something" 
config = YAML::load(IO.read(current_dir + '/database.yml'))
ActiveRecord::Base.logger = Logger.new(current_dir + "/debug.log")
ActiveRecord::Base.establish_connection(config['rude_q_test'])
load(current_dir + "/schema.rb")
