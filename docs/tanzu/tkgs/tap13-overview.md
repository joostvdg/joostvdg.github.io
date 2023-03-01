---
tags:
  - TKG
  - Vsphere
  - TAP
  - 1.3.4
  - TANZU
---

title: TAP 1.3.x on TKGs
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

## Install Machine Pre-requisites

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


```sh
tanzu package available list buildservice.tanzu.vmware.com --namespace tap-install
```

TAP `1.3.4` ships with TBS `1.7.4`:

```sh
TBS_VERSION=1.7.4
```

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

## Satisfy Pre-requisites

A TAP installation has some pre-requisites, which are expected to exist in the cluster.

* **Cluster Essentials**: this means the **Kapp** and **SecretGen** controllers
* **Namespace**: the namespace to install TAP in, `tap-install` is the convention
* **Registry Secrets**: the secrets to the registry used for installing packages from, and the registry to push build images to
* **TAP Package Repository**: to install the TAP package, the TAP Package Repository needs to exist in the cluster

When installing a Build, Iterate, or Full profile in an internetes restricted environment, we also need:

* **Tanzu Build Service Dependencies**: TBS assumes it can download all of its dependencies durring the install, if it can't, the installation fails

The scripts below are called in order via the profile's install script.
We cover them so you know what is in them, and why.

