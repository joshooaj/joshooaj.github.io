using namespace System.Text
using namespace System.Text.RegularExpressions

# Used to keep track of where we are in a markdown file. Might use this pattern
# later for a more full-featured tool to parse and modify markdown files.
enum MdState {
    Undefined
    InCodeBlock
}

class CodeBlock {
    [string] $Source
    [string] $Language
    [string] $Content
    [int]    $LineNumber
    [int]    $Position
    [bool]   $Inline

    [string] ToString() {
        return '{0}:{1} Language={2}, Length={3}' -f $this.Source, $this.LineNumber, $this.Language, $this.Content.Length
    }
}

function Get-MdCodeBlock {
    <#
    .SYNOPSIS
    Gets code from inline code and fenced code blocks in markdown files.

    .DESCRIPTION
    Gets code from inline code and fenced code blocks in markdown files with
    support for simple PyMdown Snippets syntax, and the PyMdown InlineHilite
    extension which allows you to use a "shebang" like `#!powershell Get-ChildItem *.md -Recurse | Get-MdCodeBlock`.

    .PARAMETER Path
    Specifies the path to the markdown file from which to extract code blocks.

    .PARAMETER BasePath
    Specifies the base path to use when resolving relative file paths for the CodeBlock object's Source property.

    .EXAMPLE
    Get-ChildItem -Path .\*.md -Recurse | Get-MdCodeBlock

    Gets information about inline and fenced code from all .md files in the current directory and any subdirectories
    recursively.

    .EXAMPLE
    Get-MdCodeBlock -Path docs\*.md -BasePath docs\

    Gets information about inline and fenced code from all .md files in the "docs" subdirectory. The Source property
    on each CodeBlock object returned will be relative to the docs subdirectory.

    .EXAMPLE
    Get-MDCodeBlock -Path docs\*.md -BasePath docs\ -Language powershell | ForEach-Object {
        Invoke-ScriptAnalyzer -ScriptDefinition $_.Content
    }

    Gets all inline and fenced PowerShell code from all .md files in the docs\ directory, and runs each of them through
    PSScriptAnalyzer using `Invoke-ScriptAnalyzer`.

    .EXAMPLE
    Get-ChildItem -Path *.md -Recurse | Get-MdCodeBlock | Where-Object Language -eq 'powershell' | ForEach-Object {
        $tokens = $errors = $null
        $ast = [management.automation.language.parser]::ParseInput($_.Content, [ref]$tokens, [ref]$errors)
        [pscustomobject]@{
            CodeBlock = $_
            Tokens    = $tokens
            Errors    = $errors
            Ast       = $ast
        }
    }

    Gets all inline and fenced powershell code from all markdown files in the current directory and all subdirectories,
    and runs them through the PowerShell language parser to return a PSCustomObject with the original CodeBlock, and the
    tokens, errors, and Abstract Syntax Tree returned by the language parser. You might use this to locate errors in
    your documentation, or find very specific elements of PowerShell code.

    .NOTES
    [Pymdown Snippets extension](https://facelessuser.github.io/pymdown-extensions/extensions/snippets/)
    [Pymdown InlineHilite extension](https://facelessuser.github.io/pymdown-extensions/extensions/inlinehilite/)
    #>
    [CmdletBinding()]
    [OutputType([CodeBlock])]
    param (
        [Parameter(Mandatory, ValueFromPipeline, Position = 0)]
        [string[]]
        [SupportsWildcards()]
        $Path,

        [Parameter()]
        [string]
        $BasePath = '.',

        [Parameter()]
        [string]
        $Language
    )

    process {
        foreach ($unresolved in $Path) {
            foreach ($file in (Resolve-Path -Path $unresolved).Path) {
                $file = (Resolve-Path -Path $file).Path
                $BasePath = (Resolve-Path -Path $BasePath).Path
                $escapedRoot = [regex]::Escape($BasePath)
                $relativePath = $file -replace $escapedRoot, ''


                # This section imports files referenced by PyMdown snippet syntax
                # Example: --8<-- "abbreviations.md"
                # Note: This function only supports very basic snippet syntax.
                # See https://facelessuser.github.io/pymdown-extensions/extensions/snippets/ for documentation on the Snippets PyMdown extension
                $lines = Get-Content -Path $file | ForEach-Object {
                    if ($_ -match '--8<-- "(?<file>[^"]+)"') {
                        $snippetPath = Join-Path -Path $BasePath -ChildPath $Matches.file
                        if (Test-Path -Path $snippetPath) {
                            Get-Content -Path $snippetPath
                        } else {
                            Write-Warning "Snippet not found: $snippetPath"
                        }
                    } else {
                        $_
                    }
                }


                $lineNumber = 0
                $code = $null
                $state = [MdState]::Undefined
                $content = [stringbuilder]::new()

                foreach ($line in $lines) {
                    $lineNumber++
                    switch ($state) {
                        'Undefined' {
                            if ($line -match '^\s*```(?<lang>\w+)?' -and ([string]::IsNullOrWhiteSpace($Language) -or $Matches.lang -eq $Language)) {
                                $state = [MdState]::InCodeBlock
                                $code = [CodeBlock]@{
                                    Source     = $relativePath
                                    Language   = $Matches.lang
                                    LineNumber = $lineNumber
                                }
                            } elseif (($inlineMatches = [regex]::Matches($line, '(?<!`)`(#!(?<lang>\w+) )?(?<code>[^`]+)`(?!`)'))) {
                            #} elseif ($line -match '(?<!`)`(#!(?<lang>\w+) )?(?<code>[^`]+)`(?!`)' -and ([string]::IsNullOrWhiteSpace($Language) -or $Matches.lang -eq $Language)) {
                                foreach ($inlineMatch in $inlineMatches) {
                                    [CodeBlock]@{
                                        Source     = $relativePath
                                        Language   = $inlineMatch.Groups.lang
                                        Content    = $inlineMatch.Groups.code
                                        LineNumber = $lineNumber
                                        Position   = $inlineMatch.Index
                                        Inline     = $true
                                    }
                                }
                            }
                        }

                        'InCodeBlock' {
                            if ($line -match '^\s*```') {
                                $state = [MdState]::Undefined
                                $code.Content = $content.ToString()
                                $code
                                $code = $null
                                $null = $content.Clear()
                            } else {
                                $null = $content.AppendLine($line)
                            }
                        }
                    }
                }
            }
        }
    }
}