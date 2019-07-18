# Monitor Jenkins on Kubernetes

## Helm

### Prepare

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

### Install Prometheus & Alertmanager

```bash
helm upgrade -i prometheus \
  stable/prometheus \
  --namespace obs \
  --version 7.1.3 \
  --set server.ingress.hosts=${PROM_ADDR} \
  --set alertmanager.ingress.hosts=${AM_ADDR} \
  -f prom-values.yaml
```

```bash
kubectl -n obs \
    rollout status \
    deploy prometheus-server
```

#### prom-values

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

### Install Grafana

```bash
GRAFANA_ADDR="grafana.${DOMAIN}"
```

```bash
helm install stable/grafana \
    --name grafana \
    --namespace obs \
    --version 3.5.12 \
    --set ingress.hosts="{$GRAFANA_ADDR}" \
    --values grafana-values.yaml
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

#### Dashboards

```yaml
dashboards:
    prometheus-stats:
      # Ref: https://grafana.com/dashboards/2
      gnetId: 2
      revision: 2
      datasource: Prometheus
```

##### Jenkins

* 306
* 9524
* 9964

#### General

* 6879 - cost analysis per pod
* 8670 - cost for whole cluster
* 8685 - cluster overview (resource capacity)
* 5228 - cluster overview (resource capacity)
* 8588 - cluster overview (deployments & statefulsets)
* 6739 - PV capacity


### Install Jenkins

```bash
helm upgrade -i jenkins \
    stable/jenkins \
    --namespace obs\
    -f jenkins-values.yaml
```

```bash
printf $(kubectl get secret --namespace obs jenkins -o jsonpath="{.data.jenkins-admin-password}" | base64 --decode);echo
```

## Prometheus config

### JVM

```bash
vm_cpu_load
```

```bash
vm_uptime_milliseconds
```

```bash
vm_memory_total_used
```

```bash
(vm_memory_total_max - vm_memory_total_used) / vm_memory_total_max * 100.0
```

### Plugins

```bash
sum(jenkins_plugins_active) by (app_kubernetes_io_instance)
```

### Job duration

```bash
default_jenkins_builds_last_build_duration_milliseconds
```

### Job Count

```bash
jenkins_job_count_value
```

### Jobs in Queue

```bash
jenkins_job_queuing_duration
```

```bash
sum(jenkins_queue_size_value) by (app_kubernetes_io_instance)
```

### Healthcheck Duration

```bash
sum(rate(jenkins_health_check_duration[5m])) 
    by (app_kubernetes_io_instance)
```

### CPU Usage

```bash
sum(rate(
  container_cpu_usage_seconds_total{
    container_name="jenkins"
  }[5m]
)) 
by (pod_name)
```

### Oversubcription of Pod memory

```bash
sum(rate(
  container_memory_usage_bytes{
    container_name="jenkins"
  }[5m]
)) 
by (pod_name) / 
```

```bash
sum(label_join(
  container_memory_usage_bytes{
    container_name="jenkins"
  }, 
  "pod", 
  ",", 
  "pod_name"
)) 
by (pod) / 
sum(
  kube_pod_container_resource_requests_memory_bytes{
   container_name="jenkins"
  }
) 
by (pod)
```

## Next Steps

## Resources

* https://medium.com/@eng.mohamed.m.saeed/monitoring-jenkins-with-grafana-and-prometheus-a7e037cbb376
* https://stackoverflow.com/questions/52230653/graphite-jenkins-job-level-metrics
* https://towardsdatascience.com/jenkins-events-logs-and-metrics-7c3e8b28962b
* https://github.com/nvgoldin/jenkins-graphite
*
*
