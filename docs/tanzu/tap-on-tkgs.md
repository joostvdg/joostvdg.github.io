---
tags:
  - TKG
  - Vsphere
  - TAP
  - 1.3.4
  - TANZU
---

title: TAP on TKGs
description: Tanzu Application Platform on vSphere with Tanzu

# TAP on TKGs


!!! Success "Update January 2023"
    This guide has been updated January 31st, to reflect TAP **1.3.4**.

    Some improvements in the multi-cluster installation have been made.
    Enough to warrant an update to this guide.

**TKGs** stands for Tanzu Kubernetes Grid vSphere, or _vSphere with Tanzu_.

**TAP** stands for Tanzu Application Platform.

This guide is about installing and using TAP on TGKs, with the following additional constraints:

* restricted internet access
* prepare Certificate Authority
* self-hosted Container Registry
* certificates signed with custom Certificate Authority (CA)
* separate Kubernetes cluster for TAP roles
    * Shared Services Cluster, `tap-s1` for the Container Registry and a TAP Build profile
    * Workload Cluster, `tap-w1` for a TAP Run profile

The scripts and other configuration files can found in my [Tanzu Example](https://github.com/joostvdg/tanzu-example/tree/main/tap/1.3.4/scripts) repository.

!!! Warning
    This guide is tested with TAP `1.3.x`, not everything applies for `1.4.0+`.

## Steps

* Installation machine pre-requisites
* Shared services cluster pre-requisites
* Relocate Tanzu Application Platform (TAP) and Tanzu Build Service (TBS) images to local Harbor instance
* Install TAP Build profile
* Install TAP Run profile
* Install TAP View profile
* Use TAP GUI to create and register new Workloads

## Machine Pre-requisites

We have pre-requisites for the cluster, and we have pre-requisites for the machine which runs the commands.
Here are the pre-requisites for all the commands:

* [Kubernetes CLI Tools for vSphere](https://docs.vmware.com/en/VMware-vSphere/7.0/vmware-vsphere-with-tanzu/GUID-0F6E45C4-3CB1-4562-9370-686668519FCA.html)
* [Tanzu CLI v1.4 or later](https://docs.vmware.com/en/VMware-Tanzu-Kubernetes-Grid/1.6/vmware-tanzu-kubernetes-grid-16/GUID-install-cli.html)
* Tanzu CLI plugins for TKGs
* Tanzu CLI plugins for TAP
* kubectl
* [yq](https://github.com/mikefarah/yq)
* [jq](https://stedolan.github.io/jq/)
* [http](https://httpie.io/) (or Curl)
* [Carvel tools](https://carvel.dev/) (mostly `ytt` and `imgpkg`)

## TKGs Considerations

There are several requirements to your TKGs workload clusters.

1. **Trust CA**: In order to trust the certificate of Harbor for using images from there, your worker nodes need to trust it.

2. **Memory & CPU** TAP is resource intensive, reserve at least 12 CPU and 10GB of RAM for a full TAP install. About half for Run or Build profiles.

3. **Storage** Tanzu Build Service will store its images on the nodes. These worker nodes need at leat 70GB of storage available.

??? example "Cluster Definition"
    This is a Cluster definition for TKGs.

    You can apply this to a SuperVisor Cluster.

    ```yaml title="tap-s1.yml" linenums="1" hl_lines="20-24 34-38"
    apiVersion: run.tanzu.vmware.com/v1alpha2
    kind: TanzuKubernetesCluster
    metadata:
      name: tap-s1
      namespace: tap
    spec:
      topology:
        controlPlane:
          replicas: 1
          vmClass: best-effort-large
          storageClass: vc01cl01-t0compute 
          tkr:
            reference:
              name: v1.22.9---vmware.1-tkg.1.cc71bc8
        nodePools:
        - name: worker-pool-1
          replicas: 1
          vmClass: best-effort-4xlarge
          storageClass: vc01cl01-t0compute
          volumes:
            - name: containerd
              mountPath: /var/lib/containerd
              capacity:
                storage: 90Gi 
          tkr:
            reference:
              name: v1.22.9---vmware.1-tkg.1.cc71bc8
      settings:
        storage:
          defaultClass: vc01cl01-t0compute
        network:
          cni:
            name: antrea    
          trust: 
            additionalTrustedCAs: 
              - name: KearosCA
                data: |
                  LS0tLS1CRUdJTiBDRVJUSUZJQ0...
    ```

!!! Warning
    If you use [Tanzu Mission Control](https://docs.vmware.com/en/VMware-Tanzu-Mission-Control/index.html) to create the workload clusters, you cannot specify the `spec.settings.network.trust` section.

    Or if you do not _want_ to configure the CA certificate for every cluster.
    
    For both scenarios, you can use a **TkgServiceConfiguration** resource on the supervisor cluster.

    ```yaml
    apiVersion: run.tanzu.vmware.com/v1alpha1
    kind: TkgServiceConfiguration
    metadata:
      name: tkg-service-configuration
    spec:
      defaultCNI: antrea
      trust:
        additionalTrustedCAs:
          - name: KearosCA
            data: |
                LS0tLS1CRUd...
    ```

!!! Danger

    You have to set the correct PodSecurityProfiles, when dealing with TGKs.

    Below is a fast and terrible solution to ignore them. Use at your own risk.

    ```sh
    kubectl create role psp:privileged \
        --verb=use \
        --resource=podsecuritypolicy \
        --resource-name=vmware-system-privileged

    kubectl create rolebinding default:psp:privileged \
        --role=psp:privileged \
        --serviceaccount=elastic-system:default

    kubectl create clusterrolebinding default-tkg-admin-privileged-binding --clusterrole=psp:vmware-system-privileged --group=system:authenticated
    ```

## Relocate Images To Harbor

!!! Warning
    We expect you installed and configured a Harbor with a custom CA.

    I have described it in the [Harbor with a Custom CA](/tanzu/harbor-ca) guide.

We are executing the following steps:

* prepare local machine
  * authenticate with Tanzu Network and local Harbor instance
* create new project in Harbor
* use Carvel's `imgpkg` to copy TAP images from Tanzu Network to Harbor
* use Carvel's `imgpkg` to copy TBS's from Tanzu Network to Harbor?

### Prepare Local Machine

!!! Important
    You can also authenticate `imgpkg` with both registries via [Environment Variables](https://carvel.dev/imgpkg/docs/develop/auth/#via-environment-variables).

    Or verify one of the other possible [authentication methods](https://carvel.dev/imgpkg/docs/develop/auth/).

    Below I'm showing how to leverage the Docker client.

Set the credentials for Tanzu Network.

```sh
export TANZU_NETWORK_USER=
export TANZU_NETWORK_PASS=
```

And ensure your Docker client is authenticated.

```sh
docker login registry.tanzu.vmware.com --username ${TANZU_NETWORK_USER} --password ${TANZU_NETWORK_PASS}
```

Set the hostname and credentials for Harbor.

```sh
HARBOR_ADMIN_NAME=admin
HARBOR_ADMIN_PASS=
HARBOR_HOSTNAME=
```

As Harbor has a custom CA, we need Docker to trust it.

Docker has an [excellent guide on trusting registry certificates](https://docs.docker.com/engine/security/certificates/).
Once you have completes the relevant steps for your OS, you can now authenticate with Harbor.

```sh
docker login ${HARBOR_HOSTNAME} --username ${HARBOR_ADMIN_NAME} --password ${TANZU_NETWORK_PASS}
```

### Create Harbor Projects

To store images for TAP and for our applications, we need projects in Harbor to exist.
We make them all public, to avoid having to create image pull secret, but feel free to do otherwise.

Create the following Harbor Projects:

* tap
* tap-apps
* buildservice

```sh
http -a admin:${HARBOR_ADMIN_PASS} \
  POST "https://${HARBOR_HOSTNAME}/api/v2.0/projects" \
  project_name="tap" public:=true --verify=false

http -a admin:${HARBOR_ADMIN_PASS} \
  POST "https://${HARBOR_HOSTNAME}/api/v2.0/projects" \
  project_name="tap-apps" public:=true --verify=false

http -a admin:${HARBOR_ADMIN_PASS} \
  POST "https://${HARBOR_HOSTNAME}/api/v2.0/projects" \
  project_name="buildservice" public:=true --verify=false
```

### Copy TAP Images

```sh
export TAP_VERSION="1.3.4"
```

```sh
imgpkg copy --registry-verify-certs=false \
 -b registry.tanzu.vmware.com/tanzu-application-platform/tap-packages:${TAP_VERSION} \
 --to-repo ${HARBOR_HOSTNAME}/tap/tap-packages
```


### Copy TBS Images To Harbor

* https://docs.vmware.com/en/Tanzu-Build-Service/1.7/vmware-tanzu-build-service/GUID-installing.html
* https://docs.vmware.com/en/VMware-Tanzu-Application-Platform/1.3/tap/GUID-tbs-offline-install-deps.html

#### Determine TBS Version

```sh
tanzu package available list buildservice.tanzu.vmware.com --namespace tap-install
```

TAP `1.3.4` ships with TBS `1.7.4`:

```sh
TBS_VERSION=1.7.4
```
#### Copy TBS Images 

!!!! Warning
    The TBS Full Dependency tar file is approximately 10GB of data.
    
    Make sure you have the space before downloading it.

```sh
imgpkg copy -b registry.tanzu.vmware.com/tanzu-application-platform/full-tbs-deps-package-repo:$TBS_VERSION \
  --to-tar=tbs-full-deps.tar
```

```sh
imgpkg copy --tar tbs-full-deps-${TBS_VERSION}.tar \
  --to-repo=$HARBOR_HOSTNAME/buildservice/tbs-full-deps
```

#### Install TBS Repository

```sh
tanzu package repository add tbs-full-deps-repository \
  --url $HARBOR_HOSTNAME/buildservice/tbs-full-deps:$TBS_VERSION  \
  --namespace tap-install
```

```sh
tanzu package repository list --namespace tap-install
```

#### Install TBS Packages

```sh
tanzu package install full-tbs-deps \
  -p full-tbs-deps.tanzu.vmware.com \
  -v $TBS_VERSION \
  -n tap-install
```

## TAP Build Cluster

### Install Basic Supply Chain

The basic profile uses the basic supply chain.

This means it does not install Grype and the Metadata store, and other scanning related tools.

```sh
export INSTALL_TAP_FUNDAMENTALS="true" # creates namespace and secrets
export INSTALL_REGISTRY_HOSTNAME=${HARBOR_HOSTNAME}
export INSTALL_REGISTRY_USERNAME=admin
export INSTALL_REGISTRY_PASSWORD=''

export BUILD_REGISTRY=${HARBOR_HOSTNAME}
export BUILD_REGISTRY_REPO=tap-apps
export BUILD_REGISTRY_USER=admin
export BUILD_REGISTRY_PASS=''

export TAP_VERSION=1.3.4
export TBS_REPO=buildservice/tbs-full-deps

export DOMAIN_NAME=""
export DEVELOPER_NAMESPACE="default"
export CA_CERT=$(cat ssl/ca.pem)

export INSTALL_CLUSTER_ESSENTIALS="false" # installs Kapp Controller & SecretGen Controller
```

We set `INSTALL_CLUSTER_ESSENTIALS` to false, as TMC installs those for us.

```sh
./tap-build-install-basic.sh
```

### Setup Developer Namespace (Build)

To make a namespace usable for TAP, we need the following:

* the namespace needs to exist
* we need the `registry-credentials` secret for reading/writing to and from the OCI registry
* [rbac permissions](https://github.com/joostvdg/tanzu-example/blob/main/tap/scripts/dev-namespace-rbac.yml) for the namespace's default **Service Account**

!!! Example "Setup Develop Namespace Script"
    This script resides in the [tap/1.3.4/scripts](https://github.com/joostvdg/tanzu-example/tree/main/tap/1.3.4/scripts) folder.

    ```sh
    ./tap-developer-namespace.sh
    ```

### Test Workload

We first set the name of the developer namespace you have setup for TAP.

```sh
DEVELOPER_NAMESPACE=${DEVELOPER_NAMESPACE:-"default"}
```

We can then either use the CLI or the `Workload` CR to create our test workload.

=== "Tanzu CLI"
    ```sh
    tanzu apps workload create smoke-app \
      --git-repo https://github.com/sample-accelerators/tanzu-java-web-app.git \
      --git-branch main \
      --type web \
      --label app.kubernetes.io/part-of=smoke-app \
      --annotation autoscaling.knative.dev/minScale=1 \
      --yes \
      -n "$DEVELOPER_NAMESPACE"
    ```
=== "Kubernetes Manifest"
    ```sh
    echo "apiVersion: carto.run/v1alpha1
    kind: Workload
    metadata:
      labels:
        app.kubernetes.io/part-of: smoke-app
        apps.tanzu.vmware.com/workload-type: web
      name: smoke-app
      namespace: ${DEVELOPER_NAMESPACE}
    spec:
      params:
      - name: annotations
        value:
          autoscaling.knative.dev/minScale: \"1\"
      source:
        git:
          ref:
            branch: main
          url: https://github.com/sample-accelerators/tanzu-java-web-app.git
    " > workload.yml
    ```

    ```sh
    kubectl apply -f workload.yml
    ```

Use `kubectl wait` to wait for the app to be ready.

```sh
kubectl wait --for=condition=Ready Workload smoke-app --timeout=10m -n "$DEVELOPER_NAMESPACE"
```

To see the logs:

```sh
tanzu apps workload tail smoke-app
```

To get the status:

```sh
tanzu apps workload get smoke-app
```

And then we can delete our test workload if want to.

```sh
tanzu apps workload delete smoke-app -y -n "$DEVELOPER_NAMESPACE"
```

!!! Example "Test TAP Workload Script"
    This script resides in the [tap/scripts](https://github.com/joostvdg/tanzu-example/blob/main/tap/scripts) folder.

    It does all the steps outlined in this paragraph, including the wait and cleanup.

    ```sh
    ./tap-workload-demo.sh
    ```

## Tap Run Cluster

### TAP Run Profile Install

```sh
export INSTALL_TAP_FUNDAMENTALS="true" # creates namespace and secrets
export INSTALL_REGISTRY_HOSTNAME=${HARBOR_HOSTNAME}
export INSTALL_REGISTRY_USERNAME=admin
export INSTALL_REGISTRY_PASSWORD=''

export BUILD_REGISTRY=${HARBOR_HOSTNAME}
export BUILD_REGISTRY_REPO=tap-apps
export BUILD_REGISTRY_USER=admin
export BUILD_REGISTRY_PASS=''

export TAP_VERSION=1.3.4
export TBS_REPO=buildservice/tbs-full-deps

export DOMAIN_NAME=""
export VIEW_DOMAIN_NAME=""
export DEVELOPER_NAMESPACE="default"
export CA_CERT=$(cat ssl/ca.pem)
export INSTALL_CLUSTER_ESSENTIALS="false" # installs Kapp Controller & SecretGen Controller
```

We set `INSTALL_CLUSTER_ESSENTIALS` to false, as TMC installs those for us.

The script below will install TAP with and its direct requirements (e.g., secret).

What we need are the following:

* Cluster Essentials:
  * Kapp Controller
  * SecretGen Controller
* `tap-install` namespace
* credentials for the OCI registry we pull TAP images from
* credentials for the OCI registry we pull build images from (images build in the Build cluster)
* package repository containing the TAP packages

!!! Example "TAP Install Script"
    This script resides in the [tap/1.3.4/scripts](https://github.com/joostvdg/tanzu-example/tree/main/tap/1.3.4/scripts) folder.

    ```sh
    ./tap-run-install.sh
    ```

### Setup Developer Namespace (RUN)

To make a namespace usable for TAP, we need the following:

* the namespace needs to exist
* we need the `registry-credentials` secret for reading/writing to and from the OCI registry
* [rbac permissions](https://github.com/joostvdg/tanzu-example/blob/main/tap/scripts/dev-namespace-rbac.yml) for the namespace's default **Service Account**

!!! Example "TAP Install Script"
    This script resides in the [tap/1.3.4/scripts](https://github.com/joostvdg/tanzu-example/tree/main/tap/1.3.4/scripts) folder.

    ```sh
    ./tap-developer-namespace.sh
    ```

!!! failure
    As of November 1st, we have to exclude the package `policy.apps.tanzu.vmware.com`, due to a breaking bug.
    Currently the  only remedy is [to disable it](https://docs.vmware.com/en/VMware-Tanzu-Application-Platform/1.3/tap/GUID-scst-policy-known-issues.html?hWord=N4IghgNiBcIC4FcBmB9AtgSwE5YPZZAF8g).

## Cross-cluster Test

* https://docs.vmware.com/en/VMware-Tanzu-Application-Platform/1.3/tap/GUID-multicluster-getting-started.html#start-the-workload-on-the-build-profile-cluster-1

### Get Deliverable From Build Cluster

1. verify Deliverable content for your workload exists in the **Build** cluster
    ```sh
    kubectl get configmap $APP_NAME --namespace ${DEVELOPER_NAMESPACE} -o go-template='{{.data.deliverable}}'
    ```
1. retrieve (from the **Build** cluster) and store it on disk
    ```sh
    kubectl get configmap $APP_NAME -n ${DEVELOPER_NAMESPACE} -o go-template='{{.data.deliverable}}' > deliverable-$APP_NAME.yaml
    ```
1.  apply it to the **Run** cluster
    ```sh
    kubectl apply -f deliverable-$APP_NAME.yaml --namespace ${DEVELOPER_NAMESPACE}
    ```
1. verify it works
    ```sh
    kubectl get deliverables --namespace ${DEVELOPER_NAMESPACE}
    ```

### Verify Application is accessible

```sh
kubectl get httpproxy -n ${DEVELOPER_NAMESPACE} -l contour.networking.knative.dev/parent=tap-hello-world -ojsonpath="{.items.*.spec.virtualhost}"
```

```sh
PROXY_URL=$(kubectl get httpproxy -n ${DEVELOPER_NAMESPACE} -l contour.networking.knative.dev/parent=tap-hello-world -ojsonpath="{.items.*.spec.virtualhost}" | jq .fqdn | grep ssl | cut -d '"' -f 2)

```sh
http $PROXY_URL
```

!!! info "App Update"

    The Bundle of the application will always have the same tag.
    The latest build will get this tag, and this means only the latest bundle will only ever have this tag.

    As a consequence of this, the **Deliverable** in the Run Cluster, is always correct.
    TAP will automatically detect the updated bundle (tag) and update the deployment.

    So the copying of the Deliverable, is a one time step.



## View Cluster

### Create Service Accounts

* https://docs.vmware.com/en/VMware-Tanzu-Application-Platform/1.3/tap/GUID-tap-gui-cluster-view-setup.html

* create: `tap-gui-viewer-service-account-rbac.yaml`

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: tap-gui
---
apiVersion: v1
kind: ServiceAccount
metadata:
  namespace: tap-gui
  name: tap-gui-viewer
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: tap-gui-read-k8s
subjects:
- kind: ServiceAccount
  namespace: tap-gui
  name: tap-gui-viewer
roleRef:
  kind: ClusterRole
  name: k8s-reader
  apiGroup: rbac.authorization.k8s.io
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: k8s-reader
rules:
- apiGroups: ['']
  resources: ['pods', 'pods/log', 'services', 'configmaps', 'limitranges']
  verbs: ['get', 'watch', 'list']
- apiGroups: ['metrics.k8s.io']
  resources: ['pods']
  verbs: ['get', 'watch', 'list']
- apiGroups: ['apps']
  resources: ['deployments', 'replicasets', 'statefulsets', 'daemonsets']
  verbs: ['get', 'watch', 'list']
- apiGroups: ['autoscaling']
  resources: ['horizontalpodautoscalers']
  verbs: ['get', 'watch', 'list']
- apiGroups: ['networking.k8s.io']
  resources: ['ingresses']
  verbs: ['get', 'watch', 'list']
- apiGroups: ['networking.internal.knative.dev']
  resources: ['serverlessservices']
  verbs: ['get', 'watch', 'list']
- apiGroups: [ 'autoscaling.internal.knative.dev' ]
  resources: [ 'podautoscalers' ]
  verbs: [ 'get', 'watch', 'list' ]
- apiGroups: ['serving.knative.dev']
  resources:
  - configurations
  - revisions
  - routes
  - services
  verbs: ['get', 'watch', 'list']
- apiGroups: ['carto.run']
  resources:
  - clusterconfigtemplates
  - clusterdeliveries
  - clusterdeploymenttemplates
  - clusterimagetemplates
  - clusterruntemplates
  - clustersourcetemplates
  - clustersupplychains
  - clustertemplates
  - deliverables
  - runnables
  - workloads
  verbs: ['get', 'watch', 'list']
- apiGroups: ['source.toolkit.fluxcd.io']
  resources:
  - gitrepositories
  verbs: ['get', 'watch', 'list']
- apiGroups: ['source.apps.tanzu.vmware.com']
  resources:
  - imagerepositories
  - mavenartifacts
  verbs: ['get', 'watch', 'list']
- apiGroups: ['conventions.apps.tanzu.vmware.com']
  resources:
  - podintents
  verbs: ['get', 'watch', 'list']
- apiGroups: ['kpack.io']
  resources:
  - images
  - builds
  verbs: ['get', 'watch', 'list']
- apiGroups: ['scanning.apps.tanzu.vmware.com']
  resources:
  - sourcescans
  - imagescans
  - scanpolicies
  verbs: ['get', 'watch', 'list']
- apiGroups: ['tekton.dev']
  resources:
  - taskruns
  - pipelineruns
  verbs: ['get', 'watch', 'list']
- apiGroups: ['kappctrl.k14s.io']
  resources:
  - apps
  verbs: ['get', 'watch', 'list']
- apiGroups: [ 'batch' ]
  resources: [ 'jobs', 'cronjobs' ]
  verbs: [ 'get', 'watch', 'list' ]
- apiGroups: ['conventions.carto.run']
  resources:
  - podintents
  verbs: ['get', 'watch', 'list']
```

And apply it to the Run and Build clusters.

```sh
kubectl create -f tap-gui-viewer-service-account-rbac.yaml
```

```sh
CLUSTER_URL=$(kubectl config view --minify -o jsonpath='{.clusters[0].cluster.server}')

CLUSTER_TOKEN=$(kubectl -n tap-gui get secret $(kubectl -n tap-gui get sa tap-gui-viewer -o=json \
| jq -r '.secrets[0].name') -o=json \
| jq -r '.data["token"]' \
| base64 --decode)

echo CLUSTER_URL: $CLUSTER_URL
echo CLUSTER_TOKEN: $CLUSTER_TOKEN
```

Run this for each cluster, and fill it in in the next step.

### Install Variables

```sh
export INSTALL_TAP_FUNDAMENTALS="true" # creates namespace and secrets
export INSTALL_REGISTRY_HOSTNAME=${HARBOR_HOSTNAME}
export INSTALL_REGISTRY_USERNAME=admin
export INSTALL_REGISTRY_PASSWORD=''

export BUILD_REGISTRY=${HARBOR_HOSTNAME}
export BUILD_REGISTRY_REPO=tap-apps
export BUILD_REGISTRY_USER=admin
export BUILD_REGISTRY_PASS=''

export TAP_VERSION=1.3.4
export DOMAIN_NAME=""
export CA_CERT=$(cat ssl/ca.pem)

export BUILD_CLUSTER_URL=https://1.2.3.4:6443
export BUILD_CLUSTER_NAME=my-build-cluster
export BUILD_CLUSTER_TOKEN=''

export RUN_CLUSTER_URL=https://5.6.7.8:6443
export RUN_CLUSTER_NAME=my-run-cluster
export RUN_CLUSTER_TOKEN=

export INSTALL_CLUSTER_ESSENTIALS="false" # installs Kapp Controller & SecretGen Controller
```

We set `INSTALL_CLUSTER_ESSENTIALS` to false, as TMC installs those for us.

### Run Install Script

```sh
./tap-view-install.sh
```

## Sigstore Stack Airgapped

It looks like you would need to setup the Sigstore stack yourself in a reachable place.

There is some guidance on [how to do so](https://docs.vmware.com/en/VMware-Tanzu-Application-Platform/1.3/tap/GUID-scst-policy-install-sigstore-stack.html?hWord=N4IghgNiBcIC4FcBmB9AtgSwE5YPZZAF8g).
But unsure if that would not hit [the current known issue](https://docs.vmware.com/en/VMware-Tanzu-Application-Platform/1.3/tap/GUID-scst-policy-known-issues.html?hWord=N4IghgNiBcIC4FcBmB9AtgSwE5YPZZAF8g).

## Links

* [TKGs - Cluster Config settings (Custom CA)](https://docs.vmware.com/en/VMware-vSphere/7.0/vmware-vsphere-with-tanzu/GUID-B1034373-8C38-4FE2-9517-345BF7271A1E.html)
* [TKGs - Workload Cluster Creation](https://docs.vmware.com/en/VMware-vSphere/7.0/vmware-vsphere-with-tanzu/GUID-3040E41B-8A54-4D23-8796-A123E7CAE3BA.html)
* [TKGs - Install Kapp Controller](https://docs.vmware.com/en/VMware-Tanzu-Kubernetes-Grid/1.6/vmware-tanzu-kubernetes-grid-16/GUID-packages-prep-tkgs-kapp.html)
* [TKGs - Install Packages with TKG 1.6](https://docs.vmware.com/en/VMware-Tanzu-Kubernetes-Grid/1.6/vmware-tanzu-kubernetes-grid-16/GUID-packages-prep-tkgs-kapp.html)
* [TAP 1.3 - Install Guide](https://docs.vmware.com/en/VMware-Tanzu-Application-Platform/1.3/tap/GUID-install.html)
* [TAP 1.3 - Offline Installation for TBS](https://docs.vmware.com/en/VMware-Tanzu-Application-Platform/1.3/tap/GUID-tbs-offline-install-deps.html)
* [TAP 1.3 - Run profile](https://docs.vmware.com/en/VMware-Tanzu-Application-Platform/1.3/tap/GUID-multicluster-reference-tap-values-run-sample.html)
* [TAP 1.3 - Multicluster Overview](https://docs.vmware.com/en/VMware-Tanzu-Application-Platform/1.3/tap/GUID-multicluster-about.html)
* [TAP 1.3 - Install Sigstore Stack](https://docs.vmware.com/en/VMware-Tanzu-Application-Platform/1.3/tap/GUID-scst-policy-install-sigstore-stack.html?hWord=N4IghgNiBcIC4FcBmB9AtgSwE5YPZZAF8g)
* [TBS - Airgapped Installation](https://docs.vmware.com/en/Tanzu-Build-Service/1.7/vmware-tanzu-build-service/GUID-installing.html)
* [TBS - Offline Installation](https://docs.vmware.com/en/VMware-Tanzu-Application-Platform/1.3/tap/GUID-tbs-offline-install-deps.html)
* [TBS Dependencies - Airgapped](https://docs.vmware.com/en/Tanzu-Build-Service/1.6/vmware-tanzu-build-service/GUID-installing-no-kapp.html#installation-to-air-gapped-environment)
* [Known Issue TAP 1.3.0 Cosign - TUF Key Invalid](https://docs.vmware.com/en/VMware-Tanzu-Application-Platform/1.3/tap/GUID-scst-policy-known-issues.html?hWord=N4IghgNiBcIC4FcBmB9AtgSwE5YPZZAF8g)
* [Docker - Trust Registry Custom Certificate/CA](https://docs.docker.com/engine/security/certificates/)