<#PSScriptInfo

.AUTHOR "Gabor Lakatos - linkedin.com/in/lakatosgabor"

.VERSION 1.1.0

.GUID eb914965c-2ddc-449b-b9fb-38066c3839c8

#>

<#

.DESCRIPTION
    This script creates an AKS cluster and all the resources required for it, such as a resource group, virtual network, subnet, NAT gateway, and managed identity. 
    The script uses ARM or BICEP templates to create the resources.
    Modules are loaded dynamically, and the script checks if the required resource providers are registered.
#>

# ┌───────────────────────────────────────────────────────────────┐
# |Configure Modules, Initial Parameters, Variables and Pre-checks|
# └───────────────────────────────────────────────────────────────┘


# User input parameters
[int]$nodeCount = Read-Host -Prompt "Number of nodes"
[string]$location = Read-Host -Prompt "Location(e.g. westeurope, northeurope)"
[string]$prefix = Read-Host -Prompt "Enter a prefix"
[string]$keyVaultName = Read-Host -Prompt "Enter the key vault name"
[string]$secretName = Read-Host -Prompt "Enter the secret(ssh key) name stored in the key vault"


# Static parameters that are hardcoded in the script
[string]$AzModulePath = '../Modules' # Replace with the path to the Az modules
[string]$templateFile = '../Templates/BICEP/myAksInfra.bicep' # Replace with the path to the ARM or BICEP template file
[string]$vnetTemplateFile = '../Templates/BICEP/vnet.bicep' # Replace with the path to the ARM or BICEP template file
[string]$natTemplateFile = '../Templates/BICEP/nat.bicep' # Replace with the path to the ARM or BICEP template file
[string]$miTemplateFileName = '../Templates/BICEP/mi.bicep' # Replace with the path to the ARM or BICEP template file
[string]$vnetRange = '172.2.0.0/16' # Replace with the desired virtual network address range
[string]$snetRange = '172.2.20.0/24' # Replace with the desired subnet address range
[string]$tenantId = (Get-AzKeyVaultSecret -VaultName $keyvaultName -Name 'tenantId' -AsPlainText)
[string]$subscriptionId = (Get-AzKeyVaultSecret -VaultName $keyvaultName -Name 'subscriptionId' -AsPlainText)
[string]$groupObjectId = (Get-AzKeyVaultSecret -VaultName $keyvaultName -Name 'groupObjectId' -AsPlainText)
[string]$publicKeyContent = (Get-AzKeyVaultSecret -VaultName $keyvaultName -Name $secretName -AsPlainText)

# Dynamic parameters that are generated by the script
[string]$rgName = $prefix + (Get-Random -Minimum 10 -Maximum 100) + '-rg'
[string]$aksClusterName = $prefix + (Get-Random -Minimum 10 -Maximum 100) + '-aks'
[string]$vnetName = $prefix + (Get-Random -Minimum 10 -Maximum 100) + '-vnet'
[string]$vnetResourceGroupName = $prefix + (Get-Random -Minimum 10 -Maximum 100) + '-vnet-rg'
[string]$snetName = $prefix + (Get-Random -Minimum 10 -Maximum 100) + '-snet'
[string]$natGatewayName = $prefix + (Get-Random -Minimum 10 -Maximum 100) + '-nat'
[string]$natGatewayResourceGroup = $prefix + (Get-Random -Minimum 10 -Maximum 100) + '-nat-rg'
[string]$publicIpName = $prefix + (Get-Random -Minimum 10 -Maximum 100) + '-IP'
[string]$workspaceName = $prefix + (Get-Random -Minimum 10 -Maximum 100) + '-ws'
[string]$workspaceRgName = 'ws' + $prefix + (Get-Random -Minimum 10 -Maximum 100) + '-rg'
[string]$managedIdentityName = $prefix + (Get-Random -Minimum 10 -Maximum 100) + '-mi'

# Counter that will be used to display the progress of the script
$counter = 1

