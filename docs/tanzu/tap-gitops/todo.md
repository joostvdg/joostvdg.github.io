# TODO

* Applications with ArgoCD
  * re-create GitLab
  * or change GitOps flow repo to GitHub
* Next steps
    * Customize TAP GUI
* write about Supply Chain extensions
    * Tekton Pipelines with Tasks
    * Tekton Tasks + Workspace + overwriting the OOTB Supply Chain
    * Change folder structure for GitOps repository
    * Test Containers + DinD
    * use Docker in Docker alternative from ITQ guy
* TAP in GCP
    * get access to GCP


## Tanzu Network TAP Download

* https://network.tanzu.vmware.com/products/tanzu-application-platform/releases

## Run Cluster Prep

### TGK Packages

* https://docs.vmware.com/en/VMware-Tanzu-Packages/2023.9.19/tanzu-packages/index.html
* version is decoupled from TKG (2.4)

List versions available (of the package repo):

```sh
imgpkg tag list -i projects.registry.vmware.com/tkg/packages/standard/repo
```

Which shows something like this (abbreviated):

```sh
v2.2.0_update.2
v2023.10.16
v2023.7.13
v2023.7.13_update.1
v2023.7.13_update.2
v2023.7.31_update.1
v2023.9.19
v2023.9.19_update.1
```

```yaml title="packagerepo-v2023.9.19_update.1.yaml"
apiVersion: packaging.carvel.dev/v1alpha1
kind: PackageRepository
metadata:
  name: tanzu-standard
  namespace: tkg-system
spec:
  fetch:
    imgpkgBundle:
      image: projects.registry.vmware.com/tkg/packages/standard/repo:v2023.9.19_update.1
```

```yaml
kubectl apply -f packagerepo-v2023.9.19_update.1.yaml
```

```sh
tanzu package repository list -A
```

```sh
kubectl create ns cert-manager
```

```sh
kubectl -n tkg-system get packages | grep cert-manager
```

```sh
tanzu package install cert-manager \
  -p cert-manager.tanzu.vmware.com \
  -n cert-manager \
  -v 1.12.2+vmware.1-tkg.1
```

### Run Profile Install

* https://docs.vmware.com/en/VMware-Tanzu-Application-Platform/1.7/tap/prerequisites.html#resource-requirements-5


```sh
export INSTALL_REGISTRY_HOSTNAME=registry.tanzu.vmware.com
export INSTALL_REPO=tanzu-application-platform
export INSTALL_REGISTRY_USERNAME=joostvdg@gmail.com
export INSTALL_REGISTRY_PASSWORD='Lm-T*6hULZ2UWJPm.DNL'
export MY_REGISTRY_HOSTNAME=https://index.docker.io/v1/~
export MY_REGISTRY_PASSWORD=dckr_pat_b6cccjpngtrvB_RH59Qje7TZnfo
export MY_REGISTRY_USERNAME=joostvdgtanzu
export TAP_PKGR_REPO=registry.tanzu.vmware.com/tanzu-application-platform/tap-packages
export TAP_VERSION=1.7.1
```


```sh
kubectl create ns tap-install
```

```sh
tanzu secret registry add tap-registry \
  --username ${INSTALL_REGISTRY_USERNAME} --password ${INSTALL_REGISTRY_PASSWORD} \
  --server ${INSTALL_REGISTRY_HOSTNAME} \
  --export-to-all-namespaces --yes --namespace tap-install
```

```sh
tanzu secret registry add registry-credentials \
    --server   ${MY_REGISTRY_HOSTNAME} \
    --username ${MY_REGISTRY_USERNAME} \
    --password ${MY_REGISTRY_PASSWORD} \
    --namespace tap-install \
    --export-to-all-namespaces \
    --yes
```

```sh
tanzu package repository add tanzu-tap-repository \
  --url ${INSTALL_REGISTRY_HOSTNAME}/${INSTALL_REPO}/tap-packages:$TAP_VERSION \
  --namespace tap-install
```

```sh
tanzu package repository get tanzu-tap-repository --namespace tap-install
```


```sh
tanzu package available list --namespace tap-install
```

```sh
tanzu package install tap \
  -p tap.tanzu.vmware.com \
  -v $TAP_VERSION \
  --values-file tap-profile-full-170.yaml \
  -n tap-install
```

```yaml title="tap-profile-full-170.yaml"
shared:
  ingress_domain: "tap02.h2o-2-19271.h2o.vmware.com"

  image_registry:
    project_path: registry.tanzu.vmware.com/tanzu-application-platform/tap-packages
    secret:
      name: tap-registry
      namespace: tap-install
  kubernetes_version: "1.26.5" # Required regardless of distribution when Kubernetes version is 1.25 or later.

ceip_policy_disclosed: true # Installation fails if this is not set to true. Not a string.

profile: run # Can take iterate, build, run, view.
supply_chain: basic # Can take testing, testing_scanning.

contour:
  envoy:
    service:
      type: LoadBalancer # This is set by default, but can be overridden by setting a different value.

appliveview_connector:
  backend:
    sslDeactivated: true
    ingressEnabled: true
    host: appliveview.tap01.h2o-2-19271.h2o.vmware.com
```


#### Example From Docs

```yaml
profile: run
ceip_policy_disclosed: FALSE-OR-TRUE-VALUE # Installation fails if this is not set to true. Not a string.

shared:
  ingress_domain: INGRESS-DOMAIN
  kubernetes_distribution: "openshift" # To be passed only for Openshift. Defaults to "".
  kubernetes_version: "K8S-VERSION"
  ca_cert_data: | # To be passed if using custom certificates.
    -----BEGIN CERTIFICATE-----
    MIIFXzCCA0egAwIBAgIJAJYm37SFocjlMA0GCSqGSIb3DQEBDQUAMEY...
    -----END CERTIFICATE-----
supply_chain: basic

contour:
  envoy:
    service:
      type: LoadBalancer # NodePort can be used if your Kubernetes cluster doesn't support LoadBalancing.

appliveview_connector:
  backend:
    sslDeactivated: TRUE-OR-FALSE-VALUE
    ingressEnabled: true
    host: appliveview.VIEW-CLUSTER-INGRESS-DOMAIN

tap_telemetry:
  customer_entitlement_account_number: "CUSTOMER-ENTITLEMENT-ACCOUNT-NUMBER" # (Optional) Identify data for creating Tanzu Application Platform usage reports.

amr:
  observer:
    auth:
      kubernetes_service_accounts:
        enable: true
    cloudevent_handler:
      endpoint: https://amr-cloudevent-handler.VIEW-CLUSTER-INGRESS-DOMAIN # AMR CloudEvent Handler location at the View profile cluster.
    ca_cert_data: |
        "AMR-CLOUDEVENT-HANDLER-CA" 
```

