function Set-FirewallGpo {
    <#
    .SYNOPSIS
    Sets the Windows Firewall local security policy for one or more network profiles.

    .DESCRIPTION
    If the Windows Firewall cannot be manually enabled, or disabled for one or more
    network profiles and you see a message similar to "For your security, some
    settings are managed by your system administrator", it means that the settings
    are managed either by group policy enforced by your organization, or the local
    security policy in the Windows host machine.

    The manual method to set this local security policy is to launch the "Local
    Security Policy" dialog (secpol.msc), and open the properties for
    "Security Settings > Windows Defender Firewall with Advanced Security - Local Group Policy Object"
    and modify the state for each of the three profiles - Domain, Private, and
    Public. Note that this should only be done if this setting is NOT managed by
    your organization, and you are entitled to modify the local security policy
    of the Windows machine in question.

    The command-line method is to use the netsh CLI. Unfortunately, it seems like
    even with the latest edition of Windows 11 and Server 2022, there is no native
    PowerShell cmdlet or one-line netsh command to modify the Windows Firewall
    local group policy object. The following netsh commands will get the job
    done. Be sure to replace "<hostname>" with the real machine hostname,
    "<ProfileName>"" with one of "allprofiles", "domainprofile", "privateprofile",
    or "publicprofile", and "<State>" with one of "On", "Off", or "NotConfigured".

    C:\> netsh
    netsh> advfirewall
    netsh advfirewall> set store gpo=<hostname>
    Ok.

    netsh advfirewall>set <ProfileName> state <State>
    Ok.

    To do this in one line, you can provide multiple "standard input" values to
    enter the advfirewall context in netsh like so:

    "advfirewall", "set store gpo=$(hostname)", "set AllProfiles state NotConfigured" | netsh

    Manually typing commands at the netsh CLI is not useful for automation, so
    this cmdlet launches the netsh CLI and types the commands for you. If the
    command fails with a non-zero exit code, the output from the CLI is provided
    in an error, or you can use -PassThru to receive the results from the
    process including the exit code, and standard output and standard error
    content.

    .PARAMETER ProfileName
    Specifies the network profile to which to apply the policy change.

    .PARAMETER State
    Specifies the new state for the Windows Firewall for the specified network
    profile(s).

    .PARAMETER PassThru
    Specifies that the raw exit code, stdout, and stderr should be returned to
    the caller.

    .EXAMPLE
    Set-FirewallGpo -ProfileName AllProfiles -State NotConfigured
    Set-NetFirewallProfile -All -Enabled True

    Sets the firewall policy for all network profiles to "NotConfigured" which
    means that as a local Administrator you can enable or disable the Windows
    Firewall for any profile. Then enables the firewall for all profiles.

    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter()]
        [ValidateSet('AllProfiles', 'DomainProfile', 'PrivateProfile', 'PublicProfile')]
        [string]
        $ProfileName = 'AllProfiles',

        [Parameter(Mandatory)]
        [ValidateSet('On', 'Off', 'NotConfigured')]
        [string]
        $State,

        [Parameter()]
        [switch]
        $PassThru
    )

    process {
        if (-not $PSCmdlet.ShouldProcess((hostname), "Set Firewall local security policy for profile '$ProfileName' to '$State'")) {
            return
        }
        try {
            $pinfo = [System.Diagnostics.ProcessStartInfo]@{
                FileName               = 'netsh'
                Arguments              = ''
                WorkingDirectory       = (Resolve-Path .\).Path
                UseShellExecute        = $false
                CreateNoWindow         = $true
                RedirectStandardOutput = $true
                RedirectStandardError  = $true
                RedirectStandardInput  = $true
            }

            $p = [System.Diagnostics.Process]::Start($pInfo)
            $p.StandardInput.WriteLine('advfirewall')
            $p.StandardInput.WriteLine("set store gpo=$(hostname)")
            $p.StandardInput.WriteLine("set $ProfileName state $State")
            $p.StandardInput.WriteLine('exit')

            $stringBuilder = [text.stringbuilder]::new()
            while ($null -ne ($line = $p.StandardOutput.ReadLine())) {
                $null = $stringBuilder.AppendLine($line.Trim())
            }
            $stdout = $stringBuilder.ToString()

            $null = $stringBuilder.Clear()
            while ($null -ne ($line = $p.StandardError.ReadLine())) {
                $null = $stringBuilder.AppendLine($line.Trim())
            }
            $stderr = $stringBuilder.ToString()

            Write-Verbose "Waiting for process $($p.Id) to exit"
            $p.WaitForExit()
            if ($p.ExitCode -ne 0) {
                $message = '{0} exited with exit code {1}. {2}' -f $pinfo.FileName, $p.ExitCode, ($stdout + $stderr)
                Write-Error -Message $message
            }

            if ($PassThru) {
                [pscustomobject]@{
                    Process        = $p
                    ExitCode       = $p.ExitCode
                    StandardOutput = $stdout
                    StandardError  = $stderr
                }
            }
        } catch {
            Write-Error -ErrorRecord $_
        }
    }
}