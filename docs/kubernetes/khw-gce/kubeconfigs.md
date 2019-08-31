title: Kubernetes The Hard Way (KHW) - Google Cloud 
description: Kubernetes The Hard Way - Prepare Kubeconfig (4/11)
hero: Kubeconfig (4/11)

# Kubeconfigs

Now that we have certificates we have to make sure we have configurations that the Kubernetes parts can actually use - certificates themselves are not enough.

This is where we will use kubernetes configuration files, or `kubeconfigs`.

We will have to create the following `kubeconfigs`:

* controller manager
* kubelet
* kube-proxy
* kube-scheduler
* admin user

## Create & Test kubeconfig file

Here's an example script:

```bash
kubectl config set-cluster kubernetes-the-hard-way \
    --certificate-authority=ca.pem \
    --embed-certs=true \
    --server=https://127.0.0.1:6443 \
    --kubeconfig=kube-controller-manager.kubeconfig

kubectl config set-credentials system:kube-controller-manager \
    --client-certificate=kube-controller-manager.pem \
    --client-key=kube-controller-manager-key.pem \
    --embed-certs=true \
    --kubeconfig=kube-controller-manager.kubeconfig

kubectl config set-context default \
    --cluster=kubernetes-the-hard-way \
    --user=system:kube-controller-manager \
    --kubeconfig=kube-controller-manager.kubeconfig

kubectl config use-context default --kubeconfig=kube-controller-manager.kubeconfig
```

The steps we execute in order are the following:

* create a kubeconfig entry for our `kubernetes-the-hard-way` cluster and export this into a `.kubeconfig` file
* add credentials to this config file, in the form of our kubernetes component's certificate
* set the default config of this config file to namespace `default` and user to the component we're configuring
* test the configuration file by using it

## Install scripts

Make sure you're in `k8s-the-hard-way/scripts`

```bash
./kube-configs.sh
```
