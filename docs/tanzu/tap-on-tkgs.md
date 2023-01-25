---
tags:
  - TKG
  - Vsphere
  - TAP
  - 1.3
  - TANZU
---

title: TAP on TKGs
description: Tanzu Application Platform on vSphere with Tanzu

# TAP on TKGs

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

The scripts and other configuration files can found in my [Tanzu Example](https://github.com/joostvdg/tanzu-example/tree/main/tap) repository.

!!! Warning
    This guide is tested with TAP `1.3.x`, not everything applies for `1.4.0+`.

## Steps

* installation machine pre-requisites
* shared services cluster pre-requisites
* Harbor and prepare TAP images
* TAP Run profile
* TAP Build profile

## Machine Pre-requisites

We have pre-requisites for the cluster, and we have pre-requisites for the machine which runs the commands.
Here are the pre-requisites for all the commands:

* [Kubernetes CLI Tools for vSphere](https://docs.vmware.com/en/VMware-vSphere/7.0/vmware-vsphere-with-tanzu/GUID-0F6E45C4-3CB1-4562-9370-686668519FCA.html)
* [Tanzu CLI v1.4 or later](https://docs.vmware.com/en/VMware-Tanzu-Kubernetes-Grid/1.6/vmware-tanzu-kubernetes-grid-16/GUID-install-cli.html)
* Tanzu CLI plugins for TKGs
* Tanzu CLI plugins for TAP
* kubectl
* yq
* jq
* http (or Curl)
* Carvel tools (mostly `ytt`)

## TKGs Considerations

!!! warning

    There are several requirements to your TKGs workload clusters.
    
    1. **Trust CA**: In order to trust the certificate of Harbor for using images from there, 
    your worker nodes need to trust it.

    2. **Memory & CPU** TAP is resource intensive, reserve at least 12 CPU and 10GB of RAM for a full TAP install. About half for Run or Build profiles.

    3. **Storage** Tanzu Build Service will store its images on the nodes. These worker nodes need at leat 70GB of storage available.

    ??? example "Cluster Definition"

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

## Certificate Authority

In Addition, we need to have the Certificate Authority.

If you don't have one, or want to learn how to create one yourself, follow along.
We use the tools from [CloudFlare](https://github.com/cloudflare/cfssl), **cfssl**, for this.

The documentation is pretty heavy and hard to follow at times, so we take inspiration from this [Medium blog post](https://rob-blackbourn.medium.com/how-to-use-cfssl-to-create-self-signed-certificates-d55f76ba5781) to stick to the basics.

The steps are as follows:

* create cfssl profile
* create CA config
* generate CA certificate and key
* create server certificate JSON config
* generate derived certificate and key

The step _generate derived certificate and key_ is done later, when we generate the Harbor certificate (our self-hosted registry of choice).

### CFSSL Profile

Save the following as `cfssl.json`:

```json title="cfssl.json"
{
  "signing": {
    "default": {
      "expiry": "8760h"
    },
    "profiles": {
      "intermediate_ca": {
        "usages": [
            "signing",
            "digital signature",
            "key encipherment",
            "cert sign",
            "crl sign",
            "server auth",
            "client auth"
        ],
        "expiry": "8760h",
        "ca_constraint": {
            "is_ca": true,
            "max_path_len": 0,
            "max_path_len_zero": true
        }
      },
      "peer": {
        "usages": [
            "signing",
            "digital signature",
            "key encipherment",
            "client auth",
            "server auth"
        ],
        "expiry": "8760h"
      },
      "server": {
        "usages": [
          "signing",
          "digital signing",
          "key encipherment",
          "server auth"
        ],
        "expiry": "8760h"
      },
      "client": {
        "usages": [
          "signing",
          "digital signature",
          "key encipherment",
          "client auth"
        ],
        "expiry": "8760h"
      }
    }
  }
}
```

### Create CA

Create a JSON config file for your CA: `ca.json`.

This file contains the values of your CA.

```json title="ca.json"
{
  "CN": "Kearos Tanzu Root CA",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "NL",
      "L": "Utrecht",
      "O": "Kearos",
      "OU": "Kearos Tanzu",
      "ST": "Utrecht"
    }
  ]
}
```

!!! info "Field names meaning"

    If you are wondering what those names, such as `C`, `L`, mean, here's a table:

    | Abbreviation | Description          |
    | :----------- | :--------------------|
    | **CN**       |  CommonName          |
    | **OU**       |  OrganizationalUnit  |
    | **O**        |  Organization        |        
    | **L**        |  Locality            |
    | **S**        |  StateOrProvinceName |   
    | **C**        |  CountryName or CountryCode         |       

And then generate the `ca.pem` and `ca-key.pem` files:

```sh
cfssl gencert -initca ca.json | cfssljson -bare ca
```

### Create Server Certificate Config file

This is very similar to the `ca.json` file, you can copy most of it.

You can include the `CN` and `hostnames` fields, but if you want to generate more than one certificate (for multiple hosts), it is better to leave them blank.
In the command with which you generate the certificate, you can then supply those with environment variables to make them more dynamic, and make it easier to update them later.

Create the following file: `base-service-cert.json`

```json title="base-service-cert.json"
{
    "key": {
      "algo": "rsa",
      "size": 2048
    },
    "names": [
        {
            "C": "NL",
            "L": "Utrecht",
            "O": "Kearos Tanzu",
            "OU": "Kearos Tanzu Hosts",
            "ST": "Utrecht"
        }
    ]
}
```

## Install Shared Services Cluster Pre-requisites

We need to setup permissions, install an Ingress Controller, and install our self-hosted Container Registry.

### PodSecurityPolicies

By default, TKGs has restrictions in place that will prevent us from installing all the pre-requisites.
So we have to give our (admin) account enough permissions by applying the following PodSecurityPolicy and bind it to our user group.

```sh
kubectl create role psp:privileged \
    --verb=use \
    --resource=podsecuritypolicy \
    --resource-name=vmware-system-privileged

kubectl create clusterrolebinding default-tkg-admin-privileged-binding \
    --clusterrole=psp:vmware-system-privileged \
    --group=system:authenticated
```

### Kapp Controller & Package Repository

We need to install several services into our cluster, such as an Ingress Controller.
We will do so via the Tanzu Packages, and for that we need to install the [Kapp Controller](https://docs.vmware.com/en/VMware-Tanzu-Kubernetes-Grid/1.6/vmware-tanzu-kubernetes-grid-16/GUID-packages-prep-tkgs-kapp.html)

The Kapp Controller comes with its on requirements on permissions, so we begin with a **PodSecurityPolicy**.

```sh
kubectl apply -f tanzu-system-kapp-ctrl-restricted.yaml
```

#### Kapp Controller Pod Security Policy

```yaml title="tanzu-system-kapp-ctrl-restricted.yaml"
apiVersion: policy/v1beta1
kind: PodSecurityPolicy
metadata:
  name: tanzu-system-kapp-ctrl-restricted
spec:
  privileged: false
  allowPrivilegeEscalation: false
  requiredDropCapabilities:
    - ALL
  volumes:
    - configMap
    - emptyDir
    - projected
    - secret
    - downwardAPI
    - persistentVolumeClaim
  hostNetwork: false
  hostIPC: false
  hostPID: false
  runAsUser:
    rule: MustRunAsNonRoot
  seLinux:
    rule: RunAsAny
  supplementalGroups:
    rule: MustRunAs
    ranges:
      - min: 1
        max: 65535
  fsGroup:
    rule: MustRunAs
    ranges:
      - min: 1
        max: 65535
  readOnlyRootFilesystem: false
```

#### Install Kapp Controller

We have to add a [Kapp Controller Configuration](https://carvel.dev/kapp-controller/docs/v0.42.0/controller-config/),
so the Kapp Controller accepts our Custom CA.

```sh
export CA_CERT=$(cat ssl/ca.pem)
export KAPP_CONTROLLER_NAMESPACE="tkg-system"
```

```sh
ytt -f ytt/kapp-controller.ytt.yml \
  -v namespace="$KAPP_CONTROLLER_NAMESPACE" \
  -v caCert="${CA_CERT}" \
  > "kapp-controller.yml"
```

```sh
kubectl apply -f kapp-controller.yml
```

```sh
kubectl get pods -n ${KAPP_CONTROLLER_NAMESPACE} | grep kapp-controller
```

#### Package Repository

At the time of writing, November 2022, the latest supported TKG version is 1.6.
So we use the 1.6 package repository.

```sh
export PKG_REPO_NAME=tanzu-standard
export PKG_REPO_URL=projects.registry.vmware.com/tkg/packages/standard/repo:v1.6.0
export PKG_REPO_NAMESPACE=tanzu-package-repo-global
```

!!! info
    The namespace `tanzu-package-repo-global` is a special namespace.

    If you install the Kapp Controller as we did, that namespace is considered the _packaging global_ namespace.
    This mean that any package made available there, via a Package Repository, can have an instance installed in any namespace.

    Otherwise, you can only create a package instance in the namespace the package is installed in.

```sh
tanzu package repository add ${PKG_REPO_NAME} \
    --url ${PKG_REPO_URL} \
    --namespace ${PKG_REPO_NAMESPACE}
```

This should yield the following:

```sh
 Adding package repository 'tanzu-standard'
 Validating provided settings for the package repository
 Creating package repository resource
 Waiting for 'PackageRepository' reconciliation for 'tanzu-standard'
 'PackageRepository' resource install status: Reconciling
 'PackageRepository' resource install status: ReconcileSucceeded
 'PackageRepository' resource successfully reconciled
Added package repository 'tanzu-standard' in namespace 'tanzu-package-repo-global'
```

Verify the package repository is healthy.

```sh
tanzu package repository get ${PKG_REPO_NAME} --namespace ${PKG_REPO_NAMESPACE}
```

We can now view all the available packages.

```sh
tanzu package available list
```

```sh
  NAME                                          DISPLAY-NAME               SHORT-DESCRIPTION                                                                 LATEST-VERSION         
  cert-manager.tanzu.vmware.com                 cert-manager               Certificate management                                                            1.7.2+vmware.1-tkg.1   
  contour.tanzu.vmware.com                      contour                    An ingress controller                                                             1.20.2+vmware.1-tkg.1  
  external-dns.tanzu.vmware.com                 external-dns               This package provides DNS synchronization functionality.                          0.11.0+vmware.1-tkg.2  
  fluent-bit.tanzu.vmware.com                   fluent-bit                 Fluent Bit is a fast Log Processor and Forwarder                                  1.8.15+vmware.1-tkg.1  
  fluxcd-helm-controller.tanzu.vmware.com       Flux Helm Controller       Helm controller is one of the components in FluxCD GitOps toolkit.                0.21.0+vmware.1-tkg.1  
  fluxcd-kustomize-controller.tanzu.vmware.com  Flux Kustomize Controller  Kustomize controller is one of the components in Fluxcd GitOps toolkit.           0.24.4+vmware.1-tkg.1  
  fluxcd-source-controller.tanzu.vmware.com     Flux Source Controller     The source-controller is a Kubernetes operator, specialised in artifacts          0.24.4+vmware.1-tkg.4  
                                                                           acquisition from external sources such as Git, Helm repositories and S3 buckets.                         
  grafana.tanzu.vmware.com                      grafana                    Visualization and analytics software                                              7.5.16+vmware.1-tkg.1  
  harbor.tanzu.vmware.com                       harbor                     OCI Registry                                                                      2.5.3+vmware.1-tkg.1   
  multus-cni.tanzu.vmware.com                   multus-cni                 This package provides the ability for enabling attaching multiple network         3.8.0+vmware.1-tkg.1   
                                                                           interfaces to pods in Kubernetes                                                                         
  prometheus.tanzu.vmware.com                   prometheus                 A time series database for your metrics                                           2.36.2+vmware.1-tkg.1  
  whereabouts.tanzu.vmware.com                  whereabouts                A CNI IPAM plugin that assigns IP addresses cluster-wide                          0.5.1+vmware.2-tkg.1   
```

### Certmanager & Contour Packages

We need an Ingress Controller.
The Ingress Controller of choice for VMware is [Contour](https://projectcontour.io/).

While not strictly necessary, VMware always recommends installing [Certmanager](https://cert-manager.io/docs/) before Contour.

We don't specify anything specific for these two packakages, sticking to the [VMware suggested values](https://docs.vmware.com/en/VMware-Tanzu-Kubernetes-Grid/1.6/vmware-tanzu-kubernetes-grid-16/GUID-packages-ingress-contour.html).

```sh
cd scripts && sh 10-cluster-add-contour-package.sh tap-s1
```

??? example "10-cluster-add-contour-package.sh"

    ```sh title="10-cluster-add-contour-package.sh"
    #!/bin/bash
    CLUSTER_NAME=$1
    INFRA=vsphere
    PACKAGES_NAMESPACE="tanzu-packages"

    echo "Creating namespace ${PACKAGES_NAMESPACE} for holding package installations"
    kubectl create namespace ${PACKAGES_NAMESPACE}

    ./install-package-with-latest-version.sh $CLUSTER_NAME cert-manager
    kubectl get po,svc -n cert-manager

    ./install-package-with-latest-version.sh $CLUSTER_NAME contour "${INFRA}-values/contour.yaml"
    kubectl get po,svc,ing --namespace tanzu-system-ingress
    ```

??? example "install-package-with-latest-version.sh"

    ```sh title="install-package-with-latest-version.sh"
    #!/bin/bash
    CLUSTER_NAME=$1
    PACKAGE_NAME=$2
    VALUES_FILE=$3
    PACKAGES_NAMESPACE="tanzu-packages"

    echo "Retrieving latest version of ${PACKAGE_NAME}.tanzu.vmware.com package"
    PACKAGE_VERSION=$(tanzu package \
        available list ${PACKAGE_NAME}.tanzu.vmware.com -A \
        --output json | jq --raw-output 'sort_by(.version)|reverse|.[0].version')

    echo "Installing package ${PACKAGE_NAME} version ${PACKAGE_VERSION} into namespace ${PACKAGES_NAMESPACE}"
    INSTALL_COMMAND="tanzu package install ${PACKAGE_NAME}  \
        --package-name ${PACKAGE_NAME}.tanzu.vmware.com \
        --namespace ${PACKAGES_NAMESPACE} \
        --version ${PACKAGE_VERSION} "

    if [ -n "$3" ]; then
        echo "Found a values file, appending to command"
        INSTALL_COMMAND="${INSTALL_COMMAND} --values-file ${VALUES_FILE}"
    fi
    eval $INSTALL_COMMAND
    ```

## Install Harbor and prepare TAP images

We use [Harbor](https://goharbor.io/) as our Container Registry of choice.

Once installed, we relocate the OCI images and bundles related to TAP and Tanzu Build Service (TBS) to Harbor.

### Prepare Harbor Certificate

The first thing we will do, is generate a certificate for Harbor.
For this, we need to know all the names it should be known as, for both internal and external traffic.

In this scenario, I'm using [sslip.io](https://sslip.io/) to fake a full FQN domain name.
It will resolve `<anything>.<valid IP address>.sslip.io` to the valid IP addres.

```sh
export LB_IP=$(kubectl get svc -n tanzu-system-ingress envoy -o jsonpath="{.status.loadBalancer.ingress[0].ip}")
export DOMAIN="${LB_IP}.sslip.io"
export HARBOR_HOSTNAME="harbor.${DOMAIN}"
export NOTARY_HOSTNAME="notary.${HARBOR_HOSTNAME}"
echo "HARBOR_HOSTNAME=${HARBOR_HOSTNAME}"
echo "NOTARY_HOSTNAME=${NOTARY_HOSTNAME}"
```

We use the `cfssl` utility to generate the Harbor certificate, signing it with the CA we created earlier.

```sh
cfssl gencert -ca ssl/ca.pem -ca-key ssl/ca-key.pem \
  -config ssl/cfssl.json \
  -profile=server \
  -cn="${HARBOR_HOSTNAME}" \
  -hostname="${HARBOR_HOSTNAME},${NOTARY_HOSTNAME},harbor.harbor.svc.cluster.local,localhost" \
   ssl/base-service-cert.json   | cfssljson -bare harbor
```

I like to separate my files, so I move them to the `ssl` folder, but feel free to skip this.
Just remember that if you do, change the location of the files in the environment variables below.

```sh
mv harbor.csr  ssl/harbor.csr
mv harbor-key.pem ssl/harbor-key.pem
mv harbor.pem ssl/harbor.pem
```

### Configure Harbor Values

We need to set the storage class for several volumes.

```sh
kubectl get storageclass
```

In my case, the storage class is what is defined below.
I also load up the certificate values into environment variables.

```sh
export STORAGE_CLASS="vc01cl01-t0compute"
export CLUSTER_NAME=tap-s1
export HARBOR_NAMESPACE=tanzu-system-registry
export HARBOR_ADMIN_PASS=''
export TLS_CERT=$(cat ssl/harbor.pem)
export TLS_KEY=$(cat ssl/harbor-key.pem)
export CA_CERT=$(cat ssl/ca.pem)
```

This way we can leverage **ytt** to use our values template to generate the values file we will use.

```sh
ytt -f ytt/harbor.ytt.yml \
  -v namespace="$HARBOR_NAMESPACE" \
  -v adminPassword="$HARBOR_ADMIN_PASS" \
  -v hostname="$HARBOR_HOSTNAME" \
  -v storaceClass="$STORAGE_CLASS" \
  -v tlsCert="${TLS_CERT}" \
  -v tlsKey="${TLS_KEY}" \
  -v caCert="${CA_CERT}" \
  > "vsphere-values/${CLUSTER_NAME}-harbor.yml"
```

??? example "Harbor Values Template"

    There are a couple of more secret values in here.
    They need to be defined, but won't be used in this guide.

    Feel free to change them.

    ```yaml title="ytt/harbor.ytt.yml"
    #@ load("@ytt:data", "data")
    ---
    namespace: #@ data.values.namespace
    hostname: #@ data.values.hostname
    port:
      https: 443
    logLevel: info
    tlsCertificate:
      tls.crt: #@ data.values.tlsCert
      tls.key: #@ data.values.tlsKey
      ca.crt: #@ data.values.caCert
    enableContourHttpProxy: true
    harborAdminPassword: #@ data.values.adminPassword
    secretKey: j0Kn0UlfSGzMTBx6
    database:
      password: 4Oj0848rTIvzJiMc
    core:
      replicas: 1
      secret: vFib2c87qg1FFZqI
      xsrfKey: sGn5nIgBQKdwx89tZLO5pTJAqbCwVRU8
    jobservice:
      replicas: 1
      secret: vFib2c87qg1FFZqI
    registry:
      replicas: 1
      secret: vFib2c87qg1FFZqI
    notary:
      enabled: true
    trivy:
      enabled: true
      replicas: 1
      gitHubToken: ""
      skipUpdate: true
    persistence:
      persistentVolumeClaim:
        registry:
          storageClass: #@ data.values.storaceClass
          accessMode: ReadWriteOnce
          size: 100Gi
        jobservice:
          storageClass: #@ data.values.storaceClass
          accessMode: ReadWriteOnce
          size: 1Gi
        database:
          storageClass: #@ data.values.storaceClass
          accessMode: ReadWriteOnce
          size: 1Gi
        redis:
          storageClass: #@ data.values.storaceClass
          accessMode: ReadWriteOnce
          size: 1Gi
        trivy:
          storageClass: #@ data.values.storaceClass
          accessMode: ReadWriteOnce
          size: 5Gi
      imageChartStorage:
        disableredirect: false
        type: filesystem
        filesystem:
          rootdirectory: /storage
    pspNames: vmware-system-privileged
    metrics:
      enabled: false
      core:
        path: /metrics
        port: 8001
      registry:
        path: /metrics
        port: 8001
      jobservice:
        path: /metrics
        port: 8001
      exporter:
        path: /metrics
        port: 8001
    network:
      ipFamilies: ["IPv4", "IPv6"]
    ```

### Install Harbor

Now that we have the values file, we can install Harbor.

```sh
sh 20-cluster-add-harbor-package.sh tap-s1
```

??? example "20-cluster-add-harbor-package.sh"

    ```sh title="20-cluster-add-harbor-package.sh"
    #!/bin/bash
    CLUSTER_NAME=$1
    INFRA=vsphere
    HARBOR_VALUES_CLUSTER="${INFRA}-values/${CLUSTER_NAME}-harbor.yml"
    PACKAGES_NAMESPACE="tanzu-packages"

    ./install-package-with-latest-version.sh $CLUSTER_NAME harbor "${HARBOR_VALUES_CLUSTER}"
    kubectl --namespace tanzu-system-registry get po,svc
    ```

#### Create Harbor Projects

To store images for TAP and for our applications, we need projects in Harbor to exist.
We make them all public, to avoid having to create image pull secret, but feel free to do otherwise.

Create the following Harbor Projects:

* tap
* tap-apps
* buildservice

```sh
http -a admin:${HARBOR_ADMIN_PASS} POST "https://${HARBOR_HOSTNAME}/api/v2.0/projects" project_name="tap" public:=true --verify=false
http -a admin:${HARBOR_ADMIN_PASS} POST "https://${HARBOR_HOSTNAME}/api/v2.0/projects" project_name="tap-apps" public:=true --verify=false
http -a admin:${HARBOR_ADMIN_PASS} POST "https://${HARBOR_HOSTNAME}/api/v2.0/projects" project_name="buildservice" public:=true --verify=false
```

## Copy TAP Images To Harbor

* [configure local Docker client](https://docs.docker.com/engine/security/certificates/) to accept Harbor's CA
* use Carvel's `imgpkg` to copy TAP images from Tanzu Network to Harbor

```sh
export TAP_VERSION="1.3.0"
export TANZU_NETWORK_USER=
export TANZU_NETWORK_PASS=
```

* https://network.tanzu.vmware.com/products/tanzu-application-platform/releases

```sh
docker login registry.tanzu.vmware.com --username ${TANZU_NETWORK_USER} --password ${TANZU_NETWORK_PASS}
```

```sh
docker login ${HARBOR_HOSTNAME}
```

```sh
imgpkg copy --registry-verify-certs=false \
 -b registry.tanzu.vmware.com/tanzu-application-platform/tap-packages:${TAP_VERSION} \
 --to-repo ${HARBOR_HOSTNAME}/tap/tap-packages
```

```sh
kubectl run harbor-pull-test --rm -i --tty --image harbor.10.220.2.199.sslip.io/tap/tap-packages@sha256:294375529dcb63736cbb82da74b0b366b75c122886da7340426367b6a2762b5f
```

### Copy TBS Images To Harbor

* https://docs.vmware.com/en/Tanzu-Build-Service/1.7/vmware-tanzu-build-service/GUID-installing.html
* https://docs.vmware.com/en/VMware-Tanzu-Application-Platform/1.3/tap/GUID-tbs-offline-install-deps.html

```sh
TBS_VERSION=1.7.2
```

```sh
imgpkg copy -b registry.tanzu.vmware.com/build-service/package-repo:$TBS_VERSION \
  --to-repo=harbor.10.220.2.199.sslip.io/buildservice/build-service
```

### Copy TBS Dependencies

!!! warning
    This did not work for me!

```sh
imgpkg copy -b registry.tanzu.vmware.com/tanzu-application-platform/full-tbs-deps-package-repo:$TBS_VERSION \
  --to-repo=harbor.10.220.2.199.sslip.io/buildservice/tbs-full-deps
```

```sh
tanzu package repository add tbs-full-deps-repository \
  --url harbor.10.220.2.199.sslip.io/buildservice/tbs-full-deps:${TBS_VERSION} \
  --namespace tap-install
```

```sh
tanzu package install full-tbs-deps -p full-tbs-deps.tanzu.vmware.com -v ${TBS_VERSION} -n tap-install
```

#### TBS Airgapped - 1

!!! important
    This solution worked, but only when doing both the image uploads as the `kbld` and `kpack` steps!

```sh
export TBS_DEP_FULL_VERSION="100.0.365"
```

```sh
imgpkg copy -b registry.tanzu.vmware.com/tbs-dependencies/full:${TBS_DEP_FULL_VERSION} \
  --to-tar=/tmp/tbs-dependencies.tar
```


```sh
imgpkg copy --tar=/tmp/tbs-dependencies.tar \
  --to-repo harbor.10.220.2.199.sslip.io/build-service/tbs-dependencies/full \
  --registry-ca-cert-path ssl/ca.pem
```

```sh
imgpkg pull -b harbor.10.220.2.199.sslip.io/build-service/tbs-dependencies/full:${TBS_DEP_FULL_VERSION} \
  -o /tmp/descriptor-bundle \
  --registry-ca-cert-path ssl/ca.pem
```

```sh
kbld -f /tmp/descriptor-bundle/.imgpkg/images.yml \
  -f /tmp/descriptor-bundle/tanzu.descriptor.v1alpha3/descriptor-100.0.365.yaml \
  | kp import -f - --registry-ca-cert-path ssl/ca.pem
```

```sh
kbld -f /tmp/descriptor-bundle/.imgpkg/images.yml \
  -f /tmp/descriptor-bundle/tanzu.descriptor.v1alpha3/descriptor-100.0.365.yaml \
  > kbld-output.yml
```

```sh
kp import --show-changes -f kbld-output.yml --registry-ca-cert-path ssl/ca.pem
```

!!! danger
    This looks at the current cluster for KPack configuration, which will override what's inside of `kbld`'s output.

    I assume this is the variable managed by `buildservice.kp_default_repository` in TAP's configuration.

    It ends up in a **ConfigMap** named `kp-config` in the namespace `kpack` as `default.repository`.
    Change this if the output of the `--show-changes` gives the wrong URL.

#### TBS Airgapped - 2

```sh
imgpkg copy -b registry.tanzu.vmware.com/build-service/bundle:${TBS_VERSION}\
  --to-tar=/tmp/tanzu-build-service.tar
```

```sh
imgpkg copy --tar /tmp/tanzu-build-service.tar \
  --to-repo=harbor.10.220.2.199.sslip.io/build-service/build-service/ \
  --registry-ca-cert-path ssl/ca.pem
```

### Confirm Nodes Can Pull From Harbor

We need to confirm our nodes trust Harbor's CA.

```sh
docker pull eu.gcr.io/cf-ism-0/tap-trp-gcp:0.1.0
docker tag eu.gcr.io/cf-ism-0/tap-trp-gcp:0.1.0 harbor.10.220.2.199.sslip.io/tap-apps/tap-trp-gcp:0.1.0
docker push harbor.10.220.2.199.sslip.io/tap-apps/tap-trp-gcp:0.1.0
```

```sh
kubectl run tmp-shell-3 --rm -i --tty --image harbor.10.220.2.199.sslip.io/tap-apps/tap-trp-gcp:0.1.0 -- /bin/bash
```

## TAP Build Cluster

### Install TAP Build Profile


```sh
export INSTALL_REGISTRY_HOSTNAME=
export INSTALL_REGISTRY_USERNAME=
export INSTALL_REGISTRY_PASSWORD=

export BUILD_REGISTRY=
export BUILD_REGISTRY_REPO=
export BUILD_REGISTRY_USER=
export BUILD_REGISTRY_PASS=

export TBS_REPO=build-service/tbs-dependencies/full

export LB_IP=$(kubectl get svc -n tanzu-system-ingress envoy -o jsonpath="{.status.loadBalancer.ingress[0].ip}")
export DOMAIN_NAME="${LB_IP}.sslip.io"
export DEVELOPER_NAMESPACE="default"
export CA_CERT=$(cat ssl/ca.pem)
```

```sh
./tap-build-install.sh
```

### Setup Developer Namespace (Build)

To make a namespace usable for TAP, we need the following:

* the namespace needs to exist
* we need the `registry-credentials` secret for reading/writing to and from the OCI registry
* [rbac permissions](https://github.com/joostvdg/tanzu-example/blob/main/tap/scripts/dev-namespace-rbac.yml) for the namespace's default **Service Account**

!!! Example "Setup Develop Namespace Script"
    This script resides in the [tap/scripts](https://github.com/joostvdg/tanzu-example/blob/main/tap/scripts/tap-developer-namespace.sh) folder.

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
    This script resides in the [tap/scripts](https://github.com/joostvdg/tanzu-example/blob/main/tap/scripts/tap-developer-namespace.sh) folder.

    It does all the steps outlined in this paragraph, including the wait and cleanup.

    ```sh
    ./tap-workload-demo.sh
    ```

## Tap Run Cluster

### PodSecurity Fixes

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

### TAP Run Profile Install

```sh
export INSTALL_REGISTRY_HOSTNAME=
export INSTALL_REGISTRY_USERNAME=
export INSTALL_REGISTRY_PASSWORD=

export BUILD_REGISTRY=
export BUILD_REGISTRY_REPO=
export BUILD_REGISTRY_USER=
export BUILD_REGISTRY_PASS=

export DOMAIN_NAME="127.0.0.1.sslip.io"
export DEVELOPER_NAMESPACE="default"
export CA_CERT=$(cat ssl/ca.pem)
```

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
    This script resides in the [tap/scripts](https://github.com/joostvdg/tanzu-example/blob/main/tap/scripts/tap-run-install.sh) folder.

    It Creates the necessary namespaces, secrets and installs Kapp Controller, SecretGen Controller and lastly; TAP.

    ```sh
    export LB_IP=$(kubectl get svc -n tanzu-system-ingress envoy -o jsonpath="{.status.loadBalancer.ingress[0].ip}")
    export DOMAIN_NAME="${LB_IP}.sslip.io"
    echo "DOMAIN_NAME=${DOMAIN_NAME}"
    ```

    ```sh
    ./tap-run-install.sh
    ```

### Setup Developer Namespace (RUN)

To make a namespace usable for TAP, we need the following:

* the namespace needs to exist
* we need the `registry-credentials` secret for reading/writing to and from the OCI registry
* [rbac permissions](https://github.com/joostvdg/tanzu-example/blob/main/tap/scripts/dev-namespace-rbac.yml) for the namespace's default **Service Account**

!!! Example "TAP Install Script"
    This script resides in the [tap/scripts](https://github.com/joostvdg/tanzu-example/blob/main/tap/scripts/tap-developer-namespace.sh) folder.

    ```sh
    ./tap-developer-namespace.sh
    ```

!!! failure
    As of November 1st, we have to exclude the package `policy.apps.tanzu.vmware.com`, due to a breaking bug.
    Currently the  only remedy is [to disable it](https://docs.vmware.com/en/VMware-Tanzu-Application-Platform/1.3/tap/GUID-scst-policy-known-issues.html?hWord=N4IghgNiBcIC4FcBmB9AtgSwE5YPZZAF8g).

## Cross-cluster Test

* https://docs.vmware.com/en/VMware-Tanzu-Application-Platform/1.3/tap/GUID-multicluster-getting-started.html

### Get Deliverable From Build Cluster

```sh
kubectl get deliverable --namespace ${DEVELOPER_NAMESPACE}
```

```sh
NAME              SOURCE                                                                                                      DELIVERY   READY   REASON             AGE
tap-hello-world   harbor.10.220.2.199.sslip.io/tap-apps/tap-hello-world-default-bundle:d64bca4f-e168-432b-bcf0-639494e9ce3f              False   DeliveryNotFound   12h
```

```sh
kubectl get deliverable tap-hello-world --namespace ${DEVELOPER_NAMESPACE} -oyaml > deliverable.yml
```

Cleanup the Deliverable.

* remove the Deliverable from the cluster: else we do not get an updated one when you push new code
* remove the owner reference and the status block from the `deliverable.yml` file

```sh
kubectl delete deliverable tap-hello-world --namespace ${DEVELOPER_NAMESPACE} 
```

### Apply Cleaned Deliverable To Run Cluster

* TODO: automate this
* TODO: add FluxCD to Run cluster
* TODO: add this to Git Repo that is watched by FluxCD

```sh
kubectl apply -f deliverable.yml --namespace ${DEVELOPER_NAMESPACE}
```

```sh
kubectl get deliverables --namespace ${DEVELOPER_NAMESPACE}
```

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