class AddIndexes < ActiveRecord::Migration
  def self.up
	add_index :hosts, [:mac], :unique=>true
	add_index :ports, [:host_id, :port, :proto], :unique=>true
  end
end
