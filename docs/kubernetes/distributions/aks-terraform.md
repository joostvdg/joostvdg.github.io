# AKS Terraform

## Resources

* https://docs.microsoft.com/en-us/azure/terraform/terraform-create-k8s-cluster-with-tf-and-aks
* https://www.terraform.io/docs/providers/azurerm/r/kubernetes_cluster.html

## Pre-Requisites

### Create Service Principle

It comes from [this guide](https://docs.microsoft.com/en-us/cli/azure/create-an-azure-service-principal-azure-cli?view=azure-cli-latest).

```
az account show --query "{subscriptionId:id, tenantId:tenantId}"
```

```bash
az ad sp create-for-rbac --role="Owner" --scopes="/subscriptions/${SUBSCRIPTION_ID}"
```

### Retrieve current Kubernetes Versions

```bash
az aks get-versions --location westeurope --output table
```

## Terraform Config

```bash
ARM_SUBSCRIPTION_ID=
ARM_CLIENT_ID=
ARM_CLIENT_SECRET=
ARM_TENANT_ID=
ARM_ENVIRONMENT=
```

### Create storage account for TF State

```bash
LOCATION=westeurope
RESOURCE_GROUP_NAME=joostvdg-cb-ext-storage
STORAGE_ACCOUNT_NAME=joostvdgcbtfstate
CONTAINER_NAME=tfstate
```

#### List locations

```bash
az account list-locations \
    --query "[].{Region:name}" \
    --out table
```

#### Create resource group

```bash
az group create \
    --name ${RESOURCE_GROUP_NAME} \
    --location ${LOCATION}
```

#### Create storage account

```bash
az storage account create \
    --name ${STORAGE_ACCOUNT_NAME} \
    --resource-group ${RESOURCE_GROUP_NAME} \
    --location ${LOCATION} \
    --sku Standard_ZRS \
    --kind StorageV2
```

#### Retrieve storage account login

Apparently, no CLI commands available?

Use the [Azure Blog on AKS via Terraform](https://docs.microsoft.com/en-us/azure/terraform/terraform-create-k8s-cluster-with-tf-and-aks#set-up-azure-storage-to-store-terraform-state) for how via the UI.

```bash
STORAGE_ACCOUNT_KEY=
```

#### Create TF Storage

```bash
az storage container create -n ${CONTAINER_NAME} --account-name ${STORAGE_ACCOUNT_NAME} --account-key ${STORAGE_ACCOUNT_KEY}
```

#### Init Terraform backend

```bash
terraform init -backend-config="storage_account_name=${STORAGE_ACCOUNT_NAME}" \
 -backend-config="container_name=${CONTAINER_NAME}" \
 -backend-config="access_key=${STORAGE_ACCOUNT_KEY}" \
 -backend-config="key=codelab.microsoft.tfstate"
```

#### Expose temp variables

These are from your Service Principle we created earlier.
Where `client_id` = appId, and `client_secret` the password.

```bash
export TF_VAR_client_id=<your-client-id>
export TF_VAR_client_secret=<your-client-secret>
```

## Rollout

### Set variables

```bash
source ../export-variables.sh
```

### Validate

```bash
terraform validate
```

### Plan

```bash
terraform plan -out out.plan
```

### Apply the plan

```bash
terraform apply out.plan
```

## Example TF

### Main

```terraform
resource "azurerm_resource_group" "cbcore" {
    name     = "${var.resource_group_name}"
    location = "${var.location}"
}

resource "azurerm_kubernetes_cluster" "cbcore" {
    name                = "${var.cluster_name}"
    location            = "${azurerm_resource_group.cbcore.location}"
    resource_group_name = "${azurerm_resource_group.cbcore.name}"
    dns_prefix          = "${var.dns_prefix}"

    linux_profile {
        admin_username = "ubuntu"

        ssh_key {
            key_data = "${file("${var.ssh_public_key}")}"
        }
    }

    agent_pool_profile {
        name            = "builds"
        count           = 1
        vm_size         = "Standard_D1_v2"
        os_type         = "Linux"
        os_disk_size_gb = 30
    }

    agent_pool_profile {
        name            = "masters"
        count           = 2
        vm_size         = "Standard_D2_v2"
        os_type         = "Linux"
        os_disk_size_gb = 30
    }

    service_principal {
        client_id     = "${var.client_id}"
        client_secret = "${var.client_secret}"
    }

    tags = {
        Environment = "Development"
        CreatedBy = "Me"
    }
}
```

### Variables

```terraform
variable "client_id" {}
variable "client_secret" {}

variable "agent_count" {
    default = 3
}

variable "ssh_public_key" {
    default = "~/.ssh/id_rsa.pub"
}

variable "dns_prefix" {
    default = "cbcore"
}

variable cluster_name {
    default = "cbcore"
}

variable resource_group_name {
    default = "cbcore"
}

variable location {
    default = "West Europe"
}
```