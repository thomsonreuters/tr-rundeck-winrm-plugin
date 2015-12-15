# TR WinRM Plugin for Rundeck

RubyGems winrm, winrm-fs based WinRM script-type plugin for Rundeck

### Who

You are an MS Windows engineer/administrator who wants to:
* run ad-hoc PowerShell scripts in parallel on tens or hundreds of servers
* carry out a set of commands/instructions on a range of servers in a predefined order with tunable parallelism
* create complex workflows to orchestrate maintenance or deployment tasks across different server types

### Where

The plugin itself can be downloaded for EL6.3+ from https://github.com/thomsonreuters/tr-rundeck-winrm-plugin/releases in RPM format. It has been tested with Rundeck 2.4.2 and should be installed alongside with the command `rpm -Uvh <file_name.rpm>` .

Auto configuration of WinRM over HTTPS is available as a provider-less Puppet module at https://github.com/thomsonreuters/winrm_ssl .

### Why

At the time of writing, our SSH Server implementation on the MS Windows platform did not return the true exit code of the command/script that had been executed to the SSH Client. It would always return a `0` indicating that the execution was successful. For any kind of automation, determining the success of commands/scripts (sometimes as previous steps) is necessary. An exit code (or errorlevel) of `0` is the conventional machine-understood way of understanding that the last command was successful. Any other exit code is indicative of failure, and the exact code may even point to the precise problem.
Rundeck has a commonly paired WinRM plugin implemented using the OverThere library. It only supports the Command step type in Rundeck and goes to the CMD.EXE interpreter on the remote nodes. Limitation being that there isn't a multi-line text box to write scripts in, and that native PowerShell code would have to be written as if it were being run from CMD.EXE (so powershell prefix and then horrible escaping). Another issue being that Rundeck adds quotation marks to the entire Command text to make it more SH (UNIX Shell) friendly - and these modifications do not always work for CMD.EXE or PowerShell and often come in the way.

### How

You must be familiar with Rundeck to follow these instructions.

1. Create a new Rundeck project and set the default node executor and node file copier plugins to TR WinRM. Alternatively, if your project would consist of a mix of operating system types, set the defaults to stub, and in your node resources file (whether XML or YAML) set per node attributes node-executor and file-copier to tr-winrm-ne and tr-winrm-fc respectively. The Linux hosts should be set to jsch-ssh and jsch-scp respectively in this case.
1. The username attribute per node should be set to the username you intend to use for logging into the Windows nodes, in the format "DOMAIN\username". Alternatively, you may set it to the value ${option.winrmUsername} indicating that the username must be picked up from an option named winrmUsername in the job options.
1. Create a new job.
   1. It must have an option named winrmPassword of input type Secure, not Secure Remote.
   1. Add a step, choose the Script type. Note that Command type is not supported and the use of which will result in unpredictable actions being carried out on your nodes.
   1. In the text box for the script, type in native Powershell code.
      1. If you wish to run a script in a different language, unfold the Advanced option just underneath this text box and specify the full path to the interpreter under Invocation String.
1. Run the job.
   1. If you set the Log level to Debug, the script will be preserved on the remote nodes for your inspection. The debug output will tell you the path to the script as well.

### Invoking Puppet

We recommend the use of 'test' switch to `puppet agent`, this implies the 'onetime', 'verbose', 'ignorecache', 'no-daemonize', 'no-usecacheonfailure', 'detailed-exitcodes', 'no-splay' and 'show_diff' options. The 'detailed-exitcodes' option changes the behaviour of successful exit codes though, and Rundeck will only register 0 as a successful run. From the man page on 'detailed-exitcodes', "Provide transaction information via exit codes. If this is enabled, an exit code of '2' means there were changes, an exit code of '4' means there were failures during the transaction, and an exit code of '6' means there were both changes and failures." Therefore, the following snippet of PowerShell code may be used to invoke Puppet, to register 0 and 2 as success:

