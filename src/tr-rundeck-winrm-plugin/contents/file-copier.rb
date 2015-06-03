require 'winrm-fs'
require 'optparse'

$stdout.sync = true
$stderr.sync = true

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

options[:target].sub!(/^(\/tmp\/)(.*)\.sh$/, '${env:TEMP}/\2.ps1')

winrm_username = options[:username]
winrm_password = options[:password]
winrm_timeout = ENV['RD_CONFIG_OPERATION_TIMEOUT'].dup.to_i

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

winrm_uri = "https://#{options[:hostname]}:5986/wsman"

winrm_conn = WinRM::WinRMWebService.new(winrm_uri, :ssl, :user => winrm_username, :pass => winrm_password, :disable_sspi => true, :ca_trust_path => '/etc/pki/tls/certs/')

winrm_conn.set_timeout(winrm_timeout)

file_manager = WinRM::FS::FileManager.new(winrm_conn)

file_manager_exec = file_manager.upload(options[:source], options[:target])

if ENV['RD_JOB_LOGLEVEL'] == "DEBUG"
  $stderr.puts "TR File Copier: Copied #{file_manager_exec} bytes from #{options[:source]} to #{options[:target]} ."
end

puts options[:target]
