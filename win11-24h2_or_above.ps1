# Finding_java_no_wmic.ps1
# PowerShell-native rewrite of the Java finder (no WMIC)
# Tested on Windows 11 (including 24H2) with Windows PowerShell 5.1 and PowerShell 7+
# v1 RTichard wadsworth

$ErrorActionPreference = 'SilentlyContinue'
$scriptver = '3.3-ps-no-wmic'

function Test-IsAdmin {
    $wi = [Security.Principal.WindowsIdentity]::GetCurrent()
    $wp = New-Object Security.Principal.WindowsPrincipal $wi
    return $wp.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Get-DateStamp {
    Get-Date -Format 'yyyyMMdd-HHmm'
}

function Read-BMN {
    while ($true) {
        $bmn = Read-Host 'Please enter the BMN number as a numerical number only e.g. 1234'
        if ($bmn -match '^\d+$') { return $bmn }
        Write-Host 'Not a valid number. Please try again.' -ForegroundColor Yellow
    }
}

function Read-Classification {
    Write-Host 'Set Data classification. Valid entries: O, OS, S, SUKEO, OCCAR-R, C1, C2, C3, C4'
    while ($true) {
        $in = (Read-Host 'Please set the classification of Data?').Trim().ToUpperInvariant()
        switch ($in) {
            'O'       { return @{ Code='O';       Label='OFFICIAL';                                   Color='White' } }
            'OS'      { return @{ Code='OS';      Label='OFFICIAL SENSITIVE';                         Color='White' } }
            'S'       { return @{ Code='S';       Label='SECRET';                                     Color='Red'   } }
            'SUKEO'   { return @{ Code='SUKEO';   Label='SUKEO';                                      Color='Red'   } }
            'OCCAR-R' { return @{ Code='OCCAR-R'; Label='OCCAR-R';                                   Color='White' } }
            'C1'      { return @{ Code='C1';      Label='C1:GROUP INTERNAL';                          Color='White' } }
            'C2'      { return @{ Code='C2';      Label='C2:GROUP LIMITED DISTRIBUTION';              Color='White' } }
            'C3'      { return @{ Code='C3';      Label='C3:GROUP CONFIDENTIAL- SENSITIVE INFORMATION'; Color='White' } }
            'C4'      { return @{ Code='C4';      Label='C4:GROUP SECRET- EXTREMELY SENSITIVE INFORMATION'; Color='White' } }
            default   { Write-Host 'Not a valid answer. Please try again.' -ForegroundColor Yellow }
        }
    }
}

function Write-Header {
    Write-Host ('*' * 102)
    Write-Host 'Only report Javas that have been flagged as a "WARNING"'
    Write-Host ('*' * 102)
}

function Get-FixedDrives {
    # Enumerate only fixed (local) drives
    [System.IO.DriveInfo]::GetDrives() | Where-Object { $_.DriveType -eq 'Fixed' -and $_.IsReady } | ForEach-Object { $_.RootDirectory.FullName }
}

function Get-JavaFilesOnDrive {
    param([string]$Root)
    # Search for java.exe and javaw.exe; suppress access denied, hidden/system included
    Get-ChildItem -Path $Root -Recurse -File -Include 'java.exe','javaw.exe' -ErrorAction SilentlyContinue -Force
}

function Parse-JavaVersion {
    param([string]$fileVersion)

    # Normalise: replace underscores with dots, split, then take first three numeric-ish segments
    $norm = $fileVersion -replace '_','.'
    $parts = ($norm -split '[^\d]+' | Where-Object { $_ -ne '' })[0..2] 2>$null
    $major = if ($parts.Count -ge 1) { [int]$parts[0] } else { 0 }
    $minor = if ($parts.Count -ge 2) { [int]$parts[1] } else { 0 }
    $patch = if ($parts.Count -ge 3) { [int]$parts[2] } else { 0 }

    # Reporting string (Java 8 uses  x.y u z ; Java 9+ uses x.y.z)
    $display = if ($major -lt 9) { "{0}.{1} u{2}" -f $major,$minor,$patch } else { "{0}.{1}.{2}" -f $major,$minor,$patch }
    [PSCustomObject]@{
        Major   = $major
        Minor   = $minor
        Patch   = $patch
        Display = $display
    }
}

function Scan-And-Report {
    param(
        [string]$ResultsPath
    )

    $drives = Get-FixedDrives
    foreach ($d in $drives) {
        Write-Host "Searching in $d"
        foreach ($f in Get-JavaFilesOnDrive -Root $d) {
            try {
                $vi = (Get-Item -LiteralPath $f.FullName).VersionInfo
                $supplier = $vi.CompanyName
                $filever  = $vi.FileVersion

                Add-Content -Path $ResultsPath -Value ("Found: {0}" -f $f.FullName)
                Write-Host   ("Found: {0}" -f $f.FullName)

                if ($supplier) {
                    Add-Content -Path $ResultsPath -Value ("Supplier: {0}" -f $supplier)
                    Write-Host   ("Supplier: {0}" -f $supplier)
                }
                if ($filever) {
                    Add-Content -Path $ResultsPath -Value ("Original Version: {0}" -f $filever)
                    Write-Host   ("Original Version: {0}" -f $filever)
                    $pv = Parse-JavaVersion -fileVersion $filever
                    Add-Content -Path $ResultsPath -Value ("Java Version: {0}" -f $pv.Display)
                    Add-Content -Path $ResultsPath -Value ('*' * 111)
                    Add-Content -Path $ResultsPath -Value ("For reporting use the supplier name and this Java Version: {0}" -f $pv.Display)
                    Add-Content -Path $ResultsPath -Value ('*' * 111)

                    Write-Host ('*' * 111)
                    Write-Host ("For reporting use the Supplier name and this Java Version {0}" -f $pv.Display)
                    Write-Host ('*' * 111)
                }

                # Warnings for Oracle / Sun
                if ($supplier -match 'Oracle Corporation|Oracle') {
                    $msg = "WARNING: Oracle Java found: $($f.FullName)"
                    Add-Content -Path $ResultsPath -Value $msg
                    Write-Host $msg -ForegroundColor Yellow
                }
                if ($supplier -match 'Sun Microsystems') {
                    $msg = "WARNING: Sun Java found: $($f.FullName)"
                    Add-Content -Path $ResultsPath -Value $msg
                    Write-Host $msg -ForegroundColor Yellow
                }
            } catch {
                # swallow individual file errors
                continue
            }
        }
    }
}

# --------------------------- Main ---------------------------

do {
    Clear-Host
    Write-Header

    $isAdmin = Test-IsAdmin
    if ($isAdmin) {
        Write-Host 'User is running as administrator.'
    } else {
        Write-Host 'WARNING: NOT running as administrator. To avoid permission denied errors, quit and run as admin.' -ForegroundColor Yellow
    }

    $bmn = Read-BMN
    $cls = Read-Classification

    $datestamp = Get-DateStamp
    $resultsFile = "BMN{0}-{1}-{2}-{3}.txt" -f $bmn, $env:COMPUTERNAME, $datestamp, $cls.Code
    $resultsPath = Join-Path -Path (Get-Location) -ChildPath $resultsFile

    # Header to file
    Add-Content -Path $resultsPath -Value ("***** Data classification set to {0} *****" -f $cls.Label)
    Add-Content -Path $resultsPath -Value ("Hostname: {0}" -f $env:COMPUTERNAME)
    Add-Content -Path $resultsPath -Value ("BMN Number: BMN{0}" -f $bmn)
    Add-Content -Path $resultsPath -Value ("Did the user set admin? {0}" -f ($(if ($isAdmin) {'Yes'} else {'No'})))
    Add-Content -Path $resultsPath -Value ("Script version {0}" -f $scriptver)

    Write-Host ('***** Data classification set to {0} *****' -f $cls.Label) -ForegroundColor $cls.Color
    Write-Host '"Script message ***** Running java env check *****"'
    Write-Host '***** java env check *****'

    if ($env:JAVA_HOME) {
        Add-Content -Path $resultsPath -Value 'Running java -version'
        try {
            & (Join-Path $env:JAVA_HOME 'bin\java.exe') -version *>> $resultsPath
        } catch {
            Add-Content -Path $resultsPath -Value ('JAVA_HOME present but java -version failed: {0}' -f $_.Exception.Message)
        }
    } else {
        Add-Content -Path $resultsPath -Value 'JAVA_HOME is not set'
    }

    # Scan all fixed drives
    Scan-And-Report -ResultsPath $resultsPath

    Write-Host ("Search complete. Results saved to {0}" -f $resultsPath) -ForegroundColor Green
    $again = Read-Host 'Do you want to rerun the script? (yes/no)'
} while ($again -match '^(y|yes)$')

