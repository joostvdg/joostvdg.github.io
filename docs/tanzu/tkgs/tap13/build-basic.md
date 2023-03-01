---
tags:
  - TKG
  - Vsphere
  - TAP
  - 1.3.4
  - TANZU
---

title: TAP Build Profile - Basic Supply Chain
description: TAP Build Profile with Basic Supply Chain on vSphere with Tanzu

# TAP Build Profile - Basic Supply Chain

The basic profile uses the basic supply chain.

This means it does not install Grype and the Metadata store, and other scanning related tools.

Make sure you go through the [Satisfy Pre-requisites](/tanzu/tkgs/tap13-overview/#satisfy-pre-requisites) section of the main guide first.

Now that we have all the pre-requisites out of the way, we can install the actual profile.

## Install Script

The install script encapsulates installed the Cluster Essentials, if required, and the TAP Fundamentals (secrets, namespace etc.) if required.

It also creates a package values file via a YTT template.

```sh title="tap-build-install-basic.sh"
#!/usr/bin/env bash
set -euo pipefail

TAP_VERSION=${TAP_VERSION:-"1.3.4"}
TAP_INSTALL_NAMESPACE="tap-install"
SECRET_GEN_VERSION=${SECRET_GEN_VERSION:-"v0.9.1"}
DOMAIN_NAME=${DOMAIN_NAME:-"127.0.0.1.nip.io"}
DEVELOPER_NAMESPACE=${DEVELOPER_NAMESPACE:-"default"}
INSTALL_TAP_FUNDAMENTALS=${INSTALL_TAP_FUNDAMENTALS:-"true"}
INSTALL_CLUSTER_ESSENTIALS=${INSTALL_CLUSTER_ESSENTIALS:-"false"}
BUILD_REGISTRY_SECRET=${BUILD_REGISTRY_SECRET:-"registry-credentials"}

if [ "$INSTALL_CLUSTER_ESSENTIALS" = "true" ]; then
  echo "> Installing Cluster Essentials (Kapp Controller, SecretGen Controller)"
  ./install-cluster-essentials.sh
fi

if [ "$INSTALL_TAP_FUNDAMENTALS" = "true" ]; then
  echo "> Installing TAP Fundamentals (namespace, secrets)"
  ./install-tap-fundamentals.sh
fi

ytt -f ytt/tap-build-profile-basic.ytt.yml \
  -v tbsRepo="$TBS_REPO" \
  -v buildRegistry="$BUILD_REGISTRY" \
  -v buildRegistrySecret="$BUILD_REGISTRY_SECRET" \
  -v buildRepo="$BUILD_REGISTRY_REPO" \
  -v domainName="$DOMAIN_NAME" \
  -v caCert="${CA_CERT}" \
  > "tap-build-basic-values.yml"


tanzu package installed update --install tap \
  -p tap.tanzu.vmware.com \
  -v $TAP_VERSION \
  --values-file tap-build-basic-values.yml \
  -n ${TAP_INSTALL_NAMESPACE}
```

## YTT Template

The YTT template makes it easy to generate different configurations over time and for different environments.

Because we don't need the scanning tools when using the Basic supply chain, we exclude the related packages.
    ```yaml
    excluded_packages:
      - scanning.apps.tanzu.vmware.com
      - grype.scanning.apps.tanzu.vmware.com
    ```

This does assume that you're oke with TAP installing the Certmanager and Contour packages.
If not, you should disable those as well.

They are: 
    ```yaml
    - cert-manager.tanzu.vmware.com
    - contour.tanzu.vmware.com
    ```

```yaml title="tap-build-profile-basic.ytt.yml"
#@ load("@ytt:data", "data")
#@ dv = data.values
#@ kpRegistry = "{}/{}".format(dv.buildRegistry, dv.tbsRepo)
---
profile: build
buildservice:
  pull_from_kp_default_repo: true
  exclude_dependencies: true
  kp_default_repository: #@ kpRegistry
  kp_default_repository_secret:
    name: #@ dv.buildRegistrySecret
    namespace: tap-install

supply_chain: basic
ootb_supply_chain_basic:
  registry:
    server: #@ dv.buildRegistry
    repository: #@ dv.buildRepo

shared:
  ingress_domain: #@ dv.domainName
  ca_cert_data: #@ dv.caCert

ceip_policy_disclosed: true

contour:
  envoy:
    service:
      type: LoadBalancer

excluded_packages:
  - scanning.apps.tanzu.vmware.com
  - grype.scanning.apps.tanzu.vmware.com
```

## Script Input

The install script it designed to be fed with environment variables.

The script has some sane defaults, and where applicable we override them.

!!! Warning
    Don't forget to fill in the values for the registry secret passwords!

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

export INSTALL_CLUSTER_ESSENTIALS="false"
```

!!! Info "Disable Cluster Essentials when using TMC"

    Clusters created via TMC get the Cluster Essentials installed automatically.
    
    So you set `INSTALL_CLUSTER_ESSENTIALS` to false, to avoid installing them twice.

    You do now have to create the **ConfigMap** for the **Kapp** controller for trusting the registry's CA.

    ```yaml
    #@ load("@ytt:data", "data")
    ---
    apiVersion: v1
    kind: Secret
    metadata:
      name: kapp-controller-config
      namespace: #@ data.values.namespace
    stringData:
      caCerts: #@ data.values.caCert
    ```

    ```sh
    KAPP_CONTROLLER_NAMESPACE=kapp-controller
    CA_CERT=$(cat ssl/ca.pem)
    ```

    ```sh
    ytt -f ytt/kapp-controller-config.ytt.yml \
      -v namespace=kapp-controller \
      -v caCert="${CA_CERT}" \
      > "kapp-controller-config.yml" 
    ```

    ```sh
    kubectl apply -f kapp-controller-config.yml --namespace $KAPP_CONTROLLER_NAMESPACE
    ```

## Values File Output

When running the install script, `tap-build-install-basic.sh`, it will generate the package value file.

The file, `tap-build-basic-values.yml`, will contain the translated values from the environment variables.

Below is an example from my own installation.

!!! Example "Resulting Values File"

    ```yaml title="tap-build-basic-values.yml"
    profile: build
    buildservice:
      pull_from_kp_default_repo: true
      exclude_dependencies: true
      kp_default_repository: harbor.h2o-2-4864.h2o.vmware.com/buildservice/tbs-full-deps
      kp_default_repository_secret:
        name: registry-credentials
        namespace: tap-install
    supply_chain: basic
    ootb_supply_chain_basic:
      registry:
        server: harbor.h2o-2-4864.h2o.vmware.com
        repository: tap-apps
    shared:
      ingress_domain: build.h2o-2-4864.h2o.vmware.com
      ca_cert_data: |-
        -----BEGIN CERTIFICATE-----
        ...
        vhs=
        -----END CERTIFICATE-----
    ceip_policy_disclosed: true
    excluded_packages:
    - scanning.apps.tanzu.vmware.com
    - grype.scanning.apps.tanzu.vmware.com
    ```

## Run Install

```sh
./tap-build-install-basic.sh
```

## Test Workload

We first set the name of the developer namespace you have setup for TAP.

```sh
DEVELOPER_NAMESPACE=${DEVELOPER_NAMESPACE:-"default"}
```

!!! Info "Set up Developer Namespace"

    If you have not setup the developer namespace yet, you can do so in [this section](/tanzu/tkgs/tap13-overview/#setup-developer-namespace) of the main guide.

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

This script resides in the [tap/scripts](https://github.com/joostvdg/tanzu-example/blob/main/tap/scripts) folder.

It does all the steps outlined in this paragraph, including the wait and cleanup.

```sh
./tap-workload-demo.sh
```

??? Example "Test TAP Workload Script"

    ```sh
    #!/usr/bin/env bash
    set -euo pipefail
    DEVELOPER_NAMESPACE=${DEVELOPER_NAMESPACE:-"default"}

    tanzu apps workload delete smoke-app -y -n "$DEVELOPER_NAMESPACE" || true

    tanzu apps workload create smoke-app -y \
      --git-repo https://github.com/sample-accelerators/tanzu-java-web-app.git \
      --git-branch main \
      --type web \
      -n "$DEVELOPER_NAMESPACE"
    
    kubectl wait --for=condition=Ready Workload smoke-app --timeout=10m -n "$DEVELOPER_NAMESPACE"
    
    tanzu apps workload delete smoke-app -y -n "$DEVELOPER_NAMESPACE"
    ```
