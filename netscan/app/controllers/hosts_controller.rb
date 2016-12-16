require 'byebug'
class HostsController < ApplicationController
  # GET /hosts/new
  def new
	
  end
  
  # PUT /hosts
  def create
	@host = Host.new(host_params)
	@host.save
	redirect_to @host
  end

  # GET /hosts
  def index
	@hosts = Host.all.order(created_at: :desc)
  end

  # GET /compact-hosts
  def compact
	@hosts = Host.all.order(:mac)
  end
  
  # GET /hosts/:id
  def show
	@host = Host.find(params[:id])
  end
  
  def edit
	@host = Host.find(params[:id])
  end
  
  def update
	@host = Host.find(params[:id])
	if(@host.update(host_params))
	  redirect_to(@host)
	else
	  render 'edit'
	end
  end
  
  def destroy
	@host = Host.find(params[:id])
	@host.destroy
	
	redirect_to hosts_path
  end
  
  private
  
  def host_params
	params.require(:host).permit(:ip, :mac, :vendor, :os, :os_cpe, :name, :description)
  end
end
