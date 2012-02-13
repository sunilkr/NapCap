#!/usr/bin/ruby

T_MARK = '================================================================================'
HTML_END_TAG = '</html>'
DEBUG = -1

module NapCap

class HTTPParser
   attr :resp_end_marker 
   attr :parsed_messages, :invalid_messages

   def split_traffic(traffic)
      print "[?] Transaction Marker: #{@trans_mark}\n" if DEBUG >= 1
      traffic.split(@trans_mark)
   end

   def split_transaction(transaction)
      parts = transaction.split("#{@http_version}")
      print "[?] Transaction Parts: #{parts.size}\n" if DEBUG > 1
      messages = []
      request = parts[0]
      index = 1
      while index<parts.size
         request += @http_version + parts[index]
         messages<<request
         response,request = parts[index+1].split(@resp_end_marker) 
         response = @http_version + response + @resp_end_marker
         messages<<response
         index +=2
      end
      return messages
   end

   def parse_request(message)
      #No multipart data yet. Only www-form-urlencoded type
      
      if (message =~ /^\s*(GET|POST|PUT|HEAD|OPTION|DELETE)/) == nil
         raise ArgumentError,"[x] Data Error: Invalid start of request. Expected (GET,POST,PUT,HEAD,DELETE,OPTION) but found '#{message[0,6]}'"
      end
      
      request = {}
      line1,rest_all = message.split(@http_version)
      request['method'], request['resource'] = line1.split(' ')
      
      headers = {}
      last_header=''
      rest_all.split(' ').each do |token|
         if token[-1].chr == ':'
            last_header = token[0..-2]
            headers[last_header] = '' unless headers[last_header]
         else
            headers[last_header] += token+' '
         end
      end
      
      content_length = (headers["Content-Length"])? headers["Content-Length"].strip.to_i : 0
      #print "[?] Content-length #{headers['Content-Length']}" if DEBUG == -1
      if content_length > 0
       #  print "[?] Extracting body from #{last_header}, size #{content_length}, content: #{headers[last_header]}" if DEBUG == -1
         request["body"] = headers[last_header].slice!(-(content_length+1)..-1).strip
      end

      request['headers'] = headers
      return request
   end

   def parse_response(message)  #Response with no body may parsed incorrectly
      raise ArgumentError,"[x] Invalid start of response. Expected \"HTTP/\" but found '#{message[0,6]}'." unless message.index(/^\s*HTTP\//)

      response = {}
      body_location = message.index(/<(html|!DOCTYPE|\?xml)/) #TODO: think better
      raw_headers = message[0,body_location].split(' ')        #TODO: what if there is no body?
      response["body"] = message[body_location..-1]
      response["code"] = raw_headers[1].strip
      response["status"] = raw_headers[2].strip

      last_header = ''
      headers = {}
      cookies = []
      cookie = ''

      (3..(raw_headers.size() -1)).each do |index|
         token = raw_headers[index]

         #TODO: Optimize
         if token[-1].chr == ':'
            last_header = token[0..-2]
            if last_header == 'Set-Cookie'
               cookies<<cookie
               cookie=''
            end        
            headers[last_header] = '' unless headers[last_header]
         else
            if last_header == 'Set-Cookie'
               cookie += token+' '
            else
               headers[last_header] += token + ' '
            end
         end
      end

      cookies[0] = cookie
      response["cookies"] = cookies
      response["headers"] = headers
      return response
   end

   def get_formatted_request(request, add_body = false)
      str = "%s %s %s\n" % [request['method'], request['resource'], @http_version.strip]
      request["headers"].each {|header,value| str += "%s: %s\n" % [header, value.strip]}
      str += "\n"+ request["body"] + "\n" if request["body"] and add_body
      return str
   end

   def get_formatted_response(response, add_body = false)
      str = "%s %s %s\n" % [@http_version.strip, response["code"], response["status"]]
      response['cookies'].each {|cookie| str += "Set-Cookie: #{cookie}\n"}
      response["headers"].each {|header,value| str+= "#{header}: #{value.strip}\n"}
      str += "\n#{response['body']}\n" if add_body && response["body"]
      return str
   end

   def initialize(transaction_marker=nil, http_version='1.1')
      @http_version = " HTTP/#{http_version} "
      @resp_end_marker = HTML_END_TAG                        #Only Content-type: text/html (a valid html response) as of now
      @trans_mark = (transaction_marker)? transaction_marker : T_MARK
   end
   
   def parse_traffic(traffic)
      @parsed_messages = []
      @invalid_messages = []
      cnt1 = 0
      transactions = self.split_traffic(traffic)
      print "HTTP Version:#{@http_version}\n" if DEBUG > 0
      print "#Transactions: #{transactions.size}\n" if DEBUG > 0
      transactions.each do|transaction|
         messages = self.split_transaction(transaction)
         print "Transaction #{cnt1 +=1} #Messages: #{messages.size}\n" if DEBUG >0
         cnt2=0
         messages.each do |message|
            print "|- Processing Message #{cnt2 +=1}\n" if DEBUG > 0
            begin
               @parsed_messages<<self.parse_request(message)
               print "|-- Message is Request\n" if DEBUG > 0
            rescue 
               begin
                  @parsed_messages<<self.parse_response(message)
                  print "|-- Message is Response\n" if DEBUG > 0
               rescue ArgumentError => ex
                  @invalid_messages<<message
                  print "|- Invalid Message #{message[0,6]}...\n" if DEBUG > 0
               end
            end
         end
      end
      return @parsed_messages,@invalid_messages
   end
end

end
