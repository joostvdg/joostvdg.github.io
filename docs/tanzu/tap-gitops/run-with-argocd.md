---
tags:
  - TKG
  - TAP
  - GitOps
  - Carvel
  - Tanzu
  - ArgoCD
---

title: TAP GitOps - TAP Run with ArgoCD
description: Tanzu Application Platform GitOps Installation with ArgoCD for deployment

# TAP Run with ArgoCD



## Setup Argo CD

```sh
kubectl apply -f argo-namespace.yaml
```

```sh
helm repo add argo https://argoproj.github.io/argo-helm
helm repo update
```

```sh
helm upgrade --install argocd argo/argo-cd \
  --namespace argocd \
  --wait \
  --version 5.46.7 \
  --values argocd-values.yaml
```

* release 2.8.7
* https://github.com/argoproj/argo-cd/releases
* use portfward instead of direct login

```sh
cp ~/Downloads/argocd-darwin-arm64 /Users/joostvdg/.local/bin/argocd
```

```sh
argocd login --insecure --port-forward --port-forward-namespace=argocd --plaintext --kube-context tap-01
```

```sh
argocd cluster list --port-forward --port-forward-namespace=argocd
```

```sh
SERVER                          NAME         VERSION  STATUS   MESSAGE                                                  PROJECT
https://kubernetes.default.svc  in-cluster            Unknown  Cluster has no applications and is not being monitored.
```

```sh
argocd cluster add tap-02 --port-forward --port-forward-namespace=argocd
```

!!! Warning
    > WARNING: This will create a service account `argocd-manager` on the cluster referenced by context `tap-02` with full cluster level privileges. Do you want to continue [y/N]?

```sh
SERVER                          NAME        VERSION  STATUS      MESSAGE                                                  PROJECT
https://10.220.10.38:6443       tap-02      1.26     Successful
https://kubernetes.default.svc  in-cluster           Unknown     Cluster has no applications and is not being monitored.
```

### Application

```sh
kubectl create namespace d1
kubectl label namespace d1 apps.tanzu.vmware.com/tap-ns=""
```

> Message:     failed to create typed patch object (d1/hello; serving.knative.dev/v1, Kind=Service): .spec.template.spec.containers[0].startupProbe: field not declared in schema

```yaml
  syncPolicy:
    syncOptions:
      - Validate=false
```

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: tap-apps-d1
  namespace: argocd
  labels:
    app.kubernetes.io/part-of: tap-hello-world
spec:
  destination:
    namespace: d1
    server: 'https://10.220.10.38:6443'
  source:
    path: config/d1/
    repoURL: 'http://gitlab.tap.h2o-2-19271.h2o.vmware.com/root/tap-apps.git'
    targetRevision: main
    directory:
      recurse: true
  sources: []
  project: default
  syncPolicy:
    syncOptions:
      - CreateNamespace=false                             
      - Validate=false
```