### MinIO Helm Chart

```sh
kubectl create secret tls kearos-ca \
   --key certs/ca-key.pem \
   --cert certs/ca.pem \
   -n cert-manager
```

```yaml title="kearos-cluster-issuer.yaml"
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: kearos-issuer
  namespace: cert-manager
spec:
  ca:
    secretName: kearos-ca
```

```sh
kubectl apply -f kearos-cluster-issuer.yaml
```

```sh
kubectl get ClusterIssuer
```

```yaml title="minio-values.yaml"
global:
  storageClass: vc01cl01-t0compute-latebinding
auth:
  rootPassword: 'VMware123!'
```

```sh
helm repo update
```

```sh
kubectl create namespace minio
```

```sh
helm upgrade --install \
  minio bitnami/minio \
  --version 12.10.1 \
  --namespace minio \
  --values minio-values.yaml
```


```yaml title="minio-httpproxy.yaml
---
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: minio
  namespace: minio
spec:
  secretName: minio-tls
  issuerRef:
    name: kearos-issuer
    kind: "ClusterIssuer"
  commonName: minio.h2o-2-19271.h2o.vmware.com
  dnsNames:
  - minio.h2o-2-19271.h2o.vmware.com
  - minio-console.h2o-2-19271.h2o.vmware.com
---
apiVersion: projectcontour.io/v1
kind: HTTPProxy
metadata:
  name: minio-insecure
  namespace: minio
spec:
  ingressClassName: contour
  virtualhost:
    fqdn: minio.h2o-2-19271.h2o.vmware.com
  routes:
  - services:
    - name: minio
      port: 9000
---
apiVersion: projectcontour.io/v1
kind: HTTPProxy
metadata:
  name: minio-api
  namespace: minio
spec:
  ingressClassName: contour
  virtualhost:
    fqdn: minio-console.h2o-2-19271.h2o.vmware.com
    tls:
      secretName: minio-tls
  routes:
  - services:
    - name: minio
      port: 9001
```

#### TechDocs

```sh
export AWS_ACCESS_KEY_ID=BdPJSbbKN3FvaBxEq4ub
export AWS_SECRET_ACCESS_KEY=WwNJpwH4oDr27UlpJl9xcIeYsVStIz7U7S0iYYc1
export AWS_REGION=us-east-1
```

```sh
mc alias set minio_h20 https://$MINIO_HOSTNAME admin 'VMware123!'
```

```sh
mc mb --ignore-existing minio_h20/techdocs
mc mb --ignore-existing minio_h20/docs
```

```sh
mc ls minio_h20/
```

```sh
[2023-11-28 16:11:03 CET]     0B docs/
[2023-11-28 16:11:07 CET]     0B techdocs/
```

```sh
npx @techdocs/cli publish --publisher-type awsS3 \
  --awsEndpoint https://minio.h2o-2-19271.h2o.vmware.com \
  --storage-name docs \
  --entity default/Component/spring-boot-postgres \
  --awsS3ForcePathStyle
```

```sh
mc ls minio_h20/docs/default/component/spring-boot-postgres/
```

```sh
[2023-11-28 16:14:17 CET]  15KiB STANDARD 404.html
[2023-11-28 16:14:18 CET]  21KiB STANDARD index.html
[2023-11-28 16:14:18 CET]   277B STANDARD sitemap.xml
[2023-11-28 16:14:18 CET]   217B STANDARD sitemap.xml.gz
[2023-11-28 16:14:18 CET] 2.0KiB STANDARD techdocs_metadata.json
[2023-11-28 16:14:51 CET]     0B assets/
[2023-11-28 16:14:51 CET]     0B search/
```

### Harbor

```sh
tanzu package repository add tanzu-standard --url projects.registry.vmware.com/tkg/packages/standard/repo:v2023.7.13 --namespace tkg-system
```

```sh
kubectl apply -f kapp-rbac-tanzu-packages.yaml
```

Create `harbor-package-install.yaml`

```sh
kubectl apply -f harbor-package-install.yaml
```

```sh
kubectl get pkgi -n tanzu-packages
```

```sh
kubectl get app -n tanzu-packages
```

```sh
kubectl get po,httpproxy -n tanzu-system-registry
```

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: tanzu-system-registry
---
apiVersion: v1
kind: Namespace
metadata:
  name: tanzu-packages
---
kind: Role
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: kapp-controller-role
  namespace: tanzu-system-registry
rules:
- apiGroups: [""]
  resources: ["configmaps", "services", "secrets", "pods", "serviceaccounts", "persistentvolumeclaims", "persistentvolumes"]
  verbs: ["*"]
- apiGroups: ["apps"]
  resources: ["deployments", "replicasets", "daemonsets", "statefulsets"]
  verbs: ["*"]
- apiGroups: ["cert-manager.io"]
  resources: ["*"]
  verbs: ["*"]
- apiGroups: ["projectcontour.io"]
  resources: ["*"]
  verbs: ["*"]
---
kind: RoleBinding
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: kapp-controller-role-binding
  namespace: tanzu-system-registry
subjects:
- kind: ServiceAccount
  name: kapp-controller-sa
  namespace: tanzu-packages
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: kapp-controller-role
---
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: harbor
  namespace: tanzu-system-registry
