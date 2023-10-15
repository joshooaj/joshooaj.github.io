Describe 'Markdown Tests' {
    Context 'PowerShell Code Blocks are Valid' {
        BeforeDiscovery {
            . $PSScriptRoot\Get-MdCodeBlock.ps1
            $script:codeBlocks = Get-ChildItem '*.md' | Get-MDCodeBlock -Language powershell
        }

        It 'Analyze codeblock at <_>' -ForEach $script:codeBlocks {
            $analysis = Invoke-ScriptAnalyzer -ScriptDefinition $_.Content -Settings PSGallery
            $analysis | Where-Object Severity -ge 'Warning' | Out-String | Should -BeNullOrEmpty
        }
    }
}