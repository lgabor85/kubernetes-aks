# deployAks.ps1

## Description
This PowerShell script creates an Azure Kubernetes Service (AKS) cluster along with all the necessary resources such as a resource group, virtual network, subnet, NAT gateway, and managed identity. The script uses ARM or BICEP templates to create these resources. Modules are loaded dynamically, and the script checks if the required resource providers are registered.

## Author
Gabor Lakatos - [LinkedIn](https://linkedin.com/in/lakatosgabor)

## Version
1.1.0

## GUID
eb914965c-2ddc-449b-b9fb-38066c3839c8

## Parameters

### User Input Parameters
- **nodeCount**: Number of nodes in the AKS cluster.
- **location**: Location for the resources (e.g., westeurope, northeurope).
- **prefix**: Prefix for naming the resources.
- **keyVaultName**: Name of the Azure Key Vault.
- **secretName**: Name of the secret (SSH key) stored in the Key Vault.

### Static Parameters
- **AzModulePath**: Path to the Azure modules.
- **templateFile**: Path to the ARM or BICEP template file for AKS infrastructure.
- **vnetTemplateFile**: Path to the ARM or BICEP template file for the virtual network.
- **natTemplateFile**: Path to the ARM or BICEP template file for the NAT gateway.
- **miTemplateFileName**: Path to the ARM or BICEP template file for the managed identity.
- **vnetRange**: Virtual network address range.
- **snetRange**: Subnet address range.
- **tenantId**: Tenant ID retrieved from the Key Vault.
- **subscriptionId**: Subscription ID retrieved from the Key Vault.
- **groupObjectId**: Group Object ID retrieved from the Key Vault.
- **publicKeyContent**: Public key content retrieved from the Key Vault.

### Dynamic Parameters
- **rgName**: Resource group name.
- **aksClusterName**: AKS cluster name.
- **vnetName**: Virtual network name.
- **vnetResourceGroupName**: Resource group name for the virtual network.
- **snetName**: Subnet name.
- **natGatewayName**: NAT gateway name.
- **natGatewayResourceGroup**: Resource group name for the NAT gateway.
- **publicIpName**: Public IP name.
- **workspaceName**: Workspace name.
- **workspaceRgName**: Resource group name for the workspace.
- **managedIdentityName**: Managed identity name.

### Counter
- **counter**: Counter used to display the progress of the script.

### Required Module Versions
- **azModuleVersion**: Array of required Azure module versions.

## Usage
Run the script in PowerShell and provide the required user input parameters when prompted. The script will dynamically generate the necessary resource names and create the resources using the specified ARM or BICEP templates.

## Example
```powershell
.\deployAks.ps1