﻿
$ErrorActionPreference = 'Stop'

function Resolve-ExtensionModule {
<#
.PARAMETER ModuleName
Required, the name of the PowerShell module that is an ACMESharp Extension Module.

.PARAMETER ModuleVersion
An optional version spec, useful if multiple version of the target Extension Module
are installed.

The spec can be an exact version string or a `-like` pattern to be matched.

.PARAMETER AcmeVersion
An optional version spec, useful if multiple versions of the core ACMESharp module is installed,
this will specify which module installation will be targeted for enabling the module.

The spec can be an exact version string or a `-like` pattern to be matched.
#>
	param(
		[Parameter(Mandatory)]
		[string]$ModuleName,
		[Parameter(Mandatory=$false)]
		[string]$ModuleVersion,

		[Parameter(Mandatory=$false)]
		[string]$AcmeVersion
	)

	## Get any modules that are resident in the current session and
	## any module versions that are available on the current system
	$acmeMods = @(Get-Module ACMESharp) + @(Get-Module -ListAvailable ACMESharp | Sort-Object -Descending Version)
	$provMods = @(Get-Module $ModuleName) + (Get-Module -ListAvailable $ModuleName | Sort-Object -Descending Version)

	if ($AcmeVersion) {
		$acmeMod = $acmeMods | Where-Object { $_.Version -like $AcmeVersion } | Select-Object -First 1
	}
	else {
		$acmeMod = $acmeMods | Select-Object -First 1
	}

	if ($ModuleVersion) {
		$provMod = $provMods | Where-Object { $_.Version -like $ModuleVersion } | Select-Object -First 1
	}
	else {
		$provMod = $provMods | Select-Object -First 1
	}

	if (-not $provMod -or -not $provMod.ModuleBase) {
		Write-Error "Cannot resolve extension module's base [$ModuleName]"
		return
	}
	if (-not $acmeMod -or -not $acmeMod.ModuleBase) {
		Write-Error "Cannot resolve ACMESharp module's own base"
		return
	}
	if (-not (Test-Path $acmeMod.ModuleBase)) {
		Write-Error "Cannot find ACMESharp module base [$($x.ModuleBase)]"
		return
	}

	$extRoot = "$($acmeMod.ModuleBase)\EXT"
	$extPath = "$($extRoot)\$($provMod.Name).extlnk"

	[ordered]@{
		acmeMod = $acmeMod
		provMod = $provMod
		extRoot = $extRoot
		extPath = $extPath
	}		
}

function Get-ExtensionModule {
<#
.PARAMETER ModuleName
Optional, the name of the PowerShell module that is an enabled ACMESharp Extension Module.  If unspecified, then all enabled Extension Modules will be returned.

.PARAMETER AcmeVersion
An optional version spec, useful if multiple versions of the core ACMESharp module is installed,
this will specify which module installation will be targeted for inspecting for enabled modules.

The spec can be an exact version string or a `-like` pattern to be matched.
#>
	param(
		[Parameter(Mandatory=$false)]
		[string]$ModuleName,

		[Parameter(Mandatory=$false)]
		[string]$AcmeVersion
	)

	## Get any modules that are resident in the current session and
	## any module versions that are available on the current system
	$acmeMods = @(Get-Module ACMESharp) + @(Get-Module -ListAvailable ACMESharp | Sort-Object -Descending Version)
	if ($AcmeVersion) {
		$acmeMod = $acmeMods | Where-Object { $_.Version -like $AcmeVersion } | Select-Object -First 1
	}
	else {
		$acmeMod = $acmeMods | Select-Object -First 1
	}
	
	if (-not $acmeMod -or -not $acmeMod.ModuleBase) {
		Write-Error "Cannot resolve ACMESharp module's own base"
		return
	}
	if (-not (Test-Path $acmeMod.ModuleBase)) {
		Write-Error "Cannot find ACMESharp module base [$($x.ModuleBase)]"
		return
	}

	$extRoot = "$($acmeMod.ModuleBase)\EXT"
	$extPath = "$($extRoot)\*.extlnk"

	$extLinks = Get-ChildItem $extPath
	if ($ModuleName) {
		$extLinks = $extLinks | Where-Object { ($_.Name -replace '\.extlnk$','') -eq $ModuleName }
	}

	$extLinks | Select-Object @{
		Name = "Name"
		Expression = { $_.Name -replace '\.extlnk$','' }
	},@{
		Name = "JSON"
		Expression = { Get-Content $_ | ConvertFrom-Json }
	} | Select-Object Name,@{
		Name = "Version"
		Expression = { $_.JSON.Version }
	},@{
		Name = "Path"
		Expression = { $_.JSON.Path }
	}
}

function Enable-ExtensionModule {
<#
.PARAMETER ModuleName
Required, the name of the PowerShell module that is an ACMESharp Extension Module.

.PARAMETER ModuleVersion
An optional version spec, useful if multiple version of the target Extension Module
are installed.

The spec can be an exact version string or a `-like` pattern to be matched.

.PARAMETER AcmeVersion
An optional version spec, useful if multiple versions of the core ACMESharp module is installed,
this will specify which module installation will be targeted for enabling the module.

The spec can be an exact version string or a `-like` pattern to be matched.
#>
	param(
		[Parameter(Mandatory)]
		[string]$ModuleName,
		[Parameter(Mandatory=$false)]
		[string]$ModuleVersion,

		[Parameter(Mandatory=$false)]
		[string]$AcmeVersion
	)
	
	$deps = Resolve-ExtensionModule -ModuleName $ModuleName -AcmeVersion $AcmeVersion
	if (-not $deps) {
		return
	}

	if (Test-Path $deps.extPath) {
		Write-Error "Extension module already enabled"
		return
	}
	mkdir -Force $deps.extRoot
	Write-Output "Installing Extension Module to [$($deps.extPath)]"
	@{
		Path = $deps.provMod.ModuleBase
		Version = $deps.provMod.Version.ToString()
	} | ConvertTo-Json > $deps.extPath
}