spec:
  secretName: harbor-tls
  issuerRef:
    name: kearos-issuer
    kind: "ClusterIssuer"
  commonName: harbor.tap.h2o-2-19271.h2o.vmware.com
  dnsNames:
  - harbor.tap.h2o-2-19271.h2o.vmware.com
---
apiVersion: v1
kind: Secret
metadata:
  name: harbor-values
  namespace: tanzu-packages
stringData:
  values.yml: |
    tlsCertificateSecretName: harbor-tls
    caBundleSecretName: harbor-tls
    namespace: tanzu-system-registry
    hostname: harbor.tap.h2o-2-19271.h2o.vmware.com
    port:
      https: 443
    logLevel: info
    enableContourHttpProxy: true
    harborAdminPassword: VMware123!
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
          storageClass: vc01cl01-t0compute
          accessMode: ReadWriteOnce
          size: 100Gi
        jobservice:
          jobLog:
            storageClass: vc01cl01-t0compute
            accessMode: ReadWriteOnce
            size: 10Gi
        database:
          storageClass: vc01cl01-t0compute
          accessMode: ReadWriteOnce
          size: 10Gi
        redis:
          storageClass: vc01cl01-t0compute
          accessMode: ReadWriteOnce
          size: 5Gi
        trivy:
          storageClass: vc01cl01-t0compute
          accessMode: ReadWriteOnce
          size: 10Gi
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

---
apiVersion: packaging.carvel.dev/v1alpha1
kind: PackageInstall
metadata:
  name: harbor
  namespace: tanzu-packages
spec:
  serviceAccountName: kapp-controller-sa
  packageRef:
    refName: harbor.tanzu.vmware.com
    versionSelection:
      constraints: 2.8.4+vmware.1-tkg.1
  values:
  - secretRef:
      name: harbor-values
      key: values.yml
```

### GitLab

Namespaces config:

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: gitlab
---
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: gitlab
  namespace: gitlab
spec:
  secretName: gitlab-tls
  issuerRef:
    name: kearos-issuer
    kind: "ClusterIssuer"
  commonName: gitlab.tap.h2o-2-19271.h2o.vmware.com
  dnsNames:
  - gitlab.tap.h2o-2-19271.h2o.vmware.com
---
apiVersion: projectcontour.io/v1
kind: HTTPProxy
metadata:
  name: gitlab
  namespace: gitlab
spec:
  ingressClassName: contour
  virtualhost:
    fqdn: gitlab.tap.h2o-2-19271.h2o.vmware.com
    tls:
      secretName: gitlab-tls
  routes:
  - services:
    - name: gitlab-webservice-default
      port: 8181
    enableWebsockets: true
    permitInsecure: true
```

```sh
kubectl apply -f gitlab-namespace.yaml
```

Values:

```yaml
global:
  edition: ce
  hosts:
    domain: gitlab.tap.h2o-2-19271.h2o.vmware.com
    https: false
  ingress:
    configureCertmanager: false
    provider: contour
    class: contour
    enabled: false
certmanager:
  installCRDs: false
  install: false
gitlab-runner:
  install: false
gitlab:
  webservice:
    minReplicas: 1
    maxReplicas: 1
  sidekiq:
    minReplicas: 1
    maxReplicas: 1
  gitlab-shell:
    minReplicas: 1
    maxReplicas: 1
```

```sh
helm upgrade --install gitlab gitlab/gitlab \
  --namespace gitlab --wait --version 6.6.0 \
  --values gitlab-values.yaml
```

```sh
kubectl create secret docker-registry dh-registry-credentials \
    --docker-username=joostvdgtanzu \
    --docker-password=??? \
    --docker-server=https://index.docker.io/v2/ -n gitlab
```

And then add the secret as imagePullSecret to the SA:

```sh
kubectl edit -n gitlab sa default
```

```sh
imagePullSecrets:
  - name: dh-registry-credentials
```

### ArgoCD - Install in Full with Access to Run


```yaml title="argocd-values.yaml"
```

```sh
helm upgrade --install argocd argo/argo-cd \
  --namespace argocd \
  --wait \
  --version 5.46.7 \
  --values argocd-values.yaml
```

## Notes - TAP GitOps 1.7

* https://docs.vmware.com/en/VMware-Tanzu-Application-Platform/1.7/tap/install-gitops-sops.html


```sh
export SOPS_AGE_KEY=$(cat key.txt)
export TAP_PKGR_REPO=harbor.tap.h2o-2-19271.h2o.vmware.com/tap/tap-packages
```

### KAPP Controller

