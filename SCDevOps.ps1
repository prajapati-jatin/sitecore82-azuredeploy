Add-Type -assembly "system.io.compression.filesystem"
$resourceGroupName = "scdevops-india"

$location = "Central India"

$serverName = "srv-sc-sql"

$masterDbName = "sc-cm-master"
$webDbName = "sc-cm-web"
$coreDbName = "sc-cm-core"

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

$azKeyVaultName = "scdevops-keyvault"  

$scAzureDeployPackage = "D:\Sitecore\Sitecore 8.2 rev. 171121 (WDP XM1 packages).zip"

$tempExtractFolder = "$env:TEMP\sc"

$global:cmDeployPackage = $null
$global:cdDeployPackage = $null

$global:cmDeployDirectory = $null
$global:cdDeployDirectory = $null

$global:cmWebUploadPackage = $null
$global:cdWebUploadPackage = $null

$keySitecoreLicense = "SitecoreLicense"
$keySqlServerLogin = "SqlServerLogin"
$keySqlServerPassword = "SqlServerPassword"
$keySitecoreAdminPassword = "SitecoreAdminPassword"

DeploySitecore

function DeploySitecore(){
    cls
    ConnectAzure
    PreparePackages $scAzureDeployPackage $tempExtractFolder
        
    RemoveResourceGroup $resourceGroupName

    CreateAzureResourceGroup $resourceGroupName $location    

    DeployAzureKeyVault -resourceGroupName $resourceGroupName -location $location -vaultName $azKeyVaultName -SqlServerLogin $SqlServerLogin -SqlServerPassword $SqlServerPassword -SitecoreAdminPassword $SitecoreAdminPassword -licenseFile "D:\Sitecore\DevOps\license.xml"
    
    CreateAppServicePlan $resourceGroupName $webAppServicePlanName $location
    CreateWebApp -resourceGroupName $resourceGroupName -webAppName $cmWebAppName -webAppServicePlanName $webAppServicePlanName -location $location
    
    $sqlAdminLogin = GetAzureKeyVaultSecret -keyName $keySqlServerLogin
    $sqlAdminPassword = GetAzureKeyVaultSecret -keyName $keySqlServerPassword
    #CreateSQLServer -resourceGroupName $resourceGroupName -location $location -sererName $serverName -adminLogin $sqlAdminLogin.SecretValueText -password $sqlAdminPassword.SecretValueText
    #SetSQLServerFirewallRule -resourceGroupName $resourceGroupName -serverName $serverName -startip $startip -endip $endip
    #CreateDatabase($cmDbMasterName)
    #CreateDatabase($cmDbCoreName)
    #CreateDatabase($cmDbWebName)    
    Deploy-Site -resourceGroupName $resourceGroupName -webAppName $cmWebAppName -filePath $global:cmWebUploadPackage
    UploadLicenseFile -resourceGroupName $resourceGroupName -webAppName $cmWebAppName

}

function UploadLicenseFile($resourceGroupName, $webAppName){
    Write-Verbose "Uploading license" -Verbose
    $licenseContent = GetSitecoreLicense
    $licenseFilePath = "$tempExtractFolder\license.xml"
    [System.IO.File]::WriteAllText($licenseFilePath, $licenseContent)
    Upload-FileToWebApp -resourceGroupName $resourceGroupName -webAppName $webAppName -filePath $licenseFilePath -kuduPath "App_Data/license.xml"
    [System.IO.File]::Delete($licenseFilePath)
}

function CreateDatabase($name){
    CreateSQLDatabase -resourceGroupName $resourceGroupName -serverName $serverName -dbName $name -serviceObjectName "Basic"
}

function CreateMasterDatabase(){
    CreateSQLDatabase -resourceGroupName $resourceGroupName -serverName $serverName -dbName $cmDbMasterName -serviceObjectName "Basic"
}

function ConnectAzure(){
    $profile = Import-AzurePublishSettingsFile "D:\Sitecore\DevOps\Azure.publishsettings"
    Connect-AzureRmAccount
}

function CreateAzureResourceGroup($name, $location){
    Write-Verbose "Creating resource group: $name" -Verbose
    $resourceGroup = Get-AzureRmResourceGroup | Where ResourceGroupName -EQ $name
    if($resourceGroup -eq $null){
        $resourceGroup = New-AzureRmResourceGroup -Name $name -Location $location
    }
    return $resourceGroup
}

