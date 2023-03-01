---
tags:
  - TKG
  - Vsphere
  - TAP
  - 1.3.4
  - TANZU
---

title: TAP Run Profile
description: TAP Build Run profile on vSphere with Tanzu

# TAP Run Profile

Make sure you go through the [Satisfy Pre-requisites](/tanzu/tkgs/tap13-overview/#satisfy-pre-requisites) section of the main guide first.

Now that we have all the pre-requisites out of the way, we can install the actual profile.

Now that we have all the pre-requisites out of the way, we can install the actual profile.

## Install Script

The install script encapsulates installed the Cluster Essentials, if required, and the TAP Fundaments (secrets, namespace etc.) if required.

It also creates a package values file via a YTT template.

```sh title="tap-run-install.sh"
#!/usr/bin/env bash
set -euo pipefail

TAP_VERSION=${TAP_VERSION:-"1.3.4"}
TAP_INSTALL_NAMESPACE="tap-install"
DOMAIN_NAME=${DOMAIN_NAME:-"127.0.0.1.nip.io"}
VIEW_DOMAIN_NAME=${VIEW_DOMAIN_NAME:-"127.0.0.1.nip.io"}
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

ytt -f ytt/tap-run-profile.ytt.yml \
  -v domainName="$DOMAIN_NAME" \
  -v buildRegistry="$BUILD_REGISTRY" \
  -v buildRepo="$BUILD_REGISTRY_REPO" \
  -v viewDomainName="$VIEW_DOMAIN_NAME" \
  -v caCert="${CA_CERT}" \
  > "tap-run-values.yml"

tanzu package installed update --install tap \
  -p tap.tanzu.vmware.com \
  -v $TAP_VERSION \
  --values-file tap-run-values.yml \
  -n ${TAP_INSTALL_NAMESPACE}
```

## YTT Template

The YTT template makes it easy to generate different configurations over time and for different environments.

```yaml title="tap-run-profile.ytt.yml"
#@ load("@ytt:data", "data")
#@ dv = data.values
---
profile: run
ceip_policy_disclosed: true

shared:
  ingress_domain: #@ dv.domainName
  ca_cert_data: #@ dv.caCert

supply_chain: basic
ootb_supply_chain_basic:
  registry:
    server: #@ dv.buildRegistry
    repository: #@ dv.buildRepo

contour:
  envoy:
    service:
      type: LoadBalancer

appliveview_connector:
  backend:
    sslDisabled: true
    ingressEnabled: true
    host: #@ "appliveview."+dv.viewDomainName
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
export VIEW_DOMAIN_NAME=""
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

When running the install script, `tap-run-install.sh`, it will generate the package value file.

The file, `tap-run-values.yml`, will contain the translated values from the environment variables.

Below is an example from my own installation.

!!! Example "Resulting Values File"

    ```yaml title="tap-run-values.yml"
    profile: run
    ceip_policy_disclosed: true
    shared:
      ingress_domain: run.h2o-2-4864.h2o.vmware.com
      ca_cert_data: |-
        -----BEGIN CERTIFICATE-----
        ...
        vhs=
        -----END CERTIFICATE-----
    supply_chain: basic
    ootb_supply_chain_basic:
      registry:
        server: harbor.h2o-2-4864.h2o.vmware.com
        repository: tap-apps
    contour:
      envoy:
        service:
          type: LoadBalancer
    appliveview_connector:
      backend:
        sslDisabled: true
        ingressEnabled: true
        host: appliveview.view.h2o-2-4864.h2o.vmware.com
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
    NAME                      PACKAGE-NAME                                        PACKAGE-VERSION  STATUS
    api-auto-registration     apis.apps.tanzu.vmware.com                          0.1.2            Reconcile succeeded
    appliveview-connector     connector.appliveview.tanzu.vmware.com              1.3.1            Reconcile succeeded
    appsso                    sso.apps.tanzu.vmware.com                           2.0.0            Reconcile succeeded
    cartographer              cartographer.tanzu.vmware.com                       0.5.4            Reconcile succeeded
    cert-manager              cert-manager.tanzu.vmware.com                       1.7.2+tap.1      Reconcile succeeded
    cnrs                      cnrs.tanzu.vmware.com                               2.0.2            Reconcile succeeded
    contour                   contour.tanzu.vmware.com                            1.22.0+tap.5     Reconcile succeeded
    eventing                  eventing.tanzu.vmware.com                           2.0.2            Reconcile succeeded
    fluxcd-source-controller  fluxcd.source.controller.tanzu.vmware.com           0.27.0+tap.1     Reconcile succeeded
    image-policy-webhook      image-policy-webhook.signing.apps.tanzu.vmware.com  1.1.10           Reconcile succeeded
    ootb-delivery-basic       ootb-delivery-basic.tanzu.vmware.com                0.10.5           Reconcile succeeded
    ootb-templates            ootb-templates.tanzu.vmware.com                     0.10.5           Reconcile succeeded
    service-bindings          service-bindings.labs.vmware.com                    0.8.1            Reconcile succeeded
    services-toolkit          services-toolkit.tanzu.vmware.com                   0.8.1            Reconcile succeeded
    source-controller         controller.source.apps.tanzu.vmware.com             0.5.1            Reconcile succeeded
    tap                       tap.tanzu.vmware.com                                1.3.4            Reconcile succeeded
    tap-auth                  tap-auth.tanzu.vmware.com                           1.1.0            Reconcile succeeded
    tap-telemetry             tap-telemetry.tanzu.vmware.com                      0.3.2            Reconcile succeeded
    ```

    Assuming you already have completed setting up the Build, 
    you can continue with the [Cross-cluster verification](/tanzu/tkgs/tap13-overview/#cross-cluster-test).