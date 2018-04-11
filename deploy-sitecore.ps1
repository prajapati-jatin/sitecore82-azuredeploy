Remove-Variable * -ErrorAction SilentlyContinue; $error.Clear(); Clear-Host
#Import necessary assemblies
Add-Type -assembly "System.IO.Compression.FileSystem"

#set required variables
$resourceGrouplocation = "Central India"
$resourceGroupName = "sitecore-devops"

$sqlServerName = "sitecore-devops-sql-srv"
$sqlMasterDBName = "scdevops_master"
$sqlCoreDBName = "scdevops_core"
$sqlWebDBName = "scdevops_web"
$sqlFWStartIP = "0.0.0.0"
$sqlFWEndIP = "0.0.0.0"

$sqlServerLogin = "scsqladmin"
$sqlServerPassword = "y52NtJ@n"

$scAdminPassword = "y52NtJ@n"

$cmWebAppName = "scdevops-cm"
$cdWebAppName = "scdevops-cd"
$webAppServicePlan = "scdevops-app-plan"

$azKeyVaultName = "scdevops-keyvault"
$keySCLicense = "SitecoreLicense"
$keySQLSrvLogin = "SQLServerLogin"
$keySQLSrvPassword = "SQLServerPassword"
$keySCAdminPassword = "SitecoreAdminPassword"

$scDeployPackage = "D:\Sitecore\Setups\Sitecore 8.2 rev. 171121 (WDP XM1 packages).zip"

$licenseFile = "D:\Sitecore\Setups\license.xml"

$extractFolder = "$env:TEMP\sc"

$cmDeployPackage = $null
$cdDeployPackage = $null
$cmDeployDirectory = $null
$cdDeployDirectory = $null
$cmWebUploadPackage = $null
$cdWebUploadPackage = $null

DeploySitecore

function DeploySitecore(){
    cls
    ConnectAzure
    #PreparePackages -filePath $scDeployPackage -destination $extractFolder
    RemoveResourceGroup($resourceGroupName)
    $resourceGroup = CreateAzureResourceGroup -name $resourceGroupName -location $resourceGrouplocation
    DeployAzureKeyVault -resGroupName $resourceGroupName -vaultName $azKeyVaultName -location $resourceGrouplocation
}



#Azure operations
function ConnectAzure(){
    Write-Verbose "Connection Azure..." -Verbose
    $profile = Import-AzurePublishSettingsFile "D:\Sitecore\DevOps\Azure.publishsettings"
}

function CreateAzureResourceGroup($name, $location){
    Write-Verbose "Creating resource group: $name" -Verbose
    $resourceGroup = Get-AzureRmResourceGroup | Where ResourceGroupName -EQ $name
    if($resourceGroup -eq $null){
        $resourceGroup = New-AzureRmResourceGroup -Name $name -Location $location
    }
    return $resourceGroup
}

function RemoveResourceGroup($name){
    Write-Verbose "Removing resource group: $name" -Verbose
    $resourceGroup = Get-AzureRmResourceGroup | Where ResourceGroupName -EQ $name
    if($resourceGroup -ne $null){
        Remove-AzureRmResourceGroup -Name $name -Force
    }
    else{
        Write-Verbose "Resource group '$name' does not exist" -Verbose
    }
}

#Azure KeyVault
function DeployAzureKeyVault{
    Param(
    [string][Parameter(Mandatory=$true)]$resGroupName,
    [string][Parameter(Mandatory=$true)]$vaultName,
    [string][Parameter(Mandatory=$true)]$location
    )
    Write-Verbose "Creating Azure Key Vault" -Verbose
    CreateAzureKeyVault -resGroupName $resGroupName -location $location -keyVaultName $vaultName
    CreateSecrets -name $vaultName
}


function CreateAzureKeyVault($resGroupName, $location, $keyVaultName){
    New-AzureRmKeyVault -VaultName $keyVaultName -ResourceGroupName $resGroupName -Location $location
}

function CreateSecrets($name){
    Write-Verbose "Creating secrets" -Verbose
    $zipContent = Zip([IO.File]::ReadAllBytes($licenseFile))
    $zipString = [System.Convert]::ToBase64String($zipContent)
    $secretLicense = ConvertTo-SecureString $zipString -AsPlainText -Force
    $secretSqlServerLogin = ConvertTo-SecureString $sqlServerLogin -AsPlainText -Force
    $secretSqlServerPassword = ConvertTo-SecureString $sqlServerPassword -AsPlainText -Force
    $secretSitecoreAdminPassword = ConvertTo-SecureString $scAdminPassword -AsPlainText -Force

    #Write-Verbose "Creating vault secret: SitecoreLicense" -Verbose
    $s1 = Set-AzureKeyVaultSecret -VaultName $name -Name $keySCLicense -SecretValue $secretLicense
    #Write-Verbose "Creating vault secret: SqlServerLogin" -Verbose
    $s2 = Set-AzureKeyVaultSecret -VaultName $name -Name $keySQLSrvLogin -SecretValue $secretSqlServerLogin
    #Write-Verbose "Creating vault secret: SqlServerPassword" -Verbose
    $s3 = Set-AzureKeyVaultSecret -VaultName $name -Name $keySQLSrvPassword -SecretValue $secretSqlServerPassword
    #Write-Verbose "Creating vault secret: SitecoreAdminPassword" -Verbose
    $s4 = Set-AzureKeyVaultSecret -VaultName $name -Name $keySCAdminPassword -SecretValue $secretSitecoreAdminPassword
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

#File operations
function PreparePackages($filePath, $destination){    
    Write-Verbose "Preparing deployment packages" -Verbose
    RemoveDirectory $destination

    ExtractZipFile $filePath $destination

    $cmDeployPackage = GetFileName $destination "*_cm.scwdp.zip"
    $cdDeployPackage = GetFileName $destination "*_cd.scwdp.zip"

    $cmDeployDirectory = "$destination\" + [System.IO.Path]::GetFileNameWithoutExtension($cmDeployPackage)    
    $cdDeployDirectory = "$destination\" + [System.IO.Path]::GetFileNameWithoutExtension($cdDeployPackage)
    
    ExtractZipFile $cmDeployPackage $cmDeployDirectory
    ExtractZipFile $cdDeployPackage $cdDeployDirectory

    $cmWebUploadPackage = "$destination\cmweb.zip"
    $cdWebUploadPackage = "$destination\cdweb.zip"

    CompressFolder "$cmDeployDirectory\Content\Website" $cmWebUploadPackage
    CompressFolder "$cdDeployDirectory\Content\Website" $cdWebUploadPackage

    Write-Verbose "CM Deploy Package: $cmDeployPackage"
    Write-Verbose "CD Deploy Package: $cdDeployPackage"

    Write-Verbose "CM Deploy Directory: $cmDeployDirectory"
    Write-Verbose "CD Deploy Directory: $cdDeployDirectory"
}

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