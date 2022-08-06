title: Jenkins on Kubernetes
description: How to run Jenkins on Kubernetes in 2022

# Jenkins on Kubernetes

## Goal

Run Jenkins as best as we can on Kubernetes, taking as much advantage of the platform and ecosystem as we can.

## Steps to take

* install LDAP
* install and configure Apache Keycloak backed by LDAP
* install Hashicorp Vault
* install Jenkins
* configure Jenkins with Jenkins Configuration as Code
* verify we can use Kubernetes agents
* verify we can use GitHub integration
* expose Telemtry via OpenTelemetry
    * collect telemtry via Prometheus/Grafana
    * collect telemtry via Tanzu Observability

## LDAP

```sh
helm repo add helm-openldap https://jp-gouin.github.io/helm-openldap/
```

```sh
helm repo update
```

```sh
helm upgrade --install ldap helm-openldap/openldap --namespace keycloak --values ldap-values.yaml --version 2.0.4
```

## Keycloak

```sh
kubectl create namespace keycloak
```

```sh
kubectl apply -f keycloak-httpproxy.yaml
```

```sh
helm upgrade --install keycloak bitnami/keycloak --namespace keycloak --values keycloak-values.yaml --version 9.2.8
```

```sh
kubectl logs -f -n keycloak keycloak-0
```

### Keycloak HTTPProxy

```sh
export LB_IP=$(kubectl get svc -n tanzu-system-ingress envoy -o jsonpath="{.status.loadBalancer.ingress[0].ip}")
```

```sh
export KEYCLOAK_HOSTNAME=keycloak.${LB_IP}.nip.io
```

```sh
cfssl gencert -ca ca.pem -ca-key ca-key.pem \
  -config cfssl.json \
  -profile=server \
  -cn="${KEYCLOAK_HOSTNAME}" \
  -hostname="${KEYCLOAK_HOSTNAME},keycloak.keycloak.svc.cluster.local,keycloak,localhost" \
   base-service-cert.json   | cfssljson -bare keycloak-server
```

## Jenkins

```sh
helm repo add jenkins https://charts.jenkins.io
helm repo update
```

```sh
kubectl create namespace jenkins
```

```sh
DH_USER=
DH_EMAIL=
DH_PASS=
NS=jenkins
```

```sh
kubectl create secret docker-registry dockerhub-pull-secret \
  --docker-username=${DH_USER} \
  --docker-password=${DH_PASS} \
  --docker-email=${DH_EMAIL} \
  --namespace ${NS}
```

```sh
GH_USER=
GH_TOKEN=
NS=jenkins
```

```sh
kubectl create secret generic github-token \
  --from-literal=user="${GH_USER}" \
  --from-literal=token="${GH_TOKEN}" \
  --namespace ${NS}
```

```sh
JENKINS_ADMIN_USER=joostvdg
JENKINS_ADMIN_PASS=
```

```sh
kubectl create secret generic jenkins-admin \
  --from-literal=user="${JENKINS_ADMIN_USER}" \
  --from-literal=token="${JENKINS_ADMIN_PASS}" \
  --namespace ${NS}
```

### Install Jenkins Helm

```sh
helm repo add jenkins https://charts.jenkins.io
helm repo update
```

```sh
helm upgrade --install jenkins jenkins/jenkins --namespace jenkins --values jenkins-values.yaml
```

### Jenkins CasC

...

### Jenkins HTTPProxy

```sh
export LB_IP=$(kubectl get svc -n tanzu-system-ingress envoy -o jsonpath="{.status.loadBalancer.ingress[0].ip}")
```

```sh
export JENKINS_HOSTNAME=jenkins.${LB_IP}.nip.io
```

```sh
cfssl gencert -ca ca.pem -ca-key ca-key.pem \
  -config cfssl.json \
  -profile=server \
  -cn="${JENKINS_HOSTNAME}" \
  -hostname="${JENKINS_HOSTNAME},jenkins.jenkins.svc.cluster.local,jenkins,localhost" \
   base-service-cert.json   | cfssljson -bare jenkins-server
```

