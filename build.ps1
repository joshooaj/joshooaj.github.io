[CmdletBinding()]
param(
    [Parameter()]
    [ValidateSet('Serve', 'Build')]
    [string]
    $Task = 'Serve',

    [Parameter()]
    [switch]
    $UseInsiders
)

docker pull ghcr.io/joshooaj/mkdocs-material-insiders:latest

switch ($Task) {
    'Serve' {
        if ($UseInsiders) {
            docker run --rm -it -p 8000:8000 -v $PWD`:/docs ghcr.io/joshooaj/mkdocs-material-insiders:latest serve --config-file mkdocs.insiders.yml --dev-addr 0.0.0.0:8000
        }
        else {
            docker run --rm -it -p 8000:8000 -v $PWD`:/docs ghcr.io/joshooaj/mkdocs-material-insiders:latest serve --dev-addr 0.0.0.0:8000
        }
    }

    'Build' {
        if ($UseInsiders) {
            docker run --rm -v $PWD`:/docs ghcr.io/joshooaj/mkdocs-material-insiders build --config-file mkdocs.insiders.yml
        }
        else {
            docker run --rm -v $PWD`:/docs ghcr.io/joshooaj/mkdocs-material-insiders build
        }
    }
    Default {}
}
