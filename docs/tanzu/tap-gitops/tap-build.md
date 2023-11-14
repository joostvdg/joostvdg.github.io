---
tags:
  - TKG
  - TAP
  - GitOps
  - Carvel
  - Tanzu
---

title: TAP GitOps - TAP Build Cluster
description: Tanzu Application Platform GitOps Installation

# TAP Build

For large scale deployments of TAP, we recommend separating the Build and Test phases of the supplychain into a separate Build cluster.

TAP supports this via the [build profile](https://docs.vmware.com/en/VMware-Tanzu-Application-Platform/1.5/tap/multicluster-reference-tap-values-build-sample.html), only installing the components related to these activities [^1].

The components installed, among others, are: Cartographer, Tekton, Tanzu Build Service, and Grype.

The focus of this chapter is on creating a GitOps install of the Build profile, configuring TAP to integrate with our tools of choice.

We will take a look at the following:

1. Install Tanzu Build Service and its dependencies via GitOps
1. Configure Build Profile
1. Add ServiceAccount for the View profile
1. Manage Workloads
1. End result

!!! Warning
    Before we dive into the Build profile specific topics, the [GitOps Prep](/tanzu/tap-gitops/tap-gitops-prep/) page is considered a pre-requisite.

## Install TBS

One of the major components of the Build profile, unsurprisingly whith such a name, is the component that does the building: Tanzu Build Service (***TBS***).

Unfortunately, TBS is can be a bit unwieldy.
It requires a good chunk of storage for ContainerD (~100GB), downloads a lot of (container) images, and relies on DockerHub images.

### Relocate TBS Dependencies

For these reasons, we recommend to always [relocate the TBS dependencies](https://docs.vmware.com/en/VMware-Tanzu-Application-Platform/1.5/tap/install-offline-tbs-offline-install-deps.html) to a registry you control, preferably close (network wise) to your clusters[^4].

The docs are very straight forward, so I won't repeat it here, please follow the docs and come back[^4].

!!! Danger "TAP TBS not TBS"
    One thing that has bitten some customers, is that they "know" TBS.

    So what they do, is they download the TBS product and its dependencies.

    Unfortunately, what TAP relies on, isn't the same packaging.

    Please make sure you relocate `tanzu-application-platform/full-tbs-deps-package-repo`!

If you're unsure which version of the TBS dependencies you need, you can verify this with a TAP Package Repository.

Please refer to the ***Retrieving Package Schemas*** section in the [TAP GitOps Prep](/tanzu/tap-gitops/tap-build/#non-sensitive-values-file) page if you are unsure how to quickly check what versions are in a Package Repository.

### TBS and TAP GitOps Install

For our installation, we want to install everything via GitOps.

By default, TAP installs TBS in online mode.
When we our TAP install to our relocated packages instead, we run into a slight issue.

We need the TAP TBS Full Dependency ***Package Repository*** and the ***Package** installed as well.
As this is a different Package Repository, it is not included in the TAP install.

This is where community here [vrabbi](https://vrabbi.cloud/about/) comes in[^2].
He has written on how to [handle this](https://vrabbi.cloud/post/tap-1-5-gitops-installation/), and has an example repository[^3]

!!! Info
    [vrabbi](https://vrabbi.cloud/about/) has a lot of good blog posts related to TAP.
    
    I recommend visiting his blog everytime there's a new version of TAP released, he usually does a break down of what changed.

The solution comes down to the following:

1. Add additional properties to our custom Schema file (`cluster-config/config/custom/00-custom-schema.yaml`)
1. Add manifest for the Package Repository (Carvel K8S CR)
1. Add manifest for the Package Installation (Carvel K8S CR)

Let's get to it.

In the existing custom schema file, add the following:

```yaml title="cluster-config/config/custom/00-custom-schema.yaml"
custom:
  tbs_full_dependencies:
    enabled: true
    pkgr_version: "1.10.10" #! matches TAP 1.5.4 I believe
    pkgr_repo_url: harbor.services.my-domain.com/buildservice/tbs-full-deps
```

Then, we create a `tbs-install` folder in parallel to the `tap-install` folder in `cluster-config/config`.
Inside, we create the files `00-pkgr.yaml` and `01-pkgi.yaml`, for the Package Repository and Package Install respectively.

The folder structure should look like this now (limited to relevant files/folders):

```sh
build-01
├── cluster-config
│   ├── config
│   │   ├── custom
│   │   │   ├── 00-custom-schema.yaml
│   │   │   └── 01-shared.yaml
│   │   ├── flux-controllers
│   │   ├── tap-install
│   │   └── tbs-install
│   │       ├── 00-pkgr.yaml
│   │       └── 01-pkgi.yaml
│   └── values
├── ns-provisioner
└── tanzu-sync
```

And for the content:

```yaml title="cluster-config/config/tbs-install/00-pkgr.yaml"
#@ load("@ytt:data", "data")
---
#@ if data.values.custom.tbs_full_dependencies.enabled:
apiVersion: packaging.carvel.dev/v1alpha1
kind: PackageRepository
metadata:
  name: tbs-full-deps-repository
  namespace: tap-install
  annotations:
    kapp.k14s.io/change-group: pkgr
spec:
  fetch:
    imgpkgBundle:
      image: #@ "{}:{}".format(data.values.custom.tbs_full_dependencies.pkgr_repo_url,data.values.custom.tbs_full_dependencies.pkgr_version)
#@ end
```

And the Package Install:

```yaml title="cluster-config/config/tbs-install/01-pkgi.yaml"
#@ load("@ytt:data", "data")
---
#@ if data.values.custom.tbs_full_dependencies.enabled:
apiVersion: packaging.carvel.dev/v1alpha1
kind: PackageInstall
metadata:
  name: full-tbs-deps
  namespace: tap-install
  annotations:
    kapp.k14s.io/change-group: tbs
    kapp.k14s.io/change-rule.0: "upsert after upserting pkgi"
    kapp.k14s.io/change-rule.1: "delete before deleting pkgi"
spec:
  serviceAccountName: tap-installer-sa
  packageRef:
    refName: full-tbs-deps.tanzu.vmware.com
    versionSelection:
      constraints: #@ data.values.custom.tbs_full_dependencies.pkgr_version
#@ end
```

## Configure Build Profile

Now that we have taken care of our dependencies, we can look at the Build profile proper[^1].

I'm preparing the profile to use the Out Of The Box Supply Chain ***Testing & Scanning***[^5].

Let's look at what sections we need to provide:

1. Profile generics, `profile`, `shared`, `ceip_policy_disclosed`, and `contour`
1. BuildService configuration
1. Supply Chain configuration (`ootb_supply_chain_testing_scanning`)
1. `scanning.metadataStore` for legacy reasons

The profile generics can be split into two, **sensitive** and **non-sensitive**.

### Shared

I recommend configuring the TAP Install Registry as sensitive, so that leaves us with two properties for the `shared`:
The `shared.ingress_domain`, which is the DNS "wildcard" for this profile/cluster, and, if required, a Custom CA cert via `shared.ca_cert_data`.

```yaml
ingress_domain: build.my-domain.com
ca_cert_data: |-
  ...
```

### Build Service

The buildservice by default leverages the registry from the `shared.image_registry`.
As we've relocated the packages, that is a **different** registry.

We also have to tell it to not install the dependencies, and instead pull them from our defined TBS registry (`kp_default_repository`).

We that as follows:

```yaml
buildservice:
  pull_from_kp_default_repo: true
  exclude_dependencies: true
  #! registry for TBS Dependencies
  kp_default_repository: "harbor.services.my-domain.com/buildservice/tbs-full-deps"
```

What it does still do, is leverage the _credentials_ used for the `shared.image_registry`.
If you need different credentials, see the **sensitive** values section below.

### OOTB Supply Chain

First, we declare which supply chain we use on the top level (e.g., `tap_install.values.`).
We do so by setting `supply_chain` to our desired Supply Chain, in my case `testing_scanning`.

As before, we want to do everything as GitOps.

TAP supports two Workload flows[^7]:

1. **Registry Ops**: Build, Test, and end with a Cartographer `Deliverable` CR, which a _Run_ profile can install
1. **GitOps**: Build, Test, and end with a PullRequest(PR) (or Merge Request for GitLab), containing the Knative Service CR

So, obviously we choose the GitOps flow.
This means we need to tell it several things, such as the server, repository, branch, and some information for the PR.

Last but now least, we inform it of the repository to use for storing the container images made by TBS (or Kaniko).

```yaml
supply_chain: testing_scanning
ootb_supply_chain_testing_scanning:
  external_delivery: true
  gitops:
    server_address: https://gitlab.services.my-domain.com
    repository_owner: root
    repository_name: tap-apps
    branch: main
    commit_strategy: pull_request
    pull_request:
      server_kind: gitlab
      commit_branch: ""
      pull_request_title: ready for review
      pull_request_body: generated by supply chain
  registry:
    server: harbor.services.my-domain.com
    repository: tap-apps #! registry project for Workload images
```

!!! Danger "Secret for the PullRequests"

    By default, the PullRequest (or MergeRequest) is made by a Tekton Pipeline.

    Tekton requires a specific kind of [Secret format](https://tekton.dev/docs/pipelines/auth/) as described in the Tanzu Docs[^7] and Tekton Docs[^8].

    This secret needs to be assigned the `default` ServiceAccount in the namespace (this is the default, pun intended).
    As you might remember from our [GitOps Prepare](/tanzu/tap-gitops/tap-gitops-prep/#share-secrets) page, we create the appropriate secrets and use the Namespace Provisioner to add them to the ServiceAccount. This is why!

### Full Example

??? Example "Full Profile Example"

    ```yaml title="platforms/clusters/build-01/cluster-config/values/tap-non-sensitive-values.yaml"
    ---
    tap_install:
      values:
        profile: build
        shared:
          ingress_domain: build.my-domain.com
          ca_cert_data: |- #! if you need a custom support a custom Certificate Authority (CA)
            -----BEGIN CERTIFICATE-----
            iUdqs7FZN2uKkLKekdTgW0QkTFEJTk5Yk9t/hOrjnHoWQfB+mLhO3vPhip
            ...
            vhs=
            -----END CERTIFICATE-----
        buildservice:
          pull_from_kp_default_repo: true
          exclude_dependencies: true
          #! registry for TBS Dependencies
          kp_default_repository: "harbor.services.my-domain.com/buildservice/tbs-full-deps"

        supply_chain: testing_scanning
        ootb_supply_chain_testing_scanning:
          external_delivery: true
          gitops:
            server_address: https://gitlab.services.my-domain.com
            repository_owner: root
            repository_name: tap-apps
            branch: main
            commit_strategy: pull_request
            pull_request:
              server_kind: gitlab
              commit_branch: ""
              pull_request_title: ready for review
              pull_request_body: generated by supply chain
          registry:
            server: harbor.services.my-domain.com
            repository: tap-apps #! registry project for Workload images
        
        scanning:
          metadataStore:
            url: "" #! a bug requires this setting for TAP 1.4 and 1.5 (not sure about 1.6)

        ceip_policy_disclosed: true
        contour:
          envoy:
            service:
              type: LoadBalancer

        #! this is from the GitOps Preperation page
        namespace_provisioner:
          controller: false
          gitops_install:
            ref: origin/main
            subPath: platforms/clusters/full-tap-cluster/ns-provisioner/install
            url: git@github.com:joostvdg/tap-gitops.git
            secretRef:
              name: github-ssh
              namespace: shared
              create_export: false
          additional_sources:
          - git:
              ref: origin/main
              subPath: platforms/clusters/full-tap-cluster/ns-provisioner/additional-sources
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

Mind you, the example below is _before_ encryption with SOPS (or ESO), so ensure it is encrypted before placing it at that location.

```yaml title="platforms/clusters/build-01/cluster-config/values/tap-sensitive-values.sops.yaml"
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

!!! Warning "Same credentials for TAP and TBS"

    Mind you, the example below is _before_ encryption with SOPS (or ESO), so ensure it is encrypted before placing it at that location.

    ```yaml title="platforms/clusters/build-01/cluster-config/values/tap-sensitive-values.sops.yaml"
    tap_install:
      sensitive_values:
        buildservice:
          kp_default_repository: #! registry, e.g.,  "index.docker.io/joostvdgtanzu/build-service"
          kp_default_repository_username: #! username
          kp_default_repository_password: #! password or PAT
    ```

## Add Tekton Pipeline

6: https://docs.vmware.com/en/VMware-Tanzu-Application-Platform/1.5/tap/getting-started-add-test-and-security.html#tekton-pipeline-config-example-3

## Add View ServiceAccount

## Manage Workloads

## End Result

### Folder Structure

```sh
platforms
└── clusters
    ├── build-01
    │   ├── README.md
    │   ├── cluster-config
    │   │   ├── config
    │   │   │   ├── apps
    │   │   │   │   ├── apps.yaml
    │   │   │   │   ├── services.yaml
    │   │   │   │   ├── team-cyan.yaml
    │   │   │   │   ├── team-orange.yaml
    │   │   │   │   └── team-teal.yaml
    │   │   │   ├── cross-cluster
    │   │   │   │   └── tap-gui-viewer-service-account-rbac.yaml
    │   │   │   ├── custom-schema.yaml
    │   │   │   ├── flux-helm-controller.yaml
    │   │   │   ├── flux-kustomize-controller.yaml
    │   │   │   ├── github-https-token.yaml
    │   │   │   ├── gitssh-namespace-provisioner-secretexport.yaml
    │   │   │   ├── metadata-store-secret.yaml
    │   │   │   ├── ootb-template-overlay.yaml
    │   │   │   ├── supplychains
    │   │   │   │   └── tasks
    │   │   │   ├── tap-install
    │   │   │   ├── tbs-install
    │   │   │   │   ├── pkgi.yaml
    │   │   │   │   └── pkgr.yaml
    │   │   │   └── trivy-install
    │   │   │       ├── pkgi.yaml
    │   │   │       └── pkgr.yaml
    │   │   └── values
    │   │       ├── tap-install-values.yaml
    │   │       ├── tap-non-sensitive-values.yaml
    │   │       └── tap-sensitive-values.sops.yaml
    │   ├── namespace-provisioner
    │   │   ├── desired-namespaces.yaml
    │   │   └── namespaces.yaml
    │   ├── namespace-resources
    │   │   └── testing-scanning-supplychain
    │   │       ├── dotnet.yaml
    │   │       ├── fluxcd-repo-download.yaml
    │   │       ├── git-clone.yaml
    │   │       ├── maven-testcontainers.yaml
    │   │       ├── maven.yaml
    │   │       ├── send-to-webhook-slack.yaml
    │   │       └── trivy-scan-templates.yaml
    │   └── tanzu-sync
    │       ├── app
    │       │   ├── config
    │       │   └── values
    │       │       └── tanzu-sync.yaml
    │       ├── bootstrap
    │       │   ├── noop
    │       │   └── readme
    │       └── scripts
    │           ├── configure-secrets.sh
    │           ├── configure.sh
    │           ├── deploy.sh
    │           └── sensitive-values.sh
```

## References

[^1]: [TAP Install 1.5 - Build profile](https://docs.vmware.com/en/VMware-Tanzu-Application-Platform/1.5/tap/multicluster-reference-tap-values-build-sample.html)
[^2]: [VRABBI - Blogs on VMware/Tanzu products](https://vrabbi.cloud/about/)
[^3]: [VRABBI - ](https://vrabbi.cloud/post/tap-1-5-gitops-installation/)
[^4]: [TAP - Offline Install - Tanzu Build Service & Dependencies](https://docs.vmware.com/en/VMware-Tanzu-Application-Platform/1.5/tap/install-offline-tbs-offline-install-deps.html)
[^5]: [TAP - OOTB Supply Chain - Testing & Scanning](https://docs.vmware.com/en/VMware-Tanzu-Application-Platform/1.5/tap/getting-started-add-test-and-security.html)
[^6]: [TAP - OOTB Supply Chain - Tekton Test Pipeline Example](https://docs.vmware.com/en/VMware-Tanzu-Application-Platform/1.5/tap/getting-started-add-test-and-security.html#tekton-pipeline-config-example-3)
[^7]: [TAP - OOTB Supply Chain - Registry Ops vs. GitOps](https://docs.vmware.com/en/VMware-Tanzu-Application-Platform/1.5/tap/scc-gitops-vs-regops.html)
[^8]: [Tekton - Git server secrets](https://tekton.dev/docs/pipelines/auth/)

https://docs.vmware.com/en/VMware-Tanzu-Application-Platform/1.5/tap/install-offline-intro.html
https://docs.vmware.com/en/VMware-Tanzu-Application-Platform/1.5/tap/install-gitops-intro.html
https://docs.vmware.com/en/VMware-Tanzu-Application-Platform/1.5/tap/getting-started-add-test-and-security.html