function CreateSQLServer($resourceGroupName, $location, $sererName, $adminLogin, $password){
    Write-Verbose "Creating SQL Server $serverName" -Verbose
    $server = Get-AzureRmSqlServer -ResourceGroupName $resourceGroupName | Where ServerName -EQ $serverName
    if($server -eq $null){
        Write-Host "Creating SQL Server: $serverName"
        $server = New-AzureRmSqlServer -ResourceGroupName $resourceGroupName -ServerName $serverName -Location $location -SqlAdministratorCredentials $(New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $adminLogin, $(ConvertTo-SecureString -String $password -AsPlainText -Force))
    }   
}

function SetSQLServerFirewallRule($resourceGroupName, $serverName, $startip, $endip){
    Write-Verbose "Setting firewall for $serverName" -Verbose
    $serverfirewall = Get-AzureRmSqlServerFirewallRule -ResourceGroupName $resourceGroupName -ServerName $serverName | Where FirewallRuleName -EQ "AllowedIPs"
    if($serverfirewall -eq $null){
        $serverfirewall = New-AzureRmSqlServerFirewallRule -ResourceGroupName $resourceGroupName -ServerName $serverName -FirewallRuleName "AllowedIPs" -StartIpAddress $startip -EndIpAddress $endip
    }   
}

function CreateSQLDatabase($resourceGroupName, $serverName, $dbName, $serviceObjectName = "Basic"){
    $db = Get-AzurermSqlDatabase -ResourceGroupName $resourceGroupName -ServerName $serverName | Where DatabaseName -EQ $dbName
    if($db -eq $null){
        $db = New-AzureRmSqlDatabase -ResourceGroupName $resourceGroupName -ServerName $serverName -DatabaseName $dbName -RequestedServiceObjectiveName $serviceObjectName
    }
    return $db
}

function CreateAppServicePlan($resourceGroupName, $webAppServicePlanName, $location){
    $appPlan = Get-AzureRmAppServicePlan -ResourceGroupName $resourceGroupName | Where Name -EQ $webAppServicePlanName
    if($appPlan -eq $null){
        $appPlan = New-AzureRmAppServicePlan -Name $webAppServicePlanName -Location $location -ResourceGroupName $resourceGroupName -Tier Free
    }
    return $appPlan
}

function CreateWebApp($resourceGroupName, $webAppName, $webAppServicePlanName, $location){
    $webApp = Get-AzureRmWebApp -ResourceGroupName $resourceGroupName | Where Name -EQ $webAppName
    if($webApp -eq $null){
        $webApp = New-AzureRmWebApp -Name $webAppName -Location $location -AppServicePlan $webAppServicePlanName -ResourceGroupName $resourceGroupName
    }
}


function RemoveResourceGroup($resourceGroupName){    
    Write-Verbose "Removing resource group: $resourceGroupName" -Verbose
    $resourceGroup = Get-AzureRmResourceGroup | Where ResourceGroupName -EQ $resourceGroupName
    if($resourceGroup -ne $null){
        Remove-AzureRmResourceGroup -Name $resourceGroupName -Force
    }
}


function Get-AzureRmWebAppPublishingCredentials($resourceGroupName, $webAppName){
    $resourceType = "Microsoft.Web/sites/config"
    $resourceName = "$webAppName/publishingcredentials"

    $publishingCredentials = Invoke-AzureRmResourceAction -ResourceGroupName $resourceGroupName -ResourceType $resourceType -ResourceName $resourceName -Action list -ApiVersion 2016-08-01 -Force
    return $publishingCredentials
}

function Get-KuduApiAuthorisationHeaderValue($resourceGroupName, $webAppName, $slotName = $null){
    $publishingCredentials = Get-AzureRmWebAppPublishingCredentials $resourceGroupName $webAppName $slotName
    return ("Basic {0}" -f [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(("{0}:{1}" -f $publishingCredentials.Properties.PublishingUserName, $publishingCredentials.Properties.PublishingPassword))))
}

