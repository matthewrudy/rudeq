require File.dirname(__FILE__) + '/spec_helper'

describe RudeQ::ClassMethods do # RudeQueue extends ClassMethods
  before(:each) do
    RudeQueue.delete_all
    RudeQueue.raise_on_processed = false
    create_some_noise
  end
  
  def create_some_noise
    RudeQueue.create!(:queue_name => "doNT use this in Specs", :data => {:not => "to be messed with"})
    RudeQueue.create!(:queue_name => "abcde", :data => {:same_as => "the specs but already processed"}, :processed => true)
  end
  
  describe "get and set" do
    it "should work with strings" do
      RudeQueue.set('abcde', "Something to set")
      RudeQueue.get('abcde').should == "Something to set"
    end
    it "should work with symbols" do
      RudeQueue.set('abcde', :a_symbol)
      RudeQueue.get('abcde').should == :a_symbol
    end
    it "should work with arrays" do
      array = [1, :b, "C"]
      RudeQueue.set('abcde', array)
      RudeQueue.get('abcde').should == array
    end
    it "should work with hashes" do
      hash = {:symbol => "A string", "stringy" => 23, 74 => :cheese}
      RudeQueue.set('abcde', hash)
      RudeQueue.get('abcde').should == hash
    end
    it "should work with integers" do
      RudeQueue.set('abcde', 7816327370)
      RudeQueue.get('abcde').should == 7816327370
    end
    it "should work with ActiveRecords" do
      record = Something.create!(:name => "MatthewRudy")

      RudeQueue.set('abcde', record)
      RudeQueue.get('abcde').should == record
    end
    it "should resolve booleans correctly" do
      RudeQueue.set('abcde', true)
      RudeQueue.get('abcde').should == true
      
      RudeQueue.set('abcde', false)
      RudeQueue.get('abcde').should == false
    end
    
    it "should :get in the same order they are :set" do
      RudeQueue.set('abcde', :first)
      RudeQueue.set('abcde', "second")
      
      RudeQueue.get('abcde').should == :first
      
      RudeQueue.set('abcde', 33.3333)
      
      RudeQueue.get('abcde').should == "second"
      RudeQueue.get('abcde').should == 33.3333
      RudeQueue.get('abcde').should be(nil)
    end
    
    it "should keep queues seperated" do
      RudeQueue.set('queue_1', :data_1)
      RudeQueue.set('queue_2', "DATA2")
      
      RudeQueue.get('queue_2').should == "DATA2"
      RudeQueue.get('queue_2').should be(nil)
      RudeQueue.get('queue_1').should == :data_1
      RudeQueue.get('queue_1').should be(nil)
    end
    
    it "should call to_s on inputs" do
      qname = stub("fake input")
      qname.should_receive(:to_s).exactly(:twice).and_return("fake queue name")
      
      RudeQueue.set(qname, ["Data"])
      RudeQueue.get(qname).should == ["Data"]
    end
    
    it "should work with queue name as strings or symbols" do
      RudeQueue.set(:bah, "something about bah")
      RudeQueue.get("bah").should == "something about bah"
      
      RudeQueue.set("girah", {:craziness => "embodied"})
      RudeQueue.get(:girah).should == {:craziness => "embodied"}
    end
  end
  
  describe ".set" do
    it "should delegate to :create!" do
      RudeQueue.should_receive(:create!).with(:queue_name => 'abcde', :data => :magical_planet)
      RudeQueue.set('abcde', :magical_planet)
    end
    it "should return nil" do
      RudeQueue.set('abcde', "something").should be(nil)
    end
  end
  
  describe ".get" do    
    it "should revert a record if something goes wrong before it finishes" do
      RudeQueue.raise_on_processed = true
      RudeQueue.set('abcde', :this_will_remain_unprocessed)
      
      # confirm the object is in the db
      record = RudeQueue.find(:first, :order => "id DESC")
      record.queue_name.should == 'abcde'
      record.data.should == :this_will_remain_unprocessed
      record.processed?.should == false
      record.token.should == nil
      
      lambda {RudeQueue.get('abcde')}.should raise_error(RuntimeError)
      
      record.reload
      record.queue_name.should == 'abcde'
      record.data.should == :this_will_remain_unprocessed
      record.processed?.should == false
      record.token.should == nil
    end
  end

  describe "fetch" do
    describe "with data" do
      
      before(:each) do
        RudeQueue.set(:fetch_queue, "some data")
      end
  
      it "should return the value of the block" do
        rtn = RudeQueue.fetch(:fetch_queue) do |data|
          data.should == "some data"
          :the_return
        end
        rtn.should == :the_return
      end

      it "should execute the block with the data" do
        self.should_receive(:something)
        RudeQueue.fetch(:fetch_queue) do |data|
          self.something
          data.should == "some data"
        end
      end

    end

    describe "without data" do

      it "should not execute the block" do
        self.should_not_receive(:something)
        RudeQueue.fetch(:fetch_queue) do |data|
          raise(Exception, "this should never get here")
        end
      end

      it "should return nil" do
        rtn = RudeQueue.fetch(:fetch_queue) do |data|
          raise(Exception, "again this shouldnt happen")
        end
        rtn.should be_nil
      end

    end
  end

  describe "queue_options" do
    describe :processed do
      describe "set to :destroy" do
        before(:each) do
          @old_processed = RudeQueue.queue_options[:processed]
          RudeQueue.queue_options[:processed] = :destroy
        end
        after(:each) do
          RudeQueue.queue_options[:processed] = @old_processed
        end
        it "should delete processed items" do
          count = RudeQueue.count
          
          RudeQueue.set(:abcde, "some value")
          RudeQueue.count.should == (count + 1)
          
          RudeQueue.get(:abcde).should == "some value"
          RudeQueue.count.should == count
        end
      end
      describe "set to something crazy" do
        before(:each) do
          @old_processed = RudeQueue.queue_options[:processed]
          RudeQueue.queue_options[:processed] = :something_crazy
        end
        after(:each) do
          RudeQueue.queue_options[:processed] = @old_processed
        end
        it "should raise an exception" do
          RudeQueue.set(:abcde, "some value")
          lambda {RudeQueue.get(:abcde)}.should raise_error(ArgumentError)
        end
      end
    end
  end
  
  describe ".backlog" do
    it "should count the unprocessed items for the provided queue_name" do
      RudeQueue.delete_all

      RudeQueue.backlog(:abcde).should == 0
      RudeQueue.backlog().should == 0

      RudeQueue.set(:abcde, "a value")
      RudeQueue.backlog(:abcde).should == 1
      RudeQueue.backlog().should == 1

      RudeQueue.set(:something_else, "another value")
      3.times { RudeQueue.set(:abcde, :add_three_more)}
      
      RudeQueue.backlog(:abcde).should == 4
      RudeQueue.backlog().should == 5

      RudeQueue.get(:abcde).should == "a value"
      RudeQueue.backlog(:abcde).should == 3
      RudeQueue.backlog().should == 4
    end
  end

  describe ".cleanup!" do
    it "should use :delete_all" do
      RudeQueue.should_receive(:delete_all) # not :destroy_all
      RudeQueue.cleanup!
    end
    
    it "should allow string inputs" do
      RudeQueue.cleanup!("3600")
    end
    
    it "should allow integer inputs" do
      RudeQueue.cleanup!(3600)
    end
    
    it "should not clear unprocessed items" do
      RudeQueue.set('abcde', :giraffe)
      RudeQueue.set('abcde', :monkey)
      RudeQueue.count.should >= 2
      
      RudeQueue.cleanup!
      
      RudeQueue.count.should >=2
      RudeQueue.get('abcde').should == :giraffe
    end
    
    it "should not clear old unprocessed items" do
      RudeQueue.set('abcde', :giraffe)
      giraffe = RudeQueue.find(:first, :conditions => {:data => :giraffe})
      
      time_now = Time.now
      Time.stub!(:now).and_return(time_now + 1.year)
      
      giraffe.updated_at.should < 2.weeks.ago
      
      RudeQueue.cleanup!
      
      giraffe.reload
      RudeQueue.get('abcde').should == :giraffe
    end
    
    it "should not clear processed items newer than the argument" do
      RudeQueue.set('abcde', :giraffe)
      RudeQueue.get('abcde').should == :giraffe
      
      giraffe = RudeQueue.find(:first, :conditions => {:data => :giraffe})
      
      time_now = Time.now
      Time.stub!(:now).and_return(time_now + 1.week - 5.minutes)
      
      giraffe.updated_at.should > 1.week.ago
      giraffe.processed.should be(true)
      
      RudeQueue.cleanup!(1.week)
      
      giraffe.reload
    end
    
    it "should not clear processed items newer than one hour, by default" do
      RudeQueue.set('abcde', :giraffe)
      RudeQueue.get('abcde').should == :giraffe
      
      giraffe = RudeQueue.find(:first, :conditions => {:data => :giraffe})
      
      time_now = Time.now
      Time.stub!(:now).and_return(time_now + 59.minutes)
      
      giraffe.updated_at.should > 1.hour.ago
      giraffe.processed.should be(true)
      
      RudeQueue.cleanup!()
      
      giraffe.reload
    end
    
    it "should clear processed items older than the argument" do
      RudeQueue.set('abcde', :giraffe)
      RudeQueue.get('abcde').should == :giraffe
      
      giraffe = RudeQueue.find(:first, :conditions => {:data => :giraffe})
      
      time_now = Time.now
      Time.stub!(:now).and_return(time_now + 1.week + 5.minutes)
      
      giraffe.updated_at.should < 1.week.ago
      giraffe.processed.should be(true)
      
      RudeQueue.cleanup!(1.week)
      
      lambda { giraffe.reload }.should raise_error(ActiveRecord::RecordNotFound)
    end
    
    it "should clear processed items older than one hour, by default" do
      RudeQueue.set('abcde', :giraffe)
      RudeQueue.get('abcde').should == :giraffe
      
      giraffe = RudeQueue.find(:first, :conditions => {:data => :giraffe})
      
      time_now = Time.now()
      Time.stub!(:now).and_return(time_now + 61.minutes)
      
      giraffe.updated_at.should < 1.hour.ago
      giraffe.processed.should be(true)
      
      RudeQueue.cleanup!
      
      lambda { giraffe.reload }.should raise_error(ActiveRecord::RecordNotFound)
    end
  end
