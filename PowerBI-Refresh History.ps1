Set-Location -Path $PSScriptRoot

Connect-PowerBIServiceAccount

Write-Host "Gathering workspaces"
$allGroups = Invoke-PowerBIRestMethod -Url 'groups' -Method Get
$allGroups = $allGroups | ConvertFrom-Json

$w_data = foreach ($row in $allGroups.value){
    [PSCustomObject] @{
    w_id = $row.id
    w_name = $row.name
    }
}

$w_datacount = $w_data.Count

Write-Host "Getting datasets from each workspace ($w_datacount)."
$w_datasets = foreach ($row in $w_data){
    $g_id = $row.w_id
    $w_name = $row.w_name
    $w_result = Invoke-PowerBIRestMethod -Url "groups/$g_id/datasets" -Method Get | ConvertFrom-Json
    
    [PSCustomObject] @{
        ws_id = $g_id
        ws_name = $w_name
        d_value = $w_result.value
    }
}

$dataset_obj = foreach($row in $w_datasets){
    $ws_id = $row.ws_id
    $ws_name = $row.ws_name
    foreach($row2 in $row.d_value){
        $ds_id = $row2.id
        $ds_name = $row2.name
        $ds_url = $row2.WebUrl
        $ds_cfg = $row2.configuredBy

        [PSCustomObject] @{
            ws_id = $ws_id
            ws_name = $ws_name
            ds_id = $ds_id
            ds_name = $ds_name
            ds_url = $ds_url
            ds_cfg = $ds_cfg
            }
        }
    }


$dataset_rh = foreach($row in $dataset_obj){
    $g_id = $row.ws_id
    $d_id = $row.ds_id
    $g_name = $row.ws_name
    $d_name = $row.ds_name
    $url = "groups/$g_id/datasets/$d_id/refreshes"
    $ind_rh = Invoke-PowerBIRestMethod -Url $url -Method Get | ConvertFrom-Json

    [PSCustomObject] @{
        g_id = $g_id
        d_id = $d_id
        g_name = $g_name
        d_name = $d_name
        ind_rh = $ind_rh.value
    }
}

$dataset_rh_out = foreach($row in $dataset_rh){
    $g_id = $row.g_id
    $d_id = $row.d_id
    $g_name = $row.g_name
    $d_name = $row.d_name

    foreach($inner in $row.ind_rh){
        $r_req_id = $inner.requestId
        $r_id = $inner.id
        $r_refresh_type = $inner.refreshType
        $r_start = $inner.startTime
        $r_end = $inner.endTime
        $r_status = $inner.status
        $r_exception = $inner.serviceExceptionJson

        [PSCustomObject] @{
            g_id = $g_id
            d_id = $d_id
            g_name = $g_name
            d_name = $d_name
            r_req_id = $r_req_id
            r_id = $r_id
            r_refresh_type = $r_refresh_type
            r_start = $r_start
            r_end = $r_end
            r_status = $r_status
            r_exception = $r_exception

        }
    }
}

$dataset_rh_out | Select-Object -Property g_id,d_id,g_name,d_name,r_req_id,r_id,r_refresh_type,r_start,r_end,r_status,r_exception | Export-Csv -Path ".\refresh_history.csv"  -NoTypeInformation -Force

Write-Host "Output complete. Please find the file 'refresh_history.csv' in the local directory."
