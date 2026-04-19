<#
.SYNOPSIS
    Logging utility for the IT Onboarding automation system.
.DESCRIPTION
    Writes structured log entries to a CSV audit file and prints
    colour-coded output to the console. Called by every module.
#>

function Write-OnboardingLog {
    [CmdletBinding()]
    param(
        [string]$User    = "System",
        [string]$Action,
        [ValidateSet("SUCCESS", "ERROR", "WARNING", "INFO")]
        [string]$Status,
        [string]$Message = ""
    )

    $Entry = [PSCustomObject]@{
        Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        User      = $User
        Action    = $Action
        Status    = $Status
        Message   = $Message
    }

    # Append to the log file (set by the master script)
    if ($script:LogFile) {
        $Entry | Export-Csv -Path $script:LogFile -Append -NoTypeInformation -Encoding UTF8
    }

    # Console output with colour coding
    $Color = switch ($Status) {
        "SUCCESS" { "Green"  }
        "ERROR"   { "Red"    }
        "WARNING" { "Yellow" }
        default   { "Gray"   }
    }
    $Prefix = "   [$Status]".PadRight(12)
    Write-Host "$Prefix $Action$(if ($Message) { " — $Message" })" -ForegroundColor $Color
}
