---
tags:
  - TKG
  - Vsphere
  - TAP
  - 1.3.4
  - TANZU
---

title: TAP View Profile
description: TAP Build View profile on vSphere with Tanzu

# TAP View Profile

Make sure you go through the [Satisfy Pre-requisites](/tanzu/tkgs/tap13-overview/#satisfy-pre-requisites) section of the main guide first.

Now that we have all the pre-requisites out of the way, we can install the actual profile.

## Setup Read Permissions

The View profile is designed to _view_ the resources across all related TAP clusters.

This means it needs read permission on each cluster.

### Create Service Accounts

* https://docs.vmware.com/en/VMware-Tanzu-Application-Platform/1.3/tap/GUID-tap-gui-cluster-view-setup.html

* create: `tap-gui-viewer-service-account-rbac.yaml`

??? Example "Service Account RBAC"

    ```yaml title="tap-gui-viewer-service-account-rbac.yaml"
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

Apply this to each Build and Run cluster that you want this View profile cluster to have access to.

```sh
kubectl create -f tap-gui-viewer-service-account-rbac.yaml
```

And then retrieve the resulting URL and Token for each cluster.

We need these for the next step.

!!! Info
    This guides assumes you are using a single Build and a single Run cluster.

    If you have a different setup, you have to update the scripts and YTT template accordingly.

```sh
CLUSTER_URL=$(kubectl config view --minify -o jsonpath='{.clusters[0].cluster.server}')

CLUSTER_TOKEN=$(kubectl -n tap-gui get secret $(kubectl -n tap-gui get sa tap-gui-viewer -o=json \
| jq -r '.secrets[0].name') -o=json \
| jq -r '.data["token"]' \
| base64 --decode)

echo CLUSTER_URL: $CLUSTER_URL
echo CLUSTER_TOKEN: $CLUSTER_TOKEN
```

## Install Script

The install script encapsulates installed the Cluster Essentials, if required, and the TAP Fundamentals (secrets, namespace etc.) if required.

It also creates a package values file via a YTT template.

```sh title="tap-view-install.sh"
#!/usr/bin/env bash
set -euo pipefail

TAP_VERSION=${TAP_VERSION:-"1.3.4"}
TAP_INSTALL_NAMESPACE="tap-install"
DOMAIN_NAME=${DOMAIN_NAME:-"127.0.0.1.nip.io"}
INSTALL_TAP_FUNDAMENTALS=${INSTALL_TAP_FUNDAMENTALS:-"true"}
INSTALL_CLUSTER_ESSENTIALS=${INSTALL_CLUSTER_ESSENTIALS:-"false"}

if [ "$INSTALL_CLUSTER_ESSENTIALS" = "true" ]; then
  echo "> Installing Cluster Essentials (Kapp Controller, SecretGen Controller)"
  ./install-cluster-essentials.sh
fi

if [ "$INSTALL_TAP_FUNDAMENTALS" = "true" ]; then
  echo "> Installing TAP Fundamentals (namespace, secrets)"
  ./install-tap-fundamentals.sh
fi

echo "> Generating tap-view-values.yml"
ytt -f ytt/tap-view-profile.ytt.yml \
  -v caCert="${CA_CERT}" \
  -v domainName="$DOMAIN_NAME" \
  -v buildClusterUrl="${BUILD_CLUSTER_URL}" \
  -v buildClusterName="${BUILD_CLUSTER_NAME}" \
  -v buildClusterToken="${BUILD_CLUSTER_TOKEN}" \
  -v buildClusterTls="${BUILD_CLUSTER_TLS}" \
  -v runClusterUrl="${RUN_CLUSTER_URL}" \
  -v runClusterName="${RUN_CLUSTER_NAME}" \
  -v runClusterToken="${RUN_CLUSTER_TOKEN}" \
  -v runClusteTls="${RUN_CLUSTER_TLS}" \
  > "tap-view-values.yml"

echo "> Installing TAP $TAP_VERSION in $TAP_INSTALL_NAMESPACE"
tanzu package installed update --install tap \
  -p tap.tanzu.vmware.com \
  -v $TAP_VERSION \
  --values-file tap-view-values.yml \
  -n ${TAP_INSTALL_NAMESPACE}
```

## YTT Template

The YTT template makes it easy to generate different configurations over time and for different environments.

The View profile has one main component, the **TAP GUI**, based on the OSS project Backstage.

We have to configure this with various values, three noticable values:

* `tap_gui.app_config.catalog.locations`: ensure there's always some applications registered in the TAP GUI
* `tap_gui.app_config.kubernetes.clusterLocatorMethods`: this is how the View cluster can read resources from the other clusters

!!! Info
    For more information about the configuration, use the Tanzu CLI to retrieve its value schema.

    ```sh
    tanzu package available  get tap-gui.tanzu.vmware.com/1.3.5 --values-schema -n tap-install
    ```

```yaml title="tap-view-profile.ytt.yml"
#@ load("@ytt:data", "data")
#@ dv = data.values
---
profile: view
ceip_policy_disclosed: true #! Installation fails if this is not set to true. Not a string.

shared:
  ingress_domain: #@ data.values.domainName
  ca_cert_data: #@ data.values.caCert

tap_gui:
  service_type: ClusterIP
  ingressEnabled: true
  ingressDomain: #@ data.values.domainName
  app_config:
    auth:
      allowGuestAccess: true
    customize:
      #! custom_logo: 'BASE-64-IMAGE'
      custom_name: 'Portal McPortalFace'
    organization:
      name: 'Org McOrg Face'
    app:
      baseUrl: #@ "http://tap-gui."+data.values.domainName
    catalog:
      locations:
        - type: url
          target: https://github.com/joostvdg/tap-catalog/blob/main/catalog-info.yaml
        - type: url
          target: https://github.com/joostvdg/tap-hello-world/blob/main/catalog/catalog-info.yaml
    backend:
      baseUrl: #@ "http://tap-gui."+data.values.domainName
      cors:
        origin: #@ "http://tap-gui."+data.values.domainName
    kubernetes:
      serviceLocatorMethod:
        type: 'multiTenant'
      clusterLocatorMethods:
        - type: 'config'
          clusters:
            - url: #@ data.values.buildClusterUrl
              name: #@ data.values.buildClusterName
              authProvider: serviceAccount
              serviceAccountToken: #@ data.values.buildClusterToken
              skipTLSVerify: true
              skipMetricsLookup: false
            - url: #@ data.values.runClusterUrl
              name: #@ data.values.runClusterName
              authProvider: serviceAccount
              serviceAccountToken: #@ data.values.runClusterToken
              skipTLSVerify: true
              skipMetricsLookup: false

appliveview:
  ingressEnabled: true
  sslDisabled: true
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
export DOMAIN_NAME=""
export CA_CERT=$(cat ssl/ca.pem)

export BUILD_CLUSTER_URL=https://1.2.3.4:6443
export BUILD_CLUSTER_NAME=my-build-cluster
export BUILD_CLUSTER_TOKEN=''

export RUN_CLUSTER_URL=https://5.6.7.8:6443
export RUN_CLUSTER_NAME=my-run-cluster
export RUN_CLUSTER_TOKEN=

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

When running the install script, `tap-view-install.sh`, it will generate the package value file.

The file, `tap-view-values.yml`, will contain the translated values from the environment variables.

Below is an example from my own installation.

!!! Example "Resulting Values File"

    ```yaml title="tap-run-values.yml"
    profile: view
    ceip_policy_disclosed: true
    shared:
      ingress_domain: view.h2o-2-4864.h2o.vmware.com
      ca_cert_data: |-
        -----BEGIN CERTIFICATE-----
        ...
        vhs=
        -----END CERTIFICATE-----
    tap_gui:
      service_type: ClusterIP
      ingressEnabled: true
      ingressDomain: view.h2o-2-4864.h2o.vmware.com
      app_config:
        auth:
          allowGuestAccess: true
        customize:
          custom_name: Portal McPortalFace
        organization:
          name: Org McOrg Face
        app:
          baseUrl: http://tap-gui.view.h2o-2-4864.h2o.vmware.com
        catalog:
          locations:
          - type: url
            target: https://github.com/joostvdg/tap-catalog/blob/main/catalog-info.yaml
        backend:
          baseUrl: http://tap-gui.view.h2o-2-4864.h2o.vmware.com
          cors:
            origin: http://tap-gui.view.h2o-2-4864.h2o.vmware.com
        locations:
        - type: url
          target: https://github.com/joostvdg/tap-catalog/blob/main/catalog-info.yaml
        - type: url
          target: https://github.com/joostvdg/tap-hello-world/blob/main/catalog/catalog-info.yaml
        kubernetes:
          serviceLocatorMethod:
            type: multiTenant
          clusterLocatorMethods:
          - type: config
            clusters:
            - url: https://10.11.1.1:6443
              name: build-01
              authProvider: serviceAccount
              serviceAccountToken: eyJhb...
              skipTLSVerify: true
              skipMetricsLookup: false
            - url: https://10.12.1.1:6443
              name: run-01
              authProvider: serviceAccount
              serviceAccountToken: eyJhb...
              skipTLSVerify: true
              skipMetricsLookup: false
    appliveview:
      ingressEnabled: true
      sslDisabled: true
    ```

## Run Install

```sh
./tap-run-install.sh
```

!!! Success "Next Steps"
    Verify the TAP installation succeeded.

    ```sh
    tanzu package installed list --namespace tap-install
    ```

    Which should look like this:

    ```sh
    NAME                      PACKAGE-NAME                               PACKAGE-VERSION  STATUS
    accelerator               accelerator.apps.tanzu.vmware.com          1.3.2            Reconcile succeeded
    api-portal                api-portal.tanzu.vmware.com                1.2.5            Reconcile succeeded
    appliveview               backend.appliveview.tanzu.vmware.com       1.3.1            Reconcile succeeded
    cert-manager              cert-manager.tanzu.vmware.com              1.7.2+tap.1      Reconcile succeeded
    contour                   contour.tanzu.vmware.com                   1.22.0+tap.5     Reconcile succeeded
    fluxcd-source-controller  fluxcd.source.controller.tanzu.vmware.com  0.27.0+tap.1     Reconcile succeeded
    learningcenter            learningcenter.tanzu.vmware.com            0.2.4            Reconcile succeeded
    learningcenter-workshops  workshops.learningcenter.tanzu.vmware.com  0.2.3            Reconcile succeeded
    metadata-store            metadata-store.apps.tanzu.vmware.com       1.3.4            Reconcile succeeded
    source-controller         controller.source.apps.tanzu.vmware.com    0.5.1            Reconcile succeeded
    tap                       tap.tanzu.vmware.com                       1.3.4            Reconcile succeeded
    tap-gui                   tap-gui.tanzu.vmware.com                   1.3.5            Reconcile succeeded
    tap-telemetry             tap-telemetry.tanzu.vmware.com             0.3.2            Reconcile succeeded
    ```

    Assuming you already have completed setting up the Build, 
    you can continue with the [Cross-cluster verification](/tanzu/tkgs/tap13-overview/#cross-cluster-test).