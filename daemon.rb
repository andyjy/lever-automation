# frozen_string_literal: true

require 'daemons'
require_relative 'controller/controller'

controller = Controller.new

Daemons.run_proc('lever_daemon.rb') do
  loop do
    unless ENV['ENABLE_DAEMON'].nil? || ENV['ENABLE_DAEMON'].empty? || ['0', 'false'].include?(ENV['ENABLE_DAEMON'].downcase)
      controller.process_opportunities(nil) 
    end
    
    break if controller.terminating?
    sleep(10)
  end
end
