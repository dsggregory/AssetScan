class CreateHosts < ActiveRecord::Migration
  def change
    create_table :hosts do |t|
      t.string :ip
      t.string :mac
      t.string :vendor
      t.string :os
      t.string :os_cpe
      t.string :name
      t.string :description

      t.timestamps
    end
  end
end
