Connect-AzureRmAccount
Write-Verbose "Removing resource group" -verbose
$resourceGroupName = "scdevops-india"
$resourceGroup = Get-AzureRmResourceGroup | Where ResourceGroupName -EQ $resourceGroupName
if($resourceGroup -ne $null){
    Remove-AzureRmResourceGroup -Name $resourceGroupName -Force
}