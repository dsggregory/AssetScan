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
  
  # Since iOS8, Apple has started randomizing mac addrs to avoid tracking.
  # They seem to only randomize the first 3 bytes (first 6 hex chars) of the
  # mac and leave the final 3 bytes as the original.
  #
  # 8C:29:37:22:8F:D7
  # ^^ ^^ ^^ = changed
  #
  # This attempts to find a host record whose last 3bytes of the mac-addr
  # exist and that it's an ios host (via cpe).
  #
  def existing_ios_mac(mac)
	hrtn=nil
	
	re = Regexp.union([
				  'fortinet',		#'cpe:/h:fortinet:fortigate_100d',
				  'apple'	#'cpe:/o:apple:iphone_os:6.1.4'
				 ])
	macfin = mac[9..-1]	# last three bytes of mac (in string)
	ha = Host.where("substr(mac, 10) = ?", macfin)
	if(!ha.nil?)
	  ha.each do |h|
		hrtn = h if(re.match(h.os_cpe).nil? == false)
	  end
	end
	
	if(!hrtn.nil?)
	  hrtn.mac = mac
	  new_issue('change', 'mac changed')
	end

	hrtn
  end
  
  def find_old_host(mac)
	oldh = Host.where(mac: mac)
	if(!oldh || oldh.length==0)
	  if((oldh=existing_ios_mac(mac)).nil?)
		oldh = Host.new(:mac => mac)
		new_issue('new', 'new asset')
	  end
	else
	  oldh = oldh[0]
	end

	oldh
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
	  host.ip = aip; # temp in case it needs to set a new issue
	  oldh = find_old_host(host.mac)
	  host = oldh
	  
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
			if(host.new_record? && (!oldp || oldp.length==0))
			  oldp = Port.new
			  new_issue('new', 'new port on asset')
			  do_issue = true
			else
			  oldp = oldp[0]
			  port = oldp
			  do_issue = false
			end
			
			port.proto = assign(oldp.proto, port.proto, :proto, do_issue)
			port.port = assign(oldp.port, port.port, :port, do_issue)
			
			s = p['service'][0]
			port.name = assign(oldp.name, s['name'], :portname, do_issue)
			port.version = assign(oldp.version, s['version'], :version, do_issue)
			port.cpe = assign(oldp.cpe, s['cpe'][0], :cpe, do_issue) if(s['cpe'])
			
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

def usage
  STDERR.puts <<EOF
  
Usage: sudo rails runner bin/scan.rb [-f nmap_xml | -r ip_range] [-quick]

    -f - specify an existing nmap XML file to parse
    -r - specify an alternate IP range to pass to nmap
    -quick - run a quick discovery scan vs. the default exhaustive scan

EOF
  exit(1)
end

opts = {xml_file: nil, quick: false, range: nil}
i=0
while(i<ARGV.length)
  if(ARGV[i] == '-f')
	i+=1
	opts[:xml_file] = ARGV[i]
  elsif(ARGV[i] == '-quick')
	opts[:quick] = true
  elsif(ARGV[i] == '-r')
	i+=1
	opts[:range] = ARGV[i]
  else
	usage
  end
  
  i+=1
end

if(opts[:xml_file])
  parser = ScanParse.new(opts[:xml_file])
else
  if(Process.euid != 0)
	STDERR.puts('ERROR: must be root to properly scan')
	exit(1)
  end

  if(opts[:quick])
	# a quick check to just get IPs and MACs
	nm_name = 'quick'
	nm_opts = '-sP'
  else
	nm_name = 'full'
	nm_opts = '-A -v -v'
  end
  if(opts[:range])
	nm_dest = opts[:range]
	nm_name = 'single'
  else
	nm_dest = '192.168.1.0/24'
  end
  # We reuse the nmap output file and leave it around for troubleshooting
  outf = Rails.root.join("log/nmap-#{nm_name}.xml")
  system("nmap #{nm_opts} -oX #{outf.to_s} #{nm_dest}")
  
  parser = ScanParse.new(outf.to_s)
end
