<#
.SYNOPSIS
    Module 2 — Assign Microsoft 365 license to a new user via Microsoft Graph.
.DESCRIPTION
    Resolves the configured SKU name to a SkuId, checks available seat count,
    and assigns the license to the user.
    Graph API permissions required:
      Directory.Read.All, User.ReadWrite.All
#>

function Set-M365License {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$UserId,

        [Parameter(Mandatory)]
        [string]$UPN,

        [Parameter(Mandatory)]
        [PSCustomObject]$Config
    )

    Write-Host "`n  Step 2 — M365 License Assignment" -ForegroundColor White

    try {
        # Resolve the friendly SKU name to the actual GUID
        $AllSkus   = Get-MgSubscribedSku
        $TargetSku = $AllSkus | Where-Object { $_.SkuPartNumber -eq $Config.DefaultLicenseSKU }

        if (-not $TargetSku) {
            $AvailableSkus = ($AllSkus | Select-Object -ExpandProperty SkuPartNumber) -join ", "
            throw "SKU '$($Config.DefaultLicenseSKU)' not found. Available SKUs: $AvailableSkus"
        }

        # Check available seats
        $Available = $TargetSku.PrepaidUnits.Enabled - $TargetSku.ConsumedUnits
        if ($Available -le 0) {
            Write-OnboardingLog -User $UPN -Action "License assignment skipped — no seats available" `
                -Status "WARNING" -Message "SKU: $($Config.DefaultLicenseSKU)"
            return
        }

        # Check if license already assigned
        $CurrentLicenses = Get-MgUserLicenseDetail -UserId $UserId
        if ($CurrentLicenses.SkuId -contains $TargetSku.SkuId) {
            Write-OnboardingLog -User $UPN -Action "License already assigned" -Status "WARNING" `
                -Message "SKU: $($Config.DefaultLicenseSKU)"
            return
        }

        # Assign the license
        Set-MgUserLicense -UserId $UserId `
            -AddLicenses @(@{ SkuId = $TargetSku.SkuId }) `
            -RemoveLicenses @()

        Write-OnboardingLog -User $UPN -Action "M365 license assigned" -Status "SUCCESS" `
            -Message "SKU: $($Config.DefaultLicenseSKU) | Remaining seats: $($Available - 1)"

        # Assign additional department-specific licenses if configured
        if ($Config.DepartmentLicenses) {
            # placeholder: extend Config.DepartmentLicenses with { "Engineering": "VISIO_PLAN2" } etc.
        }

    } catch {
        Write-OnboardingLog -User $UPN -Action "License assignment FAILED" -Status "ERROR" `
            -Message $_.Exception.Message
    }
}