#Define reuired module versions
[array] $azModuleVersion = @(

    [PSCustomObject]@{ moduleName = "Az.Accounts"; moduleVersion = "3.0.1" }
    [PSCustomObject]@{ moduleName = "Az.OperationalInsights"; moduleVersion = "3.2.1" }
    [PSCustomObject]@{ moduleName = "Az.Network"; moduleVersion = "7.8.0" }
    [PSCustomObject]@{ moduleName = "Az.ManagedServiceIdentity"; moduleVersion = "1.2.1" }
    [PSCustomObject]@{ moduleName = "Az.Resources"; moduleVersion = "7.2.0" }
    [PSCustomObject]@{ moduleName = "Az.Aks"; moduleVersion = "6.0.3" }

)

# Define Resource provider(s) needed for this script
[array] $providers = @(

    [PSCustomObject]@{ providerNameSpace = "Microsoft.ManagedIdentity" }
    [PSCustomObject]@{ providerNameSpace = "Microsoft.ContainerService" }
    [PSCustomObject]@{ providerNameSpace = "Microsoft.Network" }
    [PSCustomObject]@{ providerNameSpace = "Microsoft.OperationalInsights" }
    
)

# Function to set the subscription
function logIn {

    [CmdletBinding()]
    param (

        [Parameter(Mandatory = $true)]
        [string]$subscriptionId,

        [Parameter(Mandatory = $false)]
        [string]$tenantId
            
    )

    try {

        $currentSession = Get-AzContext

        while ($null -eq $currentSession) {

            Write-Progress -Activity "Logging in to Azure..."

            Connect-AzAccount -Subscription $subscriptionId -Tenant $tenantId -UseDeviceAuthentication
            $currentSession = Get-AzContext

        }
    }
    catch {

        Write-Error "An error occurred: $_"
        throw $_

    }
}


# Function to load the required modules
function loadModules {

    [CmdletBinding()]
    param (

        [Parameter(Mandatory = $true)]
        [array]$azModuleVersion,
        [parameter(Mandatory = $true)]
        [string]$AzModulePath

    )

    try {

        Write-Progress -Activity "Loading modules..."

        foreach ($module in $azModuleVersion) {

            if ( -Not (Get-Module -Name $module.moduleName)) {

                $modulePath = Join-Path $AzModulePath "$($module.moduleName)"
                Import-Module -Name $modulePath -RequiredVersion $module.moduleVersion -ErrorAction Stop
                Write-Output "Module $($module.moduleName) version $($module.moduleVersion) loaded successfully."    

            }
            elseif ((Get-Module -Name $module.moduleName).Version -lt $module.moduleVersion) {

                $modulePath = Join-Path $AzModulePath "$($module.moduleName)"
                Remove-Module -Name $module.moduleName -Force
                Import-Module -Name $modulePath -RequiredVersion $module.moduleVersion -ErrorAction Stop
                Write-Output "Module $($module.moduleName) version $($module.moduleVersion) loaded successfully."    

            }
            else {

                Write-Output "Module $($module.moduleName) version $($module.moduleVersion) is already loaded."

            }

        
        }
    }
    catch {

        Write-Error "An error occurred while loading modules: $_"
        throw $_

    }
}
# Function to check if the required resource providers are registered
function Get-Providers {

    [CmdletBinding()]
    param (

        [Parameter(Mandatory = $true)]
        [array]$providers

    )

    try {

        Write-Progress -Activity "Checking if required resource providers are registered..."
        
        # if the providers RegistrationState is NotRegistered, register it
        foreach ($provider in $providers) {

            $providerNameSpace = $provider.providerNameSpace
            $providerStatus = (Get-AzResourceProvider -ProviderNamespace $providerNameSpace).RegistrationState

            if ($providerStatus -eq "NotRegistered") {

                Write-Output "Registering provider $providerNameSpace...`n"
                Register-AzResourceProvider -ProviderNamespace $providerNameSpace

            }
            else {

                Write-Output "Provider $providerNameSpace is registered`n"

            }
        }
    }
    catch {
            
        Write-Error $_.Exception.Message
        Exit

    }
    
}

# Function to set resource group
function getRg {

    [CmdletBinding()]
    param (

        [Parameter(Mandatory = $true)]
        [string]$rgName,

        [Parameter(Mandatory = $true)]
        [string]$location

    )

    # Create the resource group if needed
    try {

        Get-AzResourceGroup -Name $rgName -ErrorAction Stop
    
    }
    catch {

        New-AzResourceGroup -Name $rgName -Location $location
    
    }
    
    
}

