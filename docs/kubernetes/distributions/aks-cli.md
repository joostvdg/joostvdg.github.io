# Azure CLI

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

* See: https://weidongzhou.wordpress.com/2018/06/27/could-not-get-external-ip-for-load-balancer-on-azure-aks/
* And: https://github.com/Azure/AKS/issues/427

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

#### Prepare variables

```bash
RESOURCE_GROUP_NAME=
CLUSTER_NAME=
LOCATION=eastus
NODE_POOL_MASTERS=masters
NODE_POOL_BUILDS=builds
VM_SIZE_MASTERS_NP=Standard_DS2_v2
VM_SIZE_BUILDS_NP=?
```

#### Create Resource Group

```bash
az group create --name ${RESOURCE_GROUP_NAME} --location ${LOCATION}
```

#### Create AKS Cluster

```bash
az aks create \
    --resource-group ${RESOURCE_GROUP_NAME} \
    --name ${CLUSTER_NAME} \
    --enable-vmss \
    --node-count 1 \
    --nodepool-name ${NODE_POOL_MASTERS} \
    --node-vm-size ${VM_SIZE_MASTERS_NP} \
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
az aks get-credentials --resource-group ${RESOURCE_GROUP_NAME} --name ${CLUSTER_NAME}
```

### Add second node pool

```bash
az aks nodepool add \
    --resource-group ${RESOURCE_GROUP_NAME} \
    --cluster-name ${CLUSTER_NAME} \
    --name ${NODE_POOL_BUILDS} \
    --node-count 3
```
