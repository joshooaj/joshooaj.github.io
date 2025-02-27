[CmdletBinding()]
param(
    [Parameter()]
    [ValidateSet('Serve', 'Build', 'Publish')]
    [string]
    $Task = 'Serve'
)

# TODO: Fix GH_TOKEN permissions issues in CI resulting in 403 errors
# if (Test-Path $PSScriptRoot/gists.json) {
#     $gists = Get-Content $PSScriptRoot/gists.json | ConvertFrom-Json
#     foreach ($gist in $gists) {
#         foreach ($file in $gist.files) {
#             $filePath = [io.path]::Combine($PSScriptRoot, 'docs', 'gists', $file)
#             if (Test-Path $filePath) {
#                 Write-Host "Gist already downloaded: $filePath"
#                 continue
#             }
#             Write-Host "Saving gist contents to $filePath"
#             gh gist view $gist.id -f $file | Set-Content -Path $filePath
#         }
#     }
# }

switch ($Task) {
    'Serve' {
        #docker run --rm -it -p 8000:8000 -v $PWD`:/docs ghcr.io/joshooaj/mkdocs-material-insiders:latest serve --dev-addr 0.0.0.0:8000
        docker run --rm -it -p 8000:8000 -v $PWD`:/docs --entrypoint= squidfunk/mkdocs-material:latest sh -c 'pip install -r requirements.txt && mkdocs serve --dev-addr 0.0.0.0:8000'
    }

    'Build' {
        #docker run --rm -v $PWD`:/docs ghcr.io/joshooaj/mkdocs-material-insiders build
        docker run --rm -v $PWD`:/docs --entrypoint= squidfunk/mkdocs-material:latest sh -c 'pip install -r requirements.txt && mkdocs build'
    }

    'Publish' {
        #${env:GHCR_TOKEN} | docker login -u joshooaj --password-stdin ghcr.io
        #docker pull ghcr.io/joshooaj/mkdocs-material-insiders:latest
        #docker run -v $PWD`:/docs ghcr.io/joshooaj/mkdocs-material-insiders gh-deploy --force
        docker run -v $PWD`:/docs --entrypoint= squidfunk/mkdocs-material:latest sh -c 'pip install -r requirements.txt && mkdocs gh-deploy --force'
    }

    Default {}
}
