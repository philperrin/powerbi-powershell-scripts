#--------------------------------------------------------------------------------------------------
# Script created by Phil Perrin with much support from Captain Google.
# Last updated 6/3/25
# Version: 1.0
#
# Purpose:
# Query Power BI Service to extract the parameters from each dataset in workspaces.
# Does not include 'My Workspace'. Does not include Usage Metric reports.
#
# Instructions:
# 1. Run PowerShell as admin.
# 2. First time use: 
#    a. Install the Power BI PowerShell cmdlets (Install-Module MicrosoftPowerBIMgmt)
#       https://docs.microsoft.com/en-us/powershell/power-bi/overview?view=powerbi-ps.
# 3. Adjust parameters as needed.
# 4. Run the script - user will be prompted for the Power BI account to use.
# 5. Optional: Give Phil some feedback on how to make this better.
#
#--------------------------------------------------------------------------------------------------

# Connect to Power BI. User will be prompted to select the account to use.
Connect-PowerBIServiceAccount

# First, get workspaces and filter out so only prod
Write-Host "Gathering workspaces and filtering out dev/qa/pocs."
$allGroups = Invoke-PowerBIRestMethod -Url 'groups' -Method Get | ConvertFrom-Json

$w_data = foreach ($row in $allGroups.value){
    [PSCustomObject] @{
    w_id = $row.id
    w_name = $row.name
    }
}

Write-Host "Done!"

$w_datacount = $w_data.Count

# Now that we have the list of workspaces we need, let's get the datasets in each.
Write-Host "Getting datasets from each workspace ($w_datacount)."


$w_datasets = foreach ($row in $w_data){
    $g_id = $row.w_id
    $w_name = $row.w_name
    $w_result = Invoke-PowerBIRestMethod -Url "groups/$g_id/datasets" -Method Get | ConvertFrom-Json
    
    [PSCustomObject] @{
        w_id = $g_id
        w_name = $w_name
        d_value = $w_result.value
    }
}

# A bit of a mess, but with that data, let's convert the output into something usable - keeping the dataset, group id, name and if the dataset is refreshable.
$dataset_obj = foreach ($row in $w_datasets){
    $w_id = $row.w_id
    $w_name = $row.w_name
    $d_array = $row.d_value
    foreach($row2 in $d_array){
        $d_id = $row2.id
        $d_name = $row2.name
        $d_refresh = $row2.isRefreshable
            [PSCustomObject] @{
                w_id = $w_id
                w_name = $w_name
                d_id = $d_id
                d_name = $d_name
                d_refresh = $d_refresh
                }
            }
        }

Write-Host "Done!"

# Keep only the refreshable datasets
$dataset_obj2 = $dataset_obj | Where-Object { $_.isRefreshable -notlike "FALSE" }
$dataset_obj2 = $dataset_obj2 | Where-Object { $_.d_name -notlike "*usage metrics*"}


$ds_o2_count = $dataset_obj2.count

Write-Host "Getting parameter values info from each dataset ($ds_o2_count)."
Get-Date -Format "g"
# Using the dataset id and the group id, pull the parameters from each dataset.
$i=0
$param_values = foreach ($roww in $dataset_obj2) {
    $w_id = $roww.w_id
    $d_id = $roww.d_id
    $d_name = $roww.d_name
    $w_name = $roww.w_name

    $i++
    $percentComplete = ($i / $ds_o2_count) * 100
    Write-Progress -Activity "Processing Items" -Status "Item $i of $ds_o2_count" -PercentComplete $percentComplete
    $parameters = Invoke-PowerBIRestMethod -Url "groups/$w_id/datasets/$d_id/parameters" -Method Get | ConvertFrom-Json
    
    [PSCustomObject] @{
        d_id = $d_id
        w_id = $w_id
        d_name = $d_name
        w_name = $w_name
        p_value = $parameters.value
        }
}
Get-Date -Format "g"
Write-Host "Done!"


Write-Host "Let's put all the parameter details into their own columns."
$param_details = foreach($row in $param_values){
    $d_id = $row.d_id
    $w_id = $row.w_id
    $d_name = $row.d_name
    $w_name = $row.w_name

    foreach($inner in $row.p_value){
        $p_name = $inner.name
        $p_type = $inner.type
        $p_isRequired = $inner.isRequired
        $p_currentValue = $inner.currentValue

         [PSCustomObject] @{
            d_id = $d_id
            w_id = $w_id
            d_name = $d_name
            w_name = $w_name

            p_name = $p_name
            p_type = $p_type
            p_isRequired = $p_isRequired
            p_currentValue = $p_currentValue
            }
        }
    }

$result_count = $param_details.count
Write-Host "Done! Exporting results ($result_count)."

# Export results to file.
$param_details | Select-Object -Property w_id,w_name,d_id,d_name,p_name,p_type,p_isRequired,p_currentValue | Export-Csv -Path ".\dataset_parameters.csv"  -NoTypeInformation -Force

Write-Host "Output complete. Please find the file 'dataset_parameters.csv' in the local directory."