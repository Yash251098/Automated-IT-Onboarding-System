<#
.SYNOPSIS
    Module 5 — Send a branded HTML welcome email to the new employee via Exchange Online.
.DESCRIPTION
    Uses the Microsoft Graph Mail API (Send-MgUserMail) to dispatch a welcome message
    from the configured admin mailbox to the new user's M365 mailbox.
    Note: The new user's mailbox is provisioned asynchronously after license assignment.
          A brief retry loop is included to wait for mailbox readiness.
    Graph API permissions required:
      Mail.Send (application permission on the admin sender account)
#>

function Send-WelcomeEmail {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$UPN,           # New user's email / UPN

        [Parameter(Mandatory)]
        [string]$FirstName,

        [Parameter(Mandatory)]
        [string]$TempPassword,

        [Parameter(Mandatory)]
        [PSCustomObject]$Config
    )

    Write-Host "`n  Step 5 — Welcome Email" -ForegroundColor White

    # Wait for Exchange mailbox to provision (up to 2 minutes)
    $MaxWait   = 120
    $Elapsed   = 0
    $Interval  = 20
    $Provisioned = $false

    Write-Host "     Waiting for Exchange mailbox to provision..." -ForegroundColor DarkGray
    while ($Elapsed -lt $MaxWait) {
        try {
            $Mailbox = Invoke-MgGraphRequest -Method GET `
                -Uri "https://graph.microsoft.com/v1.0/users/$UPN/mailboxSettings" `
                -ErrorAction SilentlyContinue
            if ($Mailbox) { $Provisioned = $true; break }
        } catch { }
        Start-Sleep -Seconds $Interval
        $Elapsed += $Interval
        Write-Host "     ...still waiting ($Elapsed s elapsed)" -ForegroundColor DarkGray
    }

    if (-not $Provisioned) {
        Write-OnboardingLog -User $UPN -Action "Welcome email skipped — mailbox not ready after ${MaxWait}s" `
            -Status "WARNING"
        return
    }

    try {
        $PortalUrl    = "https://myaccount.microsoft.com"
        $TeamsUrl     = "https://teams.microsoft.com"
        $IntranetUrl  = $Config.SharePointSiteUrl
        $SupportEmail = $Config.AdminEmail
        $OrgName      = $Config.OrgName

        $HtmlBody = @"
<!DOCTYPE html>
<html lang="en">
<head><meta charset="UTF-8"><style>
  body  { font-family: Segoe UI, Arial, sans-serif; background: #f4f4f4; margin:0; padding:0; }
  .wrap { max-width:600px; margin:30px auto; background:#fff; border-radius:8px;
          box-shadow:0 2px 8px rgba(0,0,0,.1); overflow:hidden; }
  .hdr  { background:#0078d4; color:#fff; padding:28px 32px; }
  .hdr h1 { margin:0; font-size:22px; font-weight:600; }
  .hdr p  { margin:6px 0 0; font-size:14px; opacity:.85; }
  .body { padding:28px 32px; color:#333; line-height:1.7; }
  .cred { background:#f0f7ff; border-left:4px solid #0078d4; border-radius:4px;
          padding:16px 20px; margin:20px 0; font-size:14px; }
  .cred strong { display:inline-block; width:160px; color:#555; }
  .btn  { display:inline-block; background:#0078d4; color:#fff; text-decoration:none;
          padding:10px 22px; border-radius:5px; font-size:14px; margin:4px 0; }
  .links { margin:20px 0; }
  .footer { background:#f9f9f9; border-top:1px solid #eee;
            padding:16px 32px; font-size:12px; color:#888; }
</style></head>
<body>
<div class="wrap">
  <div class="hdr">
    <h1>Welcome to $OrgName, $FirstName!</h1>
    <p>Your IT account is ready — here's everything you need to get started.</p>
  </div>
  <div class="body">
    <p>Hi <strong>$FirstName</strong>,</p>
    <p>Your Microsoft 365 account has been provisioned. Please find your login credentials below.
       <strong>You will be prompted to change your password on first sign-in.</strong></p>

    <div class="cred">
      <p><strong>Username (UPN):</strong> $UPN</p>
      <p><strong>Temporary Password:</strong> $TempPassword</p>
    </div>

    <p><strong>Quick links to get you started:</strong></p>
    <div class="links">
      <a class="btn" href="$PortalUrl">Set up my account</a>&nbsp;
      <a class="btn" href="$TeamsUrl">Open Microsoft Teams</a>&nbsp;
      <a class="btn" href="$IntranetUrl">Company Intranet</a>
    </div>

    <p style="margin-top:24px"><strong>Recommended first steps:</strong></p>
    <ol>
      <li>Sign in at <a href="$PortalUrl">myaccount.microsoft.com</a> and change your password.</li>
      <li>Set up Multi-Factor Authentication (MFA) — you will be prompted on first login.</li>
      <li>Install the Microsoft Authenticator app on your mobile device.</li>
      <li>Download and install Microsoft Teams and Outlook from the Company Portal.</li>
      <li>Enrol your device in Intune via the Company Portal app.</li>
    </ol>

    <p>If you have any questions or issues, please contact IT Support at
       <a href="mailto:$SupportEmail">$SupportEmail</a>.</p>

    <p>We're excited to have you on board!</p>
    <p>— IT Operations Team, $OrgName</p>
  </div>
  <div class="footer">
    This is an automated message from the IT Onboarding System.
    Please do not reply directly to this email.
  </div>
</div>
</body></html>
"@

        $MailMessage = @{
            message = @{
                subject      = "Welcome to $OrgName — Your IT Account is Ready"
                body         = @{
                    contentType = "HTML"
                    content     = $HtmlBody
                }
                toRecipients = @(@{
                    emailAddress = @{ address = $UPN }
                })
                ccRecipients = @(@{
                    emailAddress = @{ address = $Config.AdminEmail }
                })
            }
            saveToSentItems = $true
        }

        Send-MgUserMail -UserId $Config.AdminEmail -BodyParameter $MailMessage
        Write-OnboardingLog -User $UPN -Action "Welcome email sent" -Status "SUCCESS" `
            -Message "From: $($Config.AdminEmail)"

    } catch {
        Write-OnboardingLog -User $UPN -Action "Welcome email FAILED" -Status "ERROR" `
            -Message $_.Exception.Message
    }
}
