
# Install Components for Monitoring

## Prepare

```bash
export DOMAIN=
```

```bash
export PROM_ADDR=mon.${DOMAIN}
export AM_ADDR=alertmanager.${DOMAIN}
export JKS_ADDR=jenkins.${DOMAIN}
```

```bash
kubectl create namespace obs
kubens obs
```

## Install Prometheus & Alertmanager

```bash
helm upgrade -i prometheus \
  stable/prometheus \
  --namespace obs \
  --version 7.1.3 \
  --set server.ingress.hosts={$PROM_ADDR} \
  --set alertmanager.ingress.hosts={$AM_ADDR} \
  -f prom-values.yaml
```

```bash
kubectl -n obs \
    rollout status \
    deploy prometheus-server
```

### prom-values

```yaml
server:
  ingress:
    enabled: true
    annotations:
      ingress.kubernetes.io/ssl-redirect: "false"
      nginx.ingress.kubernetes.io/ssl-redirect: "false"
  resources:
    limits:
      cpu: 100m
      memory: 1000Mi
    requests:
      cpu: 10m
      memory: 500Mi
alertmanager:
  ingress:
    enabled: true
    annotations:
      ingress.kubernetes.io/ssl-redirect: "false"
      nginx.ingress.kubernetes.io/ssl-redirect: "false"
  resources:
    limits:
      cpu: 10m
      memory: 20Mi
    requests:
      cpu: 5m
      memory: 10Mi
kubeStateMetrics:
  resources:
    limits:
      cpu: 10m
      memory: 50Mi
    requests:
      cpu: 5m
      memory: 25Mi
nodeExporter:
  resources:
    limits:
      cpu: 10m
      memory: 20Mi
    requests:
      cpu: 5m
      memory: 10Mi
pushgateway:
  resources:
    limits:
      cpu: 10m
      memory: 20Mi
    requests:
      cpu: 5m
      memory: 10Mi
serverFiles:
  alerts:
    groups:
    - name: nodes
      rules:
      - alert: JenkinsToManyJobsQueued
        expr: sum(jenkins_queue_size_value) > 5
        for: 3m
        labels:
          severity: notify
        annotations:
          summary: Jenkins to many jobs queued
          description: A Jenkins instance is failing a health check
alertmanagerFiles:
  alertmanager.yml:
    global: {}
    route:
      group_wait: 10s
      group_interval: 5m
      receiver: slack
      repeat_interval: 3h
      routes:
      - receiver: slack
        repeat_interval: 5d
        match:
          severity: notify
          frequency: low
    receivers:
    - name: slack
      slack_configs:
      - api_url: "XXXXXXXXXX"
        send_resolved: true
        title: "{{ .CommonAnnotations.summary }}"
        text: "{{ .CommonAnnotations.description }}"
        title_link: http://example.com
```

## Install Grafana

```bash
GRAFANA_ADDR="grafana.${DOMAIN}"
```

```bash
helm upgrade -i grafana stable/grafana \
    --version 3.5.5 \
    --namespace obs \
    --set ingress.hosts="{$GRAFANA_ADDR}" \
    --values grafana-values.yaml

# cannot use latest version, see:
# https://github.com/helm/charts/pull/15702
# https://github.com/helm/charts/issues/15725
```

```bash
kubectl -n obs rollout status deployment grafana
```

```bash
echo "http://$GRAFANA_ADDR"
```

```bash
open "http://$GRAFANA_ADDR"
```

```bash
kubectl -n obs \
    get secret grafana \
    -o jsonpath="{.data.admin-password}" \
    | base64 --decode; echo
```

```bash
open "https://grafana.com/dashboards"
```

### Grafana Config

```yaml
ingress:
  enabled: true
persistence:
  enabled: true
  accessModes:
  - ReadWriteOnce
  size: 1Gi
resources:
  limits:
    cpu: 20m
    memory: 50Mi
  requests:
    cpu: 5m
    memory: 25Mi
datasources:
 datasources.yaml:
   apiVersion: 1
   datasources:
   - name: Prometheus
     type: prometheus
     url: http://prometheus-server
     access: proxy
     isDefault: true
dashboardProviders:
  dashboardproviders.yaml:
    apiVersion: 1
    providers:
    - name: 'Default'
      orgId: 1
      folder: 'default'
      type: file
      disableDeletion: true
      editable: true
      options:
        path: /var/lib/grafana/dashboards/default
```

### Dashboards

```yaml
dashboards:
  jenkins:
    Jenkins-OLD:
      gnetId: 9964
      revision: 1
      datasource: Prometheus
  costs:
    Costs-Pod:
      gnetId: 6879
      revision: 1
      datasource: Prometheus
    Costs:
      gnetId: 8670
      revision: 1
      datasource: Prometheus
  cluster:
    Summary:
      gnetId: 8685
      revision: 1
      datasource: Prometheus
    Capacity:
      gnetId: 5228
      revision: 6
      datasource: Prometheus
    Deployments:
      gnetId: 8588
      revision: 1
      datasource: Prometheus
    Volumes:
      gnetId: 6739
      revision: 1
      datasource: Prometheus
```

* 9964 - Jenkins
* 6879 - cost analysis per pod
* 8670 - cost for whole cluster
* 8685 - cluster overview (resource capacity)
* 5228 - cluster overview (resource capacity)
* 8588 - cluster overview (deployments & statefulsets)
* 6739 - PV capacity

## Install Jenkins

```bash
kubectl create namespace jenkins
kubens jenkins
```

