<#
.SYNOPSIS
    Module 3 — Assign Intune device enrollment profile and compliance group.
.DESCRIPTION
    Assigns the configured Windows Autopilot / enrollment profile to the new user
    and adds them to the device compliance security group so Intune conditional
    access and compliance policies apply from day one.
    Graph API permissions required:
      DeviceManagementServiceConfig.ReadWrite.All
      GroupMember.ReadWrite.All
#>

function Set-IntuneEnrollment {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$UserId,

        [Parameter(Mandatory)]
        [string]$UPN,

        [Parameter(Mandatory)]
        [PSCustomObject]$Config
    )

    Write-Host "`n  Step 3 — Intune Device Enrollment" -ForegroundColor White

    # ── 3a. Assign enrollment configuration profile ───────────────────────────
    try {
        if ($Config.IntuneEnrollmentProfileId) {
            $AssignBody = @{
                enrollmentConfigurationAssignments = @(
                    @{
                        target = @{
                            "@odata.type" = "#microsoft.graph.userTarget"
                            userId        = $UserId
                        }
                    }
                )
            }
            $Uri = "https://graph.microsoft.com/v1.0/deviceManagement/deviceEnrollmentConfigurations/" +
                   "$($Config.IntuneEnrollmentProfileId)/assign"

            Invoke-MgGraphRequest -Method POST -Uri $Uri `
                -Body ($AssignBody | ConvertTo-Json -Depth 6) `
                -ContentType "application/json"

            Write-OnboardingLog -User $UPN -Action "Intune enrollment profile assigned" -Status "SUCCESS" `
                -Message "Profile ID: $($Config.IntuneEnrollmentProfileId)"
        } else {
            Write-OnboardingLog -User $UPN -Action "Intune enrollment profile skipped" -Status "WARNING" `
                -Message "IntuneEnrollmentProfileId not set in config.json"
        }
    } catch {
        Write-OnboardingLog -User $UPN -Action "Intune enrollment profile assignment FAILED" `
            -Status "ERROR" -Message $_.Exception.Message
    }

    # ── 3b. Add user to device compliance security group ─────────────────────
    try {
        if ($Config.CompliancePolicyGroupId) {
            # Check if already a member
            $Members = Get-MgGroupMember -GroupId $Config.CompliancePolicyGroupId -All
            if ($Members.Id -contains $UserId) {
                Write-OnboardingLog -User $UPN -Action "Already in compliance group" -Status "WARNING"
            } else {
                New-MgGroupMember -GroupId $Config.CompliancePolicyGroupId `
                    -DirectoryObjectId $UserId
                Write-OnboardingLog -User $UPN -Action "Added to compliance policy group" -Status "SUCCESS" `
                    -Message "Group ID: $($Config.CompliancePolicyGroupId)"
            }
        } else {
            Write-OnboardingLog -User $UPN -Action "Compliance group assignment skipped" -Status "WARNING" `
                -Message "CompliancePolicyGroupId not set in config.json"
        }
    } catch {
        Write-OnboardingLog -User $UPN -Action "Compliance group membership FAILED" -Status "ERROR" `
            -Message $_.Exception.Message
    }

    # ── 3c. Apply device configuration profile (optional) ────────────────────
    # Extend here to push specific device config profiles (BitLocker, Windows Hello, etc.)
    # using: deviceManagement/deviceConfigurations/{id}/assign
}
