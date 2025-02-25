[CmdletBinding()]
param(
    [Parameter()]
    [ValidateSet('Serve', 'Build', 'Publish')]
    [string]
    $Task = 'Serve'
)

if (Test-Path $PSScriptRoot/gists.json) {
    $gists = Get-Content $PSScriptRoot/gists.json | ConvertFrom-Json
    foreach ($gist in $gists) {
        foreach ($file in $gist.files) {
            $filePath = [io.path]::Combine($PSScriptRoot, 'docs', 'gists', $file)
            Write-Host "Saving gist contents to $($filePath)"
            gh gist view $gist.id -f $file | Set-Content -Path $filePath
        }
    }
}

switch ($Task) {
    'Serve' {
        docker run --rm -it -p 8000:8000 -v $PWD`:/docs ghcr.io/joshooaj/mkdocs-material-insiders:latest serve --dev-addr 0.0.0.0:8000
    }

    'Build' {
        docker run --rm -v $PWD`:/docs ghcr.io/joshooaj/mkdocs-material-insiders build
    }

    'Publish' {
        ${env:GHCR_TOKEN} | docker login -u joshooaj --password-stdin ghcr.io
        docker pull ghcr.io/joshooaj/mkdocs-material-insiders:latest
        docker run -v $PWD`:/docs ghcr.io/joshooaj/mkdocs-material-insiders gh-deploy --force
    }

    Default {}
}