The scripts themselves are available [in GitHub](https://github.com/joostvdg/tanzu-example/tree/main/tap/1.3.4/scripts).

### Cluster Essentials

!!! Warning "Not Required when using TMC"
    When using **Tanzu Mission Controll** to create your clusters, TMC installs the Cluster Essentials for you.

A basic script to install the **Kapp** and **SecretGen** controllers.

For vSphere with Tanzu, TKGs, you need a specific version of the Kapp configuration.

We assume you are using a Custom CA, so this script also creates a ConfigMap to configure Kapp to trust the CA certificate.

```sh title="install-cluster-essentials.sh"
#!/usr/bin/env bash
set -euo pipefail
KAPP_CONTROLLER_NAMESPACE=${KAPP_CONTROLLER_NAMESPACE:-"tkg-system"}
SECRET_GEN_VERSION=${SECRET_GEN_VERSION:-"v0.9.1"}
PLATFORM=${PLATFORM:="tkgs"}
TKGS="tkgs"

echo "> Installing Kapp Controller"
if [[ $PLATFORM eq $TGKS ]]
then
  # This is a TKGs version
  ytt -f ytt/kapp-controller.ytt.yml \
    -v namespace="$KAPP_CONTROLLER_NAMESPACE" \
    -v caCert="${CA_CERT}" \
    > "kapp-controller.yml"
  kubectl apply -f kapp-controller.yml
else
  # Non TKGs
  kubectl apply -f https://github.com/vmware-tanzu/carvel-kapp-controller/releases/latest/download/release.yml
  echo "Configure Custom Cert for Kapp Controller"
  ytt -f ytt/kapp-controller-config.ytt.yml \
    -v namespace=kapp-controller \
    -v caCert="${CA_CERT}" \
    > "kapp-controller-config.yml"
  kubectl apply -f kapp-controller-config.yml --namespace kapp-controller
fi

echo "> Installing SecretGen Controller with version ${SECRET_GEN_VERSION}"
kapp deploy -y -a sg -f https://github.com/vmware-tanzu/carvel-secretgen-controller/releases/download/"$SECRET_GEN_VERSION"/release.yml%
```

### Secrets & Package Repo

The convention is to install TAP and its packages in the namespace `tap-install`.

With this script we create the namespace, the two registry secrets (install and build), and install the TAP Package Repository.

We use the `tanzu secret registry` command to create the registry secrets.
This uses the **SecretGen** controller we install via the Cluster Essentials.

The reason for this, is that it allows you to create the secret once, and have it available in all the namespace that need it.
When you need to update these secrets, you don't have to hunt for them, you use the same `tanzu secret registry` command.

!!! Danger
    Be aware the Build secret is also `--export-to-all-namespaces` in this scenario.

    For a POC or single team installation that is fine.

    When you want to fine grained permissions to allow each development team to only upload images to their respective repository, you have to change this!

```sh title="install-tap-fundamentals.sh"
#!/usr/bin/env bash
set -euo pipefail

TAP_VERSION=${TAP_VERSION:-"1.3.4"}
TAP_INSTALL_NAMESPACE="tap-install"
DOMAIN_NAME=${DOMAIN_NAME:-"127.0.0.1.nip.io"}
INSTALL_REGISTRY_SECRET="tap-registry"
BUILD_REGISTRY_SECRET="registry-credentials"

echo "> Creating tap-install namespace: $TAP_INSTALL_NAMESPACE"
kubectl create ns $TAP_INSTALL_NAMESPACE || true

INSTALL_REGISTRY_HOSTNAME=${INSTALL_REGISTRY_HOSTNAME:-"registry.tanzu.vmware.com"}
INSTALL_REGISTRY_USERNAME=${INSTALL_REGISTRY_USERNAME:-""}
INSTALL_REGISTRY_PASSWORD=${INSTALL_REGISTRY_PASSWORD:-""}
INSTALL_REGISTRY_REPO=${INSTALL_REGISTRY_REPO:-"tap/tap-packages"}

echo "> Creating ${INSTALL_REGISTRY_SECRET} secret"
tanzu secret registry add ${INSTALL_REGISTRY_SECRET} \
    --server    $INSTALL_REGISTRY_HOSTNAME \
    --username  $INSTALL_REGISTRY_USERNAME \
    --password  $INSTALL_REGISTRY_PASSWORD \
    --namespace ${TAP_INSTALL_NAMESPACE} \
    --export-to-all-namespaces \
    --yes

BUILD_REGISTRY=${BUILD_REGISTRY:-"dev.registry.tanzu.vmware.com"}
BUILD_REGISTRY_REPO=${BUILD_REGISTRY_REPO:-""}
BUILD_REGISTRY_USER=${BUILD_REGISTRY_USER:-""}
BUILD_REGISTRY_PASS=${BUILD_REGISTRY_PASS:-""}

echo "> Creating ${BUILD_REGISTRY_SECRET} secret"
tanzu secret registry add ${BUILD_REGISTRY_SECRET} \
    --server    $BUILD_REGISTRY \
    --username  $BUILD_REGISTRY_USER \
    --password  $BUILD_REGISTRY_PASS \
    --namespace ${TAP_INSTALL_NAMESPACE} \
    --export-to-all-namespaces \
    --yes

PACKAGE_REPOSITORY="$INSTALL_REGISTRY_HOSTNAME"/$INSTALL_REGISTRY_REPO:"$TAP_VERSION"
echo "> Install TAP Package Repository: ${PACKAGE_REPOSITORY}"
tanzu package repository add tanzu-tap-repository --url "$PACKAGE_REPOSITORY" --namespace ${TAP_INSTALL_NAMESPACE} || true
kubectl wait --for=condition=ReconcileSucceeded PackageRepository tanzu-tap-repository -n ${TAP_INSTALL_NAMESPACE} --timeout=15m
```

### TBS Dependencies

!!! Info "Build, Iterate, Full Profiles only"
    When installing other profiles, such as View and Run, you do not need Tanzu Build Service or its dependencies.

When in an internetes restricted environment, we need to install the TBS dependencies by ourselves.

This way we can leverage relocated images that come from a local source we can use, such as Harbor.

The commands below assume you've already relocated the images to an accessible Harbor instance.

```sh
HARBOR_HOSTNAME=
TBS_VERSION=
```

!!! Info
    TAP `1.3.4` ships with Tanzu Build Service (TBS) version `1.7.4`.

Install the package repository, pointing to the manifests in Harbor.

```sh
tanzu package repository add tbs-full-deps-repository \
  --url $HARBOR_HOSTNAME/buildservice/tbs-full-deps:$TBS_VERSION  \
  --namespace tap-install
```

Verify the packages are available.

```sh
tanzu package repository list --namespace tap-install
```

We can then install the all the dependencies.

```sh
tanzu package install full-tbs-deps \
  -p full-tbs-deps.tanzu.vmware.com \
  -v $TBS_VERSION \
  -n tap-install
```

## Install TAP Profiles

The suggested order is as follows:

* [View](/tanzu/tkgs/tap13/view)
* [Build - Basic Supply Chain](/tanzu/tkgs/tap13/build-basic/)
* [Build - Scanning & Testing](/tanzu/tkgs/tap13/build-scanning-testing/)
* [Run](/tanzu/tkgs/tap13/run/)

With the addition that if you install for the first time, you first in stall the Basic Supply Chain with the Build profile.

Once you prove the Build profile works, you update it to the Scanning & Testing supply chain.

You can also wait with that update, until you've completed the complete View, Build, and Run setup.

## Setup Developer Namespace

To make a namespace usable for TAP, we need the following:

* the namespace needs to exist
* we need the `registry-credentials` secret for reading/writing to and from the OCI registry
* [rbac permissions](https://github.com/joostvdg/tanzu-example/blob/main/tap/scripts/dev-namespace-rbac.yml) for the namespace's default **Service Account**

This script resides in the [tap/1.3.4/scripts](https://github.com/joostvdg/tanzu-example/tree/main/tap/1.3.4/scripts) folder.

```sh
./tap-developer-namespace.sh
```

??? Example "Create Developer Namespace Script"

    ```sh
    #!/usr/bin/env bash
    set -euo pipefail

    DEVELOPER_NAMESPACE=${DEVELOPER_NAMESPACE:-"default"}
    BUILD_REGISTRY=${BUILD_REGISTRY:-""}
    BUILD_REGISTRY_USER=${BUILD_REGISTRY_USER:-""}
    BUILD_REGISTRY_PASS=${BUILD_REGISTRY_PASS:-""}

    echo "> Creating Dev namspace $DEVELOPER_NAMESPACE"
    kubectl create ns ${DEVELOPER_NAMESPACE} || true

    echo "> Creating Dev namespace registry secret"
    tanzu secret registry add registry-credentials  \
      --server    $BUILD_REGISTRY \
      --username  $BUILD_REGISTRY_USER \
      --password  $BUILD_REGISTRY_PASS \
      --namespace ${DEVELOPER_NAMESPACE} \
      --yes

    echo "> Configuring RBAC for developer namespace"
    kubectl apply -f dev-namespace-rbac.yml -n $DEVELOPER_NAMESPACE
    ```

    You can also run this as follows, to setup a different namespace than `default`.

    ```sh
    DEVELOPER_NAMESPACE="some-other-namespace" ./tap-build-install-basic.sh
    ```

## Cross-cluster Test

* https://docs.vmware.com/en/VMware-Tanzu-Application-Platform/1.3/tap/GUID-multicluster-getting-started.html#start-the-workload-on-the-build-profile-cluster-1

### Get Deliverable

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

### Verify Application

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