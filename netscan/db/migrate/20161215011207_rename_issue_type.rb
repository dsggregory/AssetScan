class RenameIssueType < ActiveRecord::Migration
  def change
	rename_column :issues, :type, :reason
  end
end
