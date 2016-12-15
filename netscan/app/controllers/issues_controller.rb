class IssuesController < ApplicationController
  def index
	@issues = Issue.where('accepted!=?', true)
  end
  
  # POST /issues-accept
  def accept
	params['accepts'].each do |issue_id, bval|
	  Issue.update(issue_id, :accepted => true) if(bval=='1')
	end
	redirect_to issues_path
  end
end
