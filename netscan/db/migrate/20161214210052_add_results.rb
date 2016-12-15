class AddResults < ActiveRecord::Migration
  def change
	# Result records are dismissed after being read
    create_table :results do |t|
      t.string :host_id
	  t.boolean :accepted
      t.string :type	# new, change to column
	  t.text :description
      t.timestamps
    end
    
    add_index 'results', ['accepted']

  end
end