# Function to set the Log Analytics workspace
function newWorkspace {

    [CmdletBinding()]
    param (

        [Parameter(Mandatory = $true)]
        [string]$workspaceName,
        [Parameter(Mandatory = $true)]
        [string]$workspaceRgName,
        [Parameter(Mandatory = $true)]
        [string]$location

    )

    # Create the resource group if needed
    try {

        Get-AzResourceGroup -Name $workspaceRgName -ErrorAction Stop
    
    }
    catch {

        New-AzResourceGroup -Name $workspaceRgName -Location $Location
    
    }

    # Create the workspace

    try {

        Get-AzOperationalInsightsWorkspace -ResourceGroupName $workspaceRgName -Name $workspaceName -ErrorAction Stop
    
    }
    catch {

        New-AzOperationalInsightsWorkspace -ResourceGroupName $workspaceRgName -Name $workspaceName -Location $location
    
    }


}

# Function to configure the virtual network, subnet, and NAT gateway
function aksNetworkConfig {

    [CmdletBinding()]
    param(

        [Parameter(Mandatory = $true)]
        [string]$vnetResourceGroupName,
        [Parameter(Mandatory = $true)]
        [string]$vnetName,
        [Parameter(Mandatory = $true)]
        [string]$vnetRange,
        [Parameter(Mandatory = $true)]
        [string]$snetName,
        [Parameter(Mandatory = $true)]
        [string]$snetRange,
        [Parameter(Mandatory = $false)]
        [string]$natGatewayName,
        [Parameter(Mandatory = $true)]
        [string]$natGatewayResourceGroup,
        [parameter(Mandatory = $true)]
        [string]$publicIpName,
        [Parameter(Mandatory = $true)]
        [string]$vnetTemplateFile,
        [Parameter(Mandatory = $true)]
        [string]$natTemplateFile,
        [Parameter(Mandatory = $true)]
        [string]$choiceNat
    
    )

    # Create the virtual network and subnet if needed
    try {

        Get-AzVirtualNetwork -Name $vnetName -ResourceGroupName $vnetResourceGroupName -ErrorAction Stop
    
    }
    catch {

        New-AzResourceGroupDeployment -ResourceGroupName $vnetResourceGroupName `
            -TemplateFile $vnetTemplateFile `
            -virtualNetworkName $vnetName `
            -virtualNetworkAddressPrefix $vnetRange `
            -snetName $snetName `
            -snetAddressPrefix $snetRange `
            -Mode Incremental `
            -Confirm
    
    }

    # Attach an existing NAT gateway or create a new one from bicep template
    if ($choiceNat -eq "n") {

        try {

            Get-AzNatGateway -Name $natGatewayName -ResourceGroupName $natGatewayResourceGroup -ErrorAction Stop

        }
        catch {

            New-AzResourceGroupDeployment -ResourceGroupName $natGatewayResourceGroup -TemplateFile $natTemplateFile `
                -TemplateParameterObject @{ 
                        
                natName             = $natGatewayName; 
                publicIpName        = $publicIpName; 
                subnetName          = $snetName; 
                vnetName            = $vnetName; 
                vnetAddressPrefix   = $vnetRange;
                subnetAddressPrefix = $snetRange

            } -Mode Incremental -Confirm

        }

    }    
}

# Function to create a new managed identity
function aksMiConfig {

    [CmdletBinding()]
    param(

        [Parameter(Mandatory = $true)]
        [string]$rgName,
        [Parameter(Mandatory = $true)]
        [string]$managedIdentityName,
        [Parameter(Mandatory = $true)]
        [string]$vnetName,
        [Parameter(Mandatory = $true)]
        [string]$subnetName,
        [Parameter(Mandatory = $true)]
        [string]$miTemplateFile
    )

    [array]$roleDefinitionIds = @(

        (Get-AzRoleDefinition -Name "Network Contributor").Id

    )

    # Create the managed identity
    try {

        Get-AzUserAssignedIdentity -ResourceGroupName $aksResourceGroupName `
            -Name $managedIdentityName `
            -ErrorAction Stop

    }
    catch {

        New-AzResourceGroupDeployment -ResourceGroupName $rgName `
            -TemplateFile $miTemplateFile `
            -TemplateParameterObject @{ 

            managedIdentityName = $managedIdentityName;
            vnetName            = $vnetName; 
            subnetName          = $subnetName; 
            roleDefinitionIds   = $roleDefinitionIds;

        } `
            -Mode Incremental `
            -Confirm

    }
}


