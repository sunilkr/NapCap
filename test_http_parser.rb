#!/usr/bin/ruby

require 'http_parser'

parser = HttpParse::HTTPParser.new
traffic = File.new("TestTrafficSample2.txt",'r').read
parsed,invalid = parser.parse_traffic(traffic)
print "Parsed Messages: #{parsed.size}\n"
parsed.each do|msg|
   print parser.get_formatted_request(msg,true) if msg["method"]
   print parser.get_formatted_response(msg) if msg["status"]
   print "\n----\n"
end
