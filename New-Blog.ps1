[CmdletBinding()]
param (
    [Parameter(Mandatory)]
    [string]
    $Title,

    [Parameter()]
    [string[]]
    $Category = @(,'PowerShell')
)

$created = Get-Date
$folder = Join-Path $PSScriptRoot "docs/blog/posts/$($created.ToString('yyyy-MM-dd'))-$($Title -replace '\s', '-')"
$null = New-Item -Path $folder -ItemType Directory -Force

@"
---
draft: true
date:
  created: $($created.ToString('yyyy-MM-dd'))
authors:
  - joshooaj@gmail.com
categories:
$($Category | ForEach-Object { "  - $($_)`n" })
links:
  - Text: https://link
---

# $Title

{{ Attention-grabbing introduction before the fold }}

<!-- more -->

![hero image](hero.jpg)

{{ The rest of the post }}

--8<-- "abbreviations.md"
"@ | Set-Content -Path (Join-Path $folder 'index.md')