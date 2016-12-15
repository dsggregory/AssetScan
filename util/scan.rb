#!/usr/bin/env ruby

# Schema
# Hosts
#   id, ip, mac, vendor, name, description, os, os_cpe, created, updated
# Ports
#   id, host_id, port, proto, description, created, updated

# nmap -sP 192.168.1.0/24   - IPS and macs
# nmap -A -v -v -oX out.xml 192.168.1.0/24   - 

require 'rubygems'
require 'xmlsimple'
require 'byebug'

xml = XmlSimple.xml_in(ARGV[0])
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
	
	puts "Addresses:"
	h['address'].each do |a|
	  puts "  addr: #{a['addr']}"
	  puts "  addrtype: #{a['addrtype']}"
	  puts "  vendor: #{a['vendor']}"
	end

	hos = h['os']
	if(hos && hos[0] && (os=hos[0]['osmatch']))
	  puts "OS:"
	  os.each do |o|
		puts "  Name: #{o['name']}"
		if(o['osclass'] && (c=o['osclass'][0]))
		   puts "  Type: #{c['type']}"
		   puts "  CPE: #{c['cpe'][0]}" if(c['cpe'])
		end
	  end
	end
	
	if(h['ports'] && h['ports'][0] && h['ports'][0]['port'])
	  puts "Ports:"
	  h['ports'][0]['port'].each do |p|
  #byebug
		if(p['state'] && p['state'][0] && p['state'][0]['state']=='open')
		  puts "  Port: #{p['portid']}"
		  puts "    Proto: #{p['protocol']}"
		  s = p['service'][0]
		  puts "    Name: #{s['name']}"
		  puts "    Product: #{s['product']}"
		  puts "    Version: #{s['version']}"
		  puts "    CPE: #{s['cpe'][0]}" if(s['cpe'])
		end
	  end
	end
	
	puts '====================='
end

