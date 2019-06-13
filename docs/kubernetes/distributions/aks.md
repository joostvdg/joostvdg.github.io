# Azure Kubernetes Service

## Resources

* https://github.com/MicrosoftDocs/azure-docs/blob/master/articles/aks/use-multiple-node-pools.md
* https://www.danielstechblog.io/azure-kubernetes-service-cluster-autoscaler-configurations/
* https://www.cloudbees.com/blog/securing-jenkins-role-based-access-control-and-azure-active-directory
* https://go.cloudbees.com/docs/cloudbees-core/cloud-install-guide/aks-install/#
* https://go.cloudbees.com/docs/cloudbees-core/cloud-install-guide/kubernetes-helm-install/#_additional_information_creating_a_tls_certificate

## Configure AZ CLI

```bash
az login
```

```bash
az account show --query "{subscriptionId:id, tenantId:tenantId}"
```

```bash
export SUBSCRIPTION_ID=
```

```bash
SUBSCRIPTION_ID=...
az account set --subscription="${SUBSCRIPTION_ID}"
```

```bash
az ad sp create-for-rbac --role="Owner" --scopes="/subscriptions/${SUBSCRIPTION_ID}"
```

### Should be owner

Should be owner, else it cannot create a LoadBalancer via the `nginx-ingress`.

See: https://weidongzhou.wordpress.com/2018/06/27/could-not-get-external-ip-for-load-balancer-on-azure-aks/
And: https://github.com/Azure/AKS/issues/427

## Terraform Config

```bash
ARM_SUBSCRIPTION_ID
ARM_CLIENT_ID
ARM_CLIENT_SECRET
ARM_TENANT_ID
ARM_ENVIRONMENT
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

## Configure Kubecontext

```bash
az aks get-credentials --resource-group cbcore --name cbcore
```

## Configure Cluster Autoscaler

```bash
az extension add --name aks-preview
```

```bash
az feature register --name VMSSPreview --namespace Microsoft.ContainerService
az feature list -o table --query "[?contains(name, 'Microsoft.ContainerService/VMSSPreview')].{Name:name,State:properties.state}"
az provider register --namespace Microsoft.ContainerService
az feature list -o table --query "[?contains(name, 'Microsoft.ContainerService')].{Name:name,State:properties.state}"
```

## Configure multi-node pool

```bash
az feature register --name MultiAgentpoolPreview --namespace Microsoft.ContainerService
az feature list -o table --query "[?contains(name, 'Microsoft.ContainerService/MultiAgentpoolPreview')].{Name:name,State:properties.state}"
```

```bash
az provider register --namespace Microsoft.ContainerService
```

## Create AKS cluster via CLI

### Resources

* https://github.com/MicrosoftDocs/azure-docs/blob/master/articles/aks/use-multiple-node-pools.md
* https://docs.microsoft.com/en-us/azure/aks/cluster-autoscaler
* https://www.danielstechblog.io/azure-kubernetes-service-cluster-autoscaler-configurations/

### Get available versions

```bash
az aks get-versions --location westeurope
```

### Create initial cluster

```bash
# Create a resource group in East US
az group create --name myResourceGroup --location eastus

# Create a basic single-node AKS cluster
az aks create \
    --resource-group myResourceGroup \
    --name myAKSCluster \
    --enable-vmss \
    --node-count 1 \
    --nodepool-name masters \
    --node-vm-size Standard_DS2_v2 \
    --enable-cluster-autoscaler \
    --enable-vmss \
    --generate-ssh-keys
```

#### PodSecurityPolicy

```bash
--enable-cluster-autoscaler    : Enable cluster autoscaler, default value is false.
    If specified, please make sure the kubernetes version is larger than 1.10.6.
```

#### Networking

```bash
--network-plugin               : The Kubernetes network plugin to use.
    Specify "azure" for advanced networking configurations. Defaults to "kubenet".
--network-policy               : (PREVIEW) The Kubernetes network policy to use.
    Using together with "azure" network plugin.
    Specify "azure" for Azure network policy manager and "calico" for calico network policy
    controller.
    Defaults to "" (network policy disabled).
```

### Retrieve credentials

```bash
az aks get-credentials --resource-group myResourceGroup --name myAKSCluster
```

### Add second node pool

```bash
az aks nodepool add \
    --resource-group myResourceGroup \
    --cluster-name myAKSCluster \
    --name mynodepool \
    --node-count 3
```

