ActiveRecord::Schema.define(:version => 1) do
  create_table :process_queues, :force => true do |t|
    t.string :queue_name
    t.text :data
    t.string :token, :default => nil
    t.boolean :processed, :default => false, :null => false

    t.timestamps
  end
  add_index :process_queues, :processed
  add_index :process_queues, [:queue_name, :processed]
end