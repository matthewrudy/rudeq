# example usage:
# class MyWorker < RudeQ::Worker
#   def queue_name
#     :my_queue
#   end
#
#   def do_work(data)
#     MyMailer.send(data)
#   end
# end
module RudeQ
  class Worker
    def queue_name
      raise NotImplementedError
    end
    
    def do_work(data)
      raise NotImplementedError
    end
    
    def get_work
      RudeQueue.get(queue_name)
    end
    
    def do!
      logger.info("starting up")
      if work = get_work
        logger.info("found some work")
        do_work(work)
      else
        logger.info("couldn't find any work")
      end
      logger.info("finished for now")
    end      
  
    def logger
      unless @logger
        @logger = Logger.new(RAILS_ROOT + "/log/#{self.class.to_s.underscore}_#{RAILS_ENV}.log")
        class << @logger
          def format_message(severity, timestamp, progname, msg)
            "#{timestamp.strftime('%Y%m%d-%H:%M:%S')} (#{$$}) #{msg}\n"
          end
        end
      end
      return @logger
    end
  end
end