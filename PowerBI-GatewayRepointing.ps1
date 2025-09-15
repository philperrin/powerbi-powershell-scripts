#--------------------------------------------------------------------------------------------------
# Script created by Phil Perrin with much support from Captain Google.
# Last updated 8/26/25
# Version: 1.0
#
# Purpose:
# Retrieve the gateways and datasources used by datasets in 2 workspaces.
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

# Workspaces:
# Finance Ops Prod: 487658f8-e935-4ce0-bc0f-6ddf08c82b61
# Finance Shared Services: 2ac752e7-a51a-4475-98ce-5df3c6532727

# First, get workspaces and filter out so only prod
Write-Host "Gathering workspaces"
$allGroups = Invoke-PowerBIRestMethod -Url 'groups' -Method Get
$allGroups = $allGroups | ConvertFrom-Json

$allGroups = foreach($row in $allGroups.value){
    $g_id = $row.id
    $g_name = $row.name
    [PSCustomObject] @{
        g_id = $g_id
        g_name = $g_name
    }
}

$allGroups_2 = $allGroups | Where-Object {$_.g_id -eq "487658f8-e935-4ce0-bc0f-6ddf08c82b61" -or $_.g_id -eq "2ac752e7-a51a-4475-98ce-5df3c6532727"}

$w_datacount = $allGroups_2.Count

# Now that we have the list of workspaces we need, let's get the datasets in each.
Write-Host "Getting datasets from each workspace ($w_datacount)."
$w_datasets = foreach ($row in $allGroups_2){
    $g_id = $row.g_id
    $g_name = $row.g_name
    $d_result = Invoke-PowerBIRestMethod -Url "groups/$g_id/datasets" -Method Get | ConvertFrom-Json

    foreach ($inner in $d_result.value){
        $d_id = $inner.id
        $d_name = $inner.name

        [PSCustomObject] @{
            g_id = $g_id
            g_name = $g_name
            d_id = $d_id
            d_name = $d_name
            }
        }
}


$dataset_gateways = foreach ($row in $w_datasets){
    $g_id = $row.g_id
    $g_name = $row.g_name
    $d_id = $row.d_id
    $d_name = $row.d_name
    $d_result = Invoke-PowerBIRestMethod -Url "groups/$g_id/datasets/$d_id/datasources" -Method Get | ConvertFrom-Json

    foreach ($inner in $d_result.value){
        $gw_dstype = $inner.datasourceType
        $gw_dsid = $inner.datasourceId
        $gw_id = $inner.gatewayId
        $gw_result = $inner.connectionDetails

        foreach ($inner2 in $gw_result){
            $gwcd_path = $inner2.path
            $gwcd_kind = $inner2.kind
            $gwcd_url = $inner2.url


            [PSCustomObject] @{
                g_id = $g_id
                g_name = $g_name
                d_id = $d_id
                d_name = $d_name
                gw_id = $gw_id
                gw_dsid = $gw_dsid
                gw_dstype = $gw_dstype
                gwcd_path = $gwcd_path
                gwcd_kind = $gwcd_kind
                gwcd_url = $gwcd_url
            }
        }
    }
}


$gw_lookup = Invoke-PowerBIRestMethod -Url "gateways" -Method Get | ConvertFrom-Json
$gw_details = foreach($row in $gw_lookup.value){
    $gw_id = $row.id
    $gw_name = $row.name

    [PSCustomObject] @{
        gw_id = $gw_id
        gw_name = $gw_name
    }
}

$dataset_gateway_info = Join-Object -Left $dataset_gateways -Right $gw_details -LeftJoinProperty gw_id -RightJoinProperty gw_id -Type AllInLeft

$unique_gwid = $dataset_gateway_info.gw_id | Select-Object -Unique

$ds_info = foreach($row in $unique_gwid){
    $url = "gateways/$row/datasources"
    $gwds_lookup = Invoke-PowerBIRestMethod -URL $url -Method Get | ConvertFrom-Json

    foreach($inner in $gwds_lookup.value){
        $gwds_id = $inner.id
        $gwds_name = $inner.datasourceName
    
        [PSCustomObject] @{
            gwds_id = $gwds_id
            gwds_name = $gwds_name
        }
    }
}

$dataset_gateway_info2 = Join-Object -Left $dataset_gateway_info -Right $ds_info -LeftJoinProperty gw_dsid -RightJoinProperty gwds_id -Type AllInLeft

$dataset_gateway_info2 | Select-Object -Property g_id,g_name,d_id,d_name,gw_id,gw_name,gw_dsid,gwds_name,gw_dstype,gwcd_path,gwcd_kind,gwcd_url | Export-Csv -Path ".\dataset_gateway_info.csv"  -NoTypeInformation -Force

