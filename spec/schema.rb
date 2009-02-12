ActiveRecord::Schema.define(:version => 1) do
  create_table :rude_queues, :force => true do |t|
    t.string :queue_name
    t.text :data
    t.string :token, :default => nil
    t.boolean :processed, :default => false, :null => false

    t.timestamps
  end
  add_index :rude_queues, :processed
  add_index :rude_queues, [:queue_name, :processed]

  create_table :somethings, :force => true do |t|
    t.string :name
    t.integer :count
    
    t.timestamps
  end
end
