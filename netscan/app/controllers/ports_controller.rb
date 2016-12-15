class PortsController < ApplicationController
  # DELETE /ports/:id
  def destroy
	p = Port.find(params[:id])
	p.delete
	redirect_to host_path(p.host)
  end
end
