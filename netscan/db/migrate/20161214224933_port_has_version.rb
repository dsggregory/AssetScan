class PortHasVersion < ActiveRecord::Migration
  def change
	rename_column :ports, :vendor, :version
  end
end
