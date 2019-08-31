title: Kubernetes Service - Google GKE (Helm)
description: Kubernetes Public Cloud Service Google GKE With Helm

# GKE with Helm

## Env Variables

```bash
CLUSTER_NAME=MyGKECluster
REGION=europe-west4
NODE_LOCATIONS=${REGION}-a,${REGION}-b
ZONE=europe-west4-a
K8S_VERSION=1.11.5-gke.4
PROJECT_ID=
```

## Get Kubernetes versions

```bash
gcloud container get-server-config --region $REGION
```

## Create Cluster

```bash
gcloud container clusters create ${CLUSTER_NAME} \
    --region ${REGION} --node-locations ${NODE_LOCATIONS} \
    --cluster-version ${K8S_VERSION} \
    --num-nodes 2 --machine-type n1-standard-2 \
    --addons=HorizontalPodAutoscaling \
    --min-nodes 2 --max-nodes 3 \
    --enable-autoupgrade \
    --enable-autoscaling \
    --enable-network-policy \
    --labels=purpose=practice
```

## Post Install

```bash
kubectl create clusterrolebinding cluster-admin-binding \
    --clusterrole cluster-admin \
    --user $(gcloud config get-value account)
```

## Delete Cluster

```bash
gcloud container clusters delete $CLUSTER_NAME --region $REGION
```

### Configure kubeconfig

```bash
gcloud container clusters get-credentials ${CLUSTER_NAME} --region ${REGION}
```

## Install Cluster Tools

### Helm

We use [Helm](https://helm.sh) as a package manager to more easily install other tools on Kubernetes.

There's several repositories with a large number of mature charts - the name of the Helm packages.

One being [Helm/Stable](https://github.com/helm/charts/tree/master/stable) another being [Helm Hub](https://hub.helm.sh/charts).

#### Create service account

```bash
kubectl create serviceaccount --namespace kube-system tiller
```

!!! Warning
    Tiller is deemed not safe for production, at least not in its default configuration.
    Either enable its TLS configuration and take other measures (such as namespace limitation) or use alternative solutions. Such as Kustomize, Pulumi, Jenkins X or raw Yaml.

#### Create cluster role binding

```bash
kubectl create clusterrolebinding tiller-cluster-rule --clusterrole=cluster-admin --serviceaccount=kube-system:tiller
```

#### helm init

```bash
helm init --service-account tiller
```

#### Test version

```bash
helm version
```

!!! Warning
    Currently, nginx ingress controller has an issue with Helm 2.14.
    So if you 2.14, either downgrade to 2.13.1 or install the Ingress Controller via an alternative solution (such as Kustomize).

### Ingress Controller

```bash
helm install --namespace ingress-nginx --name nginx-ingress stable/nginx-ingress \
    --set controller.service.externalTrafficPolicy=Local \
    --set controller.replicaCount=3 \
    --set rbac.create=true
```

#### Get LoadBalancer IP

```bash
export LB_IP=$(kubectl get svc -n ingress-nginx nginx-ingress-controller -o jsonpath="{.status.loadBalancer.ingress[0].ip}")
echo $LB_IP
```

!!! Warning
    Now is the time to configure your DNS to use whatever `LB_IP`'s value is.

### Cert Manager

[Cert Manager](https://github.com/jetstack/cert-manager) is the recommended approach for managing TLS certificates in Kubernetes. If you do not want to manage certificates yourself, please use this.

The certificates it uses are real and valid certificates, provided by [Let's Encrypt](https://letsencrypt.org/).

#### Install CRD's

```bash
kubectl apply -f https://raw.githubusercontent.com/jetstack/cert-manager/release-0.8/deploy/manifests/00-crds.yaml
```

#### Create Namespace

```bash
kubectl create namespace cert-manager
```

#### Label namespace

```bash
kubectl label namespace cert-manager certmanager.k8s.io/disable-validation=true
```

#### Add Helm Repo

```bash
helm repo add jetstack https://charts.jetstack.io
helm repo update
```

#### Install

```bash
helm install \
    --name cert-manager \
    --namespace cert-manager \
    --version v0.8.0 \
    jetstack/cert-manager
```