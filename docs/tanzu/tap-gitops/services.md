---
tags:
  - TKG
  - TAP
  - GitOps
  - Carvel
  - Tanzu
---

title: TAP GitOps - Services Cluster
description: Tanzu Application Platform GitOps Installation

# Shared Services

The goal of this cluster is to provide all the services the TAP clusters need.

This includes but is not limited to:

* Image Registry -> Harbor[^11]
* Binary Artifact Repository -> Sonatype Nexus[^12]
* Git Server -> GitLab[^22]
* Authentication -> OpenLDAP[^13]
* Single Sign On -> Keycloak[^14]
* Monitoring -> Prometheus[^15] (Thanos[^16]) + Grafana[^17]
* SAST (Static Code Analysis) -> SonarQube[^18]
* Certificate Management -> Hashicorp Vault[^19]
* Object Storage -> MinIO[^20]

The services themselves don't matter that much persee.
We focus initially on the function of the server and how we get the services installed.

Where applicable, we will look at a service's configuration in detail.

!!! Danger "Note On Infrastructure"
		While most of the installation values we use can be applied to any Kubernetes cluster, there are some infrastructure specific.

		As this environment is installed on Tanzu Kubernetes Grid 2.1 with a management cluster (e.g., ***TGKm***), there are places where the values are specific to this infrastructure.

## GitOps Tool Of Choice

As the goal is to dive into using TAP's GitOps capabilities, it makes a lot of sense to install the services that way as well.

There are several tools available that can do the job.
For the sake of this guide, I've select FluxCD.

For two reasons:

1. Several VMware Tanzu products include FluxCD, such as TMC and TAP, so I want more practice.
1. FluxCD is straightforward for when you need to create "layers" of dependant resurces, which is excellent for bootstrapping core services on Kubernetes.

A bonus reason, ArgoCD seems to work very well as a complementary technology for installing Applications.
We can use it for ensure TAP's Deliverable's are synchronized to the Run clusters.
This way, we can leverage two of the most popular GitOps tools and leave it to the reader to decide any preference.

## FluxCD Bootstrapping

To avoid a chicken and egg situation with the Git server we use GitHub to bootstrap FluxCD[^21].

Set the environment variables for your GitHub user and the PAT token (***recommended***).

```sh
export GITHUB_TOKEN=<your-token>
export GITHUB_USER=<your-username>
export GITHUB_REPO=tap-gitops
```

Verify all is in order:

```sh
flux check --pre
```

If alls is good, we can run the flux bootstrap:

```sh
flux bootstrap github \
  --owner=${GITHUB_USER} \
  --repository=${GITHUB_REPO} \
  --branch=main \
  --path=./platforms/clusters/services \
  --personal
```

!!! Info "Repository Folder Structure"
		As you can see, I use several layers for the folder structure for FluxCD.

		At the first layer, I differentiate between the platform configuration and other types of configuration.
		You can think about infrastructure, docs, or possibly application configuration.

		Inside platforms, I use the customary `clusters` folder, in which the GitOps folders for each (Kubernetes) cluster are located.

### SOPS For Secrets

In the introduction, we decided to use SOPS for managing secrets that need to be synchronized into the Kubernetes clusters.