```yaml
apiVersion: v1
kind: Secret
metadata:
  # Name must be `kapp-controller-config` for kapp controller to pick it up
  name: kapp-controller-config

  # Namespace must match the namespace kapp-controller is deployed to
  namespace: tkg-system

stringData:
  # A cert chain of trusted ca certs. These will be added to the system-wide
  # cert pool of trusted ca's (optional)
  caCerts: |
    -----BEGIN CERTIFICATE-----
    MIID7jCCAtagAwIBAgIURv5DzXSDklERFu4gL2sQBNeRg+owDQYJKoZIhvcNAQEL
    BQAwgY4xCzAJBgNVBAYTAk5MMRgwFgYDVQQIEw9UaGUgTmV0aGVybGFuZHMxEDAO
    BgNVBAcTB1V0cmVjaHQxFTATBgNVBAoTDEtlYXJvcyBUYW56dTEdMBsGA1UECxMU
    S2Vhcm9zIFRhbnp1IFJvb3QgQ0ExHTAbBgNVBAMTFEtlYXJvcyBUYW56dSBSb290
    IENBMB4XDTIyMDMyMzE1MzUwMFoXDTI3MDMyMjE1MzUwMFowgY4xCzAJBgNVBAYT
    Ak5MMRgwFgYDVQQIEw9UaGUgTmV0aGVybGFuZHMxEDAOBgNVBAcTB1V0cmVjaHQx
    FTATBgNVBAoTDEtlYXJvcyBUYW56dTEdMBsGA1UECxMUS2Vhcm9zIFRhbnp1IFJv
    b3QgQ0ExHTAbBgNVBAMTFEtlYXJvcyBUYW56dSBSb290IENBMIIBIjANBgkqhkiG
    9w0BAQEFAAOCAQ8AMIIBCgKCAQEAyZXDL9W2vu365m//E/w8n1M189a5mI9HcTYa
    0xZhnup58Zp72PsgzujI/fQe43JEeC+aIOcmsoDaQ/uqRi8p8phU5/poxKCbe9SM
    f1OflLD9k2dwte6OV5kcSUbVOgScKL1wGEo5mdOiTFrEp5aLBUcbUeJMYz2IqLVa
    v52H0vTzGfmrfSm/PQb+5qnCE5D88DREqKtWdWW2bCW0HhxVHk6XX/FKD2Z0FHWI
    ChejeaiarXqWBI94BANbOAOmlhjjyJekT5hL1gh7BuCLbiE+A53kWnXO6Xb/eyuJ
    obr+uHLJldoJq7SFyvxrDd/8LAJD4XMCEz+3gWjYDXMH7GfPWwIDAQABo0IwQDAO
    BgNVHQ8BAf8EBAMCAQYwDwYDVR0TAQH/BAUwAwEB/zAdBgNVHQ4EFgQUfGU50Pe9
    YTv5SFvGVOz6R7ddPcUwDQYJKoZIhvcNAQELBQADggEBAHMoNDxy9/kL4nW0Bhc5
    Gn0mD8xqt+qpLGgChlsMPNR0xPW04YDotm+GmZHZg1t6vE8WPKsktcuv76d+hX4A
    uhXXGS9D0FeC6I6j6dOIW7Sbd3iAQQopwICYFL9EFA+QAINeY/Y99Lf3B11JfLU8
    jN9uGHKFI0FVwHX428ObVrDi3+OCNewQ3fLmrRQe6F6q2OU899huCg+eYECWvxZR
    a3SlVZmYnefbA87jI2FRHUPqxp4P2mDwj/RZxhgIobhw0zz08sqC6DW0Aj1OIJe5
    sDAm0uiUdqs7FZN2uKkLKekdTgW0QkTFEJTk5Yk9t/hOrjnHoWQfB+mLhO3vPhip
    vhs=
    -----END CERTIFICATE-----
```

## TKR 1.26 Admission Policies

* see issue: https://vmware.slack.com/archives/C02D60T1ZDJ/p1697207282314919
* create cluster via TMC
* create mutation policies to add labels to all namespaces

```yaml
type:
  kind: Policy
  version: v1alpha1
  package: vmware.tanzu.manage.v1alpha1.clustergroup.policy
fullName:
  orgId: 26620245-46a1-4f87-8b0c-63f6b4c41198
  clusterGroupName: joostvdg-h2o
  name: enforce
spec:
  type: mutation-policy
  recipe: label
  recipeVersion: v1
  input:
    scope: "*"
    targetKubernetesResources:
      - apiGroups:
          - ""
        kinds:
          - Namespace
    label:
      key: pod-security.kubernetes.io/enforce
      value: privileged
  namespaceSelector:
    matchExpressions:
      - key: kubernetes.io/metadata.name
        operator: Exists
```

```yaml
type:
  kind: Policy
  version: v1alpha1
  package: vmware.tanzu.manage.v1alpha1.clustergroup.policy
fullName:
  orgId: 26620245-46a1-4f87-8b0c-63f6b4c41198
  clusterGroupName: joostvdg-h2o
  name: enforce-version
spec:
  type: mutation-policy
  recipe: label
  recipeVersion: v1
  input:
    scope: "*"
    targetKubernetesResources:
      - apiGroups:
          - ""
        kinds:
          - Namespace
    label:
      key: pod-security.kubernetes.io/enforce-version
      value: latest
  namespaceSelector:
    matchExpressions:
      - key: kubernetes.io/metadata.name
        operator: Exists

```

```sh
export INSTALL_REGISTRY_HOSTNAME=registry.tanzu.vmware.com
export INSTALL_REGISTRY_USERNAME=jvandergrien@vmware.com
export INSTALL_REGISTRY_PASSWORD='X6qRPlP@0056$&qx%SCSIOFH'
export GIT_SSH_PRIVATE_KEY=$(cat $HOME/.ssh/id_rsa)
export GIT_KNOWN_HOSTS=$(ssh-keyscan github.com)
export SOPS_AGE_KEY=$(cat /Users/joostvdg/Projects/tap-gitops/key.txt)
export TAP_PKGR_REPO=registry.tanzu.vmware.com/tanzu-application-platform/tap-packages
```

## KPACK Tutorial

* https://github.com/buildpacks-community/kpack/blob/main/docs/tutorial.md

### Registry Secret

```sh
kp secret create my-registry-cred \
  --registry harbor.tap.h2o-2-19271.h2o.vmware.com \
  --registry-user admin \
  --namespace tap-install
```

```sh
kubectl create secret docker-registry tutorial-registry-credentials \
    --docker-username=admin \
    --docker-password='VMware123!' \
    --docker-server=harbor.tap.h2o-2-19271.h2o.vmware.com \
    --namespace ktest
```

### ServiceAccount

```yaml title="sa.yaml"
apiVersion: v1
kind: ServiceAccount
metadata:
  name: tutorial-service-account
  namespace: ktest
secrets:
- name: tutorial-registry-credentials
imagePullSecrets:
- name: tutorial-registry-credentials
```

```sh
kubectl apply -f sa.yaml
```

### ClusterStore

```yaml title="store.yaml"
apiVersion: kpack.io/v1alpha2
kind: ClusterStore
metadata:
  name: ktest
spec:
  sources:
  - image: gcr.io/paketo-buildpacks/java
  - image: gcr.io/paketo-buildpacks/nodejs
```

```sh
kubectl apply -f store.yaml
```

### ClusterStack

```yaml title="stack.yaml"
apiVersion: kpack.io/v1alpha2
kind: ClusterStack
metadata:
  name: ktest-base
spec:
  id: "io.buildpacks.stacks.jammy"
  buildImage:
    image: "paketobuildpacks/build-jammy-base"
  runImage:
    image: "paketobuildpacks/run-jammy-base"
```

