
# Install CloudBees Core On GKE

## Prerequisite

Have a GKE cluster in which you're `ClusterAdmin`.

Don't have one yet? [Read here how to create one!](/kubernetes/distributions/install-gke/)

## Prepare

```bash
kubectl create namespace cloudbees-core
```

```bash
helm repo add cloudbees https://charts.cloudbees.com/public/cloudbees
helm repo update
```

```bash
kubens cloudbees-core
```

!!! Info
    `kubense` is a subcommand of the [kubecontext](https://github.com/ahmetb/kubectx) tool.

## Install ClusterIssuer/Cert

This assumes you have [Cert-Manager](/certificates/lets-encrypt-k8s/) installed.

```bash
kubectl apply -f clusterissuer.yaml
kubectl apply -f certificate.yaml
```

### clusterissuer.yaml

Make sure to replace `<REPLACE_WITH_YOUR_EMAIL_ADDRESS>` with your own email address.

Let's Encrypt will use this to register the certificate and will notify you there when it expires.

```yaml
apiVersion: certmanager.k8s.io/v1alpha1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    email: <REPLACE_WITH_YOUR_EMAIL_ADDRESS>
    server: https://acme-v02.api.letsencrypt.org/directory
    privateKeySecretRef:
      name: letsencrypt-prod
    http01: {}
```

### certificate.yaml

```yaml
apiVersion: certmanager.k8s.io/v1alpha1
kind: Certificate
metadata:
  name: <MyHostName>
  namespace: cloudbees-core
spec:
  secretName: tls-cloudbees-core-kearos-net
  dnsNames:
  - cloudbees-core.kearos.net
  acme:
    config:
    - http01:
        ingressClass: nginx
      domains:
      - cloudbees-core.kearos.net
  issuerRef:
    name: letsencrypt-prod
    kind: ClusterIssuer
```

## Install with values.yaml

```bash
helm install --name cloudbees-core \
    -f cloudbees-core-values.yaml \
    --namespace=cloudbees-core \
    cloudbees/cloudbees-core
```

```bash
kubectl rollout status statefulset cjoc
```

```bash
kubectl get po cjoc-0
```

```bash
kubectl logs -f cjoc-0
```

```bash
stern cjoc
```

### Get Initial Password

```bash
kubectl -n cloudbees-core exec cjoc-0 cat /var/jenkins_home/secrets/initialAdminPassword
```

### values.yaml

```yaml
# A helm example values file for standard kubernetes install.
# An nginx-ingress controller is not installed and ssl isn't installed.
# Install an nginx-ingress controller
nginx-ingress:
  Enabled: false

OperationsCenter:
  # Set the HostName for the Operation Center
  HostName: 'cloudbees-core.kearos.net'
  # Setting ServiceType to ClusterIP creates ingress
  ServiceType: ClusterIP
  CSRF:
    ProxyCompatibility: true
  Ingress:
    Annotations:
      certmanager.k8s.io/cluster-issuer: "letsencrypt-prod"
      kubernetes.io/ingress.class: nginx
      kubernetes.io/tls-acme: "false"
      nginx.ingress.kubernetes.io/app-root: https://$best_http_host/cjoc/teams-check/
      nginx.ingress.kubernetes.io/proxy-body-size: 50m
      nginx.ingress.kubernetes.io/proxy-request-buffering: "off"
      nginx.ingress.kubernetes.io/ssl-redirect: "true"
    tls:
    ## Set this to true in order to enable TLS on the ingress record
      Enable: true
      # Create a certificate kubernetes and use it here.
      SecretName: tls-cloudbees-core-kearos-net
      Host: cloudbees-core.kearos.net
```

## Core Post Install

## Setup API Token

Go to `http://<MyHostName>/cjoc`, login with your admin user.

Click on the user's name (top right corner) -> `Configure` -> `Generate Token`.

!!! Warning
    You will see this token only once, so copy it and store it somewhere.

### Get CLI

```bash
export CJOC_URL=https://<MyHostName>/cjoc/
http --download ${CJOC_URL}/jnlpJars/jenkins-cli.jar --verify false
```

### Alias CLI

```bash
USR=admin
TKN=
```

```bash
alias cboc="java -jar jenkins-cli.jar -noKeyAuth -auth ${USR}:${TKN} -s ${CJOC_URL}"
```

```bash
cboc version
```

### For More CLI

Go to `http://<MyHostName>/cjoc/cli`