```
puppet agent --test

write-output "Puppet exited with code $LASTEXITCODE";

if ($LASTEXITCODE -eq 0 -or $LASTEXITCODE -eq 2) {
  $host.setShouldExit(0);
}
else {
  $host.setShouldExit($LASTEXITCODE);
}
```

### Advanced

* Powershell scripts are invoked as: `$script = Get-Content <path-to-script>; $script | Out-String | <invocation-string> - `. Where the invocation string is set to `powershell -NoProfile -NonInteractive` and can be overridden from the project properties. This convoluted method is a summation of reducing network calls, evading security policies on unsigned scripts, and capturing exit codes.
WinRM setup defaults on the nodes impose limits such as `maxmemorypershellmb` and `maxtimeoutms`. These can be configured via the winrm_ssl Puppet module mentioned above.

### Microsoft Hotfixes

KB2506143: If you get "Access is Denied" errors while running winrm.cmd commands over WinRM (as you will inadvertently if you include the winrm_ssl component/Puppet module), upgrade to Windows Management Framework 3.0 .

KB2842230: If you get "Out of memory" or failed to allocate memory errors of any sort in spite of having set a considerably large value on MaxMemoryPerShellMB .

KB3008627: If you get MSI installation failures from invoking the install over WinRM (or even via a Puppet run invoked over WinRM). KB3000988 also does the job.

### Troubleshooting

* In case of error, look for an HTTP code in the output and look it up. They usually pinpoint to an authentication or an authorisation problem.
   * A 5xx series error may indicate a remote node configuration problem or a timeout if quicker returning scripts work.
      * Or it could mean that untrusted SSL certificates were found. Keep reading for a workaround.
* Connection timed out or reset errors are usually firewalling or routing issues. You can,
   * Get in touch with the systems administrator of the Rundeck instance and have the connectivity checked.
   * Switch to using HTTP instead of HTTPS. WinRM runs on TCP port 5986 for the latter, 5985 for the former and you may have better luck with that. Be informed that the winrm_ssl component disables the WinRM HTTP listener under defaults, but can be configured to not do so.

### Powershell Quirks

Coming soon...

### Starter Pack

Coming soon...

### winrm_ssl

The winrm_ssl Puppet module automatically, under defaults, configures five aspects of WinRM:

Using Ruby's OpenSSL extension, convert the TLS certificates from the Puppet Agent setup to the Windows' PFX format, and install that in Windows' Certificate Store. It then adds a WinRM HTTPS Listener with that certificate from the store - the mapping is via the Certificate Thumbprint.
Delete's the WinRM HTTP Listener: `winrm.cmd delete winrm/config/listener?Address=*+Transport=HTTP`
Enable Basic Auth on the WinRM Service (no change to Client): `winrm.cmd set winrm/config/service/auth @{Basic="True"}`
Up the _MaxMemoryPerShellMB setting_: `winrm.cmd set winrm/config/winrs @{MaxMemoryPerShellMB="1024"}`
Up the _MaxTimeoutms_ setting: `winrm.cmd set winrm/config @{MaxTimeoutms="60000"}`

These are parameterised and the Puppet Class Signature is: `class winrm_ssl($auth_basic = true, $disable_http = true, $manage_service = true, $maxmemorypershellmb = 1024, $maxtimeoutms = 60000) {}`

The _manage_service_ parameter simply ensures that the winrm service is set to autostart, and is started. Overriding any of these depends on your Puppet approach between Hiera and classic DSL.

### Build

1. Install CentOS 6.x RTM of the lowest point release you want to support. Keep RTM repos attached and any updates repos detached.
1. Run `_build/setup_01of02.sh` and `_build/setup_02of02.sh` once. These will need the RTM repos attached.
1. Update the files, particularty the version numbers in `_build/package_01of01.sh`.
1. Run `_build/package_01of01.sh`.
