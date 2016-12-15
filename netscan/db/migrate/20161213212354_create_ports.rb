class CreatePorts < ActiveRecord::Migration
  def change
    create_table :ports do |t|
      t.integer :host_id
      t.integer :port
      t.string :proto
      t.string :name
      t.text :description

      t.timestamps
    end
  end
end
