#!/usr/bin/ruby

require 'digest/md5'
require 'fileutils'
require 'net/http'
require 'optparse'
require 'rexml/document'
require 'tempfile'
require 'uri'

require 'pp'

@opt_project = @opt_token = @opt_rdapi = @opt_store = ''
@opt_exclusive = false

@xml_formatter = REXML::Formatters::Pretty.new(2, true)
@xml_formatter.compact = true

OptionParser.new do |option|
  option.on('-p', '--project NAME', 'NAME of the Rundeck project') { |x| @opt_project = x }
  option.on('-k', '--token TOKEN', 'Rundeck API Token') { |x| @opt_token = x }
  option.on('-r', '--rundeck API', 'The Rundeck API URL') { |x| @opt_rdapi = x }
  option.on('-s', '--store PATH', 'Path to the storage, may be a URL or a Path depending on invocation') { |x| @opt_store = x }
  option.on('-x', '--exclusive', 'Ensures, or errors, that the target should exlusively contain contents from the source') { |x| @opt_exclusive = true }
  option.on('-h', '--help', 'Print this help message') { puts option; exit 127; }
  option.parse!
end

def fromapi(par_path)
  var_uri = URI.parse("#{@opt_rdapi}#{par_path}?authtoken=#{@opt_token}&project=#{@opt_project}")
  var_xml = Net::HTTP.get_response(var_uri)
  
  if(var_xml.code.to_i < 200 or var_xml.code.to_i > 299)
    raise var_xml.body
  end
  
  var_xml.body
end

def toapi(par_path, par_params = Hash.new, par_files = Hash.new)
  var_boundary = Digest::MD5.hexdigest(rand.to_s)
  var_data = ''
  
  par_params.each { |k, v|
    var_data += "--#{var_boundary}\r\ncontent-disposition: form-data; name=\"#{k}\"\r\n\r\n" + "#{v}\r\n"
  }
  
  par_files.each { |k, v|
    var_data += "--#{var_boundary}\r\ncontent-disposition: form-data; name=\"#{k}\"; filename=\"#{k}\"\r\n\r\n" + "#{v}\r\n"
  }
  
  var_data += "--#{var_boundary}--\r\n"
  
  var_uri = URI.parse("#{@opt_rdapi}#{par_path}?authtoken=#{@opt_token}&project=#{@opt_project}")
  var_http = Net::HTTP.new(var_uri.host, var_uri.port)
  
  var_request = Net::HTTP::Post.new(var_uri.request_uri)
  var_request.body = var_data
  var_request['content-type'] = "multipart/form-data; boundary=#{var_boundary}"
  
  var_xml = var_http.request(var_request)
  
  if(var_xml.code.to_i < 200 or var_xml.code.to_i > 299)
    raise var_xml.body
  end
  
  var_xml.body
end
