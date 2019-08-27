# Prepare Environment

This is a guide on monitoring Jenkins on Kubernetes, which makes it rather handy to have a Kubernetes cluster at hand.

There are many ways to create a Kubernetes cluster, below is a guide on creating a cluster with Google Cloud's GKE.

Elsewhere on this site, there are alternatives, such as [Azure's AKS](/kubernetes/distributions/aks-terraform/) and [AWS's EKS](/kubernetes/distributions/eks-eksctl/).

## Things To Do

* create a cluster
* install and configure Helm
	* for easily installing other applications on the cluster
* install and configure Certmanager
	* for managing TLS certificates with Let's Encrypt

## Create GKE Cluster

Enough talk about what we should be doing, let's create the cluster!

### Prerequisites

* [gcloud](https://cloud.google.com/sdk/gcloud/) command-line utility
* Google Cloud account that is activated

### Variables

```bash
K8S_VERSION=1.13.7-gke.8
REGION=europe-west4
CLUSTER_NAME=<your cluster name>
PROJECT_ID=<your google project id>
```

### Query available versions

```bash
gcloud container get-server-config --region $REGION
```

### Create Cluster

```bash
gcloud container clusters create ${CLUSTER_NAME} \
    --region ${REGION} \
    --cluster-version ${K8S_VERSION} \
    --num-nodes 2 --machine-type n1-standard-2 \
    --addons=HorizontalPodAutoscaling \
    --min-nodes 2 --max-nodes 3 \
    --enable-autoupgrade \
    --enable-autoscaling \
    --enable-network-policy \
    --labels=owner=jvandergriendt,purpose=practice
```

### Set ClusterAdmin

```bash
kubectl create clusterrolebinding \
    cluster-admin-binding \
    --clusterrole cluster-admin \
    --user $(gcloud config get-value account)
```

## Install Ingress Controller

```bash
kubectl apply \
    -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/1cd17cd12c98563407ad03812aebac46ca4442f2/deploy/mandatory.yaml

kubectl apply \
    -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/1cd17cd12c98563407ad03812aebac46ca4442f2/deploy/provider/cloud-generic.yaml
```

```bash
export LB_IP=$(kubectl -n ingress-nginx \
    get svc ingress-nginx \
    -o jsonpath="{.status.loadBalancer.ingress[0].ip}")

echo $LB_IP
```

## Install Helm

```bash
kubectl create \
    -f https://raw.githubusercontent.com/vfarcic/k8s-specs/master/helm/tiller-rbac.yml \
    --record --save-config

helm init --service-account tiller

kubectl -n kube-system \
    rollout status deploy tiller-deploy
```

## Install Cert-Manager

```bash
kubectl apply -f https://raw.githubusercontent.com/jetstack/cert-manager/release-0.8/deploy/manifests/00-crds.yaml
```

```bash
kubectl create namespace cert-manager
kubectl label namespace cert-manager certmanager.k8s.io/disable-validation=true
```

```bash
helm repo add jetstack https://charts.jetstack.io
helm repo update
```

```bash
helm install \
    --name cert-manager \
    --namespace cert-manager \
    --version v0.8.0 \
    jetstack/cert-manager
```

### Configure ClusterIssuer

```bash
kubectl apply -f cluster-issuer.yaml
```

```yaml
apiVersion: certmanager.k8s.io/v1alpha1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    email: <replacewith your email address>
    server: https://acme-v02.api.letsencrypt.org/directory
    privateKeySecretRef:
      name: letsencrypt-prod
    http01: {}
```