```sh
kubectl apply -f stack.yaml
```

### Builder

```yaml title="builder.yaml"
apiVersion: kpack.io/v1alpha2
kind: Builder
metadata:
  name: test
  namespace: ktest
spec:
  serviceAccountName: tutorial-service-account
  tag: harbor.tap.h2o-2-19271.h2o.vmware.com/buildservice/full-deps-package-repo:default-builder
  stack:
    name: ktest-base
    kind: ClusterStack
  store:
    name: ktest
    kind: ClusterStore
  order:
  - group:
    - id: paketo-buildpacks/java
  - group:
    - id: paketo-buildpacks/nodejs
```

```sh
kubectl apply -f builder.yaml
```

```sh
kubectl get builder -n ktest
```

```sh
kubectl describe builder -n ktest test
```

full-deps-package-repo

harbor.tap.h2o-2-19271.h2o.vmware.com/buildservice/full-deps-package-repo:default-builder
harbor.tap.h2o-2-19271.h2o.vmware.com/buildservice/full-deps-package-repo:


docker pull harbor.tap.h2o-2-19271.h2o.vmware.com/buildservice/full-deps-package-repo@sha256:741114edfb85c5fafdabdb04ad5cc3057e4f645dea3bef8d687f0e1cad75209e


## Relocate Images

### TAP

```sh
# Set tanzunet as the source registry to copy the Tanzu Application Platform packages from.
export IMGPKG_REGISTRY_HOSTNAME_0=registry.tanzu.vmware.com
export IMGPKG_REGISTRY_USERNAME_0=joostvdg@gmail.com
export IMGPKG_REGISTRY_PASSWORD_0='Lm-T*6hULZ2UWJPm.DNL'

# The user’s registry for copying the Tanzu Application Platform package to.
export IMGPKG_REGISTRY_HOSTNAME_1=harbor.tap.h2o-2-19271.h2o.vmware.com
export IMGPKG_REGISTRY_USERNAME_1=admin
export IMGPKG_REGISTRY_PASSWORD_1='VMware123!'
export TAP_VERSION=1.7.1
export REGISTRY_CA_PATH=/Users/joostvdg/Projects/vmware-docs/labs/h20/tap/150/scripts/ssl/ca.crt
```

```sh
imgpkg copy \
  -b registry.tanzu.vmware.com/tanzu-application-platform/tap-packages:$TAP_VERSION \
  --to-tar tap-packages-$TAP_VERSION.tar \
  --include-non-distributable-layers
```

```sh
imgpkg copy \
  --tar tap-packages-$TAP_VERSION.tar \
  --to-repo $IMGPKG_REGISTRY_HOSTNAME_1/tap/tap-packages \
  --include-non-distributable-layers \
  --registry-ca-cert-path $REGISTRY_CA_PATH
```

### TBS Full Deps

```sh
imgpkg copy -b registry.tanzu.vmware.com/tanzu-application-platform/full-deps-package-repo:${TAP_VERSION} \
  --to-tar=full-deps-package-repo-${TAP_VERSION}.tar
```

move full-deps-package-repo.tar to environment with registry access

```sh
imgpkg copy --tar full-deps-package-repo-${TAP_VERSION}.tar \
  --to-repo=harbor.tap.h2o-2-19271.h2o.vmware.com/buildservice/full-deps-package-repo \
  --registry-ca-cert-path $REGISTRY_CA_PATH
```

### TBS Deps Package Repository

```sh
kubectl create ns tbs-deps-1-7-1
```

```sh
tanzu package repository add tbs-deps-1-7-1 \
  --url harbor.tap.h2o-2-19271.h2o.vmware.com/buildservice/full-deps-package-repo:${TAP_VERSION} \
  --namespace tbs-deps-1-7-1
```

```sh
tanzu package available -n tbs-deps-1-7-1 list
```

```sh
export PACKAGE=full-deps.buildservice.tanzu.vmware.com
export PACKAGE_VERSION=1.7.38
```

```sh
tanzu package available -n tbs-deps-1-7-1 get $PACKAGE/${PACKAGE_VERSION} --values-schema
```

### TBS Deps Package

```yaml title="tbs-deps-full-171.yaml"
kp_default_repository: harbor.tap.h2o-2-19271.h2o.vmware.com/buildservice/full-deps-package-repo
```

```sh
tanzu package install tbs-deps-full \
  -p $PACKAGE \
  -v $PACKAGE_VERSION \
  --values-file tbs-deps-full-171.yaml \
  -n tbs-deps-1-7-1
```

```sh
tanzu package installed delete -n tbs-deps-1-7-1 tbs-deps-full
```

{
  "auths": {
    "harbor.tap.h2o-2-19271.h2o.vmware.com": {
      "username": "admin",
      "password": "VMware123!",
      "auth": "YWRtaW46Vk13YXJlMTIzIQ=="
    }
  }
}

{
  "auths": {
    "harbor.tap.h2o-2-19271.h2o.vmware.com": {
      "username": "admin",
      "password": "VMware123!",
      "auth": "YWRtaW46Vk13YXJlMTIzIQo="
    }
  }
}

## TAP GUI

### Backstage Plugins

* https://vrabbi.cloud/post/tanzu-developer-portal-configurator-deep-dive/
* https://docs.vmware.com/en/VMware-Tanzu-Application-Platform/1.7/tap/tap-gui-configurator-building.html
* https://www.npmjs.com/search?q=vmware-tanzu

* create: `tdp-config.yaml`

```yaml
app:
  plugins:
    - name: "@vmware-tanzu/tdp-plugin-techinsights"
      version: "0.0.2"
    - name: "@vrabbi/tekton-wrapper"
      version: "0.1.2"

backend:
  plugins:
    - name: "@vmware-tanzu/tdp-plugin-techinsights-backend"
      version: "0.0.2"
```

```sh
imgpkg describe -b $(kubectl get -n tap-install $(kubectl get package -n tap-install \
--field-selector spec.refName=tpb.tanzu.vmware.com -o name) -o \
jsonpath="{.spec.template.spec.fetch[0].imgpkgBundle.image}") -o yaml --tty=true | grep -A 1 \
"kbld.carvel.dev/id: harbor-repo.vmware.com/esback/configurator" | grep "image: " | sed 's/\simage: //g'
```