# ┌──────────────────────┐
# |Set up the Environment|
# └──────────────────────┘

# Prep #1: Log in to Azure PowerShell

Write-Output "-------------------------------------------"
Write-Output "|Set-up part 1: Log in to Azure PowerShell|"
Write-Output "-------------------------------------------`n"

logIn -subscriptionId $subscriptionId -tenantId $tenantId

Write-Output "--------------------"
Write-Output "|Set-up part 1 done|"
Write-Output "--------------------`n"

# Prep 2: Load Modules

Write-Output "-----------------------------"
Write-Output "|Set-up part 2: Load Modules|"
Write-Output "-----------------------------`n"

loadModules -azModuleVersion $azModuleVersion -AzModulePath $AzModulePath

Write-Output "--------------------"
Write-Output "|Set-up part 2 done|"
Write-Output "-------------------`n"

# Prep 3: Verify required resource providers are registered

Write-Output "---------------------------------------------------"
Write-Output "|Set-up part 3: Verify required resource providers|"
Write-Output "---------------------------------------------------`n"

Get-Providers -providers $providers

Write-Output "--------------------"
Write-Output "|Set-up part 3 done|"
Write-Output "--------------------`n"




# ┌───────────────┐
# |Main Code Block|
# └───────────────┘


# Step 1: Set the resource group for the AKS cluster

Write-Output "----------------------------------------------------"
Write-Output "|Step 1: Set the resource group for the AKS cluster|"
Write-Output "----------------------------------------------------`n"

$resourceGroups = Get-AzResourceGroup | Select-Object ResourceGroupName
Write-Output $resourceGroups

$choiceRg = Read-Host -Prompt "Do you want to use an existing (e) RG or create one (n)? (Type 'e' or 'n')"

if ($choiceRg -eq "n") {

    getRg -rgName $rgName -location $location

}
else {
    
    Write-Output "`n"

    $rgName = Read-Host -Prompt "Resource Group Name: "
    getRg -rgName $rgName -location $location

}

$counter++

Write-Output "-------------"
Write-Output "|Step 1 done|"
Write-Output "-------------`n"

#Step 2: Set the Log Analytics workspace for the AKS cluster
Write-Output "-------------------------------------------------------------"
Write-Output "|Step 2: Set the Log Analytics workspace for the AKS cluster|"
Write-Output "-------------------------------------------------------------`n"

$workSpaces = Get-AzOperationalInsightsWorkspace | Select-Object Name, ResourceGroupName

$choiceWS = Read-Host -Prompt "Do you want to use an existing (e) workspace or create one (n)? (Type 'e' or 'n')"

if ($choiceWS -eq "e") {

    Write-Progress -Activity "Setting the Log Analytics Workspace..." -Status "$counter/5" -PercentComplete ($counter / 5 * 100)

    $workspaceName = $workSpaces.Name
    $workspaceRgName = $workSpaces.ResourceGroupName

}
else {

    Write-Progress -Activity "Creating the Log Analytics workspace..." -Status "$counter/5" -PercentComplete ($counter / 5 * 100)

    newWorkspace -workspaceName $workspaceName `
        -workspaceRgName $workspaceRgName `
        -location $location
}

[string]$workspaceId = (Get-AzOperationalInsightsWorkspace `
        -ResourceGroupName $workspaceRgName `
        -Name $workspaceName).ResourceId

$counter++

Write-Output "-------------"
Write-Output "|Step 2 done|"
Write-Output "-------------`n"

# Step 3: Configure the vNet, subnet, and NAT gateway for the AKS cluster
Write-Output "----------------------------------------------------------------------------------"
Write-Output "|Step 3: Configure the vNet, subnet, and optional NAT gateway for the AKS cluster|"
Write-Output "----------------------------------------------------------------------------------`n"

