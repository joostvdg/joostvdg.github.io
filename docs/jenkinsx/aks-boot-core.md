# Jenkins X On AKS With JX Boot & CloudBees Core

The goal of the guide is the following:

> manage CloudBees Core on Modern via Jenkins X in its own environment/namespace.

To make it more interesting, we add more variables in the mix in the form of "requirements".

* cluster must NOT run on GKE, Jenkins X works pretty well there and doesn't teach us much
* every exposed service MUST use TLS, no excuses
* we do not want to create a certificate for every service that uses TLS
* as much as possible must be **Configuration-as-Code**

In conclusion:

* We use [Terraform](/kubernetes/distributions/aks-terraform.md) to manage the Kubernetes Cluster on **AKS**
* [JX Boot](https://jenkins-x.io/docs/reference/boot/) to manage Jenkins X
* We use Google CloudDNS to manage the DNS
    * this enables us to validate an entire subdomain via Let's Encrypt in one go

!!! note
    Unfortunately, these are already quite a lot of requirements. The Vault integration on anywhere but GKE is not stable.
    So we cheat and use `local` storage for credentials, meaning we need to use `jx boot` every time to upgrade the cluster.

    We will come back to this!

## Create AKS Cluster

Either create a cluster via [AKS Terraform](/kubernetes/distributions/aks-terraform.md) (recommended) or via [AKS CLI](/kubernetes/distributions/aks-cli.md).

## Install Jenkins X

### Boot Config

Make a fork of the [jenkins-x-boot-config](https://github.com/jenkins-x/jenkins-x-boot-config.git) repository and clone it.

```bash
GH_USER=
```

```bash
git clone https://github.com/${GH_USER}/jenkins-x-boot-config.git
cd jenkins-x-boot-config
```

Changes to make:

* provider from `gke` to `aks`
* set domain
* set clustername
* set external dns (see below)
* set repository value for each environments (not dev) as below

```yaml
- key: staging
  repository: environment-jx-aks-staging
```

### External DNS

Using Google CloudDNS:

* login to the GCP account you want to use
* enable CloudDNS API by going to it
* create a CloudDNS zone for your subdomain
    * if the main domain is `example.com` -> `aks.example.com`
    * once created, you get `NS` entries, copy these (usualy in the form `ns-cloud-X{1-4}.googledomains.com`
* in your Domain's DNS configuration, map your subdomain to these `NS` entries
* create a service account that can use CloudDNS API
* add the Google Project to which the Service Account belongs to: `jx-requirements.yaml` and `values.yaml`
* export the `json` configuration file
    * rename the file to `credentials.json`
* create secret a secret in Kubernetes
    * `kubectl create secret generic external-dns-gcp-sa --from-file=credentials.json`
* fix external dns values template -> `systems/external-dns/values.tmpl.yaml`
    * add `project: "{{ .Requirements.cluster.project }}"` to `external-dns`.`google`

!!! important
    You have to create the secret `external-dns-gcp-sa` in every namespace you set up TLS via the `dns01` challenge.

??? example "jx-requirements.yaml"
    We're omitting the default values as much as possible, such as the `dev` and `production` environments.

    ```yaml
    cluster:
    environmentGitOwner: <YOUR GITHUB ACCOUNT>
    gitKind: github
    gitName: github
    gitServer: https://github.com
    namespace: jx
    project: your-google-project
    provider: aks
    environments:
    - ingress:
        domain: staging.aks.example.com
        externalDNS: true
        namespaceSubDomain: ""
        tls:
        email: <YOUR EMAIL ADDRESS>
        enabled: true
        production: true
    key: staging
    repository: environment-jx-aks-staging
    gitops: true
    ingress:
    domain: aks.example.com
    externalDNS: true
    namespaceSubDomain: -jx.
    tls:
        email: <YOUR EMAIL ADDRESS>
        enabled: true
        production: true
    kaniko: true
    secretStorage: local
    ```

??? example "values.yaml"
    ```yaml
    cluster:
        projectID: your-google-project
    ```

### TLS Config

Update the `jx-requirements.yaml`, make sure `ingress` configuration is correct:

```yaml
ingress:
  domain: aks.example.com
  externalDNS: true
  namespaceSubDomain: -jx.
  tls:
    email: admin@example.com
    enabled: true
    production: true
```

If all is done correctly with the CloudDNS configuration, the external dns will contain all the entries of the `jx` services (such as hook, chartmuseum) and certmanager will be able to verify the domain with Let's Encrypt.

### Docker Registry Config

!!! example "values.yaml"

    ```yaml
    jenkins-x-platform:
        dockerRegistry: myacr.azurecr.io
    ```

    This was not enough, added it to the values template: `env/jenkins-x-platform/values.tmpl.yaml`

    ```yaml
    dockerRegistry: myacr.azurecr.io
    ```

### TLS For Application In Environment

* create issuer
* create certificate

!!! note
    This implies you need to run `jx boot` at least once before working on your environment configuration!

Easiest way I found, was to copy the yaml from the issuer and certificate in the `jx` namespace.
You then remove the unnecesary elements, those generated by Kubernetes itself (such as creation date, status, etc).

You have to change the domain name and hosts values, as they should now point to the subdomain corresponding to this environment (unless its production).
Once the files are good, you add them to your environment.
You do so, by adding them to the templates folder -> `env/templates`.

```bash hl_lines="10 11"
.
├── Jenkinsfile
├── LICENSE
├── Makefile
├── README.md
├── env
│   ├── Chart.yaml
│   ├── requirements.yaml
│   ├── templates
│   │   ├── certificate.yaml
│   │   └── issuer.yaml
│   └── values.yaml
└── jenkins-x.yml
```

```bash
kubectl -n jx get issuer letsencrypt-prod -o yaml
```

```bash
kubectl -n jx get certificate tls-<unique to your cluster>-p -o yaml
```

??? example "issuer.yaml"
    The end result should look like this:

    ```yaml
    apiVersion: certmanager.k8s.io/v1alpha1
    kind: Issuer
    metadata:
      name: letsencrypt-prod
    spec:
      acme:
        email: admin@example.com
        privateKeySecretRef:
          name: letsencrypt-prod
        server: https://acme-v02.api.letsencrypt.org/directory
        solvers:
        - dns01:
            clouddns:
              project: your-google-project
              serviceAccountSecretRef:
                key: credentials.json
                name: external-dns-gcp-sa
          selector:
            dnsNames:
            - '*.staging.aks.example.com'
            - staging.aks.example.com
    ```

??? example "certificate.yaml"

    ```yaml
    apiVersion: certmanager.k8s.io/v1alpha1
    kind: Certificate
    metadata:
        name: tls-staging-aks-example-com-p
    spec:
        commonName: '*.staging.aks.example.com'
        dnsNames:
        - '*.staging.aks.example.com'
        issuerRef:
            name: letsencrypt-prod
        secretName: tls-staging-aks-example-com-p
    ```

## Install CloudBees Core

In order to install CloudBees Core with TLS, we need the following:

* TLS configuration for the environment Core is landing in (see above on how)
* add CloudBees Core as a requirement to the `env/requirements.yaml`
* add configuration for CloudBees Core to the `env/values.yaml`

### requirements.yaml

```yaml hl_lines="10 11 12 13"
dependencies:
- name: exposecontroller
  version: 2.3.89
  repository: http://chartmuseum.jenkins-x.io
  alias: expose
- name: exposecontroller
  version: 2.3.89
  repository: http://chartmuseum.jenkins-x.io
  alias: cleanup
- name: cloudbees-core
  version: 2.176.203
  repository: https://charts.cloudbees.com/public/cloudbees
  alias: cbcore
```

### values.yaml

!!! important
    The value you've set for the `alias` in the requirements, is your entrypoint for the configuration in the `values.yaml`!

    Also, take care to change the following values to reflect your environment!
    * OperationsCenter.HostName
    * OperationsCenter.Ingress.tls.Host
    * OperationsCenter.Ingress.tls.SecretName

```yaml
cbcore:
  OperationsCenter:
    CSRF:
      ProxyCompatibility: true
    HostName: cbcore.staging.aks.example.com
    Ingress:
      Annotations:
        kubernetes.io/ingress.class: nginx
        kubernetes.io/tls-acme: "true"
        nginx.ingress.kubernetes.io/app-root: https://$best_http_host/cjoc/teams-check/
        nginx.ingress.kubernetes.io/proxy-body-size: 50m
        nginx.ingress.kubernetes.io/proxy-request-buffering: "off"
        nginx.ingress.kubernetes.io/ssl-redirect: "true"
      tls:
        Enable: true
        Host: cbcore.staging.aks.example.com
        SecretName: tls-staging-aks-example-com-p
    ServiceType: ClusterIP
  nginx-ingress:
    Enabled: false
```

## Resources

* https://cloud.google.com/iam/docs/creating-managing-service-account-keys#iam-service-account-keys-create-console
* https://medium.com/google-cloud/kubernetes-w-lets-encrypt-cloud-dns-c888b2ff8c0e
* https://support.google.com/domains/answer/3290309?hl=en-GB&ref_topic=9018335
* https://thorsten-hans.com/how-to-use-private-azure-container-registry-with-kubernetes