```sh
      image: registry.tanzu.vmware.com/tanzu-application-platform/tap-packages@sha256:001d3879720c2dc131ec95db6c6a34ff3c2f912d9d8b7ffacb8da08a844b740f
```

> Record this value to later use it in place of the TDP-IMAGE-LOCATION placeholder in the workload definition

```sh
export TDP_IMAGE_LOCATION=registry.tanzu.vmware.com/tanzu-application-platform/tap-packages@sha256:001d3879720c2dc131ec95db6c6a34ff3c2f912d9d8b7ffacb8da08a844b740f
```

```sh
export ENCODED_TDP_CONFIG_VALUE=$(base64 -i tdp-config.yaml)
```

* create `tdp-sc.yaml`

```yaml
apiVersion: carto.run/v1alpha1
kind: ClusterSupplyChain
metadata:
  name: tdp-configurator
spec:
  resources:
  - name: source-provider
    params:
    - default: default
      name: serviceAccount
    - default: registry.tanzu.vmware.com/tanzu-application-platform/tap-packages@sha256:001d3879720c2dc131ec95db6c6a34ff3c2f912d9d8b7ffacb8da08a844b740f
      name: tdp_configurator_bundle
    templateRef:
      kind: ClusterSourceTemplate
      name: tdp-source-template
  - name: image-provider
    params:
    - default: default
      name: serviceAccount
    - name: registry
      default:
        ca_cert_data: |-
          -----BEGIN CERTIFICATE-----
          MIID7jCCAtagAwIBAgIURv5DzXSDklERFu4gL2sQBNeRg+owDQYJKoZIhvcNAQEL
          BQAwgY4xCzAJBgNVBAYTAk5MMRgwFgYDVQQIEw9UaGUgTmV0aGVybGFuZHMxEDAO
          BgNVBAcTB1V0cmVjaHQxFTATBgNVBAoTDEtlYXJvcyBUYW56dTEdMBsGA1UECxMU
          S2Vhcm9zIFRhbnp1IFJvb3QgQ0ExHTAbBgNVBAMTFEtlYXJvcyBUYW56dSBSb290
          IENBMB4XDTIyMDMyMzE1MzUwMFoXDTI3MDMyMjE1MzUwMFowgY4xCzAJBgNVBAYT
          Ak5MMRgwFgYDVQQIEw9UaGUgTmV0aGVybGFuZHMxEDAOBgNVBAcTB1V0cmVjaHQx
          FTATBgNVBAoTDEtlYXJvcyBUYW56dTEdMBsGA1UECxMUS2Vhcm9zIFRhbnp1IFJv
          b3QgQ0ExHTAbBgNVBAMTFEtlYXJvcyBUYW56dSBSb290IENBMIIBIjANBgkqhkiG
          9w0BAQEFAAOCAQ8AMIIBCgKCAQEAyZXDL9W2vu365m//E/w8n1M189a5mI9HcTYa
          0xZhnup58Zp72PsgzujI/fQe43JEeC+aIOcmsoDaQ/uqRi8p8phU5/poxKCbe9SM
          f1OflLD9k2dwte6OV5kcSUbVOgScKL1wGEo5mdOiTFrEp5aLBUcbUeJMYz2IqLVa
          v52H0vTzGfmrfSm/PQb+5qnCE5D88DREqKtWdWW2bCW0HhxVHk6XX/FKD2Z0FHWI
          ChejeaiarXqWBI94BANbOAOmlhjjyJekT5hL1gh7BuCLbiE+A53kWnXO6Xb/eyuJ
          obr+uHLJldoJq7SFyvxrDd/8LAJD4XMCEz+3gWjYDXMH7GfPWwIDAQABo0IwQDAO
          BgNVHQ8BAf8EBAMCAQYwDwYDVR0TAQH/BAUwAwEB/zAdBgNVHQ4EFgQUfGU50Pe9
          YTv5SFvGVOz6R7ddPcUwDQYJKoZIhvcNAQELBQADggEBAHMoNDxy9/kL4nW0Bhc5
          Gn0mD8xqt+qpLGgChlsMPNR0xPW04YDotm+GmZHZg1t6vE8WPKsktcuv76d+hX4A
          uhXXGS9D0FeC6I6j6dOIW7Sbd3iAQQopwICYFL9EFA+QAINeY/Y99Lf3B11JfLU8
          jN9uGHKFI0FVwHX428ObVrDi3+OCNewQ3fLmrRQe6F6q2OU899huCg+eYECWvxZR
          a3SlVZmYnefbA87jI2FRHUPqxp4P2mDwj/RZxhgIobhw0zz08sqC6DW0Aj1OIJe5
          sDAm0uiUdqs7FZN2uKkLKekdTgW0QkTFEJTk5Yk9t/hOrjnHoWQfB+mLhO3vPhip
          vhs=
          -----END CERTIFICATE-----
        repository: tap-apps
        server: harbor.tap.h2o-2-19271.h2o.vmware.com
    - default: default
      name: clusterBuilder
    sources:
    - name: source
      resource: source-provider
    templateRef:
      kind: ClusterImageTemplate
      name: tdp-kpack-template

  selectorMatchExpressions:
  - key: apps.tanzu.vmware.com/workload-type
    operator: In
    values:
    - tdp
---
apiVersion: carto.run/v1alpha1
kind: ClusterImageTemplate
metadata:
  name: tdp-kpack-template
spec:
  healthRule:
    multiMatch:
      healthy:
        matchConditions:
        - status: "True"
          type: BuilderReady
        - status: "True"
          type: Ready
      unhealthy:
        matchConditions:
        - status: "False"
          type: BuilderReady
        - status: "False"
          type: Ready
  imagePath: .status.latestImage
  lifecycle: mutable
  params:
  - default: default
    name: serviceAccount
  - default: default
    name: clusterBuilder
  - name: registry
    default: {}
  ytt: |
    #@ load("@ytt:data", "data")
    #@ load("@ytt:regexp", "regexp")

    #@ def merge_labels(fixed_values):
    #@   labels = {}
    #@   if hasattr(data.values.workload.metadata, "labels"):
    #@     exclusions = ["kapp.k14s.io/app", "kapp.k14s.io/association"]
    #@     for k,v in dict(data.values.workload.metadata.labels).items():
    #@       if k not in exclusions:
    #@         labels[k] = v
    #@       end
    #@     end
    #@   end
    #@   labels.update(fixed_values)
    #@   return labels
    #@ end

    #@ def image():
    #@   return "/".join([
    #@    data.values.params.registry.server,
    #@    data.values.params.registry.repository,
    #@    "-".join([
    #@      data.values.workload.metadata.name,
    #@      data.values.workload.metadata.namespace,
    #@    ])
    #@   ])
    #@ end

    #@ bp_node_run_scripts = "set-tpb-config,portal:pack"
    #@ tpb_config = "/tmp/tpb-config.yaml"

    #@ for env in data.values.workload.spec.build.env:
    #@   if env.name == "TPB_CONFIG_STRING":
    #@     tpb_config_string = env.value
    #@   end
    #@   if env.name == "BP_NODE_RUN_SCRIPTS":
    #@     bp_node_run_scripts = env.value
    #@   end
    #@   if env.name == "TPB_CONFIG":
    #@     tpb_config = env.value
    #@   end
    #@ end

    apiVersion: kpack.io/v1alpha2
    kind: Image
    metadata:
      name: #@ data.values.workload.metadata.name
      labels: #@ merge_labels({ "app.kubernetes.io/component": "build" })
    spec:
      tag: #@ image()
      serviceAccountName: #@ data.values.params.serviceAccount
      builder:
        kind: ClusterBuilder
        name: #@ data.values.params.clusterBuilder
      source:
        blob:
          url: #@ data.values.source.url
        subPath: builder
      build:
        env:
        - name: BP_OCI_SOURCE
          value: #@ data.values.source.revision
        #@  if regexp.match("^([a-zA-Z0-9\/_-]+)(\@sha1:)?[0-9a-f]{40}$", data.values.source.revision):
        - name: BP_OCI_REVISION
          value: #@ data.values.source.revision
        #@ end
        - name: BP_NODE_RUN_SCRIPTS
          value: #@ bp_node_run_scripts
        - name: TPB_CONFIG
          value: #@ tpb_config
        - name: TPB_CONFIG_STRING
          value: #@ tpb_config_string

---
apiVersion: carto.run/v1alpha1
kind: ClusterSourceTemplate
metadata:
  name: tdp-source-template
spec:
  healthRule:
    singleConditionType: Ready
  lifecycle: mutable
  params:
  - default: default
    name: serviceAccount
  revisionPath: .status.artifact.revision
  urlPath: .status.artifact.url
  ytt: |
    #@ load("@ytt:data", "data")

    #@ def merge_labels(fixed_values):
    #@   labels = {}
    #@   if hasattr(data.values.workload.metadata, "labels"):
    #@     exclusions = ["kapp.k14s.io/app", "kapp.k14s.io/association"]
    #@     for k,v in dict(data.values.workload.metadata.labels).items():
    #@       if k not in exclusions:
    #@         labels[k] = v
    #@       end
    #@     end
    #@   end
    #@   labels.update(fixed_values)
    #@   return labels
    #@ end

    ---
    apiVersion: source.apps.tanzu.vmware.com/v1alpha1
    kind: ImageRepository
    metadata:
      name: #@ data.values.workload.metadata.name
      labels: #@ merge_labels({ "app.kubernetes.io/component": "source" })
    spec:
      serviceAccountName: #@ data.values.params.serviceAccount
      interval: 10m0s
      #@ if hasattr(data.values.workload.spec, "source") and hasattr(data.values.workload.spec.source, "image"):
      image: #@ data.values.workload.spec.source.image
      #@ else:
      image: #@ data.values.params.tdp_configurator_bundle
      #@ end

```

