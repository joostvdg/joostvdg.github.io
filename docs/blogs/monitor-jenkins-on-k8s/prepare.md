# Prepare Environment

## Create GKE Cluster

### Variables

```bash
REGION=europe-west4
CLUSTER_NAME=joostvdg-2019-08-1
K8S_VERSION=1.13.7-gke.8
REGION=europe-west4
PROJECT_ID=
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
