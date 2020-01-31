title: CloudBees Core Modern Multi-Cluster
description: Manage Masters on multiple Kubernetes Cluster with CloudBees Core

# CloudBees Core On Multiple Clusters



* https://docs.cloudbees.com/docs/cloudbees-core/latest/cloud-admin-guide/multiple-clusters
* https://docs.microsoft.com/en-us/azure/aks/ingress-static-ip

## Pre-Requisites

* GKE Cluster: Primary
* AKS Cluster: Secondary

## Configure Primary Cluster

* create cluster
* retrieve account token
* retrieve Kubernetes API Endpoint
* retrieve Kubernetes Root CA
    * hint -> `echo " " | base64 -D`
* install CloudBees Core via Helm (or Jenkins X)

## Configure Secondary Cluster

* https://docs.microsoft.com/en-us/azure/aks/ingress-tls

### Install Ingress Controller

 Create a namespace for your ingress resources

Add the official stable repository

```bash
helm repo add stable https://kubernetes-charts.storage.googleapis.com/
```

 Use Helm to deploy an NGINX ingress controller

Create a values file, `ingress-values.yaml`.

The reason is stated as this:

> Since version 0.22.1 of stable/nginx-ingress chart, ClusterRole and ClusterRoleBinding are not created automatically when the controller scope is enabled. They are required for this functionality to work. To use the controller scope feature, see the article [Helm install of stable/nginx-ingress fails to deploy the Ingress Controller](https://support.cloudbees.com/hc/en-us/articles/360020511351-Helm-install-of-stable-nginx-ingress-fails-to-deploy-the-Ingress-Controller). 

```yaml
rbac:
  create: true
defaultBackend:
  enabled: false
controller:
  ingressClass: "nginx"
  metrics:
    enabled: "true"
  replicaCount: 2
  nodeSelector: 
    beta\.kubernetes.io/os: linux 
  scope:
    enabled: "true"
    namespace: cbmasters
  service:
    externalTrafficPolicy: "Cluster"
```

```bash
kubectl create namespace ingress-nginx
```

```bash tab="Helm V3"
helm install nginx-ingress stable/nginx-ingress \
    --namespace ingress-nginx \
    --values ingress-values.yaml \
    --version  1.29.6
```

```bash tab="Helm V2"
helm install \
    --name nginx-ingress stable/nginx-ingress \
    --namespace ingress-nginx \
    --values ingress-values.yaml  \
    --version  1.29.6
```


### Certmanager

Install the CustomResourceDefinition resources separately

```bash
kubectl apply --validate=false \
    -f https://raw.githubusercontent.com/jetstack/cert-manager/release-0.13/deploy/manifests/00-crds.yaml
```

Label the ingress-basic namespace to disable resource validation

```bash
kubectl label namespace ingress-basic certmanager.k8s.io/disable-validation=true
```

Add the Jetstack Helm repository

```bash
helm repo add jetstack https://charts.jetstack.io
```

Update your local Helm chart repository cache

```bash
helm repo update
```

Create a `certmanager-values.yaml` file.

```yaml
ingressShim:
    defaultIssuerName: letsencrypt
    defaultIssuerKind: ClusterIssuer
```

Install the cert-manager Helm chart.


```bash tab="Helm V3"
helm install cert-manager \
  --namespace cert-manager \
  --version v0.13.0 \
  --values certmanager-values.yaml \
  jetstack/cert-manager
```

```bash tab="Helm V2"
helm install \
  --name cert-manager \
  --namespace cert-manager \
  --version v0.13.0 \
  --values certmanager-values.yaml \
  jetstack/cert-manager
```

### Configure Certificate Issuer

```yaml
apiVersion: cert-manager.io/v1alpha2
kind: ClusterIssuer
metadata:
  name: letsencrypt
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: MY_EMAIL_ADDRESS
    privateKeySecretRef:
      name: letsencrypt
    solvers:
    - http01:
        ingress:
          class: nginx
```

```bash
kubectl apply -f cluster-issuer.yaml --namespace ingress-basic
```

### Configure Certificate

Todo

### Prepare Receiving Namespace

```bash
NAMESPACE=
```

```bash
kubectl create namespace $NAMESPACE
```

Create a configuration for CloudBees Core Helm chart, called `cloudbees-values.yaml`.

```yaml
OperationsCenter:
    Enabled: false
Master:
    Enabled: true
    OperationsCenterNamespace: jx-staging
Agents:
    Enabled: true
 ```


```bash
helm fetch \
 --repo https://charts.cloudbees.com/public/cloudbees \
 --version 3.8.0+a0d07461ae1c \
 cloudbees-core
```

```bash
helm template cloudbees-core-namespace \
 cloudbees-core-3.8.0+a0d07461ae1c.tgz \
 -f cloudbees-values.yaml \
 --namespace ${NAMESPACE} \
 > cloudbees-core-namespace.yml
```

```bash
kubectl apply -f cloudbees-core-namespace.yml --namespace ${NAMESPACE}
```

## Configure CloudBees Core

* Client Secret -> `secret text` -> the token from Terraforms output
* 

### Configre Siodecar Injector

```bash
helm fetch \
 --repo https://charts.cloudbees.com/public/cloudbees \
 --version 2.0.1 \
    cloudbees-sidecar-injector
```

Untar the config, and update the configmap -> `templates/configmap.yaml`.
Set `requiresExplicitInjection` to true.

```bash
    requiresExplicitInjection: true
```

Generate the end result:

```bash
helm template cloudbees-sidecar-injector \
 cloudbees-sidecar-injector \
 --namespace  cloudbees-sidecar-injector\
 > cloudbees-sidecar-injector.yml
```

And apply the file.

```bash
kubectl apply -f cloudbees-sidecar-injector.yml
```

### Debugging SSL Issue

Add System properties:
```bash
javax.net.ssl.trustStore=/etc/ssl/certs/java/cacerts
javax.net.ssl.trustStorePassword=changeit
javax.net.debug=SSL,trustmanager
```

Add annotation `com.cloudbees.sidecar-injector/inject: yes`, and change this in the master configuration.

```yaml
apiVersion: "apps/v1"
kind: "StatefulSet"
spec:
  template:
    metadata:
      annotations:
        prometheus.io/path: /${name}/prometheus
        prometheus.io/port: "8080"
        prometheus.io/scrape: "true"
        com.cloudbees.sidecar-injector/inject: yes
      labels:
        app.kubernetes.io/component: Managed-Master
        app.kubernetes.io/instance: ${name}
        app.kubernetes.io/managed-by: CloudBees-Core-Cloud-Operations-Center
        app.kubernetes.io/name: ${name}
```

```bash
trustStore is: /etc/ssl/certs/java/cacerts
trustStore type is: jks
trustStore provider is:
```

----- BEGIN CONNECTION DETAILS -----
H4sIAAAAAAAAAA3KQQ7CIBBA0bvMWqBMKLS9zTAi1lowMF0Z7y6bn7zkfyE3KgIbLC56Gx6sJhtn
5XBFFe0IYiA3zeviA8MN9vt4UZ0n+aGrvQefIp++GcO1Jd2F8l6yzkfSR6JWuy5JDL8qG/j9ATek
aGdwAAAA
----- END CONNECTION DETAILS -----

Problem is, Jenkins uses an outdated SSL library (openSSL) that doesn't support SNI (servername).
This cause Nginx Ingress Controller to return an invalid certificate: `  Issuer: CN=Kubernetes Ingress Controller Fake Certificate, O=Acme Co`.
As this is not a CA cert, it cannot be directly trusted.

### MiniCA Solution

The gist: 
* create custom CA with [minica](https://github.com/jsha/minica)
* generate wildcard certificate for primary domain
* set wildcard cert as `default ssl certificate`
        * `  - --default-ssl-certificate=default/cloudbees-core.kearos.net-tls`
* add custom CA to `cacerts` truststore and `ca-certificates.cert`
* update `ca-bundles` configmap solution with [sidecar injector](https://docs.cloudbees.com/docs/cloudbees-core/latest/cloud-admin-guide/kubernetes-self-signed-certificates)


```bash
minica --domains kearos.net
```

```bash
cat minica.pem >> ca-certificates.crt
keytool -import -noprompt -keystore cacerts -file minica.pem -storepass changeit -alias kearos-net;
```

```bash
kubectl create configmap --from-file=ca-certificates.crt,cacerts ca-bundles
```

```bas
kubectl create secret tls tls-fake-kearos-net --key ./kearos.net/key.pem --cert ./kearos.net/cert.pem --namespace default
```

`kubectl edit deployment nginx-ingress-controller`

```yaml
spec:
    containers:
    - args:
        - /nginx-ingress-controller
        - --configmap=$(POD_NAMESPACE)/nginx-configuration
        - --tcp-services-configmap=$(POD_NAMESPACE)/tcp-services
        - --udp-services-configmap=$(POD_NAMESPACE)/udp-services
        - --publish-service=$(POD_NAMESPACE)/ingress-nginx
        - --annotations-prefix=nginx.ingress.kubernetes.io
        - --default-ssl-certificate=default/tls-fake-kearos-net
```


```bash
kubectl create configmap --from-file=ca-certificates.crt,cacerts ca-bundles
```

Change `cjoc-0` ingress:

Add

```yaml
      - backend:
          serviceName: cjoc
          servicePort: 80
        path: /
```

Remove:

```yaml
metadata:
  annotations:
    nginx.ingress.kubernetes.io/app-root: https://$best_http_host/cjoc/teams-check/
```

### Fix Port 50000 issue

```yaml
# nginx-config-map.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: tcp-services
  namespace: kube-system
data:
  50000: "jx-staging/cjoc:50000"
```

```bash
kubectl apply -f nginx-config-map.yaml
```

```yaml
- containerPort: 50000
    name: jnlp
    protocol: TCP
```

And in its args, add `--tcp-services-configmap` and point to the tcp-services configmap you created.

```bash
args: 
    ...
   - --tcp-services-configmap=kube-system/tcp-services
```

```bash
kubectl edit -n kube-system deployment jxing-nginx-ingress-default-backend
```

* https://kubernetes.github.io/ingress-nginx/user-guide/exposing-tcp-udp-services/



```yaml
- name: jnlp
    port: 50000
    protocol: TCP
    targetPort: jnlp
```

```bash
kubectl edit -n kube-system svc jxing-nginx-ingress-controller
```



## Ticket for Core V2

In the 2.204 Operations Center image, the location of the truststore (`cacerts`) and the ca certificate bundle ( `ca-certificates.crt`) has changed. In general there isn't a direct issue, but we mention it in a lot of places. This should be checked, propably tested and communicated to docs.

### KBs

* https://support.cloudbees.com/hc/en-us/articles/360018267271
* https://support.cloudbees.com/hc/en-us/articles/360018094412-Deploy-Self-Signed-Certificates-in-Masters-and-Agents-Custom-Location-

### Core Docs

* https://docs.cloudbees.com/docs/cloudbees-core/latest/cloud-admin-guide/kubernetes-self-signed-certificates

### Sidecar Injector

* https://github.com/cloudbees/sidecar-injector/blob/master/charts/cloudbees-sidecar-injector/README.md#create-a-certificate-bundle
* https://github.com/cloudbees/sidecar-injector/blob/c965497a51bc68f6dc6df8e9aef2403819f7902f/charts/cloudbees-sidecar-injector/values.yaml