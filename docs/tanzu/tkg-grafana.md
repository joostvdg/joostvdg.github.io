---
tags:
  - grafana
  - LDAP
  - packages
  - tkg
  - TANZU
---

title: Grafana TKG Package
description: Tanzu Kubernetes Grid Grafana package with users via LDAP

In this guide we're going to install the Tanzu Kubernetes Grid (TGK) Grafana package, using LDAP for user authN and authZ.

We will do the following steps:

* Install the TKG package repository
* Install the Prometheus package (dependency)
* Install the Grafana package
* Create a ConfigMap for the LDAP configuration
* Apply an overlay to the Grafana package install to use the configmap

We assume you've installed LDAP as described in [Tanzu Dependencies - LDAP](../dependencies/#ldap-dependency)

## Pre-requisites

* TKG cluster with cluster essentials
* Tanzu CLI

## Install TKG Package Repository

This is according to the [Tanzu documentation](https://docs.vmware.com/en/VMware-Tanzu-Kubernetes-Grid/1.6/vmware-tanzu-kubernetes-grid-16/GUID-packages-install-packages.html).

First, ensure the repository is not yet installed.

```sh
tanzu package repository list -A
```

Then, set the name and source.

```sh
export PKG_REPO_NAME=tanzu-standard
export PKG_REPO_URL=projects.registry.vmware.com/tkg/packages/standard/repo:v1.6.0
export PKG_REPO_NAMESPACE=tanzu-package-repo-global
```

We then install the package repository.

```sh
tanzu package repository add ${PKG_REPO_NAME} \
    --url ${PKG_REPO_URL} \
    --namespace ${PKG_REPO_NAMESPACE}
```

Which should yield something like this:

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

Verify it is installed correcly:

```sh
tanzu package repository get ${PKG_REPO_NAME} --namespace ${PKG_REPO_NAMESPACE}
```

Which should yield something like this:

```sh
NAME            REPOSITORY                                               TAG     STATUS               DETAILS  
tanzu-standard  projects.registry.vmware.com/tkg/packages/standard/repo  v1.6.0  Reconcile succeeded   
```

Verify the packages are now available:

```sh
tanzu package available list
```

Which should list the following set of packages.

```sh hl_lines="10"
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

## Grafana Package Install

Before we can install the Grafana package, we need to install the Prometheus package.

This package doesn't need any specific configuration for our needs.

### Install Prometheus

```sh
PACKAGES_NAMESPACE=tanzu-packages
PACKAGE_NAME=prometheus.tanzu.vmware.com
PACKAGE_VERSION=2.36.2+vmware.1-tkg.1
```

```sh
tanzu package install ${PACKAGE_NAME} \
    --package-name ${PACKAGE_NAME} \
    --namespace ${PACKAGES_NAMESPACE} \
    --version ${PACKAGE_VERSION} \
    --create-namespace
```

### Install Grafana

```sh
PACKAGES_NAMESPACE=tanzu-packages
PACKAGE_NAME=grafana.tanzu.vmware.com
PACKAGE_VERSION=7.5.16+vmware.1-tkg.1
```

To view all the available values you can configure, you can run the following command:

```sh
tanzu package available get ${TAP_PACKAGE_NAME}/${TAP_PACKAGE_VERSION} --namespace tap-install --values-schema   
```

Once you have constructed your Grafana values file, you can install it:

```sh
tanzu package installed update --install ${PACKAGE_NAME} \
    --package-name ${PACKAGE_NAME} \
    --namespace ${PACKAGES_NAMESPACE} \
    --version ${PACKAGE_VERSION} \
    --values-file "grafana-data-values.yaml"
```

### Grafana Values

Below is an example Grafana values file, inspired by [VMware docs](https://docs.vmware.com/en/VMware-Application-Catalog/services/apps/GUID-apps-grafana-configuration-configure-ldap.html).


```yaml title="grafana-data-values.yaml" hl_lines="32 34 37 41"
namespace: tanzu-system-grafana

grafana:
  deployment:
    replicas: 1
    containers:
      resources: {}
    podAnnotations: {}
    podLabels: {}
    k8sSidecar:
      containers:
        resources: {}
  service:
    type: LoadBalancer
    port: 80
    targetPort: 3000
    labels: {}
    annotations: {}
  config:
    grafana_ini: |
      [analytics]
      check_for_updates = false
      [grafana_net]
      url = https://grafana.com
      [log]
      mode = console
      [paths]
      data = /var/lib/grafana/data
      logs = /var/log/grafana
      plugins = /var/lib/grafana/plugins
      provisioning = /etc/grafana/provisioning
      [auth.ldap]
      # Set to `true` to enable LDAP integration (default: `false`)
      enabled = true

      # Path to the LDAP specific configuration file (default: `/etc/grafana/ldap.toml`)
      config_file = /etc/grafana/ldap.toml

      # Allow sign-up should be `true` (default) to allow Grafana to create users on successful LDAP authentication.
      # If set to `false` only already existing Grafana users will be able to login.
      allow_sign_up = true
    datasource_yaml: |-
      apiVersion: 1
      datasources:
        - name: Prometheus
          type: prometheus
          url: prometheus-server.tanzu-system-monitoring.svc.cluster.local
          access: proxy
          isDefault: true
    dashboardProvider_yaml: |-
      apiVersion: 1
      providers:
        - name: 'sidecarDashboardProvider'
          orgId: 1
          folder: ''
          folderUid: ''
          type: file
          disableDeletion: false
          updateIntervalSeconds: 10
          allowUiUpdates: false
          options:
            path: /tmp/dashboards
            foldersFromFilesStructure: true
  pvc:
    annotations: {}
    storageClassName: null
    accessMode: ReadWriteOnce
    storage: "2Gi"
  secret:
    type: "Opaque"
    admin_user: "YWRtaW4="
    admin_password: "YWRtaW4="

ingress:
  enabled: true
  virtual_host_fqdn: "grafana.10.220.2.199.sslip.io"
  prefix: "/"
  servicePort: 80
```

## LDAP Configmap

We need to give Grafana enough information to use our LDAP server.

We do that by creating a ConfigMap, which we will apply to the installation via an [YTT Overlay](https://carvel.dev/ytt/docs/v0.44.0/ytt-overlays/) (next paragraph).

We configure the following:

* Host values, such as `host`, `port`, and use of ssl (no)
* Bind user, via the `bind_dn` and the admin's password
* User search, via `search_filter` and `search_base_dns`
    * ***search_base_dns***: where in the hierarchy are users located
    * ***search_filter***: how can we recognize users, in our case, we use the **objectClass** with the name **inetOrgPerson**
* Group search, via `group_search_filter`, `group_search_filter_user_attribute`, `group_search_base_dns`
    * ***group_search_base_dns***: the list of `dn`'s that where Groups are to be found
    * ***group_search_filter_user_attribute***: which property of the _users_ do we use in the `group_search_filter`
    * ***group_search_filter***: the filter for finding which Groups a User belongs to
* Server attribute mapping, translating the server attributes to attributes Grafana uses
    * withouth these, such as `username`, Grafana cannot identify the user properly and gives conflicts
* Group RBAC mapping, via one or more `[[servers.group_mappings]]` entries
    * here you can map a `group_dn` entry from LDAP to the Roles in Grafana

!!! Danger
    The LDAP **dn**'s and filters cannot contains spaces.
    If they contain spaces, the TOML file in the ConfigMap will introduce line breaks, corrupting the configuration file!

```toml title="grafana-ldap-configmap.yml"
apiVersion: v1
kind: ConfigMap
metadata:
  name: ldap-config
  namespace: tanzu-system-grafana
data:
  ldap.toml: |-
    [[servers]]
    host = "ldap-openldap.ldap.svc.cluster.local"
    port = 389
    use_ssl = false
    start_tls = false
    ssl_skip_verify = true

    bind_dn = "cn=admin,dc=example,dc=org"
    bind_password = "C5z6DUTNSMDoiWCHI2GIuSPIzCJt5Zo0"

    search_filter = "(&(objectClass=inetOrgPerson)((cn=%s)))"
    search_base_dns = ["ou=People,dc=example,dc=org"]

    group_search_filter = "(&(objectClass=groupOfNames)(member=uid=%s,ou=People,dc=example,dc=org))"
    group_search_filter_user_attribute = "uid"
    group_search_base_dns = ["ou=Groups,dc=example,dc=org"]

    # Specify names of the ldap attributes your ldap uses
    [servers.attributes]
    email =  "mail"
    name = "givenName"
    surname = "sn"
    username = "uid"


    [[servers.group_mappings]]
    group_dn = "cn=Administrators,dc=example,dc=org"
    org_role = "Admin"
    grafana_admin = true


    [[servers.group_mappings]]
    group_dn = "cn=BlueAdmins,ou=Groups,dc=example,dc=org"
    org_role = "Admin" 
    grafana_admin = true

    [[servers.group_mappings]]
    group_dn = "cn=GreenAdmins,ou=Groups,dc=example,dc=org"
    org_role = "Editor"

    [[servers.group_mappings]]
    group_dn = "*"
    org_role = "Viewer"
```

```sh
kubectl apply -f grafana-ldap-configmap.yml
```

### LDAP/AD Config

??? example "Group configuration when using LDAP/AD"

    ```toml
    [[servers]]
    host = “34.220.248.176”
    port = 389
    use_ssl = false
    start_tls = false
    ssl_skip_verify = false
    bind_dn = “grafana@fullauto.local”
    bind_password = ‘adasdads@’
    search_filter = “(sAMAccountName=%s)”
    search_base_dns = [“dc=fullauto,dc=local”]
    [servers.attributes]
    name = “givenName”
    surname = “sn”
    username = “sAMAccountName”
    member_of = “memberOf”
    email =  “mail”
    [[servers.group_mappings]]
    group_dn = “CN=grafana-admin,CN=Users,DC=fullauto,DC=LOCAL”
    org_role = “Admin”
    [[servers.group_mappings]]
    group_dn = “CN=grafana-editor,CN=Users,DC=fullauto,DC=LOCAL”
    org_role = “Editor”
    [[servers.group_mappings]]
    group_dn = “CN=grafana-viewer,CN=Users,DC=fullauto,DC=LOCAL”
    org_role = “Viewer”
    [[servers.group_mappings]]
    group_dn = “*”
    org_role = “Viewer”
    ```

## Grafana LDAP Overlay

Because the Grafana package does not support the LDAP values, we patch the Grafana installation using a YTT Overlay.

You can read up more about Overlays on the [YTT](https://carvel.dev/ytt/#example:example-overlay-files) website, and see another example for Harbor in the [VMware docs](https://docs.vmware.com/en/VMware-Tanzu-Kubernetes-Grid/1.6/vmware-tanzu-kubernetes-grid-16/GUID-packages-harbor-registry.html#fix-fsgroup).


```yaml title="grafana-ldap-overlay.yaml"
#@ load("@ytt:overlay", "overlay")

#@overlay/match by=overlay.and_op(overlay.subset({"kind": "Deployment"}), overlay.subset({"metadata": {"name": "grafana"}}))
---
spec:
  template:
    spec:
      containers:
        #@overlay/match by="name"
        - name: grafana
          volumeMounts:
            #@overlay/match by=overlay.index(0)
            #@overlay/insert before=True
            - mountPath: /etc/grafana/ldap.toml
              name: ldapconfig
              subPath: ldap.toml
      volumes:
        #@overlay/match by=overlay.index(0)
        #@overlay/insert before=True
        - configMap:
            defaultMode: 420
            name: ldap-config
          name: ldapconfig
```

The Overlay is "packaged" as a Kubernetes secret.
Make sure this secret is in the namespace the Grafana **Package** is installed (not Grafana itself).

```sh
kubectl create secret generic grafana-ldap-overlay \
  --from-file=grafana-ldap-overlay.yaml \
  -n tanzu-packages
```

Then we annotate the Grafana **Package Install** (the Carvel CR), telling it to apply our Overlay to the installation.

```sh
kubectl annotate packageinstalls grafana.tanzu.vmware.com \
  ext.packaging.carvel.dev/ytt-paths-from-secret-name.1=grafana-ldap-overlay \
  -n tanzu-packages
```