### Kaniko To Harbor

```sh
HARBOR_SERVER=harbor.10.220.7.70.nip.io
HARBOR_USER=
HARBOR_PASS=
```

```sh
kubectl create secret docker-registry harbor-registry-creds \
  --docker-username=${HARBOR_USER} \
  --docker-password=${HARBOR_PASS} \
  --docker-server=${HARBOR_SERVER} \
  --namespace jenkins
```

### Checks API

* create Jenkins credentials for GitHub API
* ensure you have create a GitHub Server in Jenkins config

```yaml
credentials:
  system:
    domainCredentials:
    - credentials:
      - string:
          description: "github token"
          id: "githubtoken"
          scope: GLOBAL
          secret: "{AQAAABAAAAAwDgut+8oOqmwh4qHohWO09AxFPsz78EXLrtoC4QEFr9nY8orwx/mcLaS11G831IDmO8Ftxs2QockuYPJveteneQ==}"
      - usernamePassword:
          description: "github-credentials"
          id: "github-credentials"
          password: "{AQAAABAAAAAwutoG/5mM+UqCYohxLLogZ7Dpd8lyfWh9MeAbNybMplhycx4Z17h1WgzQPQn0lHAM+mfHsufBMuRTwl79rnfk9g==}"
          scope: GLOBAL
          username: "joostvdg"
```

```yaml
  gitHubPluginConfig:
    configs:
    - credentialsId: "githubtoken"
      name: "GitHub"
    hookUrl: "https://jenkins.10.220.7.70.nip.io/github-webhook/"
```

## Pipeline

* create credentials
    * `githubtoken` of type secret text with the GitHub API Token
    * `github-credentials` username and password -> github username and API Token
* create GitHub Org Job
    * add plugin GitHub Branch Source?

## Webhooks behind a firewall

* https://www.jenkins.io/blog/2019/01/07/webhook-firewalls/
* https://developer.ibm.com/tutorials/deliver-your-webhooks-without-worrying-about-firewalls/


```sh
docker pull quay.io/schabrolles/smeeclient:stable --platform linux/amd64
docker tag quay.io/schabrolles/smeeclient:stable harbor.10.220.7.70.nip.io/test/smeeclient:stable
docker push harbor.10.220.7.70.nip.io/test/smeeclient:stable
```

* SMEESOURCE
* HTTPTARGET

```sh
kubectl run smee-client -n jenkins --rm -i --tty --image harbor.10.220.7.70.nip.io/test/harbor.10.220.7.70.nip.io/test/smeeclient:stable  \
     --env=SMEESOURCE=
```

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: smee-client
  namespace: jenkins
  labels:
    app: smee-client
spec:
  containers:
  - name: smee-client
    image: harbor.10.220.7.70.nip.io/test/smeeclient:stable
    env:
    - name: SMEESOURCE
      value: "https://smee.io/TVjVEDxMHHQeNPDl"
    - name: HTTPTARGET
      value: "http://jenkins:8080/github-webhook/"
```

## Thanos

```sh
kubectl create namespace thanos
```

```sh
helm upgrade --install thanos bitnami/thanos --namespace thanos --values thanos-values.yaml
```

## TO

* https://github.com/bdekany/wavefront-otel-auto-instrumentation
* https://artifacthub.io/packages/helm/bitnami/wavefront
* https://docs.wavefront.com/opentelemetry_tracing.html

```sh
kubectl create namespace wavefront
```

```sh
TO_API_TOKEN=
TO_NAMESPACE=
CLUSTER_NAME=
```

```sh
kubectl create secret generic to-api-token  --from-literal=api-token="${TO_API_TOKEN}" --namespace ${TO_NAMESPACE}
```

```yaml
projectPacific:
  enabled: true
vspheretanzu:
  enabled: true
wavefront:
  url: https://vmware.wavefront.com
  existingSecret: to-api-token
collector:
  useDaemonset: true
  apiServerMetrics: true
  cadvisor:
    enabled: true
  logLevel: info
  discovery:
    annotationExcludes: []
  tags:
    datacenter: vbc-h20-62
    project: vbc-h20
    owner: joostvdg
