title: CloudBees CI - Configuration As Code
description: Use Configuration as Code to automate the configuration of CloudBees CI
Hero: Automate CBCI (Modern) with CasC

# Configuration As Code

What we will do is leverage CloudBees CI's(CBCI) Configuration as Code (CasC) to automate as much of the CBCI installation as possible.

## Solution

### Prerequisites

* A running Kubernetes cluster
* [Helm](https://helm.sh/)
* [Helmfile](https://github.com/roboll/helmfile)
* [Kubectl](https://kubernetes.io/docs/tasks/tools/) with access to the Kubernetes cluster

### Steps to take

* Bootstrap the Kubernetes cluster
* Setup Helm configuration (we'll use Helmfile)
* Setup Configuration as Code for the Operations Center
* Setup Configuration as Code for Controllers

### Tools Included

* [nginx-ingress](https://kubernetes.github.io/ingress-nginx/deploy/): our Ingress Controller for accessing web applications in the cluster
* [external-dns](https://github.com/kubernetes-sigs/external-dns): manages the DNS entries in our Google CloudDNS Zone, so each Ingress resource gets its own unique DNS entry, this also enables us to generate specfic certificates via cert-manager
* [cert-manager](https://cert-manager.io/): manages certificate requests, so all our web applications can use TLS
* [openldap](https://www.openldap.org/): an LDAP server, for having an actual representative authentication realm for CBCI
  * We use [Geek-Cookbook](https://geek-cookbook.funkypenguin.co.nz/recipes/openldap/)'s version.
* [prometheus](https://prometheus.io/docs/introduction/overview/): we use Prometheus to collect metrics from the resources in the cluster
* [grafana](https://grafana.com/grafana/): we use Grafana to turn the metrics from Prometheus into viewable dashboards
  * the dashboard that is installed comes from [here](https://joostvdg.github.io/blogs/monitor-jenkins-on-k8s/dashboard/)

## Bootstrap Kubernetes Cluster

### Create Namespaces

We need a namespace for nginx-ingress, cert-manager, and CloudBees CI.

```sh
kubectl create namespace cbci
kubectl create namespace cert-manager
kubectl create namespace nginx-ingress
```

### Configure cert-manager namespace

Cert Manager will perform some validations on Ingress resources.
It cannot do that on _its own_ Ingress resource, so we label the `cert-manager` namespace so Cert Manager ignores itself.

```sh
kubectl label namespace cert-manager certmanager.k8s.io/disable-validation=true
```

### External DNS Config

In my case, I am using the [External DNS Controller](https://github.com/kubernetes-sigs/external-dns) with Google Cloud and a Cloud DNS Zone.

For this I have created a GCP Service Account with a credentials file (the JSON file).
If you want both `cert-manager` and `nginx-ingress` to directly use the Cloud DNS configuration to bypass the more lenghty alternatives (such as http verification) you need to supply them with the GCP Service Account.

[Read here](https://github.com/kubernetes-sigs/external-dns/blob/master/docs/tutorials/nginx-ingress.md) for more on using the External DNS Controller with GCP.

For other options, please refer to the [External DNS Controller docs](https://github.com/kubernetes-sigs/external-dns#deploying-to-a-cluster), which has guides for all the supported environments.

=== "Cert Manager"

    ```sh
    kubectl -n cert-manager create secret generic external-dns-gcp-sa --from-file=credentials.json
    ```

=== "Nginx Ingress Controller"

    ```sh
    kubectl -n nginx-ingress create secret generic external-dns-gcp-sa --from-file=credentials.json 
    ```

### Configure CBCI namespace

We need to configure the LDAP password secret, so our CasC for OC bundle can configure LDAP while JCasC translates the placeholder to the actual password.

This should be the same value as the `ldapGlobalPassword` in the `helmfile-values.yaml`.

```sh
kubectl create secret generic ldap-manager-pass --from-literal=pass=${LDAP_GLOBAL_PASSWORD} --namespace cbci
```

## Helm Configuration

### Helmfile Layout

The files that matter to Helmfile are the following.

```sh title="helmfile directory structure"
.
├── helmfile-values.yaml
├── helmfile.yaml
└── values
    └── *.yaml.gotmpl
```

### Helmfile.yaml

The `helmfile.yaml` file has several sections.

Let's look at each section separately, before I share the whole file.

We start with the environments. 
In this case, I have just one environments, `default`, but you can choose to have more, opting to have seperate value files for Staging and Production for example.

```yaml title="helmfile.yaml (enviroments)"
environments:
  default: # (1)
    values:
    - helmfile-values.yaml 
```

1.  the default environment is chosen if you do not choose an environment

As Helmfile will interact with Helm for us, we can properly manage our Helm repositories.
If we give Helmfile a list of Helm repositories, it will make to update them prior to any installation, so you don't have to worry about that.

```yaml title="helmfile.yaml (repositories)"
repositories:
- name: stable
  url: https://charts.helm.sh/stable
- name: cloudbees
  url: https://charts.cloudbees.com/public/cloudbees
- name: jetstack
  url: https://charts.jetstack.io
- name: bitnami
  url: https://charts.bitnami.com/bitnami
- name: geek-cookbook
  url: https://geek-cookbook.github.io/charts/
- name: grafana
  url: https://grafana.github.io/helm-charts
- name: prometheus-community
  url: https://prometheus-community.github.io/helm-charts
```

Another thing we cannot steer if Helmfile does the interaction with Helm for us, are Helms flags.
Some of these flags might be important for you, I've chosen to set these.

```yaml title="helmfile.yaml (defaults)"
helmDefaults:
  wait: true # (1)
  timeout: 600 # (2)
  historyMax: 25 # (3)
  createNamespace: true # (4)
```

1.  We will wait on the resources becoming ready before creating the next. This ensures our dependencies are honored.
2.  I personally always set an explicit timeout, so it is easy to spot if we hit a timeout. The timeout refers to how long we wait for the resources to be ready.
3.  How many update versions Hel tracks. I like to be able to rollback and have a bit of history.
4.  Some namespaces we created in the bootstrap, the rest should get created when required. This setting will make sure that any Helm installation in a new namespace, will have it created.

Next up are the releases. These are the Helm chart releases.
For the latest versions and the configurable properties, I recommend using [ArtifactHub.io](https://artifacthub.io/).

Releases need a name, chart, version, and values.
The chart, is a combination of the source repository (how you named it) and the chart name _in_ that repository.
In our case, this would be `cloudbees`, because I called the CloudBees Helm repository that, and then `/cloudbees-core`.
While the product has been renamed, the Helm chart has kept the CloudBees Core name.

Another thing you can see, is the `needs` list.
This tells Helmfile to install those releases (by name) before installing this one.

```yaml title="helmfile.yaml (releases)"
releases:
- name: cbci
  namespace: cbci
  chart: cloudbees/cloudbees-core # (1)
  version: '3.37.2+7390bf58e3ab' 
  values:
  - values/cbci.yaml.gotmpl  # (2)
  needs: # (3)
  - nginx-ingress
  - external-dns
  - cert-manager
  - ldap

- name: cm-cluster-issuer
  namespace: cert-manager
  chart: incubator/raw # (4)
  values:
  - values/cluster-issuer.yaml.gotmpl
  needs:
  - cbci
  - cert-manager
```

1.  The name of a Chart, `<Repository Name>/<Chart Name>`
2.  The values to use for this Helm installation. In this case we're specifying a [Go template](https://blog.gopheracademy.com/advent-2017/using-go-templates/), signified by the `yaml.gotmpl` extension.
3.  Informs Helmfile there is a dependency relationship between this Release and others, making sure it install them in the proper order.
4.  `incubator/raw` lets you include templated files directly, without having a Helm release

Helmfile supports various ways of supplying the Helm values.
In this example I'm using a [Go template](https://blog.gopheracademy.com/advent-2017/using-go-templates/) which lets us template the Helm chart installations.
By using a template values file, we can re-use values accross Helm charts to ensure that if two or more Charts reference the same value, we can guarantee it is the same.

The second release, `cm-cluster-issuer` is a file that is in the same repository as the Helmfile configuration.
This is why the chart is listed as `incubator/raw`, it lets you include templated Kubernetes manifests directly, without creating a Helm release.

??? example "Full Helmfile"

    ```yaml title="helmfile.yaml" linenums="1"
    environments:
      default:
        values:
        - helmfile-values.yaml

    repositories:
    - name: stable
      url: https://charts.helm.sh/stable
    - name: cloudbees
      url: https://charts.cloudbees.com/public/cloudbees
    - name: jetstack
      url: https://charts.jetstack.io
    - name: bitnami
      url: https://charts.bitnami.com/bitnami
    - name: geek-cookbook
      url: https://geek-cookbook.github.io/charts/
    - name: grafana
      url: https://grafana.github.io/helm-charts  
    - name: prometheus-community
      url: https://prometheus-community.github.io/helm-charts

    helmDefaults:
      wait: true
      timeout: 600
      historyMax: 25
      createNamespace: true  

    releases:
    - name: cbci
      namespace: cbci
      chart: cloudbees/cloudbees-core 
      version: 3.37.2+7390bf58e3ab 
      values:
      - values/cbci.yaml.gotmpl
      needs:
      - nginx-ingress
      - external-dns
      - cert-manager
      - ldap

    - name: nginx-ingress
      namespace: nginx-ingress
      chart: bitnami/nginx-ingress-controller
      version: 7.6.21
      values:
      - values/nginx-ingress.yaml.gotmpl

    - name: external-dns
      namespace: nginx-ingress
      chart: bitnami/external-dns
      version: 5.4.8
      values:
      - values/external-dns.yaml.gotmpl

    - name: cert-manager
      namespace: cert-manager
      chart: jetstack/cert-manager
      version: 1.5.3
      values:
      - values/cert-manager.yaml.gotmpl
      needs:
      - nginx-ingress

    - name: cm-cluster-issuer
      namespace: cert-manager
      chart: incubator/raw
      values:
      - values/cluster-issuer.yaml.gotmpl
      needs:
      - cbci
      - cert-manager

    - name: ldap
      namespace: cbci
      chart: geek-cookbook/openldap
      version: 1.2.4
      values:
      - values/ldap.yaml.gotmpl

    - name: prometheus
      namespace: mon
      chart: prometheus-community/prometheus
      version: 14.8.1
      values:
      - values/prom.yaml.gotmpl

    - name: grafana
      namespace: mon
      chart: grafana/grafana
      version: 6.16.11
      values:
      - values/grafana.yaml.gotmpl
      needs:
      - prometheus
    ```

### Helmfile-values.yaml

As stated in the previous section, I have opted for using templated Helm values files.
This lets me add placeholder values, which I can replace with values via Helmfile.

In the `environments` section, I referenced the file `helmfile-values.yaml` for the default, and only, environment.
So let's take a look at this file.

There are mostly passwords in there, for Grafana and LDAP.
There are also two values related to the External DNS Controller configuration,  `googleProject` and `googleASSecret`.

Feel free to remove these, if you're not using GCP or you're not using the External DNS Controller.

```yaml title="helmfile-values.yaml"
adminEmail: # (1)
googleProject: # (2)
googleASSecret: external-dns-gcp-sa # (3)
ldapGlobalPassword: 
ldapUser1Password: 
ldapUser2Password: 
ldapUser3Password: 
grafanaUser: 
grafanaPass: 
```

1.  the admin email address used for the Cluster Issuer, and will receive notifications from Cert Manager for certificate expirations
2.  the Google Project _id_ where the Cloud DNS Zone resides
3.  the name of the Kubernetes secret containing the GCP Service Account JSON file

### Values Files

I won't list each of them here, they are all available in my [CloudBees CI CasC](https://github.com/joostvdg/cloudbees-ci-casc/) repo on GitHub.


The Cluster Issuer is an optional resource.
I personally always prefer having an automated DNS setup and HTTPS with matching Certificates (e.g., no wildcard certificates).

!!!	tip "Optional"
    Only use this if you are using GCP, the External DNS Controller, and Cert Manager.

```yaml title="values/cluster-issuer.yaml.gotmpl"
resources:
  - apiVersion: cert-manager.io/v1
    kind: ClusterIssuer
    metadata:
      name: letsencrypt-prod
    spec:
      acme:
        email: {{ .Values.adminEmail }}
        server: https://acme-v02.api.letsencrypt.org/directory
        privateKeySecretRef:
          name: letsencrypt-prod
        solvers: # (1)
        - selector: {} 
          dns01:
            cloudDNS:
              project: {{ .Values.googleProject }}
              serviceAccountSecretRef:
                name: {{ .Values.googleASSecret }}
                key: credentials.json
```

1.  An empty 'selector' means that this solver matches all domains

The most important one of couse, is the Helm values for the CloudBees CI installation.
It already contains some secret sauce that will help us with synchronizing the CasC for OC Bundle.

```yaml title="values/cbci.yaml.gotmpl" linenums="1"
OperationsCenter:
  HostName: {{ .Values.cbciHostname }}
  CSRF:
    ProxyCompatibility: true
  Annotations: # (1)
    prometheus.io/path: "/prometheus"
    prometheus.io/port: "8080"
    prometheus.io/scrape: "true"
  Ingress:
    Annotations:
      cert-manager.io/cluster-issuer: letsencrypt-prod # (2)
      kubernetes.io/tls-acme: 'true'
      kubernetes.io/ingress.class: nginx
    tls:
      Enable: true
      Host: {{ .Values.cbciHostname }}
      SecretName: my-cbci-tls-secret
  JavaOpts: # (3)
    -Djenkins.install.runSetupWizard=false
    -Dcore.casc.config.bundle=/var/jenkins_config/oc-casc-bundle-from-git/cloudbees-ci-casc/casc-for-oc/bundle
  ContainerEnv: # (4)
    - name: LDAP_MANAGER_PASSWORD
      valueFrom:
        secretKeyRef:
          name: ldap-manager-pass
          key: pass
  ExtraContainers: # (5)
  - name: git-sync
    image: gcr.io/k8s-staging-git-sync/git-sync@sha256:866599ca98bcde1404b56152d8601888a5d3dae7fc21665155577d607652aa09
    args:
      - --repo=https://github.com/joostvdg/cloudbees-ci-casc
      - --branch=main
      - --depth=1
      - --wait=20
      - --root=/git
    volumeMounts:
      - name: content-from-git
        mountPath: /git

  ExtraVolumes: # (6)
  - name: content-from-git
    emptyDir: {}
  - name: casc-oc-volume
    configMap:
      name: casc-oc
  ExtraVolumeMounts: # (7)
  - name: casc-oc-volume
    mountPath: /var/jenkins_config/oc-casc-bundle
    readOnly: true
  - name: content-from-git
    mountPath: /var/jenkins_config/oc-casc-bundle-from-git
    readOnly: true

Agents: # (8)
  Enabled: true
  SeparateNamespace:
    Enabled: true
    Name: ci-agents
    Create: true

Hibernation: # (9)
  Enabled: true
```

1.  OC Pod Annotations for Prometheus, so our Prometheus installation can scrape the Metrics from the OC
2.  Annotations for the Ingress resource, so we get a valid certificate from Cert Manager via our referenced Certificate Issuer
3.  Disable the Installation Wizard, and tell the OC where it can find its CasC Bundle
4.  Map the LDAP password secret as an environment variable, so JCasC can interpolate it
5.  Define a sidecar container with the [Git Sync](https://github.com/kubernetes/git-sync)
6.  Define additional Pod volumes
7.  Define additional OC Container Volume Mounts
8.  Let CloudBees CI run Kubernetes agent in a separate namespace
9.  Enable the CloudBees CI [Hibernation feature](https://docs.cloudbees.com/docs/cloudbees-ci/latest/cloud-admin-guide/managing-masters#_hibernation_in_managed_masters)

Some of the things we're doing in this Helm file configuration:

* OC Pod Annotations for Prometheus, so our Prometheus installation can scrape the Metrics from the OC
* Annotations for the Ingress resource, so we get a valid certificate from Cert Manager via our referenced Certificate Issuer
* Tell the OC where it can find its CasC Bundle
* Define a sidecar container with the [Git Sync](https://github.com/kubernetes/git-sync) with additional volume mounts (more at [git-sync-for-casc-oc-bundle](/cloudbees/cbci-casc/#git-sync-for-casc-oc-bundle)) 
* Let CloudBees CI run Kubernetes agent in a separate namespace
* Enable the CloudBees CI [Hibernation feature](https://docs.cloudbees.com/docs/cloudbees-ci/latest/cloud-admin-guide/managing-masters#_hibernation_in_managed_masters)

### Install Via Helmfile

```sh
helmfile apply
```

## CasC for OC

### Git Sync For CasC OC Bundle

>  https://github.com/kubernetes/git-sync/blob/master/docs/kubernetes.md
> This container pulls git data and publishes it into volume
> "content-from-git".  In that volume you will find a symlink
> "current" (see -dest below) which points to a checked-out copy of
> the master branch (see -branch) of the repo (see -repo).
> NOTE: git-sync already runs as non-root.
> gcr.io/k8s-staging-git-sync/git-sync:v3.3.4__linux_amd64
> gcr.io/k8s-staging-git-sync/git-sync@sha256:866599ca98bcde1404b56152d8601888a5d3dae7fc21665155577d607652aa09

## CasC for Controllers

### Steps to Synchronize Bundles

* install a git client on Operations Center
  * for example: `github-branch-source`
* create a Freestyle job
  * check out from your repository with the casc Bundles
  * use the `Synchronize bundles from workspace with internal storage` build step
* create a Controller and select an available Bundle

### Update Bundle Configuration

If you're not sure what you'd want to configure in the bundle, or which plugins you really need.

You can first create a Managed Master how you want it to be. Then export its CasC configuration by the built-in   `casc-exporter`.

You do this, by going to the following URL `<masterUrl>/core-casc-export`.

### Freestyle Job

URL to checkout: `https://github.com/joostvdg/cloudbees-ci-casc.git`
Use the `Synchronize bundles from workspace with internal storage` build step.

Note: this only works if the Bundles are at the top level

![CasC Sync Step](../images/casc-sync-step-example.png)

??? Example "CasC Sync Job as CasC Item"

    ```yaml title="casc-sync-job-item.yaml" linenums="1"
    - kind: freeStyle
      displayName: casc-sync-new
      name: casc-sync-new
      disabled: false
      description: 'My CasC Bundle Synchronization job'
      concurrentBuild: false
      builders:
      - casCBundlesSyncBuildStep: {}
      blockBuildWhenUpstreamBuilding: false
      blockBuildWhenDownstreamBuilding: false
      scm:
        gitSCM:
          userRemoteConfigs:
          - userRemoteConfig:
              url: https://github.com/joostvdg/cloudbees-ci-casc.git
          branches:
          - branchSpec:
              name: '*/main'
      scmCheckoutStrategy:
        standard: {}
    ```
