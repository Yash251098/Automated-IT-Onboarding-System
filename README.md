HOW TO RUN:
The project has a clean folder structure — Start-ITOnboarding.ps1 is the single entry point that orchestrates everything. The Modules/ folder contains one self-contained function per step. Every module logs its own success/failure to a timestamped CSV audit trail automatically.
To get this running in your lab/environment:

Install the SDK: Install-Module Microsoft.Graph
Create an App Registration in Azure Portal with the Graph API permissions listed in the README
Fill in config.json with your Tenant ID, Client ID, Client Secret, and Team/Site IDs
Run: .\Start-ITOnboarding.ps1 -CsvPath ".\employees.csv"
