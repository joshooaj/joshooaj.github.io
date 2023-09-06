class RecorderNameTransformAttribute : System.Management.Automation.ArgumentTransformationAttribute {

    ## Override the abstract method "Transform". This is where the user
    ## provided value will be inspected and transformed if possible.
    [object] Transform([System.Management.Automation.EngineIntrinsics]$engineIntrinsics, [object] $inputData) {
        
        ## Index recording servers in a hashtable by name so that we can look
        ## them up by name quickly later, without multiple enumerations.
        $recorders = @{}
        Get-VmsRecordingServer | Foreach-Object {
            $recorders[$_.Name] = $_
        }

        # $inputData could be a single object or an array, and each element
        # could be $null, or any other type. The only thing we are interested
        # in are strings. We'll return everything else unaltered and let
        # PowerShell throw an error if necessary.
        return ($inputData | Foreach-Object {
            $obj = $_
            if ($obj -is [string]) {
                if ($recorders.ContainsKey($obj)) {
                    $obj = $recorders[$obj]
                } else {
                    throw [VideoOS.Platform.PathNotFoundMIPException]::new('Recording server "{0}" not found.' -f $_)
                }
            }
            $obj
        })
    }

    [string] ToString() {
        return '[RecorderNameTransformAttribute()]'
    }
}

function Get-VmsHardware {
    [CmdletBinding(DefaultParameterSetName = 'RecordingServer')]
    param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName, ParameterSetName = 'RecordingServer')]
        [RecorderNameTransformAttribute()] # (1)!
        [ValidateNotNull()]# (2)!
        [VideoOS.Platform.ConfigurationItems.RecordingServer[]]
        $RecordingServer,

        [Parameter(Position = 0, Mandatory, ParameterSetName = 'Id')]
        [Alias('HardwareId')]
        [guid[]]
        $Id
    )

    process {
        switch ($PSCmdlet.ParameterSetName) {
            'RecordingServer' {
                if (-not $MyInvocation.BoundParameters.ContainsKey('RecordingServer')) {
                    Get-VmsRecordingServer | Get-VmsHardware
                } else {
                    $RecordingServer | Foreach-Object {
                        $_.HardwareFolder.Hardwares
                    }
                }
            }

            'Id' {
                $serverId = (Get-Site).FQID.ServerId
                $Id | ForEach-Object {
                    [VideoOS.Platform.ConfigurationItems.Hardware]::new($serverId, 'Hardware[{0}]' -f $_)
                }
            }

            default {
                throw "ParameterSetName '$_' not implemented."
            }
        }
    }
}

Register-ArgumentCompleter -CommandName Get-VmsHardware -ParameterName RecordingServer -ScriptBlock {
    param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
    
    # Trim single, or double quotes from the start/end of the word to complete.
    if ($wordToComplete -match '^[''"]') {
        $wordToComplete = $wordToComplete.Trim($Matches.Values[0])
    }

    # Get all unique recorder names starting with the characters provided, if any.
    $escapedWordToComplete = [System.Text.RegularExpressions.Regex]::Escape($wordToComplete)
    Get-VmsRecordingServer | Where-Object Name -match "^$escapedWordToComplete" | Select-Object Name -Unique | ForEach-Object {
        # Wrap the completion in single quotes if it contains any whitespace.
        if ($_.Name -match '\s') {
            "'{0}'" -f $_.Name
        } else {
            $_.Name
        }
    }
}