function Disable-ExtensionModule {
<#
.PARAMETER ModuleName
Required, the name of the PowerShell module that is an ACMESharp Extension Module.

.PARAMETER ModuleVersion
An optional version spec, useful if multiple version of the target Extension Module
are installed.

The spec can be an exact version string or a `-like` pattern to be matched.

.PARAMETER AcmeVersion
An optional version spec, useful if multiple versions of the core ACMESharp module is installed,
this will specify which module installation will be targeted for enabling the module.

The spec can be an exact version string or a `-like` pattern to be matched.
#>
	param(
		[Parameter(Mandatory)]
		[string]$ModuleName,
		[Parameter(Mandatory=$false)]
		[string]$ModuleVersion,

		[Parameter(Mandatory=$false)]
		[string]$AcmeVersion
	)
	
	$deps = Resolve-ExtensionModule -ModuleName $ModuleName -AcmeVersion $AcmeVersion
	if (-not $deps) {
		return
	}

	if (-not (Test-Path $deps.extPath)) {
		Write-Error "Extension module is not enabled"
		return
	}
	Write-Output "Removing Extension Module installed at [$($deps.extPath)]"
	Remove-Item -Confirm $deps.extPath
}

function Export-ExtensionAsMarkdown {
	[CmdletBinding()]
	param(
		[Parameter(ParameterSetName="ChallengeHandler")]
		[string]$ChallengeHandler,
		[Parameter(ParameterSetName="Installer")]
		[string]$Installer,
		[Parameter(ParameterSetName="Vault")]
		[string]$Vault,
		[Parameter(ParameterSetName="ChallengeDecoder")]
		[string]$ChallengeDecoder,
		[Parameter(ParameterSetName="PkiTool")]
		[string]$PkiTool
	)

	if ($ChallengeHandler) {
		$extType = "Challenge Handler"
		$extName = $ChallengeHandler
		$ext = ACMESharp\Get-ChallengeHandlerProfile -GetChallengeHandler $ChallengeHandler
		$extParams = $ext.Parameters
		$extInst = [ACMESharp.ACME.ChallengeHandlerExtManager]::GetProvider($extName)
	}
	if ($Installer) {
		$extType = "Installer"
		$extName = $Installer
		$ext = ACMESharp\Get-InstallerProfile -GetInstaller $Installer
		$extParams = $ext.Parameters
		$extInst = [ACMESharp.Installer.InstallerExtManager]::GetProvider($extName)
	}
	if ($Vault) {
		$extType = "Vault Storage"
		$extName = $Vault
		## Forces the load of Vault-related assemblies
        ACMESharp\Get-VaultProfile -ListProfiles | Out-Null
		$ext = [ACMESharp.Vault.VaultExtManager]::GetProviderInfo($extName)
		$extInst = [ACMESharp.Vault.VaultExtManager]::GetProvider($extName)
		$extParams = $extInst.DescribeParameters()
	}
	if ($ChallengeDecoder) {
		$extType = "Challenge Decoder"
		$extName = $ChallengeDecoder
		$ext = ACMESharp\Get-ChallengeHandlerProfile -GetChallengeType $ChallengeDecoder
		$extParams = $ext.Parameters
	}
	if ($PkiTool) {
		$extType = "PKI Tool"
		$extName = $PkiTool
		## Forces the load of Vault-related assemblies
		ACMESharp\Get-ChallengeHandlerProfile -ListChallengeTypes | Out-Null
		$ext = [ACMESharp.PKI.PkiToolExtManager]::GetProviderInfo($extName)
		$extInst = [ACMESharp.PKI.PkiToolExtManager]::GetProvider($extName)
		$extParams = $extInst.DescribeParameters()
	}

	if (-not $ext) {
		Write-Error "Could not resolve $extType [$extName]"
		return
	}

	## Get all the type-specific props excluding all the common ones
	$props = $ext.GetType().GetMembers() |
			Where-Object { $_.MemberType -eq "Property" } |
			Where-Object { $_.Name -notin @('Name', 'Label', 'Description', 'Parameters') } |
			Select-Object -ExpandProperty Name

	$extName = if($ext.Name) { $ext.Name }
	## TODO:  Aliases???
	$extLabel = if ($ext.Label) { $ext.Label } else { $extName }

	Write-Output ""
	Write-Output "# $($extType): $($extLabel)"
	if ($ext.Description) {
		Write-Output ""
		Write-Output $ext.Description
	}
	else {
		Write-Output "*(no description)*"
	}
	Write-Output ""
	Write-Output @"
| | |
|-|-|
| **Name:** | ``$($extName)``
"@
	foreach ($p in $props) {
		Write-Output "| **$($p):** | $($ext.$p)"
	}
	if ($extInst) {
		$asmName = $extInst.GetType().Assembly.GetName()
		Write-Output "| **Assembly:** | ``$($asmName.Name)``"
		Write-Output "| **Version:** | ``$($asmName.Version)``"
	}
	Write-Output ""

	if ($extParams) {
		Write-Output("## Parameters")
		foreach ($p in $extParams) {
			$pLabel = if ($p.Label) { $p.Label } else { $p.Name }
			Write-Output @"
---
### $pLabel

$($p.Description)

| | |
|-|-|
| **Name:**          | ``$($p.Name)``
| **Type:**          | $($p.Type)
| **IsRequired:**    | $($p.IsRequired)
| **IsMultiValued:** | $($p.IsMultiValued)

"@
		}
	}
}