function Upload-FileToWebApp($resourceGroupName, $webAppName, $slotName = "", $filePath, $kuduPath){
    $kuduAuthtoken = Get-KuduApiAuthorisationHeaderValue $resourceGroupName $webAppName $slotName
    $kuduApiUrl = "https://$webAppName.scm.azurewebsites.net/api/vfs/site/wwwroot/$kuduPath"
    Write-Host $kuduApiUrl
    #$virtualPath = $kuduApiUrl.Replace(".scm.azurewebsites.", ".azurewebsites.").Replace("/api/vfs/site/wwwroot", "")

    Invoke-RestMethod -Uri $kuduApiUrl -Headers @{"Authorization"=$kuduAuthtoken;"If-Match"="*"} -Method Put -InFile $filePath -ContentType "multipart/form-data"
}

function Upload-ZipFile($resourceGroupName, $webAppName, $filePath, $kuduPath){
    $kuduAuthtoken = Get-KuduApiAuthorisationHeaderValue $resourceGroupName $webAppName $slotName
    $kuduApiUrl = "https://$webAppName.scm.azurewebsites.net/api/zip/site/wwwroot/$kuduPath"
    #Write-Host $kuduApiUrl

    Invoke-RestMethod -Uri $kuduApiUrl -Headers @{"Authorization"=$kuduAuthtoken;"If-Match"="*"} -Method Put -InFile $filePath -ContentType "multipart/form-data"
}

function Deploy-Site($resourceGroupName, $webAppName, $filePath){
    Write-Verbose "Deploying to $webAppName from $filePath" -Verbose

    $kuduAuthtoken = Get-KuduApiAuthorisationHeaderValue $resourceGroupName $webAppName $slotName
    $kuduApiUrl = "https://$webAppName.scm.azurewebsites.net/api/zipdeploy"

    Invoke-RestMethod -Uri $kuduApiUrl -UserAgent "powershell/1.0" -Headers @{"Authorization"=$kuduAuthtoken;"If-Match"="*"} -Method POST -InFile $filePath -ContentType "multipart/form-data" -TimeoutSec 1000000
}

function PreparePackages($filePath, $destination){    
    Write-Verbose "Preparing deployment packages" -Verbose
    RemoveDirectory $destination

    Write-Verbose "Extracting $filePath to $destination" -Verbose
    ExtractZipFile $filePath $destination

    $global:cmDeployPackage = GetFileName $tempExtractFolder "*_cm.scwdp.zip"
    $global:cdDeployPackage = GetFileName $tempExtractFolder "*_cd.scwdp.zip"

    $global:cmDeployDirectory = "$tempExtractFolder\" + [System.IO.Path]::GetFileNameWithoutExtension($global:cmDeployPackage)    
    $global:cdDeployDirectory = "$tempExtractFolder\" + [System.IO.Path]::GetFileNameWithoutExtension($global:cdDeployPackage)
    
    ExtractZipFile $cmDeployPackage $cmDeployDirectory
    ExtractZipFile $cdDeployPackage $cdDeployDirectory

    $global:cmWebUploadPackage = "$tempExtractFolder\cmweb.zip"
    $global:cdWebUploadPackage = "$tempExtractFolder\cdweb.zip"

    CompressFolder "$global:cmDeployDirectory\Content\Website" $global:cmWebUploadPackage
    CompressFolder "$global:cdDeployDirectory\Content\Website" $global:cdWebUploadPackage
}

#FILE OPERATIONS
function ExtractZipFile($file, $destination){    
    Write-Verbose "Extracting: $file to $destination" -Verbose
    [System.IO.Compression.ZipFile]::ExtractToDirectory($file, $destination)
}



function CreateDirectory($path){
    Write-Verbose "Creating directory $path" -Verbose
    if(![System.IO.Directory]::Exists($path)){
        $dir = [System.IO.Directory]::CreateDirectory($path)
    }
}

function RemoveDirectory($path){
    Write-Verbose "Removing directory $path" -Verbose
    if([System.IO.Directory]::Exists($path)){
        [System.IO.Directory]::Delete($path, $true)
    }
}

function GetFileName($path, $pattern){
    return [System.IO.Directory]::GetFiles($path, $pattern)[0]
}

