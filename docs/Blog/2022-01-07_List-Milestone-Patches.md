---
title: List Milestone XProtect Cumulative Patches
summary: How to use PowerShell to list installed cumulative patches for Milestone XProtect VMS software.
date: 2022-01-07
authors:
    - Josh Hendricks
tags:
    - PowerShell
    - XProtect
    - Draft
---

# List Milestone XProtect Cumulative Patches

The release strategy for Milestone's XProtect VMS software is currently to drop three versions every year, with the occasional exception. The most recent release was version 2021 R2 released in October, and the next version (the first release of the new year) will be 2022 R1. The "major.minor" version numbers that will be used this year are 22.1, 22.2 and 22.3. But that only accounts for scheduled releases - what about hotfixes?

![Screenshot of Milestone Patch Installer for Milestone XProtect Smart Client 2021 R2 64-bit](/assets/images/MilestonePatchInstaller.png)

## What is a "hotfix"?

The term "hotfix" refers to a package of one or more files which usually replace the existing files of the same name. These are often DLL's (Dynamic Link Library), or EXE's (executables). DLL's and executables both contain compiled code, and often a fix for a major software bug can end up changing only one file out of hundreds, or even thousands of files that make up the whole application. It often makes the most sense to send customers "patches" to replace a small number of files. Shipping a whole product installer is more work for both the development team and the customer.

## Milestone Patch Installer

The first introduction of the Milestone Patch Installer came after the release of version 2017 R... something. I forget. I can tell you it was a major improvement over the prior hotfix & patching strategy of shipping zip files containing instructions and an obscure set of DLL's, and _hoping_ the person installing it was good at following instructions.

The design of the patch installer uses Microsoft's Windows Installer framework to apply "patches". Check out Microsoft's documentation on [Patching and Upgrades](https://docs.microsoft.com/en-us/windows/win32/msi/patching-and-upgrades). Effectively it's the same strategy of shipping the updated DLL's, only in a much cleaner and easier to manage format. There are _lots_ of opinions about how to ship software and updates including containerization, Chocolatey, NuGet, and I'm quite fond of the alternatives. That said, for an application installed using the Windows Installer framework, I think it makes a lot of sense to use the patching functionalty baked into that framework. And it made it _significantly_ easier to verify if a patch had been applied

Here's what it looks like when you have one or more Milestone cumulative patches applied. To see this list of updates, go to Control Panel > Programs and Features > Installed Updates.

![Screenshot of Milestone Patch Installer for Milestone XProtect Smart Client 2021 R2 64-bit](/assets/images/WindowsInstalledUpdates.png)

Milestone's patches are typically referred to as "Cumulative Patches", "Cumulative Hotfixes" or simply "cumulatives". The point is, if you install the cumulative patches for an XProtect VMS 2021 R2 installation, you should expect that _all fixes_ available at the time you downloaded the patch installer are included in that installer. Bug fixes are sometimes rolled out 2-3 times in a month, so if you missed the first two cumulatives, that's okay. Just download the latest cumulatives available for your product version and all prior fixes for your VMS version will be applied.

## What about automation?

- Silent install and uninstall (/install /quiet)
- List installed patches (registry, powershell)
- Check for latest available patches (hard)

## Final thoughts

I love lamp.
