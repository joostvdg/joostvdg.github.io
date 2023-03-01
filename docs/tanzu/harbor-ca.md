---
tags:
  - TKG
  - Vsphere
  - Harbor
  - TANZU
---

title: Harbor custom CA
description: Harbor with a Custom CA

# Harbor custom CA

As a pre-requisite, make sure you have setup a Certificate Authirity with [CFSSL](https://github.com/cloudflare/cfssl).

If you not already done so, follow [Set up custom Certificate Authority](/tanzu/custom-ca/).

## Install Shared Services Cluster Pre-requisites

We need to setup permissions, install an Ingress Controller, and install our self-hosted Container Registry.

### PodSecurityPolicies - TGKs

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

    The scripts can be found [here](https://github.com/joostvdg/tanzu-example/tree/main/tap/).

    ```sh title="20-cluster-add-harbor-package.sh"
    #!/bin/bash
    CLUSTER_NAME=$1
    INFRA=vsphere
    HARBOR_VALUES_CLUSTER="${INFRA}-values/${CLUSTER_NAME}-harbor.yml"
    PACKAGES_NAMESPACE="tanzu-packages"

    ./install-package-with-latest-version.sh $CLUSTER_NAME harbor "${HARBOR_VALUES_CLUSTER}"
    kubectl --namespace tanzu-system-registry get po,svc
    ```

### Test Image From Harbor

```sh
docker tag joostvdgtanzu/go-demo-kbld:kbld-rand-1674551140548590000-1629935139128 ${HARBOR_HOSTNAME}/tap-apps/go-demo:0.1.0
docker push ${HARBOR_HOSTNAME}/tap-apps/go-demo:0.1.0
```

```sh
kubectl run go-demo --image ${HARBOR_HOSTNAME}/tap-apps/go-demo:0.1.0
```

```sh
kubectl port-forward go-demo 8080:8080
```

```sh
http :8080/
```

```sh
curl http://localhost:8080
```