#!/usr/bin/env ruby
# sudo rails runner bin/scan.rb

require 'rubygems'
require 'xmlsimple'

class ScanParse
  @issues = nil
  
  def initialize(xml_file)
	parse_results(xml_file)
  end
  
  def new_issue(type, desc)
	issue = Issue.new
	issue.reason = type
	issue.accepted = false
	issue.description = desc
	@issues.push(issue)
  end
  
  private
  
  # Assign new to old and create a diff issue if:
  #   o new is not empty
  #   o old is empty
  def assign(old, new, sym, add_issue=false)
	if(!new.blank?)
	  if(old.blank?)
		if(add_issue)
		  new_issue('change', '#{sym} changed')
		end
		new
	  else
		old
	  end
	else
	  old
	end
  end
  
  def parse_results(xml_file)
	xml = XmlSimple.xml_in(File.read(xml_file))
	
	xml['host'].each do |h|
	  next if(h['status'][0]['state']=='down')
	  # n['address'].each => addr, addrtype=mac/ipv4/ipv6, vendor
	  # n['hostnames'].each
	  # n['ports'].each => protocol, portid,
	  #	state[0]['state']=open,
	  #	state[0]['service'][0] => name, product, version, cpe[0]
	  # n['os'][0] =>
	  #	osmatch[0] =>
	  #		name
	  #		osclass[0] =>
	  #			type, cpe
	  # n['uptime'][0] => lastboot=datetime
	  # 
	  
	  host = Host.new
	  @issues = []
	  
	  # Addresses
	  avendor=nil
	  aip=nil
	  h['address'].each do |a|
		case a['addrtype']
		when 'mac'
		  host.mac = a['addr']
		when /ip*/
		  aip = a['addr']
		end
		avendor = a['vendor'] if(!a['vendor'].blank?)
	  end
	  
	  if(host.mac.blank?)	# mac is unique. Skip hosts without.
		STDERR.puts "#{host.ip}: mac is empty - skipping"
		next
	  end
	  
	  # Check for updates
	  oldh = Host.where(mac: host.mac)
	  if(!oldh || oldh.length==0)
		oldh = Host.new
		new_issue('new', 'new asset')
	  else
		oldh = oldh[0]
	  end
	  
	  host.vendor = assign(oldh.vendor, avendor, :vendor, !oldh.new_record?)
	  host.ip = assign(oldh.ip, aip, :ip, !oldh.new_record?)
	  
	  # OSes
	  hos = h['os']
	  if(hos && hos[0] && (os=hos[0]['osmatch']))
		os.each do |o|
		  host.os = assign(oldh.os, o['name'], :os, !oldh.new_record?)
		  if(o['osclass'] && (c=o['osclass'][0]) && c['cpe'])
			host.os_cpe = assign(oldh.os_cpe, c['cpe'][0], :cpe, !oldh.new_record?)
		  end
		end
	  end
	  
	  # Save
	  begin
		host.save
	  rescue => e
		STDERR.puts "#{host.ip}: #{e.to_s}"
	  end
	  
	  # Ports
	  if(h['ports'] && h['ports'][0] && h['ports'][0]['port'])
		h['ports'][0]['port'].each do |p|
		  if(p['state'] && p['state'][0] && p['state'][0]['state']=='open')
			port = Port.new(:host_id=>host.id)
			
			port.port = p['portid']
			port.proto = p['protocol']
			
			oldp = Port.where(host_id: port.host_id, port: port.port, proto: port.proto)
			if(!oldp || oldp.length==0)
			  oldp = Port.new
			  if(!oldp.new_record?)
				new_issue('new', 'new port on asset')
			  end
			else
			  oldp = oldp[0]
			end
			
			port.proto = assign(oldp.proto, port.proto, :proto, !oldp.new_record?)
			port.port = assign(oldp.port, port.port, :port, !oldp.new_record?)
			
			s = p['service'][0]
			port.name = assign(oldp.name, s['name'], :portname, !oldp.new_record?)
			port.version = assign(oldp.version, s['version'], :version, !oldp.new_record?)
			port.cpe = assign(oldp.cpe, s['cpe'][0], :cpe, !oldp.new_record?) if(s['cpe'])
			
			begin
			  port.save
			rescue => e
			  STDERR.puts "#{host.ip}: port=#{port.port} - #{e.to_s}"
			end
		  end
		end
	  end
	  
	  # Save Issues
	  if(@issues.length>0)
		@issues.each do |issue|
		  issue.host_id = host.id
		  issue.save
		end	  
	  end
	  
	end
  end
end

if(ARGV[0])
  parser = ScanParse.new(ARGV[0])
else
  if(Process.euid != 0)
	STDERR.puts('ERROR: must be root to properly scan')
	exit(1)
  end

  require 'tempfile'

  tmpf = Tempfile.new('nmap')
  system("nmap -A -v -v -oX #{tmpf.path} 192.168.1.0/24 >/dev/null 2>&1")
  parser = ScanParse.new(tmpf.path)
  tmpf.close
  tmpf.unlink
end