It is recommended to spread teams and applications across Jenkins instances, we will create more than one Jenkins instance. We will create these instances via Helm.

There's a quite well maintained Helm chart ready to use, but it needs some tweaks to be able to hit the ground running.

### Values

Let's explain some of the values:

* `installPlugins`: we want `blueocean` for a nicer Pipeline UI and `prometheus` to expose the metrics in a Prometheus format
* `resources`: always specify your resources, if these are wrong, our monitoring alerts and dashboard should help use tweak these values
* `javaOpts`: for some reason the default configuration doesn't have the recommended JVM and Garbage Collection configuration, so we have to specify this, see [CloudBees' JVM Troubleshoot Guide](https://go.cloudbees.com/docs/solutions/jvm-troubleshooting/) for more details
* `ingress`: because I believe every publicly available service should only be accessible via TLS, we have to configure TLS and certmanager annotions (as we're using Certmanager to manage our certificate)
* `podAnnotations`: the default metrics endpoint that Prometheus scrapes from is `/metrics`, unfortunately, the by default included Metrics Plugin exposes the metrics on that endpoint in the wrong format. This means we have to inform Prometheus how to retrieve the metrics

Make sure both `jenkins-values.X.yaml` and `jenkins-certificate.X.yaml` are created according to the template files below. Replace the X for each master, if you want three, you'll have `.1.yaml`, `.2.yaml` and `.3.yaml` for each of the files. Replace the `<ReplaceWithYourDNS>` with your DNS Host name and the `X` with the appropriate number.

For example, if your host name is `example.com`, you will have the following:

```yaml
    hostName: jenkins1.example.com
    tls:
      - secretName: tls-jenkins-1
        hosts:
          - jenkins1.example.com
```

#### jenkins-values.X.yaml

```yaml
master:
  serviceType: ClusterIP
  healthProbes: false
  installPlugins:
    - blueocean:1.17.0
    - prometheus:2.0.0
    - kubernetes:1.17.2
  resources:
    requests:
      cpu: "1000m"
      memory: "1524Mi"
    limits:
      cpu: "2000m"
      memory: "3072Mi"
  javaOpts: "-XX:+AlwaysPreTouch -XX:+UseG1GC -XX:+UseStringDeduplication -XX:+ParallelRefProcEnabled -XX:+DisableExplicitGC -XX:+UnlockDiagnosticVMOptions -XX:+UnlockExperimentalVMOptions"
  ingress:
    enabled: true
    hostName: jenkinsX.<ReplaceWithYourDNS>
    tls:
      - secretName: tls-jenkins-X
        hosts:
          - jenkinsX.<ReplaceWithYourDNS>
    annotations:
      certmanager.k8s.io/cluster-issuer: "letsencrypt-prod"
      kubernetes.io/ingress.class: nginx
      kubernetes.io/tls-acme: "false"
      nginx.ingress.kubernetes.io/proxy-body-size: 50m
      nginx.ingress.kubernetes.io/proxy-request-buffering: "off"
      nginx.ingress.kubernetes.io/ssl-redirect: "true"
  podAnnotations:
    prometheus.io/path: /prometheus
    prometheus.io/port: "8080"
    prometheus.io/scrape: "true"
agent:
  enabled: true
rbac:
  create: true
```

### jenkins-certificate.X.yaml

```yaml
apiVersion: certmanager.k8s.io/v1alpha1
kind: Certificate
metadata:
  name: jenkins1.<ReplaceWithYourDNS>
spec:
  secretName: tls-jenkins-X
  dnsNames:
  - jenkinsX.<ReplaceWithYourDNS>
  acme:
    config:
    - http01:
        ingressClass: nginx
      domains:
      - jenkinsX.<ReplaceWithYourDNS>
  issuerRef:
    name: letsencrypt-prod
    kind: ClusterIssuer%
```

### First Master

```bash
helm upgrade -i jenkins \
    stable/jenkins \
    --namespace jenkins\
    -f jenkins-values.1.yaml
```

### Apply Certificate

```bash
kubectl apply -f jenkins-certificate.1.yaml
```

#### Wait for rollout

```bash
kubectl -n jenkins rollout status deployment jenkins1
```

#### Retrieve Password

```bash
printf $(kubectl get secret --namespace jenkins jenkins1 -o jsonpath="{.data.jenkins-admin-password}" | base64 --decode);echo
```

### Second Master

```bash
helm upgrade -i jenkins2 \
    stable/jenkins \
    --namespace jenkins\
    -f jenkins-values.2.yaml
```

#### Wait for rollout

```bash
kubectl -n jenkins rollout status deployment jenkins2
```

#### Apply Certificate

```bash
kubectl apply -f jenkins-certificate.2.yaml
```

#### Retrieve Password

```bash
printf $(kubectl get secret --namespace jenkins jenkins2 -o jsonpath="{.data.jenkins-admin-password}" | base64 --decode);echo
```

### Third Master

```bash
helm upgrade -i jenkins3 \
    stable/jenkins \
    --namespace jenkins\
    -f jenkins-values.3.yaml
```

#### Wait for rollout

```bash
kubectl -n jenkins rollout status deployment jenkins3
```

#### Apply Certificate

```bash
kubectl apply -f jenkins-certificate.3.yaml
```

#### Retrieve Password

```bash
printf $(kubectl get secret --namespace jenkins jenkins3 -o jsonpath="{.data.jenkins-admin-password}" | base64 --decode);echo
```