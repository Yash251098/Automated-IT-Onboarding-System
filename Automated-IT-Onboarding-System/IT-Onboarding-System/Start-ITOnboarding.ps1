<#
.SYNOPSIS
    Automated IT Onboarding System — Master Orchestrator
.DESCRIPTION
    Reads employee data from a CSV file or accepts individual user parameters,
    then sequentially calls all onboarding modules:
      1. Azure AD user creation
      2. M365 license assignment
      3. Intune device enrollment profile
      4. Teams & SharePoint access
      5. Welcome email via Exchange Online
    All actions are logged to a timestamped CSV audit file.
.PARAMETER CsvPath
    Path to the employee CSV file (default: .\employees.csv)
.PARAMETER FirstName
    First name for single-user mode
.PARAMETER LastName
    Last name for single-user mode
.PARAMETER Department
    Department for single-user mode
.PARAMETER JobTitle
    Job title for single-user mode (optional)
.PARAMETER Manager
    Manager display name for single-user mode (optional)
.PARAMETER Location
    Office location for single-user mode (optional)
.EXAMPLE
    # Bulk onboarding from CSV
    .\Start-ITOnboarding.ps1 -CsvPath ".\employees.csv"
.EXAMPLE
    # Single user onboarding
    .\Start-ITOnboarding.ps1 -FirstName "John" -LastName "Doe" -Department "Engineering" -JobTitle "Software Engineer"
.NOTES
    Prerequisites:
      - Microsoft.Graph PowerShell SDK (Install-Module Microsoft.Graph)
      - App registration with appropriate Graph API permissions
      - Populated config.json in the same directory
    Author : Yash Nitendra Panpatil
    Project: Automated IT Onboarding System
#>

[CmdletBinding(DefaultParameterSetName = 'CSV')]
param(
    [Parameter(ParameterSetName = 'CSV')]
    [string]$CsvPath = ".\employees.csv",

    [Parameter(ParameterSetName = 'Single', Mandatory)]
    [string]$FirstName,

    [Parameter(ParameterSetName = 'Single', Mandatory)]
    [string]$LastName,

    [Parameter(ParameterSetName = 'Single', Mandatory)]
    [string]$Department,

    [Parameter(ParameterSetName = 'Single')]
    [string]$JobTitle = "",

    [Parameter(ParameterSetName = 'Single')]
    [string]$Manager = "",

    [Parameter(ParameterSetName = 'Single')]
    [string]$Location = ""
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# ── Load configuration ────────────────────────────────────────────────────────
$ConfigPath = Join-Path $PSScriptRoot "config.json"
if (-not (Test-Path $ConfigPath)) {
    throw "config.json not found at $ConfigPath. Please create it from the template."
}
$Config = Get-Content $ConfigPath -Raw | ConvertFrom-Json

# ── Dot-source module functions ───────────────────────────────────────────────
$ModulesPath = Join-Path $PSScriptRoot "Modules"
@(
    "Write-OnboardingLog.ps1",
    "New-AADUser.ps1",
    "Set-M365License.ps1",
    "Set-IntuneEnrollment.ps1",
    "Set-TeamsSharePoint.ps1",
    "Send-WelcomeEmail.ps1"
) | ForEach-Object { . (Join-Path $ModulesPath $_) }

# ── Initialise log file ───────────────────────────────────────────────────────
if (-not (Test-Path $Config.LogPath)) {
    New-Item -ItemType Directory -Path $Config.LogPath -Force | Out-Null
}
$script:LogFile = Join-Path $Config.LogPath "OnboardingLog_$(Get-Date -Format 'yyyyMMdd_HHmmss').csv"
Write-OnboardingLog -User "System" -Action "Onboarding script started" -Status "INFO"

# ── Connect to Microsoft Graph ────────────────────────────────────────────────
Write-Host "`nConnecting to Microsoft Graph..." -ForegroundColor Cyan
try {
    $ClientSecret = ConvertTo-SecureString $Config.ClientSecret -AsPlainText -Force
    $Credential   = New-Object System.Management.Automation.PSCredential($Config.ClientId, $ClientSecret)
    Connect-MgGraph -TenantId $Config.TenantId `
                    -ClientSecretCredential $Credential `
                    -NoWelcome | Out-Null
    Write-OnboardingLog -User "System" -Action "Microsoft Graph connected" -Status "SUCCESS"
} catch {
    Write-OnboardingLog -User "System" -Action "Graph connection failed" -Status "ERROR" -Message $_.Exception.Message
    throw "Cannot connect to Microsoft Graph: $($_.Exception.Message)"
}

# ── Build the employee list ───────────────────────────────────────────────────
$Employees = if ($PSCmdlet.ParameterSetName -eq 'CSV') {
    if (-not (Test-Path $CsvPath)) { throw "CSV file not found: $CsvPath" }
    Import-Csv -Path $CsvPath
} else {
    @([PSCustomObject]@{
        FirstName  = $FirstName
        LastName   = $LastName
        Department = $Department
        JobTitle   = $JobTitle
        Manager    = $Manager
        Location   = $Location
    })
}

$TotalUsers  = ($Employees | Measure-Object).Count
$SuccessCount = 0
$FailCount   = 0

# ── Process each employee ─────────────────────────────────────────────────────
foreach ($Employee in $Employees) {
    $UPN = "$($Employee.FirstName.ToLower()).$($Employee.LastName.ToLower())@$($Config.Domain)"
    Write-Host "`n$('─' * 60)" -ForegroundColor DarkGray
    Write-Host " Onboarding: $($Employee.FirstName) $($Employee.LastName)  ($UPN)" -ForegroundColor Cyan
    Write-Host "$('─' * 60)" -ForegroundColor DarkGray

    # Step 1 — Create Azure AD user
    $NewUser = New-AADUser -Employee $Employee -UPN $UPN -Config $Config

    if ($null -eq $NewUser) {
        Write-Host " [SKIP] Skipping remaining steps for $UPN due to user creation failure." -ForegroundColor Yellow
        $FailCount++
        continue
    }

    # Step 2 — Assign M365 license
    Set-M365License -UserId $NewUser.Id -UPN $UPN -Config $Config

    # Step 3 — Configure Intune enrollment
    Set-IntuneEnrollment -UserId $NewUser.Id -UPN $UPN -Config $Config

    # Step 4 — Add to Teams & SharePoint
    Set-TeamsSharePoint -UserId $NewUser.Id -UPN $UPN -Department $Employee.Department -Config $Config

    # Step 5 — Send welcome email
    Send-WelcomeEmail -UPN $UPN -FirstName $Employee.FirstName -TempPassword $Config.DefaultPassword -Config $Config

    $SuccessCount++
}

# ── Summary ───────────────────────────────────────────────────────────────────
Disconnect-MgGraph | Out-Null

Write-Host "`n$('=' * 60)" -ForegroundColor DarkGray
Write-Host " ONBOARDING COMPLETE" -ForegroundColor Green
Write-Host " Total processed : $TotalUsers" -ForegroundColor White
Write-Host " Successful      : $SuccessCount" -ForegroundColor Green
Write-Host " Failed          : $FailCount" -ForegroundColor $(if ($FailCount -gt 0) { "Red" } else { "Green" })
Write-Host " Log file        : $script:LogFile" -ForegroundColor White
Write-Host "$('=' * 60)" -ForegroundColor DarkGray

Write-OnboardingLog -User "System" -Action "Onboarding script finished" -Status "INFO" `
    -Message "Total=$TotalUsers Success=$SuccessCount Failed=$FailCount"