end

describe RudeQ::TokenLock do

  describe ".get_unique_token" do
    it "should create a unique token" do
      lots_of_tokens = Array.new(50) do
        RudeQ::TokenLock.get_unique_token
      end
      lots_of_tokens.uniq.should == lots_of_tokens
    end
    
    it "should create a unique token even if time stands still" do
      time_now = Time.now
      Time.should_receive(:now).at_least(50).times.and_return(time_now)
      lots_of_tokens = Array.new(50) do
        RudeQ::TokenLock.get_unique_token
      end
      lots_of_tokens.uniq.should == lots_of_tokens
    end
  end
  
  # it "should not return a processed item with the same token" do
  #   @token = "tokEEEannn"
  # 
  #   RudeQ::TokenLock.should respond_to(:get_unique_token) # ensure our stub is safe
  #   RudeQ::TokenLock.should_receive(:get_unique_token).exactly(3).times.and_return(@token)
  # 
  #   @existing = RudeQueue.create!(:queue_name => 'abcde', :data => :old_data, :token => @token, :processed => true)
  # 
  #   RudeQueue.get('abcde').should be(nil)
  #     
  #   RudeQueue.set('abcde', :new_data)
  #   RudeQueue.get('abcde').should == :new_data
  #   RudeQueue.get('abcde').should be(nil)
  # end
  
end
