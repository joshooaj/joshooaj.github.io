using namespace System.IO
using namespace System.Management.Automation

function Get-DHash {
    <#
    .SYNOPSIS
    Computes the dHash value for the provided image.
    .DESCRIPTION
    The `Get-DHash` cmdlet computes the dHash value for the provided image. The dHash is a 64-bit representation of the
    image, returned as a hexadecimal string. The dHash values for two images can be compared using Compare-DHash, and
    the resulting value represents the number of bits that are different between the two images, or the
    "Hamming distance".
    The dHash is computed using the following algorithm. See the blog post referenced in the notes for more information.
    1. Convert the image to grayscale.
    2. Resize the image to 9x8.
    3. For each of the 8 rows in the resulting image, check if each pixel is brighter than the neighbor to the right. If
       it is, that bit is set to 1.
    4. Convert the 8 resulting bytes to a hexadecimal string.
    .PARAMETER Path
    Specifies the path to an image file.
    .PARAMETER Bytes
    Specifies an array of bytes representing an image.
    .PARAMETER OutFile
    For diagnostic purposes, you may provide a path to save the resized, grayscale representation of the provided image created for dHash calculation.
    .PARAMETER ColorMatrix
    Optionally you may provide a custom ColorMatrix used to create a grayscale representation of the source image.
    .EXAMPLE
    $dhash1 = Get-DHash ./image1.jpg
    $dhash2 = Get-DHash ./image2.jpg
    Compare-DHash $dhash1 $dhash2
    Computes the dHash values for two different images, and then compares the
    dHash values. The result is the number of bits that do not match between the
    two difference-hashes.
    .NOTES
    The inspiration for the dHash concept and these functions comes from a blog
    post by Dr. Neal Krawetz on [The Hacker Factor Blog](https://www.hackerfactor.com/blog/index.php?/archives/529-Kind-of-Like-That.html).
    #>
    [CmdletBinding(DefaultParameterSetName = 'Path')]
    [OutputType([string])]
    param (
        [Parameter(Mandatory, Position = 0, ValueFromPipeline, ValueFromPipelineByPropertyName, ParameterSetName = 'Path')]
        [string]
        $Path,

        [Parameter(Mandatory, Position = 0, ValueFromPipelineByPropertyName, ParameterSetName = 'LiteralPath')]
        [Alias('PSPath')]
        [Alias('LP')]
        [string]
        $LiteralPath,

        [Parameter(Mandatory, Position = 0, ParameterSetName = 'Stream')]
        [System.IO.Stream]
        $InputStream,

        # Saves a copy of the grayscale, resized reference image used for calculating dHash for diagnostic purposes.
        [Parameter(ParameterSetName = 'Path')]
        [Parameter(ParameterSetName = 'LiteralPath')]
        [Parameter(ParameterSetName = 'Stream')]
        [string]
        $OutFile,

        [Parameter(ParameterSetName = 'Path')]
        [Parameter(ParameterSetName = 'LiteralPath')]
        [Parameter(ParameterSetName = 'Stream')]
        [float[]]
        $ColorMatrix = @(0.299, 0.587, 0.114)
    )

    begin {
        Add-Type -AssemblyName System.Drawing
    }

    process {
        if ($PSCmdlet.ParameterSetName -ne 'Stream') {
            if (-not [string]::IsNullOrWhiteSpace($Path)) {
                $LiteralPath = (Resolve-Path -Path $Path).ProviderPath
            } else {
                $LiteralPath = (Resolve-Path -LiteralPath $LiteralPath).ProviderPath
            }
            foreach ($filePath in $LiteralPath) {
                try {
                    $null = Resolve-Path -LiteralPath $filePath -ErrorAction Stop
                    $stream = [file]::Open($filePath, [filemode]::Open, [fileaccess]::Read, [fileshare]::Read)
                    $params = @{
                        InputStream = $stream
                        ColorMatrix = $ColorMatrix
                    }
                    if (-not [string]::IsNullOrWhiteSpace($OutFile)) {
                        $params.OutFile = $OutFile
                    }
                    Get-DHash @params
                } catch {
                    Write-Error -ErrorRecord $_
                } finally {
                    if ($stream) {
                        $stream.Dispose()
                    }
                }
            }
            return
        }
        try {
            $dHash = [byte[]]::new(8)
            $src = [drawing.image]::FromStream($InputStream)
            $dst = ConvertTo-DHashImage -Image $src
            for ($y = 0; $y -lt $dst.Height; $y++) {
                $byte = [byte]0
                for ($x = 0; $x -lt ($dst.Width - 1); $x++) {
                    $thisPixel = $dst.GetPixel($x, $y).GetBrightness()
                    $nextPixel = $dst.GetPixel($x + 1, $y).GetBrightness()
                    $thisPixelIsBrighter = [byte]($thisPixel -gt $nextPixel)
                    $byte = $byte -shl 1
                    $byte = $byte -bor $thisPixelIsBrighter
                }
                $dHash[$y] = $byte
            }
            ConvertTo-HexString -InputObject $dHash

            if ($PSCmdlet.MyInvocation.BoundParameters.ContainsKey('OutFile')) {
                $OutFile = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($OutFile)
                $dst.Save($OutFile, [System.Drawing.Imaging.ImageFormat]::Jpeg)
            }
        } finally {
            $src, $dst | Where-Object { $null -ne $_ } | ForEach-Object {
                $_.Dispose()
            }
        }
    }
}

function Compare-DHash {
    <#
    .SYNOPSIS
    Compares the provided dHash strings and returns the difference as an integer between 0 and 64.
    .DESCRIPTION
    The `Compare-DHash` cmdlet compares the provided dHash strings and returns the difference as an
    integer between 0 and 64.
    .PARAMETER DHash1
    Specifies a case-insensitive dHash string with 16 hexadecimal characters.
    .PARAMETER DHash2
    Specifies a case-insensitive dHash string with 16 hexadecimal characters.
    .EXAMPLE
    $dhash1 = Get-DHash ./image1.jpg
    $dhash2 = Get-DHash ./image2.jpg
    Compare-DHash $dhash1 $dhash2
    Computes the dHash values for two different images, and then compares the
    dHash values. The result is the number of bits that do not match between the
    two difference-hashes.
    .NOTES
    The inspiration for the dHash concept and these functions comes from a blog
    post by Dr. Neal Krawetz on [The Hacker Factor Blog](https://www.hackerfactor.com/blog/index.php?/archives/529-Kind-of-Like-That.html).
    #>
    [CmdletBinding()]
    [OutputType([int])]
    param (
        [Parameter(Mandatory, Position = 0)]
        [string]
        $DHash1,

        [Parameter(Mandatory, Position = 1)]
        [string]
        $DHash2
    )

    process {
        $difference = 0;
        for ($index = 0; $index -lt 8; $index++) {
            $byte1 = [convert]::ToByte($DHash1.SubString($index * 2, 2), 16)
            $byte2 = [convert]::ToByte($DHash2.SubString($index * 2, 2), 16)
            $xor = $byte1 -bxor $byte2
            for ($bit = 8; $bit -gt 0; $bit--) {
                $difference += $xor -band 1
                $xor = $xor -shr 1
            }
        }
        $difference
    }
}

function ConvertFrom-HexString {
    [CmdletBinding()]
    [OutputType([byte[]])]
    param (
        [Parameter(Mandatory, Position = 0, ValueFromPipeline)]
        [string]
        $InputObject
    )

    process {
        $bytes = [byte[]]::new($InputObject.Length / 2)
        for ($index = 0; $index -lt $bytes.Length; $index++) {
            $bytes[$index] = [convert]::ToByte($InputObject.SubString($index * 2, 2), 16)
        }
        Write-Output $bytes -NoEnumerate
    }
}

function ConvertTo-HexString {
    [CmdletBinding()]
    [OutputType([string])]
    param (
        [Parameter(Mandatory, Position = 0)]
        [byte[]]
        $InputObject
    )

    process {
        [string]::Join('', ($InputObject | ForEach-Object { $_.ToString('x2') }))
    }
}

function ConvertTo-DHashImage {
    <#
    .SYNOPSIS
    Returns a grayscale 9x8 resolution image based on the input image.
    .DESCRIPTION
    The `ConvertTo-DHashImage` cmdlet returns a grayscale 9x8 resolution image
    based on the input image.
    .PARAMETER Image
    Specifies the input image.
    .PARAMETER ColorMatrix
    Optionally specifies the RGB values to use in the ColorMatrix used for grayscale conversion.
    .EXAMPLE
    [System.Drawing.Image]::FromFile('C:\path\to\image.jpg') | ConvertTo-DHashImage
    Create a new System.Drawing.Image object from image.jpg, and produce a grayscale 9x8 representation of it.
    #>
    [CmdletBinding()]
    [OutputType([System.Drawing.Image])]
    param (
        [Parameter(Mandatory, ValueFromPipeline, Position = 1)]
        [System.Drawing.Image]
        $Image,

        [Parameter()]
        [float[]]
        $ColorMatrix = @(0.299, 0.587, 0.114)
    )

    process {
        $r = $ColorMatrix[0]
        $g = $ColorMatrix[1]
        $b = $ColorMatrix[2]
        $grayScale = [float[][]]@(
            [float[]]@($r, $r, $r, 0, 0),
            [float[]]@($g, $g, $g, 0, 0),
            [float[]]@($b, $b, $b, 0, 0),
            [float[]]@( 0, 0, 0, 1, 0),
            [float[]]@( 0, 0, 0, 0, 1)
        )

        try {
            $dst = [drawing.bitmap]::new(9, 8)
            $dstRectangle = [drawing.rectangle]::new(0, 0, $dst.Width, $dst.Height)
            $graphics = [drawing.graphics]::FromImage($dst)
            $graphics.CompositingMode = [drawing.drawing2d.compositingmode]::SourceOver
            $graphics.CompositingQuality = [drawing.drawing2d.CompositingQuality]::HighQuality
            $graphics.InterpolationMode = [drawing.drawing2d.InterpolationMode]::HighQualityBicubic
            $graphics.PixelOffsetMode = [drawing.drawing2d.PixelOffsetMode]::None
            $imgAttr = [drawing.imaging.imageattributes]::new()
            $imgAttr.SetWrapMode([drawing.drawing2d.wrapmode]::Clamp)
            $imgAttr.SetColorMatrix([drawing.imaging.colormatrix]::new($grayScale))
            $graphics.DrawImage($Image, $dstRectangle, 0, 0, $Image.Width, $Image.Height, [drawing.graphicsunit]::Pixel, $imgAttr)
            $dst
        } finally {
            $imgAttr, $graphics | Where-Object { $null -ne $_ } | ForEach-Object {
                $_.Dispose()
            }
        }
    }
}

function Get-PerceptHash {
    [CmdletBinding(DefaultParameterSetName = 'Path')]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName, Position = 0, ParameterSetName = 'Path')]
        [string[]]
        $Path,

        [Parameter(Mandatory, ValueFromPipelineByPropertyName, Position = 0, ParameterSetName = 'LiteralPath')]
        [Alias('PSPath')]
        [Alias('LP')]
        [string[]]
        $LiteralPath,

        [Parameter(Mandatory, Position = 0, ParameterSetName = 'Stream')]
        [System.IO.Stream]
        $InputStream,

        [Parameter(Position = 1, ParameterSetName = 'Path')]
        [Parameter(Position = 1, ParameterSetName = 'LiteralPath')]
        [Parameter(Position = 1, ParameterSetName = 'Stream')]
        [ValidateSet('aHash', 'dHash', 'pHash', IgnoreCase = $true)]
        [string]
        $Algorithm = 'dHash'
    )

    process {
        if ($Algorithm -ne 'dHash') {
            throw "Sorry, the $Algorithm algorithm is not yet implemented. Try dHash instead."
        }
        if ($PSCmdlet.ParameterSetName -ne 'Stream') {
            if ($Path.Count -gt 0) {
                $LiteralPath = (Resolve-Path -Path $Path).ProviderPath
            } else {
                $LiteralPath = (Resolve-Path -LiteralPath $LiteralPath).ProviderPath
            }
            foreach ($filePath in $LiteralPath) {
                try {
                    $null = Resolve-Path -LiteralPath $filePath -ErrorAction Stop
                    $stream = [file]::Open($filePath, [filemode]::Open, [fileaccess]::Read, [fileshare]::Read)
                    Get-PerceptHash -InputStream $stream -Algorithm $Algorithm
                } catch {
                    Write-Error -ErrorRecord $_
                } finally {
                    if ($stream) {
                        $stream.Dispose()
                    }
                }
            }
            return
        }
        [pscustomobject]@{
            PSTypeName  = 'PerceptHash'
            Algorithm = $Algorithm
            Hash      = Get-DHash -InputStream $stream
            Path      = $filePath
        }
    }
}

