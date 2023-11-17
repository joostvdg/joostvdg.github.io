---
tags:
  - TKG
  - TAP
  - GitOps
  - Carvel
  - Tanzu
---

title: TAP GitOps - TAP Run Cluster
description: Tanzu Application Platform GitOps Installation

# TAP Run

For large-scale deployments of TAP, we recommend separating the Build and Test phases of the supply chain from the Delivery or Run phase.

TAP supports this via the [Run profile](https://docs.vmware.com/en/VMware-Tanzu-Application-Platform/1.5/tap/multicluster-reference-tap-values-run-sample.html), only installing the components related to these activities [^1].

The components installed, among others, are Contour, KNative Serving, and Crossplane.

This chapter focuses on creating a GitOps install of the Run profile and configuring TAP to integrate with our tools of choice.

We will take a look at the following:

1. Configure Run Profile
1. Add ServiceAccount for the View profile
1. Manage Workloads

!!! Warning
    Before we dive into the Run profile-specific topics, the [GitOps Prep](/tanzu/tap-gitops/tap-gitops-prep/) page is considered a pre-requisite.

## Configure Run profile

As with the general preparation and the Run profile, we'll have several config files to prepare.

1. The non-sensitive values for the Profile install
1. The sensitive values (to be encrypted with SOPS) for the Profile install
1. The Namespace Provisioner

### Non-Sensitive Values

The Run profile values are similar to the ones for the Build profile.

The main difference is that we do not configure the Tanzu Build Service, which isn't included in this profile.

For the Supply Chain, we select Basic this time, as there is little to do in Profile beyond synchronizing resources.
We aren't using those components if we use the GitOps flow for the applications.

Why don't we exclude them, then?
Excluding components is more complex than configuring them with the most basic configuration.

Feel free to add packages to the `exclude_packages` list if you need to limit the resource usage.

The only new section we have here is the `appliveview_connector`.
It connects to the component running in the View cluster.

!!! Warning "Disabled TLS for App Live View"

    In this example, we disable the SSL (or TLS).
    
    We don't need to supply a certificate, but you probably do not want this in production.

    In that case, you must either have a valid certificate (e.g., one from a trusted source) or add it in a secret the connector can use.

The base example is as follows:

```yaml
---
tap_install:
  values:
    profile: run
    shared:
      ingress_domain: run-01.my-domain.com
      ca_cert_data: |-
        -----BEGIN CERTIFICATE-----
        MIID7jCCAtagAwIBAgIURv5DzXSDklERFu4gL2sQBNeRg+owDQYJKoZIhvcNAQEL
        ...
        vhs=
        -----END CERTIFICATE-----

    supply_chain: basic
    ootb_supply_chain_basic:
      registry:
        server: harbor.services.my-domain.com
        repository: tap-apps

    ceip_policy_disclosed: true
    contour:
      envoy:
        service:
          type: LoadBalancer

    appliveview_connector:
      backend:
        sslDeactivated: true
        ingressEnabled: true
        host: appliveview.view.my-domain.com
```

### Namespace Provisioner

Next, we add an almost identical `namespace_provisioner` configuration as we had in the GitOps preparation page and the Build profile.

The only difference is that the subfolder is now `run-01`, so we get the correct values for our Run cluster.

```yaml
#! This snippet is from the GitOps Preparation page
namespace_provisioner:
  controller: false
  gitops_install:
    ref: origin/main
    subPath: platforms/clusters/run-01/ns-provisioner/install
    url: git@github.com:joostvdg/tap-gitops.git
    secretRef:
      name: github-ssh
      namespace: shared
      create_export: false
  additional_sources:
  - git:
      ref: origin/main
      subPath: platforms/clusters/run-01/ns-provisioner/additional-sources
      url: git@github.com:joostvdg/tap-gitops.git
      # secretRef section is only needed if connecting to a Private Git repo
      secretRef:
        name: github-ssh-1
        namespace: shared
        create_export: false
    path: _ytt_lib/testing-scanning-supplychain-setup
```

### Full Non-Sensitive Example

Then, we combine the base values with the Namespace Provisioner values to reach a complete example.

??? Example "Non-Sensitive Values Example"

    ```yaml
    ---
    tap_install:
      values:
        profile: run
        shared:
          ingress_domain: run-01.my-domain.com
          ca_cert_data: |-
            -----BEGIN CERTIFICATE-----
            MIID7jCCAtagAwIBAgIURv5DzXSDklERFu4gL2sQBNeRg+owDQYJKoZIhvcNAQEL
            ...
            vhs=
            -----END CERTIFICATE-----

        supply_chain: basic
        ootb_supply_chain_basic:
          registry:
            server: harbor.services.my-domain.com
            repository: tap-apps

        ceip_policy_disclosed: true
        contour:
          envoy:
            service:
              type: LoadBalancer

        appliveview_connector:
          backend:
            sslDeactivated: true
            ingressEnabled: true
            host: appliveview.view.my-domain.com

        namespace_provisioner:
          controller: false
          gitops_install:
            ref: origin/main
            subPath: platforms/clusters/run-01/ns-provisioner/install
            url: git@github.com:joostvdg/tap-gitops.git
            secretRef:
              name: github-ssh
              namespace: shared
              create_export: false
          additional_sources:
          - git:
              ref: origin/main
              subPath: platforms/clusters/run-01/ns-provisioner/additional-sources
              url: git@github.com:joostvdg/tap-gitops.git
              # secretRef section is only needed if connecting to a Private Git repo
              secretRef:
                name: github-ssh-1
                namespace: shared
                create_export: false
            path: _ytt_lib/testing-scanning-supplychain-setup
    ```

### Sensitive Values

Below are the sensitive values.

The `shared.image_registry` with the URL, username, and password.

Mind you, the example below is _before_ encryption with SOPS (or ESO); encrypt the file before placing it at that location.

```yaml title="platforms/clusters/run-01/cluster-config/values/tap-sensitive-values.sops.yaml"
tap_install:
    sensitive_values:
        shared:
            #! registry for the TAP installation packages
            image_registry:
                project_path: harbor.services.mydomain.com/tap/tap-packages
                username: #! username
                password: #! password or PAT
custom:
  sensitive_values:
    github:
      ssh:
        private_key: |
          ...
        known_hosts: |
          ...
```

## Add ServiceAccount for the View profile

One of the essential features of TAP is its GUI.

For the TAP GUI to show the Supply Chains, one of its core features, it needs access to the Kubernetes cluster hosting them.

In this scenario, we separate the Build cluster from the cluster the TAP GUI runs in (View cluster).
So, we must provide the TAP GUI with alternative means to view the Supply Chain resources.

We do that by creating a [ServiceAccount in each cluster](https://docs.vmware.com/en/VMware-Tanzu-Application-Platform/1.5/tap/tap-gui-cluster-view-setup.html) we want the TAP GUI to have visibility[^3].
Then, copy the token of that ServiceAccount into the View profile configuration.

Add this ServiceAccount with the required permission and a Token to our additional Kubernetes resources.

Let's place this in the folder `cluster-config/config/custom`, and call the file `03-tap-gui-service-account.yaml`.

??? Example "TAP GUI Viewer Service Account"

    ```yaml title="platforms/clusters/build-01/cluster-config/config/custom/03-tap-gui-service-account.yaml"
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
    apiVersion: v1
    kind: Secret
    metadata:
      name: tap-gui-viewer
      namespace: tap-gui
      annotations:
        kubernetes.io/service-account.name: tap-gui-viewer
    type: kubernetes.io/service-account-token
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
      - scantemplates
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
    - apiGroups: ['appliveview.apps.tanzu.vmware.com']
      resources:
      - resourceinspectiongrants
      verbs: ['get', 'watch', 'list', 'create']
    ```

## Manage Workloads

Like the section for the [Build profile](/tanzu/tap-gitops/tap-build/#add-workload-specific-resources), we assume to leverage the FluxCD Kustomize Controller to synchronize these resources.

One difference is that the GitOps workflow (for the applications) creates a PullRequest with the resources for us.

So we do not have to create the resource files ourselves.
We create the expected folder structure and then point a `Kustomization` towards the correct folder.

For example, create the file `team-orange-kustomization.yaml` in the appropriate sub-folder (`tap/apps/run-01`) of the `tap-apps` Git repository.

```yaml title="tap/apps/run-01/team-orange-kustomization.yaml"
apiVersion: kustomize.toolkit.fluxcd.io/v1beta2
kind: Kustomization
metadata:
  name: orange
  namespace: apps
spec:
  interval: 5m0s
  path: ./teams/orange/staging
  prune: true
  targetNamespace: orange
  sourceRef:
    kind: GitRepository
    name: apps
```

!!! Tip "Use ArgoCD"

    Working on these GitOps deployments of TAP with customers, I come across [ArgoCD](https://argo-cd.readthedocs.io/en/stable/) quite a bit.

    The synchronizations of the "Deliverable" resources are entirely separated from the others.

    This allows leveraging something like ArgoCD for managing your applications in Staging and Production instead of relying on FluxCD.

    If you are already using ArgoCD and wondering how to combine it with TAP, this is where TAP and ArgoCD fit together well[^4].

## Install

You are now ready to install the TAP Run profile.

For the actual install commands, I refer to the [docs](https://docs.vmware.com/en/VMware-Tanzu-Application-Platform/1.5/tap/install-gitops-sops.html#deploy-tanzu-sync-11) [^1].

## References

[^1]: [TAP 1.5 Install - GitOps Install with SOPS deploy](https://docs.vmware.com/en/VMware-Tanzu-Application-Platform/1.5/tap/install-gitops-sops.html#deploy-tanzu-sync-11)
[^2]: [TAP Install 1.5 - Run profile](https://docs.vmware.com/en/VMware-Tanzu-Application-Platform/1.5/tap/multicluster-reference-tap-values-run-sample.html)
[^3]: [TAP GUI - View resources on multiple clusters](https://docs.vmware.com/en/VMware-Tanzu-Application-Platform/1.5/tap/tap-gui-cluster-view-setup.html)
[^4]: [ArgoCD - declarative, GitOps continuous delivery tool for Kubernetes](https://argo-cd.readthedocs.io/en/stable/)
