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

* 

## bla bla

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

https://docs.vmware.com/en/VMware-Tanzu-Application-Platform/1.5/tap/install-offline-intro.html
https://docs.vmware.com/en/VMware-Tanzu-Application-Platform/1.5/tap/install-gitops-intro.html
https://docs.vmware.com/en/VMware-Tanzu-Application-Platform/1.5/tap/getting-started-add-test-and-security.html