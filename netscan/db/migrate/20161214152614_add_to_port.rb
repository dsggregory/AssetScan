class AddToPort < ActiveRecord::Migration
  def change
	add_column :ports, :product, :string
	add_column :ports, :vendor, :string
	add_column :ports, :cpe, :string
  end
end
