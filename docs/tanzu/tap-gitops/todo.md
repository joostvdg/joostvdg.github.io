# TODO

* Next steps
    * Applications with ArgoCD
    * Supply Chain creation
    * Supply Chain optimization
    * Customize TAP GUI
    * Configure Auth for TAP
* write about Supply Chain extensions
    * Tekton Pipelines with Tasks
    * Tekton Tasks + Workspace + overwriting the OOTB Supply Chain
    * Change folder structure for GitOps repository
    * Test Containers + DinD
    * use Docker in Docker alternative from ITQ guy
* TAP in EKS
    * Use KMS
    * Use Workload Identity
    * Use RDS for Hello World App


## Notes - TAP GitOps 1.7

* https://docs.vmware.com/en/VMware-Tanzu-Application-Platform/1.7/tap/install-gitops-sops.html

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