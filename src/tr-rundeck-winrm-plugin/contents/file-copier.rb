require 'winrm-fs'
require 'optparse'

$stdout.sync = true
$stderr.sync = true

_ec = 254

options = {}
OptionParser.new do |opts|
  opts.on("-h <hostname>", "--hostname=<hostname>", "Remote Hostname") do |hostname|
    options[:hostname] = hostname
  end
  opts.on("-u <username>", "--username=<username>", "Remote Username") do |username|
    options[:username] = username
  end
  opts.on("-p <password>", "--password=<password>", "Remote Password") do |password|
    options[:password] = password
  end
  opts.on("-s <source>", "--source=<source>", "Local Path") do |source|
    options[:source] = source
  end
  opts.on("-t <target>", "--target=<target>", "Remote Path") do |target|
    options[:target] = target
  end
end.parse!

options.each {|k, v| options[k] = (v.start_with? "'" and v.end_with? "'") ? v[1,v.length-2].strip.chomp : v.strip.chomp}

options[:target].sub!(/^(C:\\WINDOWS\\TEMP\\)(.*)\.(bat|ps1)$/, '${env:TEMP}/\2.ps1')
options[:target].sub!(/^(\/tmp\/)(.*)\.(sh|ps1)$/, '${env:TEMP}/\2.ps1')

winrm_username = options[:username]
winrm_password = options[:password]
winrm_timeout = ENV['RD_CONFIG_OPERATION_TIMEOUT'].dup.to_i

winrm_scheme = ENV['RD_CONFIG_HTTPS'] == 'HTTP' ? 'http' : 'https'
winrm_port = ENV['RD_CONFIG_HTTPS'] == 'HTTP' ? '5985' : '5986'
winrm_transport = ENV['RD_CONFIG_HTTPS'] == 'HTTP' ? :plaintext : :ssl
winrm_cert_invalid = ENV['RD_CONFIG_CERT_VALID'] == 'Enabled' ? false : true

if ENV.has_key?('RD_NODE_USERNAME') and ENV['RD_NODE_USERNAME'] =~ /^\${(.*)}$/
  user_in_env_key = 'RD_' + ENV['RD_NODE_USERNAME'].match(/^\${(.*)}$/).captures[0].gsub(/[^a-zA-Z0-9_]/, '_').upcase
  if ! ENV[user_in_env_key].empty?
    winrm_username = ENV[user_in_env_key].dup
  end
end

if ENV.has_key?('RD_NODE_WINRM_PASSWORD_OPTION')
  pass_in_env_key = 'RD_' + ENV['RD_NODE_WINRM_PASSWORD_OPTION'].gsub(/[^a-zA-Z0-9_]/, '_').upcase
  if ! ENV[pass_in_env_key].empty?
    winrm_password = ENV[pass_in_env_key].dup
  end
end

winrm_uri = "#{winrm_scheme}://#{options[:hostname]}:#{winrm_port}/wsman"

winrm_conn = WinRM::WinRMWebService.new(winrm_uri, winrm_transport, :user => winrm_username, :pass => winrm_password, \
             :disable_sspi => true, :ca_trust_path => '/etc/pki/tls/certs/', :no_ssl_peer_verification => \
             winrm_cert_invalid)

winrm_conn.set_timeout(winrm_timeout)

file_manager = WinRM::FS::FileManager.new(winrm_conn)

begin
  file_manager_exec = file_manager.upload(options[:source], options[:target])

  if ENV['RD_JOB_LOGLEVEL'] == "DEBUG"
    $stderr.puts "TR File Copier: Copied #{file_manager_exec} bytes from #{options[:source]} to #{options[:target]} ."
  end

  puts options[:target]
  _ec = 0
rescue Exception => e
  $stderr.puts e.message
  _ec = 253
end

exit _ec
