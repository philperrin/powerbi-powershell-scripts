
Set-Location -Path $PSScriptRoot

Connect-PowerBIServiceAccount

$gw_lookup = Invoke-PowerBIRestMethod -Url "gateways" -Method Get | ConvertFrom-Json
$gw_details = foreach($row in $gw_lookup.value){
    $gw_id = $row.id
    $gw_name = $row.name

    [PSCustomObject] @{
        gw_id = $gw_id
        gw_name = $gw_name
    }
}


$gw_conns = foreach($row in $gw_details){
    $gw_id = $row.gw_id
    #Write-Host $gw_id
    #Write-Host "gateways/$gw_id/datasources"
    $c_result = Invoke-PowerBIRestMethod -Url "gateways/$gw_id/datasources" -Method Get | ConvertFrom-Json

    foreach($inner in $c_result.value){
        $g_id = $inner.gatewayId
        $c_id = $inner.id
        $c_name = $inner.datasourceName

        [PSCustomObject] @{
            g_id = $g_id
            c_id = $c_id
            c_name = $c_name
        }
    }
}
$gw_conns | Select-Object -Property g_id,c_id,c_name | Export-Csv -Path ".\connections.csv"  -NoTypeInformation -Force

