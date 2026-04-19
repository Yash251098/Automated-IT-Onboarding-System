<#
.SYNOPSIS
    Module 4 — Add new user to Microsoft Teams teams and grant SharePoint access.
.DESCRIPTION
    1. Adds the user as a member to the company-wide default Teams team.
    2. Adds the user to a department-specific Teams team (if mapped in config).
    3. Grants read access to the configured SharePoint intranet site.
    Graph API permissions required:
      TeamMember.ReadWrite.All
      Sites.FullControl.All (or SharePoint admin for site permissions)
#>

function Set-TeamsSharePoint {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$UserId,

        [Parameter(Mandatory)]
        [string]$UPN,

        [Parameter(Mandatory)]
        [string]$Department,

        [Parameter(Mandatory)]
        [PSCustomObject]$Config
    )

    Write-Host "`n  Step 4 — Teams & SharePoint Access" -ForegroundColor White

    # ── 4a. Add to company-wide Teams team ───────────────────────────────────
    if ($Config.DefaultTeamsTeamId) {
        try {
            # Check existing membership to avoid duplicate error
            $ExistingMembers = Get-MgTeamMember -TeamId $Config.DefaultTeamsTeamId -All
            $AlreadyMember   = $ExistingMembers | Where-Object { $_.AdditionalProperties.userId -eq $UserId }

            if ($AlreadyMember) {
                Write-OnboardingLog -User $UPN -Action "Already a member of default Teams team" -Status "WARNING"
            } else {
                $MemberBody = @{
                    "@odata.type"     = "#microsoft.graph.aadUserConversationMember"
                    roles             = @()
                    "user@odata.bind" = "https://graph.microsoft.com/v1.0/users('$UserId')"
                }
                New-MgTeamMember -TeamId $Config.DefaultTeamsTeamId -BodyParameter $MemberBody
                Write-OnboardingLog -User $UPN -Action "Added to default Teams team" -Status "SUCCESS"
            }
        } catch {
            Write-OnboardingLog -User $UPN -Action "Default Teams team membership FAILED" `
                -Status "ERROR" -Message $_.Exception.Message
        }
    }

    # ── 4b. Add to department-specific Teams team ─────────────────────────────
    if ($Config.DepartmentTeams -and $Config.DepartmentTeams.$Department) {
        $DeptTeamId = $Config.DepartmentTeams.$Department
        try {
            $MemberBody = @{
                "@odata.type"     = "#microsoft.graph.aadUserConversationMember"
                roles             = @()
                "user@odata.bind" = "https://graph.microsoft.com/v1.0/users('$UserId')"
            }
            New-MgTeamMember -TeamId $DeptTeamId -BodyParameter $MemberBody
            Write-OnboardingLog -User $UPN -Action "Added to $Department Teams team" -Status "SUCCESS" `
                -Message "Team ID: $DeptTeamId"
        } catch {
            Write-OnboardingLog -User $UPN -Action "$Department Teams team membership FAILED" `
                -Status "WARNING" -Message $_.Exception.Message
        }
    } else {
        Write-OnboardingLog -User $UPN -Action "Department Teams team skipped" -Status "INFO" `
            -Message "No team mapped for department: $Department"
    }

    # ── 4c. Grant SharePoint site access ─────────────────────────────────────
    if ($Config.SharePointSiteId) {
        try {
            $PermissionBody = @{
                roles             = @("read")
                grantedToIdentities = @(
                    @{
                        user = @{
                            id    = $UserId
                            displayName = $UPN
                        }
                    }
                )
            }
            $SpUri = "https://graph.microsoft.com/v1.0/sites/$($Config.SharePointSiteId)/permissions"
            Invoke-MgGraphRequest -Method POST -Uri $SpUri `
                -Body ($PermissionBody | ConvertTo-Json -Depth 6) `
                -ContentType "application/json"

            Write-OnboardingLog -User $UPN -Action "SharePoint intranet access granted" -Status "SUCCESS" `
                -Message "Site: $($Config.SharePointSiteUrl)"
        } catch {
            Write-OnboardingLog -User $UPN -Action "SharePoint access FAILED" -Status "ERROR" `
                -Message $_.Exception.Message
        }
    } else {
        Write-OnboardingLog -User $UPN -Action "SharePoint access skipped" -Status "WARNING" `
            -Message "SharePointSiteId not set in config.json"
    }
}
