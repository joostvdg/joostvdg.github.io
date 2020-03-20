title: WIP- Jenkins X OpenShift 3.11 - Restricted
description:  WIP - Installing Jenkins X on RedHat OpenShift 3.11 on GCP with restricted access

# WIP Jenkins X on RedHat OpenShift 3.11 Restricted

!!! important
    This guide is still a Work In Progress (WIP). The guide is not - yet - complete in its ability to install Jenkins X without Cluster Administrative access. Do come back in the future!

    ps. at the bottom it should say when this guide was last updated

Why Jenkins X on RedHat OpenShift 3.11?
Well, not everyone can use public cloud solutions.

So, in order to help out those running OpenShift 3.11 and want to leverage Jenkins X, read along.
Unlike the other guide, [Jenkins X on OpenShift (minimal)](/jenkinsx/rhos-311-minimal/), in th

!!! note
    This guide is written early March 2020, using `jx` version `2.0.1212` and OpenShift version `v3.11.170`.
    
    The OpenShift used is [installed on GCP](/openshift/rhos311-gcp-medium/),  with some shortcuts taken. 

## Pre-requisites

* [jx binary](https://jenkins-x.io/docs/getting-started/setup/install/)
* kubectl is 1.16.x or less
* Helm v2
* running OpenShift 3.11 cluster
    * with cluster admin access (will update how to avoid this)
* GitHub or Bitbucket account - the installation doesn't progress far enough yet for this to matter

If you're like me, you're likely managing your packages via a package manager such as Homebrew or Chocolatey.
This means you might run newer versions of Helm and kubectl and need to downgrade them. See below how!

!!! caution
    If you run this in an on-premises solution or otherwise cannot contact GitHub, you have to use [Lighthouse](/jenkinsx/lighthouse-bitbucket/) for managing the webhooks.

    As of March 2020, the support for Bitbucket Server is missing some features [read here on what you can about that](). 
    Meanwhile, we suggest you either use GitHub Enterprise or GitLab as alternatives with better support.

### Temporarily set Helm V2

Download Helm v2 release from [Helms GitHub Releases page](https://github.com/helm/helm/releases/tag/v2.16.3).

Place the binary somewhere, for example `$HOME/Resource/helm2`.
Then set your path with the location of Helm v2 first, before including the whole path to ensure Helm v2 is found first.

```bash
PATH=$HOME/Resources/helm2:$PATH
```

Ensure you're now running helm 2 by the command below:

```bash
helm version --client
```

It should show this:

```bash
Client: &version.Version{SemVer:"v2.16.1", GitCommit:"bbdfe5e7803a12bbdf97e94cd847859890cf4050", GitTreeState:"clean"}
```

### Downgrade Kubctl

Downgrade kubectl (need lower than 1.17):

```bash
curl -LO https://storage.googleapis.com/kubernetes-release/release/v1.16.7/bin/darwin/amd64/kubectl
chmod +x ./kubectl
sudo mv ./kubectl /usr/local/bin/kubectl
```

To confirm your kubectl version is as expected, run the command below:

```bash
kubectl version --client
```

The output should be as follows:

```bash
Client Version: version.Info{Major:"1", Minor:"16", GitVersion:"v1.16.7", GitCommit:"be3d344ed06bff7a4fc60656200a93c74f31f9a4", GitTreeState:"clean", BuildDate:"2020-02-11T19:34:02Z", GoVersion:"go1.13.6", Compiler:"gc", Platform:"darwin/amd64"}
```

## Install Via Boot

The current (as of March 2020) recommended way of installing Jenkins X, is via [jx boot](https://jenkins-x.io/docs/getting-started/setup/boot/).

### Process

WIP

### Config

WIP

## Issues Encountered

* jx could not get YAML from GitHub for alpha plugins
* requires `kubectl` with access to the Kubernetes
    * if in OpenShift, first do a `oc login` 
* have to manually clone the Jenkins X repositories, no direct access to GitHub
    * jx version
    * https://github.com/jenkins-x/jenkins-x-versions.git
    * `~/.jx/jenkins-x-versions`
    * jx boot config
    * https://github.com/jenkins-x/jenkins-x-boot-config.git
* storage option: 
    * only local option is git server , but that seems to run into issues
    * NFS would be the best option, but it doesn't exist
* make sure kubectl has login config from OC
    * https://blog.christianposta.com/kubernetes/logging-into-a-kubernetes-cluster-with-kubectl/
* RBAC issues
    * tries to access `kube-system` namespace
    * install JX CRD's
    * create service accounts, RBAC config (roles, role bindings, cluster roles, cluser role binding)
    * create namespaces
    * list all namespaces, this is a check to see if we are connected to a Kubernetes cluster, seems overly broad
    * label a namespace

### JX Binary requests YAML from GitHub

```bash
-bash-4.4$ jx version
WARNING: failed to discover alpha commands from github: failed to get YAML from https://raw.githubusercontent.com/jenkins-x-labs/jxl/master/alpha/plugins.yml: Get https://raw.githubusercontent.com/jenkins-x-labs/jxl/master/alpha/plugins.yml: dial tcp 151.101.112.133:443: connectex: No connection could be made because the target machine actively refused it.
```

### JX Version

Warnings

```bash
WARNING: Failed to retrieve team settings: failed to create the jx-development-dev Dev namespace: Failed to label Namespace jx-development-dev namespaces "jx-development-dev" is forbidden: User "tk9at" cannot update namespaces in the namespace "jx-development-dev": no RBAC policy matched - falling back to default settings...
WARNING: Failed to find helm installs: running helm list --all --namespace jx-development-dev: failed to run 'helm list --all --namespace jx-development-dev' command in directory '', output: 'Error: pods is forbidden: User "tk9at" cannot list pods in the namespace "kube-system": no RBAC policy matched'
WARNING: Fail
```

```bash
NAME               VERSION
jx                 2.0.1242
Kubernetes cluster v1.11.0+d4cacc0
git                2.24.0.windows.2
Operating System   Windows 7 Enterprise unkown release build 7601
```

### JX boot issues

```bash
WARNING: failed to discover alpha commands from github: failed to get YAML from https://raw.githubusercontent.com/jenkins-x-labs/jxl/master/alpha/plugins.yml: Get https://raw.githubusercontent.com/jenkins-x-labs/jxl/master/alpha/plugins.yml: dial tcp 151.101.112.133:443: connectex: No connection could be made because the target machine actively refused it.
```

## RBAC Issues

### Rights Required

* list namespaces
* list pods
* list configmaps
* create namespaces
* get namespace (although if you can get only your own, that is ok!)
* label namespace
* create RBAC resources

### Lazily Create Namespace jx

Even if it exists, it tries to create the namespace `jx`.

```bash
error: failed to lazily create the namespace jx: Failed to create Namespace jx namespaces is forbidden: User "six" cannot create namespaces at the cluster scope: no RBAC policy matched
error: failed to interpret pipeline file jenkins-x.yml: failed to run '/bin/sh -c jx step verify preinstall --provider-values-dir="kubeProviders"' command in directory '.', output: ''
```

### jx version

```bash
jx version
```

```bash
error: namespaces "jx" is forbidden: User "myuser" cannot get namespaces in the namespace "jx": no RBAC policy matched
```

### Issue with jx boot startup

The `jx boot` process tries to verify our connect to a live Kubernetes environment. 
It does so, by doing a `kubectl get namespaces` API call at [pkg/cmd/boot/boot.go](https://github.com/jenkins-x/jx/blob/master/pkg/cmd/boot/boot.go#L572).

Unfortunately, this is a very broad cluster wide permission, which is many OpenShift environments is not allowed.

Current code:

```go
#pkg/cmd/boot/boot.go
func (o *BootOptions) verifyClusterConnection() error {
    client, err := o.KubeClient()
    if err == nil {
        _, err = client.CoreV1().Namespaces().List(metav1.ListOptions{})
    }
    ...
}
```

This is a potential solution:

```go
#pkg/cmd/boot/boot.go
func (o *BootOptions) verifyClusterConnection() error {
	client, curNs, err := o.KubeClientAndNamespace()
	if err == nil {
		_, err = client.CoreV1().Pods(curNs).List(metav1.ListOptions{})
    }
    ...
}
```

### Issue with swallowing jx requirement errors

If you make a mistake in the `jx-requirements.yml`, the parsing errors are swallowed.
Instead, you get a generic error that makes no sense.

```bash
error: unable to load jx-requirements.yml (from .): jx-requirements.yml file not found
```

```go
# config/install_requirements.go 
func LoadRequirementsConfig(dir string) (*RequirementsConfig, string, error) {
    ....
    # this line overrides any error previously found
    return nil, "", errors.New("jx-requirements.yml file not found")
}
```

### Verify Storage

```bash
Verifying Storage...
error: failed to ensure the bucket URL https://bitbucket.apps.ocp.kearos.net/scm/jx/build-logs.git is created: EnsureBucketIsCreated not implemented for LegacyBucketProvider
error: failed to interpret pipeline file jenkins-x.yml: failed to run '/bin/sh -c jx step verify preinstall --provider-values-dir="kubeProviders"' command in directory '.', output: ''
```

Seems we cannot combine storage in Bitbucket Server together with logs as the start:

```yaml
storage:
  logs:
    enabled: true
    url: "http://bitbucket.openshift.example.com/scm/jx/build-logs.git"
```

Workaround:

* create with logs disabled
* then enable via command below

```bash
jx edit storage -c logs --git-url http://bitbucket.openshift.example.com/scm/jx/build-logs.git  --git-branch master
```

### Label Namespace

```bash
error: failed to lazily create the namespace jx: Failed to label Namespace jx namespaces "jx" is forbidden: User "myuser" cannot update namespaces in the namespace "jx": no RBAC policy matched
error: failed to interpret pipeline file jenkins-x.yml: failed to run '/bin/sh -c jx step verify preinstall --provider-values-dir="kubeProviders"' command in directory '.', output: ''
```

### Install Velero, even if disabled

```bash
STEP: install-velero command: /bin/sh -c jx step helm apply --boot --remote --no-vault --name velero in dir: /Users/joostvdg/Projects/Personal/Github/jenkins-examples/jx/openshift/311-2/jxboot-bs/jenkins-x-boot-config/systems/velero

Modified file /Users/joostvdg/Projects/Personal/Github/jenkins-examples/jx/openshift/311-2/jxboot-bs/jenkins-x-boot-config/systems/velero/Chart.yaml to set the chart to version 1
error: Failed to create Namespace velero namespaces is forbidden: User "six" cannot create namespaces at the cluster scope: no RBAC policy matched
error: failed to interpret pipeline file jenkins-x.yml: failed to run '/bin/sh -c jx step helm apply --boot --remote --no-vault --name velero' command in directory 'systems/velero', output: ''
```

Solution, disable steps `install-velero` and `install-velero-backups` in pipeline `jenkins-x.yml`.

### Install nginx controller

This is not required, as OpenShift already has the route controller.
So disabling nginx installation is a solution, step `install-nginx-controller` in `jenkins-x.yml`.

```bash
STEP: install-nginx-controller command: /bin/sh -c jx step helm apply --boot --remote --no-vault --name jxing in dir: /Users/joostvdg/Projects/Personal/Github/jenkins-examples/jx/openshift/311-2/jxboot-bs/jenkins-x-boot-config/systems/jxing

Modified file /Users/joostvdg/Projects/Personal/Github/jenkins-examples/jx/openshift/311-2/jxboot-bs/jenkins-x-boot-config/systems/jxing/Chart.yaml to set the chart to version 1
error: Failed to create Namespace kube-system namespaces is forbidden: User "six" cannot create namespaces at the cluster scope: no RBAC policy matched
error: failed to interpret pipeline file jenkins-x.yml: failed to run '/bin/sh -c jx step helm apply --boot --remote --no-vault --name jxing' command in directory 'systems/jxing', output: ''
```

### Installing cert manager

This is not required, so we can disable steps `install-cert-manager-crds` and `install-cert-manager` in `jenkins-x.ym`.  And even if we wanted to use cert manager, we would have to install a specific version for RHOS 3.11.[^21]

### Installing JX CRD's

```bash
STEP: install-jx-crds command: /bin/sh -c jx upgrade crd in dir: /Users/joostvdg/Projects/Personal/Github/jenkins-examples/jx/openshift/311-2/jxboot-bs/jenkins-x-boot-config

Error creating commitstatuses.jenkins.io: customresourcedefinitions.apiextensions.k8s.io is forbidden: User "six" cannot create customresourcedefinitions.apiextensions.k8s.io at the cluster scope: no RBAC policy matched
```

Let and Admin install these and disable pipeline step?

* admin has to execute `jx upgrade crd`
* remove step `install-jx-crds` from `jenkins-x.yml`

## RBAC Resources

### Role for namespaces

```bash
oc apply -f jx-install-role.yml -n jx
oc adm policy add-role-to-user jx-install six --role-namespace jx
```

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  namespace: jx
  name: jx-install
rules:
- apiGroups: [""] # "" indicates the core API group
  resources: ["pods", "secrets", "configmaps", "pods/log", "services", "endpoints"]
  verbs: ["get", "watch", "list", "create", "update", "patch", "delete"]
- apiGroups: ["extensions", "apps"]
  resources: ["deployments"]
  verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
```

### Namespaces

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: jx
  labels:
    jenkins.io/created-by: "jx-boot"
    env: "dev"
    team: "jx"
```

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: jx-staging
  labels:
    jenkins.io/created-by: "jx-boot"
    env: "staging"
    team: "jx"
```

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: jx-production
  labels:
    jenkins.io/created-by: "jx-boot"
    env: "production"
    team: "jx"
```

### Jenkins X API Role

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  namespace: jx
  name: jx-api-install
rules:
- apiGroups: ["jenkins.io"] # "" indicates the core API group
  resources: ["*"]
  verbs: ["*"]
```

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: myuser-jx-api-install
  namespace: jx
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: jx-api-install
subjects:
- apiGroup: rbac.authorization.k8s.io
  kind: User
  name: myuser
  namespace: jx
```

### Service Accounts

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: jenkins-x-bucketrepo
  namespace: jx
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: jenkins-x-controllerbuild
  namespace: jx
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: jenkins-x-controllerrole
  namespace: jx
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: jenkins-x-gcactivities
  namespace: jx
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: jenkins-x-gcpods
  namespace: jx
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: jenkins-x-gcpreviews
  namespace: jx
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: jenkins-x-heapster
  namespace: jx
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: jenkins
  namespace: jx
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: jenkins-x-lighthouse
  namespace: jx
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: tide
  namespace: jx
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: tekton-pipelines
  namespace: jx
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: tekton-bot
  namespace: jx
```

### Jenkins X RBAC List


#### Roles

* controllerbuild
* controllerrole
* gcactivities
* gcpods
* gcpreviews
* jenkins-x-heapster-pod-nanny
* committer
    * https://raw.githubusercontent.com/jenkins-x/jenkins-x-platform/master/jenkins-x-platform/templates/committer-role.yaml
    * https://github.com/jenkins-x/jenkins-x-platform/blob/master/jenkins-x-platform/templates/committer-role.yaml
* jx-view
    * https://github.com/jenkins-x/jenkins-x-platform/blob/master/jenkins-x-platform/templates/jx-view-role.yaml
* owner 
    * https://github.com/jenkins-x/jenkins-x-platform/blob/master/jenkins-x-platform/templates/owner-role.yaml
    * https://raw.githubusercontent.com/jenkins-x/jenkins-x-platform/master/jenkins-x-platform/templates/owner-role.yaml
* viewer 
    * https://github.com/jenkins-x/jenkins-x-platform/blob/master/jenkins-x-platform/templates/viewer-role.yaml
    * https://raw.githubusercontent.com/jenkins-x/jenkins-x-platform/master/jenkins-x-platform/templates/viewer-role.yaml
* jenkins-x-lighthouse
* tide
* tekton-bot

#### Role Bindings

* controllerbuild
* controllerrole
* gcactivities
* gcpods
* gcpreviews
* jenkins-x-heapster-pod-nanny
* jenkins-x-lighthouse
* tide
* tekton-bot

#### Ingress

* hook
* chartmuseum

#### Cluster Role Bindings

* controllerbuild-jx
* controllerrole-jx
* gcactivities-jx
* gcpreviews-jx
* jenkins-x-heapster
* jenkins-jx-role-binding
* tekton-pipelines-jx

#### Jenkins X Resources

* Releases (jenkins.io/v1, releases)
    * controllerbuild-2.0.1243 (depends on jx version?!)
    * controllerrole-2.0.1243
    * gcactivities-2.0.1243
    * gcpods-2.0.1243
    * gcpreviews-2.0.1243
* Schedulers ("jenkins.io/v1, Resource=schedulers")
    * default-scheduler 
    * env-scheduler 
    * pr-only 
    * release-only

#### List Of Resources Failed To Be Created

* Resource: "/v1, Resource=serviceaccounts", GroupVersionKind: "/v1, Kind=ServiceAccount"
* Name: "jenkins-x-bucketrepo", Namespace: "jx"

* Resource: "rbac.authorization.k8s.io/v1, Resource=clusterrolebindings", GroupVersionKind: "rbac.authorization.k8s.io/v1, Kind=ClusterRoleBinding"
* Name: "controllerbuild-jx", Namespace: ""

* Resource: "jenkins.io/v1, Resource=releases", GroupVersionKind: "jenkins.io/v1, Kind=Release"
* Name: "controllerbuild-2.0.1243", Namespace: "jx"

* Resource: "rbac.authorization.k8s.io/v1, Resource=roles", GroupVersionKind: "rbac.authorization.k8s.io/v1, Kind=Role"
* Name: "controllerbuild", Namespace: "jx"

* Resource: "rbac.authorization.k8s.io/v1, Resource=rolebindings", GroupVersionKind: "rbac.authorization.k8s.io/v1, Kind=RoleBinding"
* Name: "controllerbuild", Namespace: "jx"

* Resource: "/v1, Resource=serviceaccounts", GroupVersionKind: "/v1, Kind=ServiceAccount"
* Name: "jenkins-x-controllerbuild", Namespace: "jx"

* Resource: "rbac.authorization.k8s.io/v1, Resource=clusterrolebindings", GroupVersionKind: "rbac.authorization.k8s.io/v1, Kind=ClusterRoleBinding"
* Name: "controllerrole-jx", Namespace: ""

* Resource: "jenkins.io/v1, Resource=releases", GroupVersionKind: "jenkins.io/v1, Kind=Release"
* Name: "controllerrole-2.0.1243", Namespace: "jx"

* Resource: "rbac.authorization.k8s.io/v1, Resource=roles", GroupVersionKind: "rbac.authorization.k8s.io/v1, Kind=Role"
* Name: "controllerrole", Namespace: "jx"

* Resource: "rbac.authorization.k8s.io/v1, Resource=rolebindings", GroupVersionKind: "rbac.authorization.k8s.io/v1, Kind=RoleBinding"
* Name: "controllerrole", Namespace: "jx"

* Resource: "/v1, Resource=serviceaccounts", GroupVersionKind: "/v1, Kind=ServiceAccount"
* Name: "jenkins-x-controllerrole", Namespace: "jx"

* Resource: "rbac.authorization.k8s.io/v1, Resource=clusterrolebindings", GroupVersionKind: "rbac.authorization.k8s.io/v1, Kind=ClusterRoleBinding"
* Name: "gcactivities-jx", Namespace: ""

* Resource: "batch/v1beta1, Resource=cronjobs", GroupVersionKind: "batch/v1beta1, Kind=CronJob"
* Name: "jenkins-x-gcactivities", Namespace: "jx"

* Resource: "jenkins.io/v1, Resource=releases", GroupVersionKind: "jenkins.io/v1, Kind=Release"
* Name: "gcactivities-2.0.1243", Namespace: "jx"

* Resource: "rbac.authorization.k8s.io/v1, Resource=roles", GroupVersionKind: "rbac.authorization.k8s.io/v1, Kind=Role"
* Name: "gcactivities", Namespace: "jx"

* Resource: "rbac.authorization.k8s.io/v1, Resource=rolebindings", GroupVersionKind: "rbac.authorization.k8s.io/v1, Kind=RoleBinding"
* Name: "gcactivities", Namespace: "jx"

* Resource: "/v1, Resource=serviceaccounts", GroupVersionKind: "/v1, Kind=ServiceAccount"
* Name: "jenkins-x-gcactivities", Namespace: "jx"

* Resource: "batch/v1beta1, Resource=cronjobs", GroupVersionKind: "batch/v1beta1, Kind=CronJob"
* Name: "jenkins-x-gcpods", Namespace: "jx"

* Resource: "jenkins.io/v1, Resource=releases", GroupVersionKind: "jenkins.io/v1, Kind=Release"
* Name: "gcpods-2.0.1243", Namespace: "jx"

* Resource: "rbac.authorization.k8s.io/v1, Resource=roles", GroupVersionKind: "rbac.authorization.k8s.io/v1, Kind=Role"
* Name: "gcpods", Namespace: "jx"

* Resource: "rbac.authorization.k8s.io/v1, Resource=rolebindings", GroupVersionKind: "rbac.authorization.k8s.io/v1, Kind=RoleBinding"
* Name: "gcpods", Namespace: "jx"

* Resource: "/v1, Resource=serviceaccounts", GroupVersionKind: "/v1, Kind=ServiceAccount"
* Name: "jenkins-x-gcpods", Namespace: "jx"

* Resource: "rbac.authorization.k8s.io/v1, Resource=clusterrolebindings", GroupVersionKind: "rbac.authorization.k8s.io/v1, Kind=ClusterRoleBinding"
* Name: "gcpreviews-jx", Namespace: ""

* Resource: "batch/v1beta1, Resource=cronjobs", GroupVersionKind: "batch/v1beta1, Kind=CronJob"
* Name: "jenkins-x-gcpreviews", Namespace: "jx"

* Resource: "jenkins.io/v1, Resource=releases", GroupVersionKind: "jenkins.io/v1, Kind=Release"
* Name: "gcpreviews-2.0.1243", Namespace: "jx"

* Resource: "rbac.authorization.k8s.io/v1, Resource=roles", GroupVersionKind: "rbac.authorization.k8s.io/v1, Kind=Role"
* Name: "gcpreviews", Namespace: "jx"

* Resource: "rbac.authorization.k8s.io/v1, Resource=rolebindings", GroupVersionKind: "rbac.authorization.k8s.io/v1, Kind=RoleBinding"
* Name: "gcpreviews", Namespace: "jx"

* Resource: "/v1, Resource=serviceaccounts", GroupVersionKind: "/v1, Kind=ServiceAccount"
* Name: "jenkins-x-gcpreviews", Namespace: "jx"

* Resource: "rbac.authorization.k8s.io/v1beta1, Resource=clusterrolebindings", GroupVersionKind: "rbac.authorization.k8s.io/v1beta1, Kind=ClusterRoleBinding"
* Name: "jenkins-x-heapster", Namespace: ""

* Resource: "rbac.authorization.k8s.io/v1beta1, Resource=roles", GroupVersionKind: "rbac.authorization.k8s.io/v1beta1, Kind=Role"
* Name: "jenkins-x-heapster-pod-nanny", Namespace: "jx"

* Resource: "rbac.authorization.k8s.io/v1beta1, Resource=rolebindings", GroupVersionKind: "rbac.authorization.k8s.io/v1beta1, Kind=RoleBinding"
* Name: "jenkins-x-heapster-pod-nanny", Namespace: "jx"

* Resource: "/v1, Resource=serviceaccounts", GroupVersionKind: "/v1, Kind=ServiceAccount"
* Name: "jenkins-x-heapster", Namespace: "jx"

* Resource: "/v1, Resource=persistentvolumeclaims", GroupVersionKind: "/v1, Kind=PersistentVolumeClaim"
* Name: "jenkins", Namespace: "jx"

* Resource: "rbac.authorization.k8s.io/v1beta1, Resource=clusterrolebindings", GroupVersionKind: "rbac.authorization.k8s.io/v1beta1, Kind=ClusterRoleBinding"
* Name: "jenkins-jx-role-binding", Namespace: ""

* Resource: "/v1, Resource=serviceaccounts", GroupVersionKind: "/v1, Kind=ServiceAccount"
* Name: "jenkins", Namespace: "jx"

* Resource: "rbac.authorization.k8s.io/v1, Resource=roles", GroupVersionKind: "rbac.authorization.k8s.io/v1, Kind=Role"
* Name: "committer", Namespace: "jx"

* Resource: "rbac.authorization.k8s.io/v1, Resource=roles", GroupVersionKind: "rbac.authorization.k8s.io/v1, Kind=Role"
* Name: "jx-view", Namespace: "jx"

* Resource: "rbac.authorization.k8s.io/v1, Resource=roles", GroupVersionKind: "rbac.authorization.k8s.io/v1, Kind=Role"
* Name: "owner", Namespace: "jx"

* Resource: "rbac.authorization.k8s.io/v1, Resource=roles", GroupVersionKind: "rbac.authorization.k8s.io/v1, Kind=Role"
* Name: "viewer", Namespace: "jx"

* Resource: "/v1, Resource=namespaces", GroupVersionKind: "/v1, Kind=Namespace"
* Name: "jx", Namespace: ""

* Resource: "extensions/v1beta1, Resource=ingresses", GroupVersionKind: "extensions/v1beta1, Kind=Ingress"
* Name: "chartmuseum", Namespace: "jx"

* Resource: "extensions/v1beta1, Resource=ingresses", GroupVersionKind: "extensions/v1beta1, Kind=Ingress"
* Name: "hook", Namespace: "jx"

* Resource: "jenkins.io/v1, Resource=schedulers", GroupVersionKind: "jenkins.io/v1, Kind=Scheduler"
* Name: "default-scheduler", Namespace: "jx"

* Resource: "jenkins.io/v1, Resource=environments", GroupVersionKind: "jenkins.io/v1, Kind=Environment"
* Name: "dev", Namespace: "jx"

* Resource: "jenkins.io/v1, Resource=sourcerepositories", GroupVersionKind: "jenkins.io/v1, Kind=SourceRepository"
* Name: "jx-env-dev", Namespace: "jx"

* Resource: "jenkins.io/v1, Resource=schedulers", GroupVersionKind: "jenkins.io/v1, Kind=Scheduler"
* Name: "env-scheduler", Namespace: "jx"

* Resource: "jenkins.io/v1, Resource=schedulers", GroupVersionKind: "jenkins.io/v1, Kind=Scheduler"
* Name: "pr-only", Namespace: "jx"

* Resource: "jenkins.io/v1, Resource=environments", GroupVersionKind: "jenkins.io/v1, Kind=Environment"
* Name: "production", Namespace: "jx"

* Resource: "jenkins.io/v1, Resource=sourcerepositories", GroupVersionKind: "jenkins.io/v1, Kind=SourceRepository"
* Name: "jx-env-prod", Namespace: "jx"

* Resource: "jenkins.io/v1, Resource=schedulers", GroupVersionKind: "jenkins.io/v1, Kind=Scheduler"
* Name: "release-only", Namespace: "jx"

* Resource: "jenkins.io/v1, Resource=environments", GroupVersionKind: "jenkins.io/v1, Kind=Environment"
* Name: "staging", Namespace: "jx"

* Resource: "jenkins.io/v1, Resource=sourcerepositories", GroupVersionKind: "jenkins.io/v1, Kind=SourceRepository"
* Name: "jx-env-staging", Namespace: "jx"

* Resource: "rbac.authorization.k8s.io/v1beta1, Resource=roles", GroupVersionKind: "rbac.authorization.k8s.io/v1beta1, Kind=Role"
* Name: "jenkins-x-lighthouse", Namespace: "jx"

* Resource: "rbac.authorization.k8s.io/v1beta1, Resource=rolebindings", GroupVersionKind: "rbac.authorization.k8s.io/v1beta1, Kind=RoleBinding"
* Name: "jenkins-x-lighthouse", Namespace: "jx"
 
* Resource: "/v1, Resource=serviceaccounts", GroupVersionKind: "/v1, Kind=ServiceAccount"
* Name: "jenkins-x-lighthouse", Namespace: "jx"

* Resource: "rbac.authorization.k8s.io/v1beta1, Resource=rolebindings", GroupVersionKind: "rbac.authorization.k8s.io/v1beta1, Kind=RoleBinding"
* Name: "tide", Namespace: "jx"

* Resource: "rbac.authorization.k8s.io/v1beta1, Resource=roles", GroupVersionKind: "rbac.authorization.k8s.io/v1beta1, Kind=Role"
* Name: "tide", Namespace: "jx"

* Resource: "/v1, Resource=serviceaccounts", GroupVersionKind: "/v1, Kind=ServiceAccount"
* Name: "tide", Namespace: "jx"

* Resource: "policy/v1beta1, Resource=podsecuritypolicies", GroupVersionKind: "policy/v1beta1, Kind=PodSecurityPolicy"
* Name: "tekton-pipelines", Namespace: ""

* Resource: "rbac.authorization.k8s.io/v1beta1, Resource=clusterrolebindings", GroupVersionKind: "rbac.authorization.k8s.io/v1beta1, Kind=ClusterRoleBinding"
* Name: "tekton-pipelines-jx", Namespace: ""

* Resource: "/v1, Resource=serviceaccounts", GroupVersionKind: "/v1, Kind=ServiceAccount"
* Name: "tekton-pipelines", Namespace: "jx"

* Resource: "/v1, Resource=serviceaccounts", GroupVersionKind: "/v1, Kind=ServiceAccount"
* Name: "tekton-bot", Namespace: "jx"

* Resource: "apiextensions.k8s.io/v1beta1, Resource=customresourcedefinitions", GroupVersionKind: "apiextensions.k8s.io/v1beta1, Kind=CustomResourceDefinition"
* Name: "clustertasks.tekton.dev", Namespace: ""

* Resource: "apiextensions.k8s.io/v1beta1, Resource=customresourcedefinitions", GroupVersionKind: "apiextensions.k8s.io/v1beta1, Kind=CustomResourceDefinition"
* Name: "conditions.tekton.dev", Namespace: ""

* Resource: "apiextensions.k8s.io/v1beta1, Resource=customresourcedefinitions", GroupVersionKind: "apiextensions.k8s.io/v1beta1, Kind=CustomResourceDefinition"
* Name: "images.caching.internal.knative.dev", Namespace: ""

* Resource: "apiextensions.k8s.io/v1beta1, Resource=customresourcedefinitions", GroupVersionKind: "apiextensions.k8s.io/v1beta1, Kind=CustomResourceDefinition"
* Name: "pipelines.tekton.dev", Namespace: ""

* Resource: "apiextensions.k8s.io/v1beta1, Resource=customresourcedefinitions", GroupVersionKind: "apiextensions.k8s.io/v1beta1, Kind=CustomResourceDefinition"
* Name: "pipelineruns.tekton.dev", Namespace: ""

* Resource: "apiextensions.k8s.io/v1beta1, Resource=customresourcedefinitions", GroupVersionKind: "apiextensions.k8s.io/v1beta1, Kind=CustomResourceDefinition"
* Name: "pipelineresources.tekton.dev", Namespace: ""

* Resource: "apiextensions.k8s.io/v1beta1, Resource=customresourcedefinitions", GroupVersionKind: "apiextensions.k8s.io/v1beta1, Kind=CustomResourceDefinition"
* Name: "tasks.tekton.dev", Namespace: ""

* Resource: "apiextensions.k8s.io/v1beta1, Resource=customresourcedefinitions", GroupVersionKind: "apiextensions.k8s.io/v1beta1, Kind=CustomResourceDefinition"
* Name: "taskruns.tekton.dev", Namespace: ""

* Resource: "rbac.authorization.k8s.io/v1, Resource=clusterrolebindings", GroupVersionKind: "rbac.authorization.k8s.io/v1, Kind=ClusterRoleBinding"
* Name: "tekton-bot-jx", Namespace: ""

* Resource: "rbac.authorization.k8s.io/v1, Resource=roles", GroupVersionKind: "rbac.authorization.k8s.io/v1, Kind=Role"
* Name: "tekton-bot", Namespace: "jx"

* Resource: "rbac.authorization.k8s.io/v1, Resource=rolebindings", GroupVersionKind: "rbac.authorization.k8s.io/v1, Kind=RoleBinding"
* Name: "tekton-bot", Namespace: "jx"

### Jenkins X CRD List

```bash
kubectl api-resources --api-group=jenkins.io
```

```bash
NAME                      SHORTNAMES                                 APIGROUP     NAMESPACED   KIND
apps                      app                                        jenkins.io   true         App
buildpacks                bp                                         jenkins.io   true         BuildPack
commitstatuses            commitstatus                               jenkins.io   true         CommitStatus
environmentrolebindings   envrolebindings,envrolebinding,envrb,erb   jenkins.io   true         EnvironmentRoleBinding
environments              env                                        jenkins.io   true         Environment
extensions                extension,ext                              jenkins.io   true         Extension
facts                     fact                                       jenkins.io   true         Fact
gitservices               gits,gs                                    jenkins.io   true         GitService
pipelineactivities        activity,act,pa                            jenkins.io   true         PipelineActivity
pipelinestructures        structure,ps                               jenkins.io   true         PipelineStructure
plugins                                                              jenkins.io   true         Plugin
releases                  rel                                        jenkins.io   true         Release
schedulers                scheduler                                  jenkins.io   true         Scheduler
sourcerepositories        sourcerepo,srcrepo,sr                      jenkins.io   true         SourceRepository
sourcerepositorygroups    srg                                        jenkins.io   true         SourceRepositoryGroup
teams                     tm                                         jenkins.io   true         Team
users                     usr                                        jenkins.io   true         User
workflows                 flow                                       jenkins.io   true         Workflow
```

```bash
kubectl api-resources -o name
```

```bash
apps.jenkins.io
buildpacks.jenkins.io
commitstatuses.jenkins.io
environmentrolebindings.jenkins.io
environments.jenkins.io
extensions.jenkins.io
facts.jenkins.io
gitservices.jenkins.io
pipelineactivities.jenkins.io
pipelinestructures.jenkins.io
plugins.jenkins.io
releases.jenkins.io
schedulers.jenkins.io
sourcerepositories.jenkins.io
sourcerepositorygroups.jenkins.io
teams.jenkins.io
users.jenkins.io
workflows.jenkins.io
```

## References

[^1]: https://kubernetes.io/docs/concepts/storage/volumes/#emptydir
[^2]: https://jenkins-x.io/docs/getting-started/first-project/create-quickstart/
[^3]: https://github.com/jenkins-x-quickstarts
[^4]: https://github.com/jenkins-x-quickstarts/golang-http
[^5]: https://github.com/jenkins-x-buildpacks/jenkins-x-kubernetes/tree/master/packs
[^6]: https://jenkins-x.io/docs/concepts/technology/#whats-is-exposecontroller
[^7]: https://github.com/jenkins-x/exposecontroller/blob/master/exposestrategy/ingress.go#L48
[^8]: https://jenkins-x.io/docs/reference/pipeline-syntax-reference/
[^9]: https://technologyconversations.com/2019/06/30/overriding-pipelines-stages-and-steps-and-implementing-loops-in-jenkins-x-pipelines/
[^10]: https://jenkins-x.io/docs/getting-started/promotion/
[^11]: https://github.com/jenkins-x/exposecontroller#exposer-types
[^12]: https://jenkins-x.io/docs/getting-started/build-test-preview/#generating-a-preview-environment
[^13]: https://jenkins-x.io/docs/reference/preview/#charts
[^21]: https://cert-manager.io/docs/installation/openshift/