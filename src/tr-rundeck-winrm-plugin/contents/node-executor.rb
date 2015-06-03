require 'winrm'
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
  opts.on("-c <command>", "--command=<command>", "Remote Command") do |command|
    options[:command] = command
  end
end.parse!

options.each {|k, v| options[k] = (v.start_with? "'" and v.end_with? "'") ? v[1,v.length-2].strip.chomp : v.strip.chomp}

options[:command].sub!(/^(chmod \+x )(\${env:TEMP}\/.*)$/, '# get-itemproperty -path \2')
options[:command].sub!(/^(\${env:TEMP}\/.*\.ps1)$/, 'Get-Content \1 | ' + ENV['RD_CONFIG_INVOCATION_STRING'] + ' -')

if ENV['RD_JOB_LOGLEVEL'] == "DEBUG" and options[:command] =~ /^(rm -f )(\${env:TEMP}\/.*)$/
  options[:command].sub!(/^(rm -f )(\${env:TEMP}\/.*)$/, '# remove-item -path \2')
  $stderr.puts "TR Node Executor: Preserved script at remote host in its ${env:TEMP} . See lines above for path."
else
  options[:command].sub!(/^(rm -f )(\${env:TEMP}\/.*)$/, 'remove-item -path \2')
end

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

winrm_exec = winrm_conn.run_powershell_script(options[:command])

winrm_exec[:data].each do |output|
  if output.has_key?(:stdout)
    $stdout.puts output[:stdout]
    $stdout.flush
  elsif output.has_key?(:stderr)
    $stderr.puts output[:stderr]
    $stderr.flush
  end
end

exit winrm_exec[:exitcode]
