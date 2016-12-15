#!/usr/bin/env ruby
# sudo rails runner bin/scan.rb [nmap-xml-file | -quick]
#
# Some popular nmap commands
# sudo nmap -sP -v 192.168.1.0/24
#    Quick discover of hosts and mac addrs - no probing
# sudo nmap -A -v -v 192.168.1.0/24
#    Exhaustive discover scan with deep probing

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
		  new_issue('change', "#{sym.to_s} changed")
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
		host = oldh
	  end
	  
	  host.vendor = assign(oldh.vendor, avendor, :vendor, !oldh.new_record?)
	  host.ip = aip if(!aip.blank?)	# assign regardless but don't track as a change
	  
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
	  
	  # Server name from a probe script
	  hscr = h['hostscript']
	  if(hscr)
		hscr.each do |hscript|
		  hscript.each do |scra|
			if(scra[0] == 'script')
			  scra[1].each do |script|
				if(script['id'] == 'nbstat' && script['elem'])
				  script['elem'].each do |e| 
					if(e['key'] == 'server_name')
					  host.name = assign(oldh.name, e['content'], :name, !oldh.new_record?)
					end
				  end
				end
			  end
			end
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
			
			# Check for updates
			oldp = Port.where(host_id: port.host_id, port: port.port, proto: port.proto)
			if(!oldp || oldp.length==0)
			  oldp = Port.new
			  new_issue('new', 'new port on asset')
			else
			  oldp = oldp[0]
			  port = oldp
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

if(ARGV[0] && ARGV[0][0]!='-')
  parser = ScanParse.new(ARGV[0])
else
  if(Process.euid != 0)
	STDERR.puts('ERROR: must be root to properly scan')
	exit(1)
  end

  if(ARGV[0] == '-quick')
	# a quick check to just get IPs and MACs
	nm_name = 'quick'
	nm_opts = '-sP'
  else
	nm_name = 'full'
	nm_opts = '-A -v -v'
  end
  if(ARGV[1])
	nm_dest = ARGV[1]
	nm_name = 'single'
  else
	nm_dest = '192.168.1.0/24'
  end
  # We reuse the nmap output file and leave it around for troubleshooting
  outf = Rails.root.join("log/nmap-#{nm_name}.xml")
  system("nmap #{nm_opts} -oX #{outf.to_s} #{nm_dest}")
  
  parser = ScanParse.new(outf.to_s)
end
