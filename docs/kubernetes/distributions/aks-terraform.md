title: Kubernetes Service - Azure AKS (Terraform)
description: Kubernetes Public Cloud Service Azure AKS Via Terraform

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

## Get kubectl config

```bash
AKS_RESOURCE_GROUP=joostvdg-cbcore
AKS_CLUSTER_NAME=acctestaks1
```

```bash
az aks get-credentials --resource-group ${AKS_RESOURCE_GROUP} --name ${AKS_CLUSTER_NAME}
```

## Enable Preview Features

Currently having cluster autoscalers requires enabling of a Preview Feature in Azure.

The same holds true for enabling multiple node pools, which I think is a best practice for using Kubernetes.

* [Enable Multi Node Pool](https://docs.microsoft.com/en-us/azure/aks/use-multiple-node-pools)
* [Enable Cluster Autoscaler - via VMScaleSets](https://docs.microsoft.com/en-us/azure/aks/cluster-autoscaler#register-scale-set-feature-provider)

## Terraform Code

!!! important
    When using Terraform for AKS and you want to use Multiple Node Pools and/or the Cluster Autoscaler, you need to use the minimum of `1.32.0` of the `azurerm` provider.

??? example "main.tf"

    ```terraform
    provider "azurerm" {
        # whilst the `version` attribute is optional, we recommend pinning to a given version of the Provider
        version = "~> 1.32.0"
    }

    terraform {
        backend "azurerm" {}
    }
    ```

??? example "k8s.tf"

    ```terraform
    resource "azurerm_kubernetes_cluster" "k8s" {
        name                = "acctestaks1"
        location            = "${azurerm_resource_group.k8s.location}"
        resource_group_name = "${azurerm_resource_group.k8s.name}"
        dns_prefix          = "jvdg"
        kubernetes_version  = "${var.kubernetes_version}"

        agent_pool_profile {
            name            = "default"
            vm_size         = "Standard_D2s_v3"
            os_type         = "Linux"
            os_disk_size_gb = 30
            enable_auto_scaling = true
            count = 2
            min_count = 2
            max_count = 3
            type = "VirtualMachineScaleSets"
            node_taints = ["mytaint=true:NoSchedule"]
        }

        agent_pool_profile {
            name            = "pool1"
            vm_size         = "Standard_D2s_v3"
            os_type         = "Linux"
            os_disk_size_gb = 30
            enable_auto_scaling = true
            min_count = 1
            max_count = 3
            type = "VirtualMachineScaleSets"
        }

        agent_pool_profile {
            name            = "pool2"
            vm_size         = "Standard_D4s_v3"
            os_type         = "Linux"
            os_disk_size_gb = 30
            enable_auto_scaling = true
            min_count = 1
            max_count = 3
            type = "VirtualMachineScaleSets"
        }

        role_based_access_control {
            enabled = true
        }

        service_principal {
            client_id     = "${var.client_id}"
            client_secret = "${var.client_secret}"
        }

        tags = {
            Environment = "Development"
            CreatedBy = "Joostvdg"
        }
    }

    output "client_certificate" {
        value = "${azurerm_kubernetes_cluster.k8s.kube_config.0.client_certificate}"
    }

    output "kube_config" {
        value = "${azurerm_kubernetes_cluster.k8s.kube_config_raw}"
    }
    ```

??? example "variables.tf"

    ```terraform
    variable "client_id" {}
    variable "client_secret" {}

    variable "kubernetes_version" {
        default = "1.14.6"
    }

    variable "agent_count" {
        default = 3
    }

    variable "ssh_public_key" {
        default = "~/.ssh/id_rsa.pub"
    }

    variable "dns_prefix" {
        default = "jvdg"
    }

    variable cluster_name {
        default = "cbcore"
    }

    variable resource_group_name {
        default = "joostvdg-cbcore"
    }

    variable container_registry_name {
        default = "joostvdgacr"
    }

    variable location {
        default = "westeurope"
    }
    ```

??? example "acr.tf"

    ```terraform
    resource "azurerm_resource_group" "ecr" {
        name     = "${var.resource_group_name}-acr"
        location = "${var.location}"
    }

    resource "azurerm_container_registry" "acr" {
        name                     = "${var.container_registry_name}"
        resource_group_name      = "${azurerm_resource_group.ecr.name}"
        location                 = "${azurerm_resource_group.k8s.location}"
        sku                      = "Premium"
        admin_enabled            = false
    }
    ```

??? example "resource-group.tf"

    ```terraform
    resource "azurerm_resource_group" "k8s" {
        name     = "${var.resource_group_name}"
        location = "${var.location}"
    }
    ```
