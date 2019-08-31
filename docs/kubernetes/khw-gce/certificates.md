title: Kubernetes The Hard Way (KHW) - Google Cloud 
description: Kubernetes The Hard Way - Certificates (3/11)
hero: Certificates (3/11)

# Certificates

!!! note
    Before we can continue here, we need to have our nodes up and running with their external ip addresses and our fixed public ip address.
    This is because some certificates require these external ip addresses!
    ```bash
    gcloud compute instances list
    gcloud compute addresses list --filter="name=('kubernetes-the-hard-way')"
    ```

We need to create a whole lot of certificates, listed below, with the help of [cfssl](https://github.com/cloudflare/cfssl).
A tool from CDN provider CloudFlare.

## Required certificates

* **CA** (or Certificate Authority): will be the root certificate of our trust chain
    * result: `ca.pem` & `ca-key.pem`
* **Admin**: the admin of our cluster (you!)
    * result: `admin-key.pem` & `admin.pem`
* **Kubelet**: the certificates of the kubelet processes on the worker nodes
    * result: 
    ```worker-0-key.pem 
    worker-0.pem 
    worker-1-key.pem 
    worker-1.pem 
    worker-2-key.pem 
    worker-2.pem
    ```
* **Controller Manager**
    * result: `kube-controller-manager-key.pem` & `kube-controller-manager.pem`
* **Scheduler**
    * result: `kube-scheduler-key.pem` & `kube-scheduler.pem`
* **API Server**
    * result `kubernetes-key.pem` & `kubernetes.pem`
* **Service Account**: ???
    * result: `service-account-key.pem` & `service-account.pem`

## Certificate example

Because we will use the `cfssl` tool from CloudFlare, we will define our certificate signing request (CSR's) in json.

```json
{
  "CN": "service-accounts",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "NL",
      "L": "Utrecht",
      "O": "Kubernetes",
      "OU": "Kubernetes The Hard Way",
      "ST": "Utrecht"
    }
  ]
}
```

## Install scripts

Make sure you're in `k8s-the-hard-way/scripts`

```bash
./certs.sh
```
