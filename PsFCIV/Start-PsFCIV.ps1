function Start-PsFCIV {
<#
.ExternalHelp PsFCIV.Help.xml
#>
[CmdletBinding(DefaultParameterSetName = '__xml')]
    param (
        [Parameter(Mandatory = $true, Position = 0)]
        [IO.DirectoryInfo]$Path,
        [Parameter(Mandatory = $true, Position = 1, ParameterSetName = '__xml')]
        [string]$XML,
        [string]$Include = "*",
        [string[]]$Exclude,
        [Parameter(ParameterSetName = '__xml')]
        [ValidateSet("Rename", "Delete")]
        [string]$Action,
        [Parameter(ParameterSetName = '__xml')]
        [ValidateSet("Bad", "Locked", "Missed", "New", "Ok", "Unknown", "All")]
        [String[]]$Show,
        [ValidateSet("MD5", "SHA1", "SHA256", "SHA384", "SHA512")]
        [AllowEmptyCollection()]
        [String[]]$HashAlgorithm = "SHA1",
        [switch]$Recurse,
        [Parameter(ParameterSetName = '__xml')]
        [switch]$Strict,
        [Parameter(ParameterSetName = '__xml')]
        [switch]$Rebuild,
        [Parameter(ParameterSetName = '__online')]
        [switch]$Online
    )

    #region Prepare environment
    # configure preferences
    if ($PSBoundParameters.Verbose) {$VerbosePreference = "continue"; $v = $true}
    if ($PSBoundParameters.Debug) {$DebugPreference = "continue"; $d = $true}
    
    # add DB file to exclusion list
    if (!$Online) {
        $XML = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($XML)
        $Exclude += $XML
    }
    
    # preserving current path
    if (!(Test-Path -LiteralPath (Resolve-Path $Path))) {
        throw "Specified directory path not found."
    }
    
    # creating statistics variable with properties. Each property will contain file names (and paths) with corresponding status.
    $script:stats = New-Object PsFCIV.Support.StatTable
    $script:statcount = New-Object PsFCIV.Support.IntStatTable

    # mode: New, Check, Rebuild, FCIV
    $mode = "Check"
    #endregion
    
    # internal function to calculate resulting statistics and show if if necessary.	
    function __showStats {
    # if -Show parameter is presented we display selected groups (Total, New, Ok, Bad, Missed, Unknown)
        if ($show) {
            if ($Show.Contains("All")) {
                $stats | __showGridView "Bad", "Locked", "Missed", "New", "Ok", "Unknown" $statcount.Total
            } else {
                $stats | Select-Object $show | __showGridView $show $statcount.Total
            }
        }
        # script work in numbers
        if ($v -or $d) {
            Write-Host ----------------------------------- -ForegroundColor Green
            if ($Rebuild) {
                Write-Host "Total entries processed      :" $statcount.Total -ForegroundColor Cyan
                Write-Host "Total removed unused entries :" $statcount.Deleted -ForegroundColor Yellow
                Write-Host "Total new added files        :" $statcount.New -ForegroundColor Green
                Write-Host "Total locked files           :" $statcount.Locked -ForegroundColor Yellow
            } else {
                Write-Host "Total files processed      :" $statcount.Total -ForegroundColor Cyan
                if (("New", "Rebuild") -contains $mode) {
                    Write-Host "Total new added files      :" $statcount.New -ForegroundColor Green
                }
                Write-Host "Total good files           :" $statcount.Ok -ForegroundColor Green
                Write-Host "Total bad files            :" $statcount.Bad -ForegroundColor Red
                Write-Host "Total unknown status files :" $statcount.Unknown -ForegroundColor Yellow
                Write-Host "Total missing files        :" $statcount.Missed -ForegroundColor Yellow
                Write-Host "Total locked files         :" $statcount.Locked -ForegroundColor Yellow
            }
            Write-Host ----------------------------------- -ForegroundColor Green
        }
        __finalize
        $statcount
    }
    
    # internal function to update statistic counters.
    function __addStatCounter ($filename, $status) {
        $script:statcount.$status++
        $script:statcount.Total++
        if ($Show -and ($Show.Contains($status) -or $Show.Contains("All"))) {
            $stats.$status.Add($filename)
        }
    }
    if ($Online) {
        Write-Debug "Online mode ON"
        dirx -Path (Join-Path $Path *) -Filter $Include -Exclude $Exclude $Recurse -Force | ForEach-Object {
            Write-Verbose "Perform file '$($_.fullName)' checking."
            $file = Get-Item -LiteralPath $_.FullName -Force -ErrorAction SilentlyContinue
            if (__testFileLock $file) {return}
            __newFileEntry $file -hex
        }
        return
    }

    <#
    in this part we perform XML file update by removing entries for non-exist files and
    adding new entries for files that are not in the database.
    #>
    if ($Rebuild) {
        Write-Debug "Rebuild mode ON"
        $mode = "Rebuild"
        if (Test-Path -LiteralPath $xml) {
            $old = __readXml $xml
        } else {
            __finalize $oldpath
            throw "Unable to find XML file. Please, run the command without '-Rebuild' switch."
        }
        $new = New-Object PsFCIV.Support.FcivRootNode
        $interm = New-Object PsFCIV.Support.FcivRootNode
        # use foreach-object instead of where-object to keep original types.
        Write-Verbose "Perform DB file cleanup from non-existent items."
        $old.Entries | ForEach-Object {
            if ((Test-Path -LiteralPath $_.Name)) {
                if ($_.Name -eq $xml) {
                    Write-Debug "File '$($_.Name)' is DB file. Removed."
                    $statcount.Deleted++
                } else {
                    [void]$interm.Entries.Add($_)
                }
            } else {
                Write-Debug "File '$($_.Name)' does not exist. Removed."
                $statcount.Deleted++
            }
        }
        
        $statcount.Total = $old.Entries.Count - $interm.Entries.Count
        dirx -Path (Join-Path $Path *) -Filter $Include -Exclude $Exclude $Recurse -Force | ForEach-Object {
            if ($_.FullName -eq $XML) {
                return
            }
            Write-Verbose "Perform file '$($_.FullName)' checking."
            $file = Get-Item -LiteralPath $_.FullName -Force
            if (__testFileLock $file) {return}
            $filename = $file.FullName -replace [regex]::Escape($($pwd.providerpath + "\"))
            if ($interm.Entries.Contains((New-Object PsFCIV.Support.FcivFileEntry $filename))) {
                Write-Verbose "File '$filename' already exist in XML database. Skipping."
                return
            } else {
                [void]$new.Entries.Add((__newFileEntry $file))
                Write-Verbose "File '$filename' is added."
                __addStatCounter $filename New
            }
        }
        $new.Entries | ForEach-Object {[void]$interm.Entries.Add($_)}
        __writeXml $interm
        __showStats
        return
    }
    
    # this part contains main routine
    $db = __readXml $xml
    # create flat list with indexer access. $db.Entries is of type of ISet<T> and doesn't have indexer
    $entries = $db.Entries | ForEach-Object {$_}
    <#
    check XML file format. If Timestamp property of the first element is null, then the file was generated by
    original FCIV.exe tool. In this case we transform existing XML to a new PsFCIV format by adding new
    properties. Each record is checked against hashes stored in the source XML file. If hash check fails,
    an item is removed from final XML.
    #>
    if ($entries.Count -gt 0 -and $entries[0].Size -eq 0) {
        if ($PSBoundParameters.ContainsKey("HashAlgorithm")) {
            $HashAlgorithm = $HashAlgorithm[0].ToUpper()
        } else {
            $HashAlgorithm = @()
        }
        Write-Debug "FCIV (compatibility) mode ON"
        $mode = "FCIV"
        if ($HashAlgorithm -and $HashAlgorithm -notcontains "sha1" -and $HashAlgorithm -notcontains "md5") {
            throw "Specified hash algorithm (or algorithms) is not supported. For native FCIV source, use MD5 and/or SHA1."
        }
        for ($index = 0; $index -lt $entries.Length; $index++) { # must be FOR loop, because indexer is used below
            $entry = $entries[$index]
            Write-Verbose "Perform file '$($entry.Name)' checking."
            $filename = $entry.Name
            # check if the path is absolute and matches current path. If the path is absolute and does not belong to
            # current path -- skip this entry.
            if ($filename.Contains(":") -and $filename -notmatch [regex]::Escape($pwd.ProviderPath)) {continue}
            # if source file name record contains absolute path, and belongs to the current pathe,
            # just strip base path. New XML format uses relative paths only.
            if ($filename.Contains(":")) {$filename = $filename -replace ([regex]::Escape($($pwd.ProviderPath + "\")))}
            # Test if the file exist. If the file does not exist, skip the current entry and process another record.
            if (!(Test-Path -LiteralPath $filename)) {
                Write-Verbose "File '$filename' not found. Skipping."
                __addStatCounter $filename Missed
                continue
            }
            # get file item and test if it is not locked by another application
            $file = Get-Item -LiteralPath $filename -Force -ErrorAction SilentlyContinue
            if (__testFileLock $file) {continue}
            # create new-style entry record that stores additional data: file length and last modification timestamp.
            $newentry = __newFileEntry $file -NoHash
            $newentry.Name = $filename
            # process current hash entries and copy required hash values to a new entry object.
            "SHA1", "MD5" | ForEach-Object {$newentry.$_ = $entry.$_}
            $entries[$index] = $newentry
            __checkfiles $newentry $file $Action $Strict
        }
        # clear DB entries and insert from backing collection. This step is necessary since ISet<T> doesn't have an
        # indexer and you cannot replace the item in set by index. Only remove->add is supported.
        $db.Entries.Clear()
        $entries | ForEach-Object {[void]$db.Entries.Add($_)}

        # we are done. Overwrite XML, display stats and exit.
        __writeXml $db
        # display statistics and exit right now.
        __showStats
    }
    # if XML file exist, proccess and check all records. XML file will not be modified.
    if ($entries.Count -gt 0) {
        Write-Debug "Native PsFCIV mode ON"
        $mode = "Check"
        # this part is executed only when we want to process certain file. Wildcards are not allowed.
        if ($Include -ne "*") {
            $db.Entries | Where-Object {$_.Name -like $Include} | ForEach-Object {
                Write-Verbose "Perform file '$($_.Name)' checking."
                $entry = $_
                # calculate the hash if the file exist.
                if (Test-Path -LiteralPath $entry.Name) {
                    # and check file integrity
                    $file = Get-Item -LiteralPath $entry.Name -Force -ErrorAction SilentlyContinue
                    __checkfiles $entry $file $Action $Strict
                } else {
                    # if there is no record for the file, skip it and display appropriate message
                    Write-Verbose "File '$filename' not found. Skipping."
                    __addStatCounter $entry.Name Missed
                }
            }
        } else {
            $db.Entries | ForEach-Object {
                <#
                to process files only in the current directory (without subfolders), we remove items
                that contain slashes from the process list and continue regular file checking.
                #>
                if (!$Recurse -and $_.Name -match "\\") {return}
                Write-Verbose "Perform file '$($_.Name)' checking."
                $entry = $_
                if (Test-Path -LiteralPath $entry.Name) {
                    $file = Get-Item -LiteralPath $entry.Name -Force -ErrorAction SilentlyContinue
                    __checkfiles $entry $file $Action $Strict
                } else {
                    Write-Verbose "File '$($entry.Name)' not found. Skipping."
                    __addStatCounter $entry.Name Missed
                }
            }
        }
    } else {
        # if there is no existing XML DB file, start from scratch and create a new one.
        Write-Debug "New XML mode ON"
        $mode = "New"
        dirx -Path (Join-Path $Path *) -Filter $Include -Exclude $Exclude $Recurse -Force | ForEach-Object {
             Write-Verbose "Perform file '$($_.fullName)' checking."
             $file = Get-Item -LiteralPath $_.FullName -Force -ErrorAction SilentlyContinue
             if (__testFileLock $file) {return}
             $entry = __newFileEntry $file
             [void]$db.Entries.Add($entry)
             __addStatCounter $entry.Name New
        }
        __writeXml $db
    }
    __showStats
}