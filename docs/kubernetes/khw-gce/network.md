title: Kubernetes The Hard Way (KHW) - Google Cloud 
description: Kubernetes The Hard Way - Networking (10/11)
hero: Configure Networking (10/11)

# Networking

First, [configure external access](#remote-access) so we can run `kubectl` commands from our own machine.

Confirm the you can now call the following:

```bash
kubectl get nodes -o wide
```

## Configure WeaveNet

```bash
kubectl apply -f "https://cloud.weave.works/k8s/net?k8s-version=$(kubectl version | base64 | tr -d '\n')&env.IPALLOC_RANGE=10.200.0.0/16"
```

### Confirm WeaveNet works

```bash
kubectl get pod --namespace=kube-system -l name=weave-net
```

It should look like this:

```bash
NAME              READY     STATUS    RESTARTS   AGE
weave-net-fwvsr   2/2       Running   1          4h
weave-net-v9z9n   2/2       Running   1          4h
weave-net-zfghq   2/2       Running   1          4h
```

## Configure CoreDNS

Before installing `CoreDNS`, please confirm networking is in order.

```bash
kubectl get nodes -o wide
```

!!! warning
    If nodes are not `Ready`, something is wrong and needs to be fixed before you continue.

```bash
kubectl apply -f ../configs/core-dns-config.yaml
```

### Confirm CoreDNS pods

```bash
kubectl get pod --all-namespaces -l k8s-app=coredns -o wide
```

## Confirm DNS works

```bash
kubectl run busybox --image=busybox:1.28 --command -- sleep 3600
```

```bash
POD_NAME=$(kubectl get pods -l run=busybox -o jsonpath="{.items[0].metadata.name}")
```

```bash
kubectl exec -ti $POD_NAME -- nslookup kubernetes
```

!!! note
    It should look like this:
    ```bash
    Server:    10.10.0.10
    Address 1: 10.10.0.10 kube-dns.kube-system.svc.cluster.local

    Name:      kubernetes
    Address 1: 10.10.0.1 kubernetes.default.svc.cluster.local
    ```