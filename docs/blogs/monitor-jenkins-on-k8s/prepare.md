title: Jenkins Kubernetes Monitoring
description: Monitoring Jenkins On Kubernetes - Prepare - 2/8
hero: Prepare - 2/8

# Prepare Environment

This is a guide on monitoring Jenkins on Kubernetes, which makes it rather handy to have a Kubernetes cluster at hand.

There are many ways to create a Kubernetes cluster, below is a guide on creating a cluster with Google Cloud's GKE.

Elsewhere on this site, there are alternatives, such as [Azure's AKS](kubernetes/distributions/aks-terraform/) and [AWS's EKS](kubernetes/distributions/eks-eksctl/).

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

Variables we need for the `gcloud` create cluster command. To make it easy to copy and paste the command.

```bash
K8S_VERSION=1.13.7-gke.8
REGION=europe-west4
CLUSTER_NAME=<your cluster name>
PROJECT_ID=<your google project id>
```

### Query available versions

If you want to see which versions are available in your Google Cloud Region, set the `REGION` variable and execute the command below.

The list you get back will contain two lists, one for `worker nodes` and one for `master nodes`. Only the versions for `master nodes` can be used to create a cluster.

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
    --labels=purpose=practice
```

### Set ClusterAdmin

For some later commands, such as Helm, we need to be ClusterAdmin.

```bash
kubectl create clusterrolebinding \
    cluster-admin-binding \
    --clusterrole cluster-admin \
    --user $(gcloud config get-value account)
```

## Install Ingress Controller

An ingress controller is what allows you to access the applications you install on your Kubernetes cluster from the outside. We need to do this for the tools we will use. So we need to install *an* ingress controller. Any will do, but `ingress-nginx` (based on the widely use `nginx` application) is the most commonly used. 

```bash
kubectl apply \
    -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/1cd17cd12c98563407ad03812aebac46ca4442f2/deploy/mandatory.yaml
```

```bash
kubectl apply \
    -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/1cd17cd12c98563407ad03812aebac46ca4442f2/deploy/provider/cloud-generic.yaml
```

For exposing our applications to the outside, we need to have a valid DNS name. For that, we need to have the IP address of our LoadBalancer. The command below retrieves that address. If it is empty, wait a few minutes and try again.

```bash
export LB_IP=$(kubectl -n ingress-nginx \
    get svc ingress-nginx \
    -o jsonpath="{.status.loadBalancer.ingress[0].ip}")

echo $LB_IP
```

!!! tip
	If you don't get an address back, check to see if your ingress controller has a service and that the service has an `EXTERNAL` IP address.
	```bash
	kubectl get svc -n ingress-nginx  -o wide
	```
	
	The response should look something like this:
	
	```
	NAME            TYPE           CLUSTER-IP    EXTERNAL-IP   PORT(S)                      AGE
	ingress-nginx   LoadBalancer   10.48.14.43   34.90.67.21   80:32762/TCP,443:31389/TCP   21d
	```

## Install Helm

Helm is a, or *the*, package manager for Kubernetes. We will use it to install the other applications. [Read more here](/kubernetes/tools/#helm).

```bash
kubectl create \
    -f https://raw.githubusercontent.com/vfarcic/k8s-specs/master/helm/tiller-rbac.yml \
    --record --save-config
```

Now that we've installed Helm, we can initialize the server component via a `helm init`.

```bash
helm init --service-account tiller
```

And now we wait.

```bash
kubectl -n kube-system \
    rollout status deploy tiller-deploy
```

## Install Cert-Manager

Cert-manager will help users automate installing TLS Certificates. [Read more about cert-manager here](/certificates/lets-encrypt-k8s/).

This creates the cert-manager specific resource definitions, also call `CustomerResourceDefinitions` or ***CRD***s. 

```bash
kubectl apply -f https://raw.githubusercontent.com/jetstack/cert-manager/release-0.8/deploy/manifests/00-crds.yaml
```

Due to how cert-manager works, it is best installed into its own namespace. There's a chicken and egg problem because it needs a Root Certificate Authority (or, RootCA) to exist, but every Certificate needs to be validated against this Certificate. Which is why we add the special label.

```bash
kubectl create namespace cert-manager
kubectl label namespace cert-manager certmanager.k8s.io/disable-validation=true
```

Now that the CRD's and the namespace are ready, we can install cert-manager. Well, almost. The Helm `Chart` - that is how we call Helm packages - is in another Castle, eh, Helm Repository. So we first have to tell Helm where to get the Chart.

```bash
helm repo add jetstack https://charts.jetstack.io
helm repo update
```

We can now install cert-manager via Helm!

```bash
helm install \
    --name cert-manager \
    --namespace cert-manager \
    --version v0.8.0 \
    jetstack/cert-manager
```

### Configure ClusterIssuer

Cert-manager can leverage Let's Encrypt to generate valid certificates. We need to instruct cert-manager which service to use, we do that by creating a `ClusterIssuer` resource.

```bash
kubectl apply -f cluster-issuer.yaml
```

??? example "cluster-issuer.yaml"
	Don't forget to replace `<replacewith your email address>` with an actual email address you can access.
	
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
