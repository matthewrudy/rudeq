class RudeQueue < ActiveRecord::Base
  include RudeQ
  
  class << self
    def processed_with_raise_hack!(*args)
      processed_without_raise_hack!(*args)
      raise RuntimeError if raise_on_processed # want to be able to raise afterwards to check transactions
    end
    alias_method_chain :processed!, :raise_hack
    attr_accessor :raise_on_processed
  end
    
end

