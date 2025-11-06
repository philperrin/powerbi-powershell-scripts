#--------------------------------------------------------------------------------------------------
# Script created by Phil Perrin with much support from Captain Google.
# Last updated 5/25/25
# Version: 1.0
#
# Purpose:
# Query Power BI Service to extract information about the workspaces (groups) and reports in each.
# Does not include 'My Workspace'.
#
# Instructions:
# 1. Run PowerShell as admin.
# 2. First time use: Install the Power BI PowerShell cmdlets (Install-Module MicrosoftPowerBIMgmt)
#    https://docs.microsoft.com/en-us/powershell/power-bi/overview?view=powerbi-ps.
# 3. Adjust parameters as needed.
# 4. Run the script - user will be prompted for the Power BI account to use.
# 5. Optional: Give Phil some feedback on how to make this better.
#
#--------------------------------------------------------------------------------------------------

# Set the run directory for output files to the same as the script directory.
Set-Location -Path $PSScriptRoot

# Get the capacities
$capacities = Invoke-PowerBIRestMethod -Url 'capacities' -Method Get | ConvertFrom-Json
$capacities = foreach ($row in $capacities.value){
    [PSCustomObject] @{
    c_id = $row.id
    c_name = $row.displayName
    c_sku = $row.sku
    }
}
$capacities | Select-Object -Property c_id,c_name,c_sku | Export-Csv -Path ".\capacities.csv"  -NoTypeInformation -Force

# Get the gateways
$gateways.value = Invoke-PowerBIRestMethod -Url 'gateways' -Method Get | ConvertFrom-Json
$gateways = foreach ($row in $gateways.value){
    [PSCustomObject] @{
    g_id = $row.id
    g_name = $row.name
    }
}
$gateways | Select-Object -Property g_id,g_name | Export-Csv -Path ".\gateways.csv"  -NoTypeInformation -Force



# Parameters:
# Diagnostic mode: $false = deletes all temp files; $true = keeps all temp files. Default is $false.
$diagnostic = $false

# Create helper directories (directories and contents will be deleted if $diagnostic = FALSE):
New-Item -ItemType Directory -Path .\helpers -Force | Out-Null
New-Item -ItemType Directory -Path .\newjsons -Force | Out-Null
New-Item -ItemType Directory -Path .\reports -Force | Out-Null
New-Item -ItemType Directory -Path .\workspaces -Force | Out-Null

# References for files we will be using throughout the script.
$pbigroupsjson = ".\helpers\pbigroups.json"
$pbigroups2json = ".\helpers\pbigroups2.json"
$groupslist = ".\helpers\groups_list.csv"
$groupslistfinal = ".\helpers\groups_list_final.csv"
$workspacelist = ".\workspace_list.csv"
$workspacereports = ".\workspace_reports.csv"

# Connect to Power BI. User will be prompted to select the account to use.
Connect-PowerBIServiceAccount

# Create an object that stores all the group/workspace info.
$allGroups = Invoke-PowerBIRestMethod -Url 'groups' -Method Get

# Saves all the group/workspace info as a json.
Out-File -FilePath $pbigroupsjson -InputObject $allGroups

# Get the count of groups/workspaces (used in odata removal)
$jsonString = Get-Content -Path $pbigroupsjson -Raw | ConvertFrom-Json
$nworkspaces = $jsonString.'@odata.count'

# The json we just created is helpful - but let's remove the @odata info. And then export results to csv.
$pbistrip = " `"`@odata.context`":`"https://wabi-west-us-d-primary-redirect.analysis.windows.net/v1.0/myorg/`$metadata#groups`",`"`@odata.count`":$nworkspaces,`"value`":"
(Get-Content $pbigroupsjson).Replace($pbistrip, "") | Set-Content $pbigroups2json
(Get-Content $pbigroups2json).Substring(1) | Set-Content $pbigroups2json
$pbigroups = Get-Content -Path $pbigroups2json -Raw | ConvertFrom-Json
$pbigroups | Select-Object -Property id | Export-Csv -Path $groupslist -NoTypeInformation

# Create a full list of workspaces with names etc.
$pbigroups | Select-Object -Property id, isReadOnly, isOnDedicatedCapacity, capacityId, defaultDatasetStorageFormat, type, name | Export-Csv -Path $workspacelist -NoTypeInformation
Get-Content -Path $groupslist | Select-Object -Skip 1 |  Out-File -FilePath $groupslistfinal
# The last bit in here just makes a file that doesn't have a header and only has the workspace ids. That is all we need for the next steps.

# Import the workspace ids to iterate through
# Pro-Tip: create a subset list for troubleshooting.
$groups = Import-Csv $groupslistfinal -Header id

# Loop through each workspace id, call Power BI to get the report listing, and export the results from each to separate json files
foreach ($row in $groups) {
    $workspaceid = $row.id
    $groupUrl = "groups/$workspaceid/reports"
    $reports = Invoke-PowerBIRestMethod -Url $groupUrl -Method Get
    Out-File -FilePath .\workspaces\$workspaceid.json -InputObject $reports
}

# So now we have a folder full of json files. Let's go through each one, clean them a bit, and convert the json to csv. 
Get-ChildItem ".\workspaces" -Filter *.json | 
Foreach-Object {
    $jsonid = $_.BaseName
    $firststrip = "  `"`@odata.context`":`"https://wabi-west-us-d-primary-redirect.analysis.windows.net/v1.0/myorg/groups/$jsonid/`$metadata#reports`",`"value`":"
    (Get-Content .\workspaces\$jsonid.json).Replace($firststrip, "[") | Set-Content .\newjsons\$jsonid.json
    (Get-Content .\newjsons\$jsonid.json).Substring(1) | Set-Content .\newjsons\$jsonid.json
    $json = Get-Content -Path ".\newjsons\$jsonid.json" -Raw | ConvertFrom-Json
    $json | Select-Object -Property id, reportType, name, webUrl, embedUrl, isFromPbix, isOwnedByMe, datasetId, datasetWorkspaceId | Export-Csv -Path ".\reports\$jsonid.csv" -NoTypeInformation
}
# Watch for errors during the run! Some files might have something funky in there and you may need to manually re-run one.

# Append all the results into one csv. Also cleans up extra headers in the content.
Get-Content ".\reports\*.csv" | 
Add-Content $workspacereports
$cleanupreportfile = Import-Csv -Path $workspacereports
$filteredData = $cleanupreportfile | Where-Object { $_.id -ne "id" }
$filteredData | Export-Csv -Path $workspacereports -NoTypeInformation

# One last update to the reports file - let's extract the report workspace id into a separate column.
$addreportworkspace = Import-Csv -Path $workspacereports
foreach ($row in $addreportworkspace) {
    $row | Add-Member -MemberType NoteProperty -Name "report_workspace_id" -Value $row.webUrl.Substring(31,36) -Force
}
$addreportworkspace | Export-Csv -Path $workspacereports -NoTypeInformation


# If NOT in diagnostic mode then delete directories and contents: helpers, newjsons, reports, workspaces
if ($diagnostic) {
    Write-Host ">>> Diagnostic Mode: All files retained. You may want to clean these up manually before running again."
}
else {
    Remove-Item -Path ".\helpers" -Force -Recurse
    Remove-Item -Path ".\newjsons" -Force -Recurse
    Remove-Item -Path ".\reports" -Force -Recurse
    Remove-Item -Path ".\workspaces" -Force -Recurse
    Write-Host ">>> Script complete and support files removed. You should have 2 csv files with workspace and report info."
}