function Compare-PerceptHash {
    <#
    .SYNOPSIS
    Compares the provided perception hashes and returns the difference as an integer.
    .DESCRIPTION
    The `Compare-PerceptHash` cmdlet compares the provided perception hashes and
    returns the difference as an integer. A value of 10 or less indicates strong
    visual similarity. A value of 0 indicates very strong visual similarity, though
    because the comparison is based on highly compressed versions of the original
    images, a value of 0 does not guarantee the images are the same.

    .PARAMETER ReferenceHash
    Specifies a case-insensitive hexadecimal string.

    .PARAMETER DifferenceHash
    Specifies a case-insensitive hexadecimal string.

    .EXAMPLE
    $dhash1 = Get-PerceptHash ./image1.jpg
    $dhash2 = Get-PerceptHash ./image2.jpg
    $dhash1, $dhash2 | Compare-PerceptHash

    Computes the dHash values for two different images, and then compares the
    dHash values. The result is the number of bits that do not match between the
    two difference-hashes.

    .NOTES
    The inspiration for the dHash concept and these functions comes from a blog
    post by Dr. Neal Krawetz on [The Hacker Factor Blog](https://www.hackerfactor.com/blog/index.php?/archives/529-Kind-of-Like-That.html).
    #>
    [CmdletBinding(DefaultParameterSetName = 'default')]
    [OutputType([int])]
    param (
        [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName, ParameterSetName = 'InputObject')]
        [Alias('Hash')]
        [string[]]
        $InputObject,

        [Parameter(Mandatory, Position = 0, ParameterSetName = 'default')]
        [string]
        $ReferenceHash,

        [Parameter(Mandatory, Position = 1, ParameterSetName = 'default')]
        [string]
        $DifferenceHash
    )

    process {
        foreach ($hash in $InputObject) {
            if ($PSCmdlet.ParameterSetName -eq 'InputObject') {
                if ([string]::IsNullOrWhiteSpace($ReferenceHash)) {
                    $ReferenceHash = $hash
                    continue
                } elseif ([string]::IsNullOrWhiteSpace($DifferenceHash)) {
                    $DifferenceHash = $hash
                    continue
                } else {
                    throw "Too many hashes have been provided for comparison. Please provide only two hashes at a time."
                }
            }
        }
    }

    end {
        try {
            $difference = 0;
            for ($index = 0; $index -lt 8; $index++) {
                $byte1 = [convert]::ToByte($ReferenceHash.SubString($index * 2, 2), 16)
                $byte2 = [convert]::ToByte($DifferenceHash.SubString($index * 2, 2), 16)
                $xor = $byte1 -bxor $byte2
                for ($bit = 8; $bit -gt 0; $bit--) {
                    $difference += $xor -band 1
                    $xor = $xor -shr 1
                }
            }
            $difference
        } catch {
            Write-Error -ErrorRecord $_
        }
    }
}

Export-ModuleMember -Function Get-PerceptHash, Compare-PerceptHash