FluxCD [supports SOPS](https://fluxcd.io/flux/guides/mozilla-sops/) as well, so there's no need to choose differently [^2].

The actual encryption is done via an encryption library.
Here we have the choice for GPG, or [Age](https://fluxcd.io/flux/guides/mozilla-sops/#encrypting-secrets-using-age) [^3].

I've chosen to use [Age](https://github.com/FiloSottile/age), primarily because I had not used it before[^4].

!!! Info "Encrypting with Vault"
    If you have a HashiCorp Vault instance running outside of the cluster, it is likely a better solution.

    Same goes for using the public cloud managed solutions if your cluster is running there.

    As this environment is build on-prem, and the Vault instance is going to be installed in _this_ cluster, we cannot use those.

Create the Age key:

```sh
age-keygen -o age.agekey
```

Ensure the `flux-system` namespace exists:

```sh
kubectl create namespace flux-system
```

And then create the decryption secret for FluxCD:

```sh
cat age.agekey |
kubectl create secret generic sops-age \
--namespace=flux-system \
--from-file=age.agekey=/dev/stdin
```

Use the following to quickly export the Age key for use in SOPS commands:

```sh
export SOPS_AGE_KEY=$(cat age.agekey  | grep "# public key: " | sed 's/# public key: //')
```

Such as encrypting a file, containing a Kubernetes Secret manifest, in place:

```sh
sops --age=${SOPS_AGE_KEY} \
  --encrypt \  
  --encrypted-regex '^(data|stringData)$' \
  --in-place basic-auth.yaml
```

To create such a secret file, we can use the following command:

```sh
kubectl create secret generic basic-auth \
  --from-literal=username='MyUser' \
  --from-literal=password='MySecretPassword' \
  --namespace targetNamespace \
  --dry-run=client \
  -oyaml > basic-auth.yaml
```

!!! Important "Configure Decryption"

    Last but not least, any (FluxCD) [Kustomization](https://fluxcd.io/flux/components/kustomize/kustomizations/) that needs to decrypt these secrets, needs to the decryption configuration[^5].

    This configuration references the secret containing the decryption key, and the type of encryption used.

    In our case, with the above created secret (`sops-age`) and the Age encryption, it should be the following:

    ```yaml title="Kustomization Example"
    apiVersion: kustomize.toolkit.fluxcd.io/v1
    kind: Kustomization
    spec:
      decryption:
        provider: sops
        secretRef:
          name: sops-age
    ```

### Source Layers

One of the complication with applying resources to a Kubernetes cluster, is the ordering.

Tool A might depend on Tool B to exist.
Tool B might need a secret, that secret requires a namespace, and so we can there are different layers to be applied in order.

Not only do we need this ordering at the start, we need to be able to add  

I generaly use the following set of Kustomizations and their ordering:

1. Namespaces
1. Secrets
1. Cluster Essentials
    - this is a reference to the Tanzu Cluster Essentials, namely, KAPP Controller and SecretGen Controller
    - as I'm using TKG 2.x, this is already installed by default
1. Deployment Pre-requisites
    - this contains pre-requisites for Helm installs and KAPP package installs (e.g., two seperate `Kustomization`'s)
    - for example, Helm Repository resources
1. Deployments
    - this contains a `Kustomization` for Helm charts and KAPP packages
1. Post-Deployments
    - this contains resources that can only be installed (e.g., depend on CRD's) after an installation is finished

Especially the Post-Deployments is a tricky category.

Unfortunately, there are some Kubernetes Controllers that install their CRD's lazily.
It is a good solution in general, but it does mean we're better of seperating the installation of these CR's into their own category.

I usually separate the KAPP universe from the Helm universe, but for the ordering and end result this does not matter.

## Installing Services

Let's go over some of these layers, how I've configured them and what options you have.

### Namespaces and Secrets

So first, we need to inform FluxCD what to synchronize. So we define Kustomizations for these two "core" layer resources.

??? Example "./platforms/clusters/services/kustomizations/core-layer-kustomizations.yaml"

    ```yaml
    apiVersion: kustomize.toolkit.fluxcd.io/v1beta2
    kind: Kustomization
    metadata:
      name: namespaces
      namespace: flux-system
    spec:
      interval: 3m0s
      sourceRef:
        kind: GitRepository
        name: flux-system
      path: ./platforms/clusters/services/flux-sources/namespaces
      prune: true
    ---
    apiVersion: kustomize.toolkit.fluxcd.io/v1beta2
    kind: Kustomization
    metadata:
      name: secrets
      namespace: flux-system
    spec:
      dependsOn:
        - name: namespaces
      interval: 3m0s
      sourceRef:
        kind: GitRepository
        name: flux-system
      path: ./platforms/clusters/services/flux-sources/secrets
      prune: true
      decryption:
        provider: sops
        secretRef:
          name: sops-age
    ```

Then we can create namespace definitions in the `flux-sources/namespaces` folder.
Running:

```sh
tree flux-sources
```

Gives you an idea which names we want to create and configure:

```sh
flux-sources
├── namespaces
│   ├── auth.yaml
│   ├── cert-manager.yaml
│   ├── gitea.yaml
│   ├── gitlab.yaml
│   ├── jenkins.yaml
│   ├── minio.yaml
│   ├── monitoring.yaml
│   ├── nexus.yaml
│   ├── psql.yaml
│   ├── sonar.yaml
│   ├── tanzu-packages.yaml
│   ├── tanzu-system-ingress.yaml
│   ├── tanzu-system-registry.yaml
│   ├── tap-install.yaml
│   ├── trivy.yaml
│   └── vault.yaml
└── secrets
    ├── basic-auth.yaml
    ├── gitea-credentials.yaml
    ├── keycloak-credentials.yaml
    ├── ldap-credentials.yaml
    ├── minio-credentials.yaml
    └── sonar-credentials.yaml
```

For example:

```yaml title="namespaces/auth.yaml"
kind: Namespace
apiVersion: v1
metadata:
  name: auth
```

This ensures we can create the secret for Keycloak in here:

??? Example "Keycloak Postgres Secret example"

    ```yaml title="secrets/keycloak-credentials.yaml"
    apiVersion: v1
    data:
        password: ENC[AES256_...g==,iv:KJ9maeBJ+5aFC2+....+8=,tag:.../phmQ==,type:str]
        postgres-password: ENC[AES256_GCM,data:...+xQ==,iv:EJWCeSuRynCC/...+7b+hA=,tag:...==,type:str]
        postgres-user: ENC[AES256_GCM,data:Jf0B+.../yEyWRHeZbtA=,iv:../ZGID4xHLs140SQhUQCwQZ1g=,tag:..==,type:str]
        username: ENC[AES256_GCM,data:...=,iv:...=,tag:..==,type:str]
    kind: Secret
    metadata:
        creationTimestamp: null
        name: keycloak-credentials
        namespace: auth
    sops:
        kms: []
        gcp_kms: []
        azure_kv: []
        hc_vault: []
        age: []
        lastmodified: "2023-06-16T07:03:16Z"
        mac: ENC[AES256_GCM,data:..../....+taPwJY=,iv:zjB3mMdVkplMAKVGBYv0T0zg4tbBz6fhXtydP6Xowok=,tag:..==,type:str]
        pgp:
            - created_at: "2023-06-16T07:03:09Z"
              enc: |
                -----BEGIN PGP MESSAGE-----

                hQIMA97+BPKHpJmVARAAxjycg/w8e2FlABl7givc25B8RArpY5m/lLKIgOg5fVOq
                ...
                ZS0JXt78e0Y8VwndrNRgqGVsrtk8K4RlLkFhJZPGteljmh+lPodMrGf3477guGdL
                zkS+rtJIlA==
                =BugG
                -----END PGP MESSAGE-----
              fp: FEFCF5923A0CD7DD810696B19B7D92BE442BD4EC
        encrypted_regex: ^(data|stringData)$
        version: 3.7.3
    ```

### Helm

For Helm Charts, we have two steps.

First, we need to ensure we have access to Helm Chart by feeding FluxCD the Helm Repository, then we can install the Helm Chart with its install values.

We point a `Kustomization` to the sub-folder `flux-sources/helm-prereqs`, so all files in there get synchronized.
This means you can choose to put each `HelmRepository` in its own file, or one file with all repositories or any combination.

I separated them into their own files, so it is easier for people to create a PR with adding a repository by adding a new file.

```sh
flux-sources
├── helm-prereqs
│   ├── aquasecurity-repo.yaml
│   ├── bitnami-repo.yaml
│   ├── gitlab.yaml
│   ├── hashicorp-repo.yaml
│   ├── jenkins-repo.yaml
│   ├── openldap-repo.yaml
│   ├── sonarqube-repo.yaml
│   ├── sonatype.yaml
│   └── tanzu-repo.yaml
```

Where each file like something like this:

```yaml title="flux-sources/helm-prereqs/tanzu-repo.yaml"
apiVersion: source.toolkit.fluxcd.io/v1beta2
kind: HelmRepository
metadata:
  name: tanzu
  namespace: default
spec:
  interval: 5m
  url: https://vmware-tanzu.github.io/helm-charts
```

Then in the `flux-sources/helm` sub-folder we store all the Helm Chart installations.

For each I intent of having everything related to that installation in the same file.

As long as I can guarantee I can install it at the same time, else it needs to move to the ***helm-post*** `Kustomization`, to avoid locking the reconciliation loop.

For example, for a service that needs to be exposed to the outside world, we might add a `Certificate` and a `HTTPProxy`:

??? Example "Helm Install Example"

    ```yaml title="flux-sources/helm/nexus.yaml"
    apiVersion: helm.toolkit.fluxcd.io/v2beta1
    kind: HelmRelease
    metadata:
      name: nexus
      namespace: nexus
    spec:
      interval: 5m
      timeout: 10m0s
      chart:
        spec:
          chart: nexus-repository-manager
          version: "55.0.0"
          sourceRef:
            kind: HelmRepository
            name: sonatype
            namespace: default
          interval: 5m
      values:
        image:
          repository: harbor.services.my-domain.com/dh-proxy/sonatype/nexus3
        nexus:
          resources:
            requests:
              cpu: 4
              memory: 8Gi
            limits:
              cpu: 4
              memory: 8Gi
        ingress:
          enabled: false
    ---
    apiVersion: projectcontour.io/v1
    kind: HTTPProxy
    metadata:
      name: nexus
      namespace: nexus
    spec:
      ingressClassName: contour
      virtualhost:
        fqdn: nexus.services.my-domain
        tls:
          secretName: nexus-tls
      routes:
      - services:
        - name: nexus-nexus-repository-manager
          port: 8081
    ---
    apiVersion: cert-manager.io/v1
    kind: Certificate
    metadata:
      name: gitea-ssh
      namespace: nexus
    spec:
      secretName: nexus-tls
      issuerRef:
        name: vault-issuer
        kind: "ClusterIssuer"
      commonName: nexus.services.my-domain
      dnsNames:
      - nexus.services.my-domain
    ---
    ```

### Carvel Apps

I treat Carvel Apps, or K-Apps, as a separate category.

The structure to handle them is very similar to the Helm applications though.
We use a pre-reqs, main, and post folders to handle them.

The recommended approach for the Carvel application installations, is to have a specific ServiceAccount for them.
So you start with an RBAC configuration file, and then add the sources of the packages: `PackageRepository` resources.

The RBAC file is quite long, so I'll just refer to it. You can find it [here](https://github.com/joostvdg/tap-gitops-example/blob/main/platforms/clusters/services/flux-sources/kapp-prereqs/rbac.yaml) [^1].

#### Package Repository

As I intend to install tools such as Harbor from the Tanzu kubernetes Grid repository, I add the TKG repository:

```yaml title="platforms/clusters/services/flux-sources/kapp-prereqs/tkg-v2-1-1.yaml"
apiVersion: packaging.carvel.dev/v1alpha1
kind: PackageRepository
metadata:
  annotations:
    packaging.carvel.dev/downgradable: "" # because it sorts on the hash...
  name: standard
  namespace: tkg-system
spec:
  fetch:
    imgpkgBundle:
      image: projects.registry.vmware.com/tkg/packages/standard/repo:v2.1.1
```

Then we can install our desired packages through those.

Unlike the FluxCD CRs related to Helm, FluxCD synchronizes these to the cluster and let's KAPP Controller handle it from there.

For KAPP Controller, there are only two relevant namespaces for packages.

1. the namespace a `Package` is made available via a `PackageRepository`
1. the global package namespace

KAPP Controller defines a namespace as its global namespace.
Any `Package` made available here through a `PackageRepository` can then be installed in ***any*** namespace.

Otherwise, a `Package` can only be installed in the namespace of the `PackageRepository`.

The flag `packaging-global-namespace` determines the namespace deemed global, which is set to `tkg-system` for TKG 2.x based clusters.

Which is why the `PackageRepository` above is installed in _that_ namespace, so we can install the packages anywhere we want.

#### Example Package

To show how to install a Carvel Package, I use the Contour package as an example.

It requires the Cert-manager package to exist, but KAPP Controller will keep reconciling it, so as long as you eventually install the Cert-manager package, it will succeed.

The config file consists of several YAML files:

* The `Role` and `RoleBinding` so KAPP Controller is allowed to install Contour in the correct namespace (e.g., `tanzu-system-ingress`)
* A `Secret`, containing the installation Values for the Carvel Package, similar to Helm install values
* The `PackageInstall`, which instructs KAPP Controller how to install the package

??? Example "Contour Package Example"

    ```yaml title="platforms/clusters/services/flux-sources/kapp/contour.yaml"
    ---
    kind: Role
    apiVersion: rbac.authorization.k8s.io/v1
    metadata:
      name: kapp-controller-role
      namespace: tanzu-system-ingress
    rules:
    - apiGroups: [""]
      resources: ["configmaps", "services", "secrets", "pods", "serviceaccounts"]
      verbs: ["*"]
    - apiGroups: ["apps"]
      resources: ["deployments", "replicasets", "daemonsets"]
      verbs: ["*"]
    - apiGroups: ["cert-manager.io"]
      resources: ["*"]
      verbs: ["*"]
    ---
    kind: RoleBinding
    apiVersion: rbac.authorization.k8s.io/v1
    metadata:
      name: kapp-controller-role-binding
      namespace: tanzu-system-ingress
    subjects:
    - kind: ServiceAccount
      name: kapp-controller-sa
      namespace: tanzu-packages
    roleRef:
      apiGroup: rbac.authorization.k8s.io
      kind: Role
      name: kapp-controller-role
    ---
    apiVersion: v1
    kind: Secret
    metadata:
      name: contour-values
      namespace: tanzu-packages
    stringData:
      values.yml: |
        infrastructure_provider: vsphere
        namespace: tanzu-system-ingress
        contour:
          useProxyProtocol: false
          replicas: 2
          pspNames: "vmware-system-restricted"
          logLevel: info
        envoy:
          service:
            type: LoadBalancer
            annotations: {}
            nodePorts:
              http: null
              https: null
            externalTrafficPolicy: Cluster
            disableWait: false
          hostPorts:
            enable: true
            http: 80
            https: 443
          hostNetwork: false
          terminationGracePeriodSeconds: 300
          logLevel: info
          pspNames: null
        certificates:
          duration: 8760h
          renewBefore: 360h

    ---
    apiVersion: packaging.carvel.dev/v1alpha1
    kind: PackageInstall
    metadata:
      name: contour
      namespace: tanzu-packages
    spec:
      serviceAccountName: kapp-controller-sa
      packageRef:
        refName: contour.tanzu.vmware.com
        versionSelection:
          constraints: 1.22.3+vmware.1-tkg.1
      values:
      - secretRef:
          name: contour-values
          key: values.yml
    ```

## Harbor and Dockerhub Proxy

Docker and DockerHub have been amazing contributors to the growth of Containerization.
And I believe both the technology and the service have contributed productivity gains.

Unfortunately, DockerHub now has strict rate limits, which makes it cumbersome and a bit of a lotery for certain popular images.

So I usually register my DockerHub account in my Harbor, and create a Proxy repository mapping to those DockerHub registry.
Then, within the Helm Chart values, I override the image repositories to the proxy repository.

For a more in-depth explanation on how to do this, read [this guide](https://tanzu.vmware.com/developer/guides/harbor-as-docker-proxy/) on the Tanzu Developer portal[^10].

As an example, this is the Nexus Helm install values shown earlier:

```yaml
values:
  image:
    repository: harbor.services.my-domain.com/dh-proxy/sonatype/nexus3
  nexus:
    ...
```

Harbor will download the images from DockerHub with an account, reducing the rate limit problem, and cache them, reducing the problem further.

## HashiCorp Vault Certificate Management

For leveraging HashiCorp Vault to manage your certificates, I refer you to the official [documentation](https://developer.hashicorp.com/vault/tutorials/kubernetes/kubernetes-cert-manager) [^23].

## References

[^1]: [TAP GitOps Example Repo - Services Cluster](https://github.com/joostvdg/tap-gitops/tree/main/platforms/clusters/services)
[^2]: [FluxCD - Encrypting using SOPS](https://fluxcd.io/flux/guides/mozilla-sops/)
[^3]: [FluxCD - SOPS using Age Key](https://fluxcd.io/flux/guides/mozilla-sops/#encrypting-secrets-using-age)
[^4]: [Age - encryption tool](https://github.com/FiloSottile/age)
[^5]: [FluxCD - Kustomizations](https://fluxcd.io/flux/components/kustomize/kustomizations/)
[^6]: [Tanzu Cluster Essentials](https://docs.vmware.com/en/Cluster-Essentials-for-VMware-Tanzu/index.html)
[^7]: [Carvel - KAPP Controller](https://carvel.dev/kapp-controller/)
[^8]: [Carvel - SecretGen Controller](https://github.com/carvel-dev/secretgen-controller)
[^9]: [Tanzu Kubernetes Grid 2.1 - Package Repository](https://docs.vmware.com/en/VMware-Tanzu-Kubernetes-Grid/2.1/using-tkg/workload-packages-ref.html)
[^10]: [Tanzu Developer Portal - Using Harbor as DockerHub Proxy](https://tanzu.vmware.com/developer/guides/harbor-as-docker-proxy/)
[^11]: [Harbor - Container/OCI Registry](https://goharbor.io/)
[^12]: [Sonatype Nexus - Binary Artifact Repository](https://www.sonatype.com/products/sonatype-nexus-repository)
[^13]: [OpenLDAP](https://www.openldap.org/)
[^14]: [Keycloak - Open Source Identity and Access Management](https://www.keycloak.org/)
[^15]: [Prometheus - Open Source timeseries database](https://prometheus.io/)
[^16]: [Thanos - Open Source, HA Prometheus setup](https://thanos.io/)
[^17]: [Grafana - Open Source monitoring graphics](https://grafana.com/)
[^18]: [SonarQube - self-manage static code analysis tool](https://www.sonarsource.com/products/sonarqube/)
[^19]: [HashiCorp Vault - Secrets management tool](https://www.hashicorp.com/products/vault)
[^20]: [MinIO - Kubernetes native storage solution](https://min.io/)
[^21]: [FluxCD Bootstrap for GitHub](https://fluxcd.io/flux/installation/bootstrap/github/)
[^22]: [GitLab - Git Server (and CI/CD platform)](https://about.gitlab.com/install/)
[^23]: [HashiCorp Vault - Using Vault to manage PKI infra in Kubernetes](https://developer.hashicorp.com/vault/tutorials/secrets-management/pki-engine)
