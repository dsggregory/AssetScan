class ResultIsIssue < ActiveRecord::Migration
  def change
	rename_table :results, :issues
  end
end