```sh
kubectl apply -f tdp-sc.yaml
```

* create `tdp-workload.yaml`

```yaml
apiVersion: carto.run/v1alpha1
kind: Workload
metadata:
  name: tdp-configurator-1-sc
  namespace: d1
  labels:
    apps.tanzu.vmware.com/workload-type: tdp
    app.kubernetes.io/part-of: tdp-configurator-1-custom
spec:
  build:
    env:
      - name: TPB_CONFIG_STRING
        value: YXBwOgogIHBsdWdpbnM6CiAgICAtIG5hbWU6ICJAdm13YXJlLXRhbnp1L3RkcC1wbHVnaW4tdGVjaGluc2lnaHRzIgogICAgICB2ZXJzaW9uOiAiMC4wLjIiCiAgICAtIG5hbWU6ICJAdnJhYmJpL3Rla3Rvbi13cmFwcGVyIgogICAgICB2ZXJzaW9uOiAiMC4xLjIiCgpiYWNrZW5kOgogIHBsdWdpbnM6CiAgICAtIG5hbWU6ICJAdm13YXJlLXRhbnp1L3RkcC1wbHVnaW4tdGVjaGluc2lnaHRzLWJhY2tlbmQiCiAgICAgIHZlcnNpb246ICIwLjAuMiIKCg== # ENCODED_TDP_CONFIG_VALUE
```

Alternative:

