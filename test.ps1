$resourceGroupName = "scdevops-india"

$location = "Central India"

$serverName = "srv-sc-sql"

$masterDbName = "sc-cm-master"
$webDbName = "sc-cm-web"
$coreDbName = "sc-cm-core"

$adminLogin = "scsqladmin"
$password = "y52NtJ@n"

$SqlServerLogin = "scsqladmin"
$SqlServerPassword = "y52NtJ@n"
$SitecoreAdminPassword = "y52NtJ@n"

$scAdminPassword = "y52NtJ@n"

$startip = "0.0.0.0"
$endip = "0.0.0.0"

$cmWebAppName = "scdevops-poc-cm"
$cdWebAppName = "scdevops-poc-cd"
$webAppServicePlanName = "scdevops-poc-app-plan"

$cmDbMasterName = "scdevops_master"
$cmDbCoreName = "scdevops_core"
$cmDbWebName = "scdevops_web"

$keyVaultName = "sc-keyvault"

$scAzureDeployPackage = "D:\Sitecore\Sitecore 8.2 rev. 171121 (WDP XM1 packages).zip"

$tempExtractFolder = "$env:TEMP\sc"

$global:cmDeployPackage = $null
$global:cdDeployPackage = $null

$global:cmDeployDirectory = $null
$global:cdDeployDirectory = $null

$global:cmWebUploadPackage = $null
$global:cdWebUploadPackage = $null
$licenseFile = "D:\Sitecore\DevOps\license.xml"

clear
ConnectAzure
DeployAzureKeyVault $resourceGroupName $keyVaultName $location $SqlServerLogin $SqlServerPassword $SitecoreAdminPassword $licenseFile

function ConnectAzure(){
    $profile = Import-AzurePublishSettingsFile D:\Sitecore\DevOps\Azure.publishsettings
}

function DeployAzureKeyVault{
    Param(
    [string][Parameter(Mandatory=$true)]$resourceGroupName,
    [string][Parameter(Mandatory=$true)]$keyVaultName,
    [string][Parameter(Mandatory=$true)]$location,
    [string][Parameter(Mandatory=$true)]$SqlServerLogin,
    [string][Parameter(Mandatory=$true)]$SqlServerPassword,
    [string][Parameter(Mandatory=$true)]$SitecoreAdminPassword,
    [string][Parameter(Mandatory=$true)]$licenseFile
    )
    Write-Verbose "Creating Azure Key Vault" -Verbose
    Write-Verbose "License file: $licenseFile" -Verbose
    CreateAzureKeyVault -resourceGroupName $resourceGroupName -location $location -keyVaultName $keyVaultName
    #CreateSecrets -keyVaultName $keyVaultName
}


function CreateAzureKeyVault($resourceGroupName, $location, $keyVaultName){
    New-AzureRmKeyVault -VaultName $keyVaultName -ResourceGroupName $resourceGroupName -Location $location
}

function CreateSecrets($keyVaultName){
    $zipContent = Zip([IO.File]::ReadAllBytes($licenseFile))
    $zipString = [System.Convert]::ToBase64String($zipContent)
    $secretLicense = ConvertTo-SecureString $zipString -AsPlainText -Force
    $secretSqlServerLogin = ConvertTo-SecureString $SqlServerLogin -AsPlainText -Force
    $secretSqlServerPassword = ConvertTo-SecureString $SqlServerPassword -AsPlainText -Force
    $secretSitecoreAdminPassword = ConvertTo-SecureString $SitecoreAdminPassword -AsPlainText -Force

    Set-AzureKeyVaultSecret -VaultName $keyVaultName -Name "SitecoreLicense" -SecretValue $secretLicense
    #Set-AzureKeyVaultSecret -VaultName $keyVaultName -Name "SqlServerLogin" -SecretValue $secretSqlServerLogin
    #Set-AzureKeyVaultSecret -VaultName $keyVaultName -Name "SqlServerPassword" -SecretValue $secretSqlServerPassword
    #Set-AzureKeyVaultSecret -VaultName $keyVaultName -Name "SitecoreAdminPassword" -SecretValue $secretSitecoreAdminPassword
}

function Zip{
    param([byte[]] $content)
    $output = New-Object System.IO.MemoryStream
    $gzipStream = New-Object System.IO.Compression.GzipStream($output, ([IO.Compression.CompressionMode]::Compress))
    $gzipStream.Write($content, 0, $content.Length);
    $gzipStream.Close()
    return $output.ToArray()
}