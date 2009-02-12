require File.dirname(__FILE__) + '/spec_helper'

class ExampleWorker < RudeQ::Worker
  def queue_name
    :some_queue
  end

  # for the test, we'll just append each bit of data to a variable
  attr_accessor :processed_data

  def do_work(data)
    self.processed_data ||= []
    self.processed_data << data
  end
end

describe RudeQ::Worker do
  before(:each) do
    @it = ExampleWorker.new
    RudeQueue.delete_all
  end
  
  describe "queue" do
    it "should expose RudeQueue.get scoped for the worker's queue" do
      RudeQueue.set(:some_queue, ["some data for the worker"])
      @it.queue.get.should == ["some data for the worker"]
    end

    it "should expose RudeQueue.set scoped for the worker's queue" do
      @it.queue.set(:some_other_data_for_the_worker)
      RudeQueue.get(:some_queue).should == :some_other_data_for_the_worker
    end

    it "should expose RudeQueue.backlog scoped for the worker's queue" do
      RudeQueue.set(:who_knows, 1)
      RudeQueue.set(:my_mum, 23)

      RudeQueue.backlog.should == 2
      RudeQueue.backlog(:some_queue).should == 0
      @it.queue.backlog.should == 0

      RudeQueue.set(:some_queue, "purple")

      RudeQueue.backlog.should == 3
      RudeQueue.backlog(:some_queue).should == 1
      @it.queue.backlog.should == 1
    end
  end
end