kubeStateMetrics:
  enabled: true
proxy:
  replicaCount: 2
  zipkinPort: 9411
  args: --traceZipkinListenerPorts 9411 --otlpGrpcListenerPorts 4317 --otlpHttpListenerPorts 4318
```

```sh
kubectl -n wavefront patch svc wavefront-proxy --patch '{"spec": {"ports": [{"name":"oltphttp", "port": 4318, "protocol": "TCP"}, {"name":"oltpgrpc", "port": 4317, "protocol": "TCP"}]}}'
```

* patch Proxy deployment
* patch Proxy service
* https://docs.wavefront.com/opentelemetry_tracing.html
* https://docs.wavefront.com/proxies_configuring.html#proxy-file-paths
* https://github.com/jenkinsci/opentelemetry-plugin
* https://github.com/bdekany/wavefront-otel-auto-instrumentation/blob/main/README.md
* https://github.com/bdekany/wavefront-otel-auto-instrumentation

## Vault

* https://learn.hashicorp.com/tutorials/vault/kubernetes-raft-deployment-guide?in=vault/kubernetes
* https://www.vaultproject.io/docs/platform/k8s/helm/configuration
* https://learn.hashicorp.com/tutorials/vault/kubernetes-raft-deployment-guide?in=vault/kubernetes#initialize-and-unseal-vault
* artifact hub: https://artifacthub.io/packages/helm/hashicorp/vault

### Vault Helm Install

```sh
helm repo add hashicorp https://helm.releases.hashicorp.com
helm repo update
```

```sh
kubectl create namespace vault
```

```sh
NS=vault
DH_USER=
DH_EMAIL=
DH_PASS=
```

```sh
kubectl create secret docker-registry dockerhub-pull-secret \
  --docker-username=${DH_USER} \
  --docker-password=${DH_PASS} \
  --docker-email=${DH_EMAIL} \
  --namespace ${NS}
```

```sh
KEYCLOAK_CLIENT_ID=
KEYCLOAK_CLIENT_SECRET=
KEYCLOAK_URL=
```

```sh
kubectl create secret generic oic-auth \
  --from-literal=clientID="${KEYCLOAK_CLIENT_ID}" \
  --from-literal=clientSecret="${KEYCLOAK_CLIENT_SECRET}" \
  --from-literal=keycloakUrl=${KEYCLOAK_URL} \
  --namespace jenkins
```

```sh
kubectl --namespace vault create secret tls tls-ca --cert ./tls-ca.cert --key ./tls-ca.key
```

```sh
helm upgrade --install vault hashicorp/vault --namespace vault --values vault-values.yaml
```

### HTTPProxy

```sh
export LB_IP=$(kubectl get svc -n tanzu-system-ingress envoy -o jsonpath="{.status.loadBalancer.ingress[0].ip}")
```

```sh
export VAULT_HOSTNAME=vault.${LB_IP}.nip.io
```

```sh
cfssl gencert -ca ca.pem -ca-key ca-key.pem \
  -config cfssl.json \
  -profile=server \
  -cn="${VAULT_HOSTNAME}" \
  -hostname="${VAULT_HOSTNAME},vault.vault.svc.cluster.local,vault-ui.vault.svc.cluster.local,vault,vault-ui,localhost" \
   base-service-cert.json   | cfssljson -bare vault-server
```

```sh
cat vault-server-key.pem | base64
```

```sh
cat vault-server.pem | base64
```

```sh
kubectl apply -f vault-httpproxy.yaml
```

```sh
kubectl get httpproxy -n vault
```

### Unsealing

```sh
kubectl get pods --selector='app.kubernetes.io/name=vault' --namespace=' vault'
```

```sh
kubectl exec --namespace vault --stdin=true --tty=true vault-0 -- vault operator init
```

## TODO

Things to improve on.

* make credentials come from Vault
* make credentials come from Kubernetes
* OpenTelemtry
    * Prometheus/Grafana/?
    * TO?
* Jobs via SeedJob from JobDSL?

## References