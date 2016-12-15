class DashboardController < ApplicationController
  def index
	# select max(id), updated_at from Issues;
	r = Issue.order('id DESC').first
	if(r)
	  @last_scan = time_diff(Time.now.utc, Time.parse(r.updated_at.to_s))
	else
	  @last_scan = '?'
	end
	
	@num_assets = Host.count
	
	@new_issues = Issue.where('accepted!=?', true)
	
  end
  
  private
  
  def time_diff(cur, prev)
	seconds_diff = (cur - prev).to_i.abs
  
	hours = seconds_diff / 3600
	seconds_diff -= hours * 3600
  
	minutes = seconds_diff / 60
	seconds_diff -= minutes * 60
  
	seconds = seconds_diff

	if(hours > 24)
	  "#{(hours/24).to_i}d"
	elsif(hours>1)
	  "#{hours}h"
	else
	  "#{minutes}m"
	end
  end
  
end
