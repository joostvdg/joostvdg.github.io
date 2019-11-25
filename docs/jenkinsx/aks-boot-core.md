title: Jenkins X: CloudBees Core + Jenkins X on AKS
description: Installing CloudBees Core With Jenkins X on AKS

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

## Install Jenkins X

First, install [Jenkins X with jx boot on AKS](/jenkinsx/jxboot-aks/).

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
* https://cloud.google.com/dns/docs/migrating
