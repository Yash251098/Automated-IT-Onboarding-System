# Automated IT Onboarding System

> End-to-end PowerShell automation for employee onboarding using **Microsoft Graph API**, **Azure AD**, **Microsoft 365**, **Intune**, **Teams**, and **Exchange Online**.

---

## Overview

This project automates the full IT onboarding lifecycle for a new employee — from account creation to device enrollment to welcome email — using a single PowerShell script that orchestrates five modular steps via the Microsoft Graph API.

**Built by:** Yash Nitendra Panpatil  
**Skills demonstrated:** PowerShell scripting · Microsoft Graph API · Azure AD · Microsoft Intune · Microsoft 365 · Exchange Online · Microsoft Teams · SharePoint · ITIL · Conditional Access

---

## Architecture

```
┌──────────────────────────────────────────────────────────┐
│                      Input Sources                       │
│  CSV / HR System   ·   Manual Trigger   ·   Scheduler   │
└────────────────────────────┬─────────────────────────────┘
                             ▼
              ┌──────────────────────────┐
              │  Start-ITOnboarding.ps1  │  Master orchestrator
              │  (Microsoft Graph Auth)  │
              └──────┬───────────────────┘
                     │
        ┌────────────┴─────────────┐
        ▼                          ▼
 Identity & Device          Collaboration
 ──────────────────          ─────────────
 1. New-AADUser.ps1         4. Set-TeamsSharePoint.ps1
 2. Set-M365License.ps1     5. Send-WelcomeEmail.ps1
 3. Set-IntuneEnrollment.ps1
        │                          │
        └──────────────────────────┘
                     ▼
        Write-OnboardingLog.ps1
        (CSV audit log + console output)
```

---

## What Each Module Does

| # | Script | Action |
|---|--------|--------|
| 1 | `New-AADUser.ps1` | Creates Azure AD / Entra ID user with temporary password, sets manager |
| 2 | `Set-M365License.ps1` | Validates seat availability and assigns M365 license (e.g. E3) |
| 3 | `Set-IntuneEnrollment.ps1` | Assigns enrollment profile; adds user to device compliance group |
| 4 | `Set-TeamsSharePoint.ps1` | Adds to company Teams, department Teams, and SharePoint intranet |
| 5 | `Send-WelcomeEmail.ps1` | Sends branded HTML welcome email with credentials via Exchange Online |

---

## Prerequisites

### 1. PowerShell Modules

```powershell
# Install the Microsoft Graph SDK (required)
Install-Module Microsoft.Graph -Scope CurrentUser -Force

# Verify installation
Get-InstalledModule Microsoft.Graph
```

### 2. Azure App Registration

Create an App Registration in **Azure Portal → Entra ID → App registrations → New registration** with the following **Application** (not Delegated) permissions:

| Permission | Used for |
|------------|----------|
| `User.ReadWrite.All` | Create and update Azure AD users |
| `Directory.Read.All` | Read tenant and group information |
| `LicenseAssignment.ReadWrite.All` | Assign M365 licenses |
| `TeamMember.ReadWrite.All` | Add members to Teams |
| `Sites.FullControl.All` | Grant SharePoint access |
| `DeviceManagementServiceConfig.ReadWrite.All` | Assign Intune enrollment profiles |
| `GroupMember.ReadWrite.All` | Add users to compliance groups |
| `Mail.Send` | Send welcome email from admin mailbox |

After adding permissions, click **Grant admin consent**.

Generate a **Client Secret** under **Certificates & secrets** and copy the value.

### 3. config.json Setup

Copy the template and populate all values:

```json
{
  "TenantId"    : "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx",
  "ClientId"    : "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx",
  "ClientSecret": "your-client-secret-value",
  "Domain"      : "yourorg.onmicrosoft.com",
  "OrgName"     : "Contoso Ltd.",
  ...
}
```

> **Security tip:** In production, store `ClientSecret` in **Azure Key Vault** and retrieve it at runtime. Never commit secrets to source control.

---

## Project Structure

