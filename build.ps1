[CmdletBinding()]
param(
    [Parameter()]
    [ValidateSet('Serve', 'Build', 'Publish')]
    [string]
    $Task = 'Serve'
)

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
