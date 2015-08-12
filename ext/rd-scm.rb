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

op = OptionParser.new do |option|
  option.on('-p', '--project NAME', 'NAME of the Rundeck project') { |x| @opt_project = x }
  option.on('-k', '--token TOKEN', 'Rundeck API Token') { |x| @opt_token = x }
  option.on('-r', '--rundeck API', 'The Rundeck API URL (eg http://x.y.z:8080/api)') { |x| @opt_rdapi = x }
  option.on('-s', '--store PATH', 'Path to the storage, may be a URL or a Path depending on invocation') { |x| @opt_store = x }
  option.on('-x', '--exclusive', 'Ensures, or errors, that the target should exlusively contain contents from the source') { |x| @opt_exclusive = true }
  option.on('-h', '--help', 'Print this help message') { puts option; exit 252; }
  option.parse!
end

def l7error(http_code, http_body)
  $stderr.puts "Rundeck API returned an HTTP #{http_code} ."
  err_log = Tempfile.new(File.basename($0, File.extname($0)) + '_')
  err_log.write(http_body)
  err_log.close
  File.rename(err_log.path, err_log.path + '.html')
  $stderr.puts "Error log dumped at #{err_log.path}.html ."
  exit 253
end

def fromapi(par_path)
  var_uri = URI.parse("#{@opt_rdapi}#{par_path}?authtoken=#{@opt_token}&project=#{@opt_project}")
  var_http = Net::HTTP.new(var_uri.host, var_uri.port)
  var_request = Net::HTTP::Get.new(var_uri.request_uri)
  var_request.initialize_http_header({'User-Agent' => 'Jakarta-trrdtools'})
  puts "Beginning GET from Rundeck API..."
  var_xml = var_http.request(var_request)
  if(var_xml.code.to_i < 200 or var_xml.code.to_i > 299)
    l7error(var_xml.code.to_i, var_xml.body)
  end
  puts "Returning results from Rundeck API."
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
  var_request.initialize_http_header({'User-Agent' => 'Jakarta-trrdtools'})
  var_request.body = var_data
  var_request['content-type'] = "multipart/form-data; boundary=#{var_boundary}"
  puts "Beginning POST to Rundeck API..."
  var_xml = var_http.request(var_request)
  if(var_xml.code.to_i < 200 or var_xml.code.to_i > 299)
    l7error(var_xml.code.to_i, var_xml.body)
  end
  puts "Returning results from Rundeck API."
  var_xml.body
end

if @opt_project.empty? or @opt_token.empty? or @opt_rdapi.empty? or @opt_store.empty?
  $stderr.puts op
  exit 251
end