# Determine if a NAT gateway or a load balancer will be used for outbound traffic and configure the variables accordingly
# If a new NAT gateway is created, the script will use the pre-defined variables for the NAT gateway name, public IP name)
# If an existing NAT gateway is used, the script will populate the variables with the existing NAT gateway name and public IP name from the given resource group
$choiceNat = Read-Host -Prompt "Do you want to use a NAT gateway (n) or a load balancer (l) for outbound traffic? (Type 'n' or 'l')"
if ($choiceNat -eq "n") {

    $choiceConfigureNat = Read-Host -Prompt "New or existing NAT gateway? (Type 'n' or 'e')"

    if ($choiceConfigureNat -eq "n") {

        $natGatewayResourceGroup = Read-Host -Prompt "Name of the NAT gateway resource group"

    } elseif ($choiceConfigureNat -eq "e") {

        $natGatewayResourceGroup = Read-Host -Prompt "Name of the NAT gateway resource group"
        $natGatewayName = Get-AzNatGateway -ResourceGroupName $natGatewayResourceGroup | Select-Object Name -ExpandProperty Name
        $publicIpName = Get-AzPublicIpAddress -ResourceGroupName $natGatewayResourceGroup | Select-Object Name -ExpandProperty Name

    }


}

# Determine if an existing vNet will be used or a new one will be created
# Depending on the user`s choice, the script will either use the pre-generated variables for the vNet and subnet or populate them from given resource group
$choiceVnet = Read-Host -Prompt "Do you want to use an existing (e) vNet or create one (n)? (Type 'e' or 'n') "
$vnetResourceGroupName = Read-Host "Name of the vNET resource group"

