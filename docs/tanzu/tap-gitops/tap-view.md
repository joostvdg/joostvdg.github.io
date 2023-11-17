---
tags:
  - TKG
  - TAP
  - GitOps
  - Carvel
  - Tanzu
---

title: TAP GitOps - TAP View Cluster
description: Tanzu Application Platform GitOps Installation

# TAP View

For large-scale deployments of TAP, we recommend separating the Build and Test phases of the supply chain from the Delivery phase and then separating the cluster that views those workloads across the clusters.

TAP supports this via the [View profile](https://docs.vmware.com/en/VMware-Tanzu-Application-Platform/1.5/tap/multicluster-reference-tap-values-view-sample.html), only installing the components related to these activities [^1].

The components installed, among others, are TAP GUI and Metadata Store(stores scan results).

This chapter focuses on creating a GitOps install of the View profile and configuring TAP to integrate with our tools of choice.

We will take a look at the following:

1. Collect ServiceAccount Tokens from other clusters
1. Configure View Profile
1. Look at next steps

## Collect ServiceAccount Tokens from other clusters

For each cluster, we [need to record](https://docs.vmware.com/en/VMware-Tanzu-Application-Platform/1.5/tap/tap-gui-cluster-view-setup.html) the Kubernetes API server URL and the token of the TAP GUI ServiceAccount[^3].

!!! Important "Connect to target cluster"
    Ensure you are connected to the cluster you want to collect the information from.

We collect the URL as follows:

```sh
CLUSTER_URL=$(kubectl config view --minify -o jsonpath='{.clusters[0].cluster.server}')
```

Assuming you followed the `Add ServiceAccount for the View profile` sections, we can collect the token this way:

```sh
CLUSTER_TOKEN=$(kubectl -n tap-gui get secret tap-gui-viewer -o=json \
| jq -r '.data["token"]' \
| base64 --decode)
```

Print them out to be sure you collected them correctly:

```sh
echo CLUSTER_URL: $CLUSTER_URL
echo CLUSTER_TOKEN: $CLUSTER_TOKEN
```

Which should result in something like this:

```sh
CLUSTER_URL: https://10.220.10.38:6443
CLUSTER_TOKEN: eyJhbGciOiJSUzI1NiIsImtpZCI6IjJK.....
```

Do this for every cluster the TAP GUI needs to read resources from.
Collect the information and hold it ready for filling in the View profile values.

## Configure View profile

As usual, we have to create two configuration files:

1. The non-sensitive values for the Profile install
1. The sensitive values (to be encrypted with SOPS) for the Profile install

!!! Info "No Namespace Provisioner"
    A TAP View cluster (or Profile installation) does not run workloads.

    So, we do not configure the Namespace Provisioner for this cluster.

### Non-Sensitive Values

Let us start with the non-sensitive values.

The primary component to configure is the TAP GUI.

The base example is as follows:

```yaml
---
tap_install:
  values:
    profile: view
    ceip_policy_disclosed: true
    shared:
      ingress_domain: view.my-domain.com
      ca_cert_data: |-
        -----BEGIN CERTIFICATE-----
        MIID7jCCAtagAwIBAgIURv5DzXSDklERFu4gL2sQBNeRg+owDQYJKoZIhvcNAQEL
        ...
        vhs=
        -----END CERTIFICATE-----
    contour:
      envoy:
        service:
          type: LoadBalancer

    tap_gui:
      metadataStoreAutoconfiguration: true
      service_type: ClusterIP
      app_config:
        auth:
          allowGuestAccess: true 
        organization:
          name: 'My Portal'
```

You might be curious about the authentication section:

```yaml
tap_gui:
  app_config:
    auth:
      allowGuestAccess: true 
```

Unless you define some form of authentication, the developer portal (based on [Backstage](https://backstage.io/)[^4]) is locked.

To limit our configuration, we enable guest access, which essentially turns off authentication.

!!! Danger "Always Use Authentication In Production"
    Because the TAP GUI has some access to Kubernetes resources and one or more clusters, we recommend always using a proper authentication mechanism in Production.

    For more information, read the docs on how to [set up an authentication provider](https://docs.vmware.com/en/VMware-Tanzu-Application-Platform/1.5/tap/tap-gui-auth.html) or refer to the [Backstage auth docs](https://backstage.io/docs/auth/) [^5][^6].

We configure the access to the other clusters in the Sensitive Values section.

### Sensitive Values

Below are the sensitive values.

The `shared.image_registry` with the URL, username, and password.

Mind you, the example below is _before_ encryption with SOPS (or ESO); encrypt the file before placing it at that location.

Here, we configure the access to the Kubernetes clusters we collected earlier.

We place the configuration under `tap_gui.app_config.kubernetes`, where we specify the type locator methods and the list of clusters.

In the `clusterLocatorMethods` there's a `clusters` property; here, we can put the list of clusters.
For each cluster we record how to access it and what to name it.

In the `serviceAccountToken` field, we put the `$CLUSTER_TOKEN` we recorded earlier.

```yaml title="platforms/clusters/view-01/cluster-config/values/tap-sensitive-values.sops.yaml"
tap_install:
  sensitive_values:
    shared:
      #! registry for the TAP installation packages
      image_registry:
        project_path: harbor.services.mydomain.com/tap/tap-packages
        username: #! username
        password: #! password or PAT
    tap_gui:
      app_config:
        kubernetes:
          serviceLocatorMethod:
            type: 'multiTenant'
          clusterLocatorMethods:
            - type: 'config'
              clusters:
                - url: https://172.16.50.23:6443
                  name: build-01
                  authProvider: serviceAccount
                  serviceAccountToken: eyJhbG...1u_O_A
                  skipTLSVerify: true
                  skipMetricsLookup: false
```

## Install

You are now ready to install the TAP View profile.

For the actual install commands, I refer to the [docs](https://docs.vmware.com/en/VMware-Tanzu-Application-Platform/1.5/tap/install-gitops-sops.html#deploy-tanzu-sync-11) [^1].

## References

[^1]: [TAP 1.5 Install - GitOps Install with SOPS deploy](https://docs.vmware.com/en/VMware-Tanzu-Application-Platform/1.5/tap/install-gitops-sops.html#deploy-tanzu-sync-11)
[^2]: [TAP Install 1.5 - View profile](https://docs.vmware.com/en/VMware-Tanzu-Application-Platform/1.5/tap/multicluster-reference-tap-values-view-sample.html)
[^3]: [TAP GUI - View resources on multiple clusters](https://docs.vmware.com/en/VMware-Tanzu-Application-Platform/1.5/tap/tap-gui-cluster-view-setup.html)
[^4]: [Backstage - OSS Developer Portal, upstream of TAP GUI](https://backstage.io/)
[^5]: [TAP GUI - Configure Authentication](https://docs.vmware.com/en/VMware-Tanzu-Application-Platform/1.5/tap/tap-gui-auth.html)
[^6]: [Backstage - Authentication Documentation](https://backstage.io/docs/auth/)
