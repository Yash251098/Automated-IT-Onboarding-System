<#
.SYNOPSIS
    Module 1 — Create a new user in Azure Active Directory via Microsoft Graph.
.DESCRIPTION
    Uses the Microsoft.Graph PowerShell SDK to provision a new Azure AD / Entra ID
    user account with the supplied employee details.
    - Sets a temporary password (ForceChangePasswordNextSignIn = true)
    - Assigns UsageLocation from config (required before license assignment)
    - Checks for duplicate UPN before creation
    Graph API permissions required:
      User.ReadWrite.All
#>

function New-AADUser {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [PSCustomObject]$Employee,

        [Parameter(Mandatory)]
        [string]$UPN,

        [Parameter(Mandatory)]
        [PSCustomObject]$Config
    )

    Write-Host "`n  Step 1 — Azure AD User Creation" -ForegroundColor White

    # Check for existing user with same UPN
    try {
        $Existing = Get-MgUser -Filter "userPrincipalName eq '$UPN'" -ErrorAction SilentlyContinue
        if ($Existing) {
            Write-OnboardingLog -User $UPN -Action "Azure AD user already exists" -Status "WARNING" `
                -Message "Skipping creation; using existing account (Id: $($Existing.Id))"
            return $Existing
        }
    } catch {
        # Filter query failed — proceed with creation attempt
    }

    try {
        $PasswordProfile = @{
            Password                             = $Config.DefaultPassword
            ForceChangePasswordNextSignIn        = $true
            ForceChangePasswordNextSignInWithMfa = $false
        }

        $UserParams = @{
            DisplayName       = "$($Employee.FirstName) $($Employee.LastName)"
            GivenName         = $Employee.FirstName
            Surname           = $Employee.LastName
            UserPrincipalName = $UPN
            MailNickName      = "$($Employee.FirstName.ToLower()).$($Employee.LastName.ToLower())"
            Department        = $Employee.Department
            JobTitle          = if ($Employee.JobTitle) { $Employee.JobTitle } else { $null }
            OfficeLocation    = if ($Employee.Location)  { $Employee.Location  } else { $null }
            UsageLocation     = $Config.UsageLocation   # e.g. "IN" — required for license
            AccountEnabled    = $true
            PasswordProfile   = $PasswordProfile
        }

        $NewUser = New-MgUser @UserParams
        Write-OnboardingLog -User $UPN -Action "Azure AD user created" -Status "SUCCESS" `
            -Message "Object ID: $($NewUser.Id)"

        # Optionally set manager
        if ($Employee.Manager) {
            try {
                $ManagerObj = Get-MgUser -Filter "displayName eq '$($Employee.Manager)'" -Top 1
                if ($ManagerObj) {
                    $ManagerRef = @{ "@odata.id" = "https://graph.microsoft.com/v1.0/users/$($ManagerObj.Id)" }
                    Set-MgUserManagerByRef -UserId $NewUser.Id -BodyParameter $ManagerRef
                    Write-OnboardingLog -User $UPN -Action "Manager assigned ($($Employee.Manager))" -Status "SUCCESS"
                }
            } catch {
                Write-OnboardingLog -User $UPN -Action "Manager assignment skipped" -Status "WARNING" `
                    -Message $_.Exception.Message
            }
        }

        return $NewUser

    } catch {
        Write-OnboardingLog -User $UPN -Action "Azure AD user creation FAILED" -Status "ERROR" `
            -Message $_.Exception.Message
        return $null
    }
}