try {
    if ($choiceVnet -eq "e" -and $choiceNat -eq "l") {

        $vnet = Get-AzVirtualNetwork -ResourceGroupName $vnetResourceGroupName
        $vnetName = $vnet.Name
        $vnetRange = $vnet.AddressSpace.AddressPrefixes[0]
        $snetName = $vnet.Subnets[0].Name
        $snetRange = $vnet.Subnets[0].AddressPrefix
        $outboundType = "loadBalancer"

    }
    elseif ($choiceVnet -eq "e" -and $choiceNat -eq "n") {

        $vnet = Get-AzVirtualNetwork -ResourceGroupName $vnetResourceGroupName
        $vnetName = $vnet.Name
        $vnetRange = $vnet.AddressSpace.AddressPrefixes[0]
        $snetName = $vnet.Subnets[0].Name
        $snetRange = $vnet.Subnets[0].AddressPrefix
        $outboundType = "userAssignedNatGateway"

        Write-Progress -Activity "Configuring NAT gateway..." -Status "$counter/5" -PercentComplete ($counter / 5 * 100)

        aksNetworkConfig -vnetResourceGroupName $vnetResourceGroupName `
            -vnetName $vnetName `
            -vnetRange $vnetRange `
            -snetName $snetName `
            -snetRange $snetRange `
            -natGatewayName $natGatewayName `
            -natGatewayResourceGroup $natGatewayResourceGroup `
            -publicIpName $publicIpName `
            -vnetTemplateFile $vnetTemplateFile `
            -natTemplateFile $natTemplateFile `
            -choiceNat $choiceNat

    }
    elseif ($choiceVnet -eq "n" -and $choiceNat -eq "l") {

        Write-Progress -Activity "Configuring  vNet..." -Status "$counter/5" -PercentComplete ($counter / 5 * 100)

        aksNetworkConfig -vnetResourceGroupName $vnetResourceGroupName `
            -vnetName $vnetName `
            -vnetRange $vnetRange `
            -snetName $snetName `
            -snetRange $snetRange `
            -natGatewayName $natGatewayName `
            -publicIpName $publicIpName `
            -vnetTemplateFile $vnetTemplateFile `
            -natTemplateFile $natTemplateFile `
            -choiceNat $choiceNat

        $outboundType = "loadBalancer"

    }
    elseif ($choiceVnet -eq "n" -and $choiceNat -eq "n") {

        Write-Progress -Activity "Configuring vNet and NAT Gateway..." -Status "$counter/5" -PercentComplete ($counter / 5 * 100)

        aksNetworkConfig -vnetResourceGroupName $vnetResourceGroupName `
            -vnetName $vnetName `
            -vnetRange $vnetRange `
            -snetName $snetName `
            -snetRange $snetRange `
            -natGatewayName $natGatewayName `
            -natGatewayResourceGroup $natGatewayResourceGroup `
            -publicIpName $publicIpName `
            -vnetTemplateFile $vnetTemplateFile `
            -natTemplateFile $natTemplateFile `
            -choiceNat $choiceNat

        $outboundType = "userAssignedNatGateway"

    }
}
catch {

    Write-Error $_.Exception.Message
    Exit

}


$counter++

Write-Output "-------------"
Write-Output "|Step 3 done|"
Write-Output "-------------`n"

# Step 4: Configure the managed identity for the AKS cluster

Write-Output "------------------------------------------------------------"
Write-Output "|Step 4: Configure the managed identity for the AKS cluster|"
Write-Output "------------------------------------------------------------`n"


$vnetResourceGroupName = (Get-AzVirtualNetwork -Name $vnetName).ResourceGroupName
$vnet = Get-AzVirtualNetwork -ResourceGroupName $vnetResourceGroupName -Name $vnetName
$snetId = (Get-AzVirtualNetworkSubnetConfig -VirtualNetwork $vnet -Name $snetName).Id

# 
$choiceMi = Read-Host -Prompt "Do you want to use an existing (e) managed identity or create one (n)? (Type 'e' or 'n')"

if ($choiceMi -eq "e") {

    $managedIdentityName = Get-AzUserAssignedIdentity -ResourceGroupName $rgName | Select-Object Name -ExpandProperty Name

}

try {

    Write-Progress -Activity "Configuring the managed identity..." -Status "$counter/5" -PercentComplete ($counter / 5 * 100)


    aksMiConfig -rgName $rgName `
        -miTemplateFile $miTemplateFileName `
        -managedIdentityName $managedIdentityName `
        -vnetName $vnetName `
        -subnetName $snetName


}

catch {

    Write-Error $_.Exception.Message
    Exit

}

$managedIdentityResourceId = (Get-AzUserAssignedIdentity -ResourceGroupName $rgName -Name $managedIdentityName).Id
$counter++

Write-Output "-------------"
Write-Output "|Step 4 done|"
Write-Output "-------------`n"

# Step 5: Create the AKS cluster

Write-Output "--------------------------------"
Write-Output "|Step 5: Create the AKS cluster|"
Write-Output "--------------------------------`n"


Write-Output "AKS Cluster will be created from template, and with parameters:`n"

Write-Output "SubscriptionId: $subscriptionId"
Write-Output "TenantId: $tenantId"
Write-Output "ResourceGroupName: $rgName"
Write-Output "Location: $location"
Write-Output "AksClusterName: $aksClusterName"
Write-Output "NodeCount: $nodeCount"
Write-Output "ManagedIdentityName: $managedIdentityName"
Write-Output "ManagedIdentityResourceId: $managedIdentityResourceId"
Write-Output "VirtualNetworkName: $vnetName"
Write-Output "VirtualNetworkSubnet: $snetName"
Write-Output "WorkspaceResourceId: $workspaceId"
Write-Output "AdminGroupObjectIDs: $groupObjectId"
Write-Output "OutboundType: $outboundType"
Write-Output "TemplateFile: $templateFile `n"

$confirm = Read-Host -Prompt "Do you want to create the AKS cluster with the these parameters? (Type 'y' or 'n')"

if ($confirm -eq "y") {

    Write-Progress -Activity "Creating the AKS cluster..." -Status "$counter/5" -PercentComplete ($counter / 5 * 100)
    
    try {
        
        New-AzResourceGroupDeployment -ResourceGroupName $rgName `
            -TemplateFile $templateFile `
            -aksClusterName $aksClusterName `
            -snetId $snetId `
            -nodeCount $nodeCount `
            -location $location `
            -outboundType $outboundType `
            -adminGroupObjectIDs $groupObjectId `
            -workspaceId $workspaceId `
            -userAssignedIdentities $managedIdentityResourceId `
            -publicKeyContent $publicKeyContent `
            -tenantID $tenantId `
            -Mode Incremental `
            -Confirm

    }
    catch {
                
        Write-Error $_.Exception.Message

        Exit

    }
}

elseif ($confirm -eq "n") {

    Write-Output "Stopping the script...`n"
    Exit

}

Write-Output "-------------"
Write-Output "|Step 5 done|"
Write-Output "-------------`n"