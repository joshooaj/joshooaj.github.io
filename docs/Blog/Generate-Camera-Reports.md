---
title: How To Generate Online/Offline Camera Reports
summary: How to use PowerShell and MilestonePSTools to generate a camera report.
date: 2022-01-01
authors:
    - Josh Hendricks
tags:
    - MilestonePSTools
    - PowerShell
---

# How To Generate Online/Offline Camera Reports

A common request from Milestone XProtect customers is to be able to generate a
report of online or offline cameras. This is something you _should_ find in the
System Monitor dashboard in Management Client or Smart Client, but often times
you want to be able to pull that information up in your favorite spreadsheets
app, and share it with another person in a portable format.

The MilestonePSTools PowerShell module makes this _relatively_ easy. It's not
going to be as easy as clicking an "export" button in the Management Client and
saving a CSV or XLSX file, but that button doesn't exist yet! The easiest way
to get this information using MilestonePSTools is going to be to follow
[this tutorial](https://www.milestonepstools.com/tutorial/) which covers the
module installation, and shows how to use the built-in `Get-VmsCameraReport`
cmdlet.

The focus of this guide though is to show how to use MilestonePSTools to write
a much smaller, simpler report that completes much faster since all we care
about is whether Milestone considers the camera to be online or offline.

If you want to use the built-in camera report command, and your VMS has a
small'ish number of cameras, or you don't care if the report is a little slow,
you can follow the tutorial linked above. And if you want to limit the output
of that report, you can use `Get-VmsCameraReport | Select-Object Name, State`
to filter the output to _just_ the Name and State properties.

## Getting status information

The `Get-ItemState` cmdlet can be used to ask the Milestone Event Server for
the state of all items in the VMS installation, or just the "Camera" objects.
