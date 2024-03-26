---
date:
  created: 2024-03-25
authors:
 - joshooaj@gmail.com
categories:
  - PowerShell
  - Windows
---

# But I AM the administrator

A while back I was helping a co-worker with a project where the customer needed
to automate a lot of minor Windows configuration steps on some Windows IoT
server appliances. One of the tasks was to make it possible to disable Windows
Firewall, because even an administrator was greeted with the message "For your
security, some settings are managed by your system administrator" and the option
to change firewall settings was disabled.

<!-- more -->

While I don't agree with _disabling_ the firewall, they weren't my or my
organizations computers and the customer needed to be able to task their
distributor with pre-configuring hundreds or maybe thousands of systems
identically without Active Directory or Azure AD.

System administration or provisioning isn't my role but I'm familiar enough
with Windows to automate most thing that come up. I figured there would be
a cmdlet or command-line tool baked into the OS that would make quick work
of this, but as I dug into it, the only option seemed to be to apply a GPO
or use the interactive netsh prompt.

Maybe there's a better way, and you should really just keep the firewall
enabled with whatever rules you require, but I wrote this function to run
those interactive netsh commands in a way that could be automated.

## Code

[Download :material-download:](Set-FirewallGpo.ps1){ .md-button .md-button--primary }

```powershell title="Set-FirewallGpo.ps1" linenums="1"
--8<-- "blog/posts/2024-03-25-SetFirewallGpo/Set-FirewallGpo.ps1"
```

--8<-- "abbreviations.md"
