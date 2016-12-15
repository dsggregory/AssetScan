class DashboardController < ApplicationController
  def index
	# select max(id), updated_at from Issues;
	r = Issue.order('id DESC').first
	@last_scan_time = r ? r.updated_at : 'never'
	
	@num_assets = Host.count
	
	@new_issues = Issue.where('accepted!=?', true)
	
  end
end
