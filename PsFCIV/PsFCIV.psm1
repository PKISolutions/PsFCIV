#region helper functions
# internal function which reads the XML file (if exist).
function __readXml ($xml) {
    # reading existing XML file and selecting required properties
    if (!(Test-Path -LiteralPath $XML)) {
        New-Object PsFCIV.Support.FcivRootNode
        return
    }
    try {
        [PsFCIV.Support.FcivRootNode]::ReadFromFile($XML)
    } catch {
        __finalize
        Write-Error -Category InvalidData -Message "Input XML file is not valid FCIV XML file." -ErrorAction Stop
    }
}
# internal xml writer
function __writeXml ($root) {
    if ($root.Entries.Count -eq 0) {
        Write-Verbose "There is no data to write to XML database."
        Write-Debug "There is no data to write to XML database."
    } else {
        Write-Debug "Preparing to DataBase file creation..."
        $root.SaveToFile($XML)
    }
}
# lightweight proxy function for Get-ChildItem cmdlet
function dirx ([string]$Path, [string]$Filter, [string[]]$Exclude, $Recurse, [switch]$Force) {
    Get-ChildItem @PSBoundParameters -File -ErrorAction SilentlyContinue
}
# internal function that will check whether the file is locked. All locked files are added to a group with 'Unknown' status.
function __testFileLock ($file) {
    $locked = $false
    trap {Set-Variable -name locked -value $true -scope 1; continue}
    $inputStream = New-Object IO.StreamReader $file.FullName
    if ($inputStream) {$inputStream.Close()}
    if ($locked) {
        Write-Verbose "File $($file.Name) is locked. Skipping this file.."
        Write-Debug "File $($file.Name) is locked. Skipping this file.."
        __addStatCounter $filename Locked
    }
    $locked
}
# internal function to generate UI window with results by using Out-GridView cmdlet.
function __showGridView ($props, $max) {
    $total = @($input)
    foreach ($property in $props) {
        $(for ($n = 0; $n -lt $max; $n++) {
            $total[0] | Select-Object @{n=$property; e={$_.$property[$n]}}
        }) | Out-GridView -Title "File list by category: $property"
    }
}
# internal function to create XML entry object for a file.
function __newFileEntry ($file, [switch]$NoHash, [switch]$hex) {
    Write-Debug "Starting object creation for '$($file.FullName)'..."
    $object = New-Object PsFCIV.Support.FcivFileEntry $file
    $object.Name = $file.FullName -replace [regex]::Escape($($pwd.ProviderPath + "\"))
    if (!$NoHash) {
    # calculating appropriate hash and convert resulting byte array to a Base64 string
        foreach ($hash in "MD5", "SHA1", "SHA256", "SHA384", "SHA512") {
            if ($HashAlgorithm -contains $hash) {
                Write-Debug "Calculating '$hash' hash..."
                $hashBytes = [PsFCIV.Support.CryptUtils]::HashFile($file, $hash)
                if ($hex) {
                    $object.$hash = [PsFCIV.Support.CryptUtils]::FormatBytes($hashBytes, "Hex")
                } else {
                    Write-Debug ("Calculated hash value: " + (-join ($hashBytes | Foreach-Object {"{0:X2}" -f $_})))
                    $object.$hash = [PsFCIV.Support.CryptUtils]::FormatBytes($hashBytes, "Base64")
                }
            }
        }
    }
    Write-Debug "Object created!"
    $object
}
# internal function that calculates current file hash and formats it to an octet string (for example, B926D7416E8235E6F94F756E9F3AE2F33A92B2C4).
function __selectHAlg ($entry, $file, $HashAlgorithm) {
    if ($HashAlgorithm.Length -gt 0) {
        $SelectedHash = $HashAlgorithm
    } else {
        :outer foreach ($hash in "SHA512", "SHA384", "SHA256", "SHA1", "MD5") {
            if ($entry.$hash) {$SelectedHash = $hash; break outer}
        }
    }
    $hex = [PsFCIV.Support.CryptUtils]::FormatBytes([PsFCIV.Support.CryptUtils]::HashFile($file, $SelectedHash), "Hex")
    Write-Debug "Selected hash name : $SelectedHash"
    Write-Debug "Selected hash value: $hex"
    New-Object psobject -Property @{
        HashName = $SelectedHash
        HashValue = $hex
    }
}
# process -Action parameter to perform an action against bad file (if actual file properties do not match the record in XML).
function __takeAction ($file, $Action) {
    switch ($Action) {
        "Rename" {Rename-Item $file $($file.FullName + ".bad")}
        "Delete" {Remove-Item $file -Force}
    }
}
# core file verification function.
function __checkfiles ($entry, $file, $Action, $Strict) {
    if (__testFileLock $file) {return}
    if ($Strict -and (($file.Length -ne $entry.Size) -or ("$($file.LastWriteTime.ToUniversalTime())" -ne $entry.TimeStamp))) {
        Write-Verbose "File '$($file.FullName)' size or Modified Date/Time mismatch."
        Write-Debug "Expected file size is: $($entry.Size) byte(s), actual size is: $($file.Length) byte(s)."
        Write-Debug "Expected file modification time is: $($entry.TimeStamp), actual file modification time is: $($file.LastWriteTime.ToUniversalTime())"
        __addStatCounter $entry.Name Bad
        __takeAction $file $Action
    } else {
        $hexhash = __selectHAlg $entry $file $HashAlgorithm
        $ActualHash = [PsFCIV.Support.CryptUtils]::FormatBytes([Convert]::FromBase64String($entry.($hexhash.HashName)), "Hex")
        if (!$ActualHash) {
            Write-Verbose "XML database entry does not contain '$($hexhash.HashName)' hash value for the entry '$($entry.Name)'."
            __addStatCounter $entry.Name Unknown
            return
        } elseif ($ActualHash -eq $hexhash.HashValue) {
            Write-Debug "File hash: $ActualHash"
            Write-Verbose "File '$($file.Name)' is ok."
            __addStatCounter $entry.Name Ok
            return
        } else {
            Write-Debug "File '$($file.Name)' failed hash verification.
                Expected hash: $hexhash.HashValue
                Actual hash: $ActualHash"
            __addStatCounter $entry.Name Bad
            __takeAction $file $Action
        }
    }
}
function __finalize {
    # do nothing at this moment
}
#endregion

#region global variables
$oldpath = ""
$stats = New-Object PsFCIV.Support.StatTable
$statcount = New-Object PsFCIV.Support.IntStatTable
#endregion

# dot-source all function files
Get-ChildItem -Path $PSScriptRoot -Include *.ps1 -Recurse -File | Foreach-Object { . $_.FullName }