# Kubernetes Tools

## Kuard

[Kuard](https://github.com/kubernetes-up-and-running/kuard) is a small demo application to show your cluster works.
Also exposes some info you might want to see.

```bash
kubectl run --restart=Never --image=gcr.io/kuar-demo/kuard-amd64:blue kuard
kubectl port-forward kuard 8080:8080
```

Open your browser to http://localhost:8080.

## Stern

[Stern](https://github.com/wercker/stern) allows you to `tail` multiple pods on Kubernetes and multiple containers within the pod. Each result is color coded for quicker debugging.

```bash
brew install stern
```

### Usage

Imagine a build in Jenkins using more than one container in the Pod.
You want to tail the logs of all containers... you can with stern.

```bash
stern maven-
```

## Kube Capacity

[Kube Capacity](https://github.com/robscott/kube-capacity) is a simple CLI that provides an overview of the resource requests, limits, and utilization in a Kubernetes cluster.

```bash
brew tap robscott/tap
brew install robscott/tap/kube-capacity
```

```bash
kube-capacity
```

```bash
NODE              CPU REQUESTS    CPU LIMITS    MEMORY REQUESTS    MEMORY LIMITS
*                 560m (28%)      130m (7%)     572Mi (9%)         770Mi (13%)
example-node-1    220m (22%)      10m (1%)      192Mi (6%)         360Mi (12%)
example-node-2    340m (34%)      120m (12%)    380Mi (13%)        410Mi (14%)
```

```bash
kube-capacity --pods
```

```bash
NODE              NAMESPACE     POD                   CPU REQUESTS    CPU LIMITS    MEMORY REQUESTS    MEMORY LIMITS
*                 *             *                     560m (28%)      780m (38%)    572Mi (9%)         770Mi (13%)

example-node-1    *             *                     220m (22%)      320m (32%)    192Mi (6%)         360Mi (12%)
example-node-1    kube-system   metrics-server-lwc6z  100m (10%)      200m (20%)    100Mi (3%)         200Mi (7%)
example-node-1    kube-system   coredns-7b5bcb98f8    120m (12%)      120m (12%)    92Mi (3%)          160Mi (5%)

example-node-2    *             *                     340m (34%)      460m (46%)    380Mi (13%)        410Mi (14%)
example-node-2    kube-system   kube-proxy-3ki7       200m (20%)      280m (28%)    210Mi (7%)         210Mi (7%)
example-node-2    tiller        tiller-deploy         140m (14%)      180m (18%)    170Mi (5%)         200Mi (7%)
```

```bash
kube-capacity --util
```

```bash
NODE              CPU REQUESTS    CPU LIMITS    CPU UTIL    MEMORY REQUESTS    MEMORY LIMITS   MEMORY UTIL
*                 560m (28%)      130m (7%)     40m (2%)    572Mi (9%)         770Mi (13%)     470Mi (8%)
example-node-1    220m (22%)      10m (1%)      10m (1%)    192Mi (6%)         360Mi (12%)     210Mi (7%)
example-node-2    340m (34%)      120m (12%)    30m (3%)    380Mi (13%)        410Mi (14%)     260Mi (9%)
```

```bash
kube-capacity --pods --util
```

## Velero

[Velero](https://github.com/heptio/velero) 

## RBAC Lookup

[RBAC Lookup](https://github.com/reactiveops/rbac-lookup) 

### Install

``` bash tab="bash"
brew install reactiveops/tap/rbac-lookup
```

``` bash tab="Krew"
kubectl krew install rbac-lookup
```

### Lookup user

```bash
rbac-lookup jvandergriendt -owide
```

### Lookup GKE user

```bash
rbac-lookup jvandergriendt  --gke
```

## K9S

[K9S](https://github.com/derailed/k9s) is a tool that gives you a console UI on your kubernetes cluster/namespace.

### Install

```bash
brew tap derailed/k9s && brew install k9s
```

### Use

By default is looks at a single namespace, and allows you to view elements of the pods running.

```bash
k9s -n cje
```