function CompressFolder($path, $filePath){
    Write-Verbose "Compressing $path to $filePath"
    $compressionToUse = [System.IO.Compression.CompressionLevel]::Optimal
    $includeBaseFolder = $false
    [System.IO.Compression.ZipFile]::CreateFromDirectory($path, $filePath, $compressionToUse, $includeBaseFolder)
}

#Azure KeyVault
function DeployAzureKeyVault{
    Param(
    [string][Parameter(Mandatory=$true)]$resourceGroupName,
    [string][Parameter(Mandatory=$true)]$vaultName,
    [string][Parameter(Mandatory=$true)]$location,
    [string][Parameter(Mandatory=$true)]$SqlServerLogin,
    [string][Parameter(Mandatory=$true)]$SqlServerPassword,
    [string][Parameter(Mandatory=$true)]$SitecoreAdminPassword,
    [string][Parameter(Mandatory=$true)]$licenseFile
    )
    Write-Verbose "Creating Azure Key Vault" -Verbose
    Write-Verbose "License file: $licenseFile" -Verbose
    CreateAzureKeyVault -resourceGroupName $resourceGroupName -location $location -keyVaultName $vaultName
    CreateSecrets -name $vaultName
}


function CreateAzureKeyVault($resourceGroupName, $location, $keyVaultName){
    New-AzureRmKeyVault -VaultName $keyVaultName -ResourceGroupName $resourceGroupName -Location $location
}

function CreateSecrets($name){
    $zipContent = Zip([IO.File]::ReadAllBytes($licenseFile))
    $zipString = [System.Convert]::ToBase64String($zipContent)
    $secretLicense = ConvertTo-SecureString $zipString -AsPlainText -Force
    $secretSqlServerLogin = ConvertTo-SecureString $SqlServerLogin -AsPlainText -Force
    $secretSqlServerPassword = ConvertTo-SecureString $SqlServerPassword -AsPlainText -Force
    $secretSitecoreAdminPassword = ConvertTo-SecureString $SitecoreAdminPassword -AsPlainText -Force

    Write-Verbose "Creating vault secret: SitecoreLicense" -Verbose
    Set-AzureKeyVaultSecret -VaultName $name -Name $keySitecoreLicense -SecretValue $secretLicense
    Write-Verbose "Creating vault secret: SqlServerLogin" -Verbose
    Set-AzureKeyVaultSecret -VaultName $name -Name $keySqlServerLogin -SecretValue $secretSqlServerLogin
    Write-Verbose "Creating vault secret: SqlServerPassword" -Verbose
    Set-AzureKeyVaultSecret -VaultName $name -Name $keySqlServerPassword -SecretValue $secretSqlServerPassword
    Write-Verbose "Creating vault secret: SitecoreAdminPassword" -Verbose
    Set-AzureKeyVaultSecret -VaultName $name -Name $keySitecoreAdminPassword -SecretValue $secretSitecoreAdminPassword
}

function Zip{
    param([byte[]] $content)
    $output = New-Object System.IO.MemoryStream
    $gzipStream = New-Object System.IO.Compression.GzipStream($output, ([IO.Compression.CompressionMode]::Compress))
    $gzipStream.Write($content, 0, $content.Length);
    $gzipStream.Close()
    return $output.ToArray()
}

function Unzip(){
    param([byte[]]$gzipContent)
    $input = New-Object System.IO.MemoryStream(,$zipContent)
    $gzipStream = New-Object System.IO.Compression.GzipStream($input, ([IO.Compression.CompressionMode]::Decompress))
    $output = New-Object System.IO.MemoryStream
    $gzipStream.CopyTo($output)
    return $output.ToArray()
}

function GetSitecoreLicense(){
    $secretLicense = Get-AzureKeyVaultSecret -VaultName $azKeyVaultName -Name "SitecoreLicense"
    $zipContent = [System.Convert]::FromBase64String($secretLicense.SecretValueText)
    $licenseFile = Unzip($zipContent)
    $licenseFileContent = [System.Text.Encoding]::UTF8.GetString($licenseFile)
    return $licenseFileContent
}

function GetAzureKeyVaultSecret($keyName){
    return Get-AzureKeyVaultSecret -VaultName $azKeyVaultName -Name $keyName
}