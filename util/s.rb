require 'rubygems'
require 'xmlsimple'
require 'byebug'

xml = XmlSimple.xml_in(File.read(ARGV[0]))
xml['host'].each do |h|
	next if(h['status'][0]['state']=='down')
#	byebug
	pp h
end
