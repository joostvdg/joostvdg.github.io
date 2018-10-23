# CD Pipeline with Jenkins & Helm

## Prerequisites

* Kubernetes 1.9.x+ cluster
* Valid domain names
* Jenkins 2.x+ with pipeline plugins below
* Helm/Tiller

## Tools

* Jenkins 2.x

## Install Helm

For more information, [checkout the github page](https://github.com/helm/helm).

Helm's current version (as of October 2018) - version 2 - consists of two parts.
One is a local client - Helm - which you should install on your own machine, see [here](https://docs.helm.sh/using_helm/#installing-helm) for how.

The other is a server component part - Tiller - that should be installed in your Kubernetes cluster.

### Install Tiller

```bash
kubectl create serviceaccount tiller --namespace kube-system
```

* create rbac config: rbac-config.yaml

```yaml
apiVersion: v1
kind: ClusterRoleBinding
apiVersion: rbac.authorization.k8s.io/v1beta1
metadata:
  name: tiller-role-binding
roleRef:
  kind: ClusterRole
  name: cluster-admin
  apiGroup: rbac.authorization.k8s.io
subjects:
- kind: ServiceAccount
  name: tiller
  namespace: kube-system
```

```bash
kubectl apply -f rbac-config.yaml
helm init --service-account tiller
```

### install nging helm chart

```bash
helm install stable/nginx-ingress
```


## Jenkins Plugins

* Warnings Plugin: https://github.com/jenkinsci/warnings-plugin/blob/master/doc/Documentation.md
* Anchore: https://jenkins.io/blog/2018/06/20/anchore-image-scanning/

## Anchore

* https://github.com/anchore/anchore-engine
* https://github.com/helm/charts/tree/master/stable/anchore-engine
* https://wiki.jenkins.io/display/JENKINS/Anchore+Container+Image+Scanner+Plugin
