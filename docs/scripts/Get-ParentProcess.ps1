function Get-ParentProcess {
    <#
    .SYNOPSIS
    Gets the name and ID of the parent process for the specified process.
    
    .DESCRIPTION
    Gets the name and ID of the parent process for the specified process. The
    process can be specified by object, such as by piping in the results of
    Get-Process, or by name or ID.

    The output is a [pscustomobject] with the name and ID of the specified
    process and the parent process if available.
    
    .PARAMETER InputObject
    Specifies a Process object such as is returned by the Get-Process cmdlet.
    
    .PARAMETER Name
    Specifies one or more process names.
    
    .PARAMETER Id
    Specifies one or more process IDs.
    
    .EXAMPLE
    Get-ParentProcess notepad

    Gets the parent process for all processes with the name "notepad".

    .EXAMPLE
    Get-ParentProcess -Id 1234

    Gets the parent process for the process with ID 1234.

    .EXAMPLE
    Get-Process -Name note* | Get-ParentProcess

    Gets the parent process for all processes having a name that starts with "note".
    #>
    [CmdletBinding(DefaultParameterSetName = 'Name')]
    [OutputType([pscustomobject])]
    param(
        [Parameter(ValueFromPipeline, ParameterSetName = 'InputObject')]
        [System.Diagnostics.Process[]]
        $InputObject,

        [Parameter(ValueFromPipelineByPropertyName, ParameterSetName = 'Name', Position = 0)]
        [string[]]
        $Name,

        [Parameter(ValueFromPipelineByPropertyName, ParameterSetName = 'Id', Position = 0)]
        [int[]]
        $Id
    )

    process {
        switch ($PSCmdlet.ParameterSetName) {
            'InputObject' {
            }

            'Name' {
                $InputObject = Get-Process -Name $Name
            }

            'Id' {
                $InputObject = Get-Process -Id $Id
            }

            default {
                throw "Parameter set '$_' not implemented."
            }
        }

        foreach ($process in $InputObject) {
            $cimProcess = Get-CimInstance -ClassName win32_process -Filter "ProcessId = $($process.Id)"
            $parent = Get-Process -Id $cimProcess.ParentProcessId -ErrorAction SilentlyContinue
            [pscustomobject]@{
                Name       = $process.Name
                Id         = $process.Id
                ParentName = $parent.Name
                ParentId   = $parent.Id
            }
        }
    }
}

Register-ArgumentCompleter -CommandName Get-ParentProcess -ParameterName Name -ScriptBlock {
    param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
    
    # Trim single, or double quotes from the start/end of the word to complete.
    if ($wordToComplete -match '^[''"]') {
        $wordToComplete = $wordToComplete.Trim($Matches.Values[0])
    }

    # Get all unique process names starting with the characters provided, if any.
    Get-Process -Name "$wordToComplete*" | Select-Object Name -Unique | ForEach-Object {
        # Wrap the completion in single quotes if it contains any whitespace.
        if ($_.Name -match '\s') {
            "'{0}'" -f $_.Name
        } else {
            $_.Name
        }
    }
}

Register-ArgumentCompleter -CommandName Get-ParentProcess -ParameterName Id -ScriptBlock {
    param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
    $id = $wordToComplete -as [int]
    if ($null -eq $id) {
        # The supplied value for Id is not an integer so don't return any completions.
        return
    }

    if ([string]::IsNullOrWhiteSpace($wordToComplete)) {
      $id = $null
    }

    # Get all processes where the Id starts with the provided number(s), or all processes if no numbers were entered yet.
    (Get-Process | Where-Object { $_.Id -match "^$id" }).Id
}