```
IT-Onboarding-System/
├── Start-ITOnboarding.ps1      # Master orchestrator
├── config.json                 # Tenant & app configuration
├── employees.csv               # Input data (sample)
├── Modules/
│   ├── Write-OnboardingLog.ps1
│   ├── New-AADUser.ps1
│   ├── Set-M365License.ps1
│   ├── Set-IntuneEnrollment.ps1
│   ├── Set-TeamsSharePoint.ps1
│   └── Send-WelcomeEmail.ps1
└── README.md
```

---

## Usage

### Bulk onboarding from CSV

```powershell
# employees.csv format:
# FirstName,LastName,Department,JobTitle,Manager,Location
.\Start-ITOnboarding.ps1 -CsvPath ".\employees.csv"
```

### Single user (ad-hoc)

```powershell
.\Start-ITOnboarding.ps1 `
    -FirstName  "John" `
    -LastName   "Doe" `
    -Department "Engineering" `
    -JobTitle   "Software Engineer" `
    -Manager    "Jane Smith" `
    -Location   "Pune"
```

### Automated via Windows Task Scheduler

```powershell
# Example command for Task Scheduler action:
powershell.exe -NonInteractive -ExecutionPolicy Bypass `
    -File "C:\Scripts\IT-Onboarding-System\Start-ITOnboarding.ps1" `
    -CsvPath "\\fileserver\HR\new_hires.csv"
```

---

## Sample Output

```
────────────────────────────────────────────────────────────
 Onboarding: John Doe  (john.doe@yourorg.onmicrosoft.com)
────────────────────────────────────────────────────────────

  Step 1 — Azure AD User Creation
   [SUCCESS]    Azure AD user created — Object ID: xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
   [SUCCESS]    Manager assigned (Jane Smith)

  Step 2 — M365 License Assignment
   [SUCCESS]    M365 license assigned — SKU: ENTERPRISEPACK | Remaining seats: 42

  Step 3 — Intune Device Enrollment
   [SUCCESS]    Intune enrollment profile assigned
   [SUCCESS]    Added to compliance policy group

  Step 4 — Teams & SharePoint Access
   [SUCCESS]    Added to default Teams team
   [SUCCESS]    Added to Engineering Teams team
   [SUCCESS]    SharePoint intranet access granted

  Step 5 — Welcome Email
   [SUCCESS]    Welcome email sent — From: it-admin@yourorg.com

════════════════════════════════════════════════════════════
 ONBOARDING COMPLETE
 Total processed : 1
 Successful      : 1
 Failed          : 0
 Log file        : C:\Logs\ITOnboarding\OnboardingLog_20250120_143022.csv
════════════════════════════════════════════════════════════
```

---

## Audit Log

Every action is appended to a timestamped CSV at the configured `LogPath`:

| Timestamp | User | Action | Status | Message |
|-----------|------|--------|--------|---------|
| 2025-01-20 14:30:22 | System | Graph API connected | SUCCESS | |
| 2025-01-20 14:30:25 | john.doe@... | Azure AD user created | SUCCESS | Object ID: xxx |
| 2025-01-20 14:30:28 | john.doe@... | M365 license assigned | SUCCESS | SKU: ENTERPRISEPACK |

---

## Security Considerations

- Store `ClientSecret` in Azure Key Vault in production.
- Use a dedicated service account / app registration with least-privilege permissions.
- Rotate the client secret every 90 days (align with your org's key rotation policy).
- The temporary password (`DefaultPassword`) should meet your org's password policy.
- All actions are logged for audit and compliance (aligns with ITIL change management).
- Conditional Access policies applied via Intune group membership from day one.

---

## Roadmap / Extensions

- [ ] Azure Key Vault integration for secret retrieval
- [ ] Slack / Teams notification to IT channel on completion
- [ ] Offboarding script (account disable, license revoke, group removal)
- [ ] Power BI dashboard linked to the audit log CSV
- [ ] Logic Apps trigger on HR system Webhook

---

## Certifications & Relevance

This project directly applies skills from:
- **AZ-204** — Microsoft Graph API, Azure identity, app registration
- **AZ-305** — Solution architecture, hybrid identity, security baselines
- **Capgemini experience** — Intune, Azure AD, M365 administration, ServiceNow, ITIL practices

---