```yaml
---
apiVersion: carto.run/v1alpha1
kind: Workload
metadata:
  name: tdp-configurator
  namespace: d1
  labels:
    apps.tanzu.vmware.com/workload-type: web
    app.kubernetes.io/part-of: tdp-configurator
spec:
  build:
    env:
      - name: BP_NODE_RUN_SCRIPTS
        value: 'set-tdp-config,portal:pack'
      - name: TPB_CONFIG
        value: /tmp/tdp-config.yaml
      - name: TPB_CONFIG_STRING
        value: YXBwOgogIHBsdWdpbnM6CiAgICAtIG5hbWU6ICJAdm13YXJlLXRhbnp1L3RkcC1wbHVnaW4tdGVjaGluc2lnaHRzIgogICAgICB2ZXJzaW9uOiAiMC4wLjIiCiAgICAtIG5hbWU6ICJAdnJhYmJpL3Rla3Rvbi13cmFwcGVyIgogICAgICB2ZXJzaW9uOiAiMC4xLjIiCgpiYWNrZW5kOgogIHBsdWdpbnM6CiAgICAtIG5hbWU6ICJAdm13YXJlLXRhbnp1L3RkcC1wbHVnaW4tdGVjaGluc2lnaHRzLWJhY2tlbmQiCiAgICAgIHZlcnNpb246ICIwLjAuMiIKCg== # ENCODED_TDP_CONFIG_VALUE
  source:
    image: registry.tanzu.vmware.com/tanzu-application-platform/tap-packages@sha256:001d3879720c2dc131ec95db6c6a34ff3c2f912d9d8b7ffacb8da08a844b740f #TDP_IMAGE_LOCATION
    subPath: builder
```

### Run It

* https://docs.vmware.com/en/VMware-Tanzu-Application-Platform/1.7/tap/tap-gui-configurator-running.html

```sh
export TDP_CONFIGURATOR_IMAGE=harbor.tap.h2o-2-19271.h2o.vmware.com/tap-apps/tdp-configurator-1-sc-d1@sha256:6d612f6f55b338c97816035f3751e40acc255dc9fd46eec4bf8dea637806fc4e
```

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: tdp-app-image-overlay-secret
  namespace: tap-install
stringData:
  tdp-app-image-overlay.yaml: |
    #@ load("@ytt:overlay", "overlay")

    #! makes an assumption that tap-gui is deployed in the namespace: "tap-gui"
    #@overlay/match by=overlay.subset({"kind": "Deployment", "metadata": {"name": "server", "namespace": "tap-gui"}}), expects="1+"
    ---
    spec:
      template:
        spec:
          containers:
            #@overlay/match by=overlay.subset({"name": "backstage"}),expects="1+"
            #@overlay/match-child-defaults missing_ok=True
            - image: harbor.tap.h2o-2-19271.h2o.vmware.com/tap-apps/tdp-configurator-1-sc-d1@sha256:6d612f6f55b338c97816035f3751e40acc255dc9fd46eec4bf8dea637806fc4e #! TDP_CONFIGURATOR_IMAGE
            #@overlay/replace
              args:
              - -c
              - |
                export KUBERNETES_SERVICE_ACCOUNT_TOKEN="$(cat /var/run/secrets/kubernetes.io/serviceaccount/token)"
                exec /layers/tanzu-buildpacks_node-engine/node/bin/node portal/dist/packages/backend  \
                --config=portal/app-config.yaml \
                --config=portal/runtime-config.yaml \
                --config=/etc/app-config/app-config.yaml
```

```sh
kubectl apply -f tdp-overlay-secret.yaml
```

### Permissions for TAP GUI SA

* create `tdp-alt-crs-rbac.yaml`

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: tdp-viewer-alt-crs
rules:
  - apiGroups:
      - tekton.dev
    resources:
      - pipelineruns
      - taskruns
    verbs:
      - get
      - list
  - apiGroups:
      - argoproj.io
    resources:
      - applications
    verbs:
      - get
      - list
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: tdp-viewer-alt-crs-tap-gui-viewer
subjects:
- kind: ServiceAccount
  name: tap-gui-viewer
  namespace: tap-gui
roleRef:
  kind: ClusterRole
  name: tdp-viewer-alt-crs
  apiGroup: rbac.authorization.k8s.io
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: tdp-viewer-alt-crs-tap-gui
subjects:
- kind: ServiceAccount
  name: tap-gui
  namespace: tap-gui
roleRef:
  kind: ClusterRole
  name: tdp-viewer-alt-crs
  apiGroup: rbac.authorization.k8s.io
```

```sh
kubectl apply -f tdp-alt-crs-rbac.yaml
```

```yaml
- group: 'serving.knative.dev'
  apiVersion: 'v1'
  plural: 'revisions'
- group: 'serving.knative.dev'
  apiVersion: 'v1'
  plural: 'services'
- group: 'serving.knative.dev'
  apiVersion: 'v1'
  plural: 'routes'
- group: 'carto.run'
  apiVersion: 'v1alpha1'
  plural: 'clusterconfigtemplates'
- group: 'carto.run'
  apiVersion: 'v1alpha1'
  plural: 'clusterdeliveries'
- group: 'carto.run'
  apiVersion: 'v1alpha1'
  plural: 'clusterdeploymenttemplates'
- group: 'carto.run'
  apiVersion: 'v1alpha1'
  plural: 'clusterimagetemplates'
- group: 'carto.run'
  apiVersion: 'v1alpha1'
  plural: 'clustersourcetemplates'
- group: 'carto.run'
  apiVersion: 'v1alpha1'
  plural: 'clustersupplychains'
- group: 'carto.run'
  apiVersion: 'v1alpha1'
  plural: 'clustertemplates'
- group: 'carto.run'
  apiVersion: 'v1alpha1'
  plural: 'deliverables'
- group: 'carto.run'
  apiVersion: 'v1alpha1'
  plural: 'runnables'
- group: 'carto.run'
  apiVersion: 'v1alpha1'
  plural: 'runnables'
- group: 'source.toolkit.fluxcd.io'
  apiVersion: 'v1beta2'
  plural: 'gitrepositories'
- group: 'source.apps.tanzu.vmware.com'
  apiVersion: 'v1alpha1'
  plural: 'imagerepositories'
- group: 'source.apps.tanzu.vmware.com'
  apiVersion: 'v1alpha1'
  plural: 'mavenartifacts'
- group: 'conventions.carto.run'
  apiVersion: 'v1alpha1'
  plural: 'podintents'
- group: 'kpack.io'
  apiVersion: 'v1alpha2'
  plural: 'images'
- group: 'kpack.io'
  apiVersion: 'v1alpha2'
  plural: 'builds'
```
