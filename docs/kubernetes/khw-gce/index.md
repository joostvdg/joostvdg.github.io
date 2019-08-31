title: Kubernetes The Hard Way (KHW) - Google Cloud 
description: Kubernetes The Hard Way - Introduction (1/11)
hero: Introduction (1/11)

# Kubernetes the Hard Way - GCE

This assumes OSX and GCE.

## Goal

The goal is to setup up HA Kubernetes cluster on GCE from it's most basic parts.
That means we will install and configure the basic components ourselves, such as the API server and Kubelets.

## Setup

As to limit the scope to doing the setup of the Kubernetes cluster ourselves, we will make it static.
That means we will create and configure the network and compute resources to be fit for 3 Control Plane VM's and 3 worker VM's.
We will not be able to recover a failing node or accomidate additional resources.

### Resources in GCE

* Public IP address, as front-end for the three API servers
* 3 VM's for the Control Plance
* 3 VM's as workers
* VPC
* Network Routes: from POD CIDR blocks to the host VM (for workers)
* Firewall configuration: allow health checks, dns, internal communication and connection to API server

### Kubernetes Resources

#### Control Plane

* **etcd**: stores cluster state
* **kube-api server**: entry point for interacting with the cluster by exposing the api
* **kube-scheduler**: makes sure pods get scheduled
* **kube-controller-manager**: aggregate of required controllers
  * **Node Controller**: > Responsible for noticing and responding when nodes go down.
  * **Replication Controller**:  > Responsible for maintaining the correct number of pods for every replication controller object in the system.
  * **Endpoints Controller**: > Populates the Endpoints object (that is, joins Services & Pods).
  * **Service Account & Token Controller**: > Create default accounts and API access tokens for new namespaces.

#### Worker nodes

* **kubelet**: > An agent that runs on each node in the cluster. It makes sure that containers are running in a pod.
* **kube-proxy**: > kube-proxy enables the Kubernetes service abstraction by maintaining network rules on the host and performing connection forwarding
* A container runtime: this can be `Docker`, `rkt` or as in our case `containerd`

## Network

* https://blog.csnet.me/k8s-thw/part1/
* https://github.com/kelseyhightower/kubernetes-the-hard-way

We will be using the network components - with Weave-Net and CoreDNS - as described in the csnet blog.
But we will use the CIDR blocks as stated in the Kelsey Hightower's Kubernetes the Hard Way (`KHW`).

### Kelsey's KHW


| Range         | Use                |
|-------------- |------------------- |
|10.240.0.10/24	| LAN (GCE VMS)      |
|10.200.0.0/16 	| k8s Pod network    |
|10.32.0.0/24 	| k8s Service network|
|10.32.0.1 	    | k8s API server     |
|10.32.0.10 	  | k8s dns            |

* API Server: https://127.0.0.1:6443
* service-cluster-ip-range=10.32.0.0/24
* cluster-cidr=10.200.0.0/1


### CSNETs

| Range         | Use                |
|-------------- |------------------- |
|10.32.2.0/24 	| LAN (csnet.me)     |
|10.16.0.0/16 	| k8s Pod network    |
|10.10.0.0/22 	| k8s Service network|
|10.10.0.1 	    | k8s API server     |
|10.10.0.10 	  | k8s dns            |

* API Server: https://10.32.2.97:6443
* service-cluster-ip-range=10.10.0.0/22
* cluster-cidr=10.16.0.0/16


## Install tools

On the machine doing the installation, we will need some tools installed.
We will use the following tools:

* **kubectl**: for communicating with the API server
* **cfssl**: for creating the certificates and sign them
* **helm**: for installing additional tools later
* **stern**: for viewing logs of multiple pods at once (for example, all kube-dns pods)
* **terraform**: for managing our resources in GCE

```bash
brew install kubernetes-cli
brew install cfssl
brew install kubernetes-helm
brew install stern
brew install terraform
```

### Check versions

```bash
kubectl version -c -o yaml
cfssl version
helm version -c --short
stern --version
terraform version
```

### Terraform remote storage

The help with problems of local storage and potential loss of data when local OS problems occur, 
we will use an S3 bucket as Terraform state storage.

* create s3 bucket
* configure Terraform to use this as remote state storage
* see how to this [here](https://medium.com/@jessgreb01/how-to-terraform-locking-state-in-s3-2dc9a5665cb6)
* read more about this, in [Terraform's docs](https://www.terraform.io/docs/backends/types/s3.html)

```bash
export AWS_ACCESS_KEY_ID="anaccesskey"
export AWS_SECRET_ACCESS_KEY="asecretkey"
export AWS_DEFAULT_REGION="eu-central-1"
```

```terraform
terraform {
  backend "s3" {
    bucket  = "euros-terraform-state"
    key     = "terraform.tfstate"
    region  = "eu-central-1"
    encrypt = "true"
  }
}

```

## GKE Service Account

Create a new GKE service account, and export it's json credentials file for use with Terraform.

See [GKE Tutorial page](https://cloud.google.com/docs/authentication/production) for how you can do this.