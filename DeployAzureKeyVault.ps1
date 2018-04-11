#Deploy Key-Vault
Param(
[string][Parameter(Mandatory=$true)]$resourceGroupName,
[string][Parameter(Mandatory=$true)]$keyVaultName,
[string][Parameter(Mandatory=$true)]$location,
[string][Parameter(Mandatory=$true)]$SqlServerLogin,
[string][Parameter(Mandatory=$true)]$SqlServerPassword,
[string][Parameter(Mandatory=$true)]$SitecoreAdminPassword,
[string][Parameter(Mandatory=$true)]$licenseFile
)

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
    CreateAzureKeyVault -resourceGroupName $resourceGroupName -location $location -keyVaultName $keyVaultName
    CreateSecrets -keyVaultName $keyVaultName
}


function CreateAzureKeyVault($resourceGroupName, $location, $keyVaultName){
    New-AzureRmKeyVault -VaultName $keyVaultName -ResourceGroupName $resourceGroupName -Location $location -EnabledForTemplateDeployment:$true
}

function CreateSecrets($keyVaultName){
    $zipContent = Zip([IO.File]::ReadAllBytes($licenseFile))
    $zipString = [System.Convert]::ToBase64String($zipContent)
    $secretLicense = ConvertTo-SecureString $zipString -AsPlainText -Force

    Set-AzureKeyVaultSecret -VaultName $keyVaultName -Name "SitecoreLicense" -SecretValue $secretLicense
    Set-AzureKeyVaultSecret -VaultName $keyVaultName -Name "SqlServerLogin" -SecretValue $SqlServerLogin
    Set-AzureKeyVaultSecret -VaultName $keyVaultName -Name "SqlServerPassword" -SecretValue $SqlServerPassword
    Set-AzureKeyVaultSecret -VaultName $keyVaultName -Name "SitecoreAdminPassword" -SecretValue $SitecoreAdminPassword
}

function Zip{
    param([byte[]] $content)
    $output = New-Object System.IO.MemoryStream
    $gzipStream = New-Object System.IO.Compression.GzipStream($output, ([IO.Compression.CompressionMode]::Compress))
    $gzipStream.Write($content, 0, $content.Length);
    $gzipStream.Close()
    return $output.ToArray()
}