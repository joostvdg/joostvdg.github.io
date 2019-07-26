# Monitor Jenkins on Kubernetes

## Get Data From Jobs

* Use Prometheus Push Gateway
** via shared lib
* JX sh step -> tekton -> write interceptor

## GKE

```bash
REGION=europe-west4
CLUSTER_NAME=joostvdg-2019-07-1
K8S_VERSION=1.13.7-gke.8
PROJECT_ID=
```

```bash
gcloud container clusters create ${CLUSTER_NAME} \
    --region ${REGION} \
    --cluster-version ${K8S_VERSION} \
    --num-nodes 2 --machine-type n1-standard-2 \
    --addons=HorizontalPodAutoscaling \
    --min-nodes 2 --max-nodes 3 \
    --enable-autoupgrade \
    --enable-autoscaling \
    --enable-network-policy \
    --labels=owner=jvandergriendt,purpose=practice
```

```bash
kubectl create clusterrolebinding \
    cluster-admin-binding \
    --clusterrole cluster-admin \
    --user $(gcloud config get-value account)
```

```bash
kubectl apply \
    -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/1cd17cd12c98563407ad03812aebac46ca4442f2/deploy/mandatory.yaml

kubectl apply \
    -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/1cd17cd12c98563407ad03812aebac46ca4442f2/deploy/provider/cloud-generic.yaml
```

```bash
kubectl create \
    -f https://raw.githubusercontent.com/vfarcic/k8s-specs/master/helm/tiller-rbac.yml \
    --record --save-config

helm init --service-account tiller

kubectl -n kube-system \
    rollout status deploy tiller-deploy
```

```bash
export LB_IP=$(kubectl -n ingress-nginx \
    get svc ingress-nginx \
    -o jsonpath="{.status.loadBalancer.ingress[0].ip}")

echo $LB_IP
```

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
  --set server.ingress.hosts={$PROM_ADDR} \
  --set alertmanager.ingress.hosts={$AM_ADDR} \
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

#### Dashboards

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

### Install Jenkins

```bash
kubectl create namespace jenkins
kubens jenkins
```

```bash
helm upgrade -i jenkins \
    stable/jenkins \
    --namespace jenkins\
    -f jenkins-values.yaml
```

```bash
kubectl -n jenkins rollout status deployment jenkins
```

```bash
printf $(kubectl get secret --namespace jenkins jenkins -o jsonpath="{.data.jenkins-admin-password}" | base64 --decode);echo
```

#### Second Master

```bash
helm upgrade -i jenkins2 \
    stable/jenkins \
    --namespace jenkins\
    -f jenkins-values.1.yaml
```

```bash
kubectl -n jenkins rollout status deployment jenkins2
```

```bash
printf $(kubectl get secret --namespace jenkins jenkins2 -o jsonpath="{.data.jenkins-admin-password}" | base64 --decode);echo
```

### Third

```bash
helm upgrade -i jenkins3 \
    stable/jenkins \
    --namespace jenkins\
    -f jenkins-values.2.yaml
```

```bash
kubectl -n jenkins rollout status deployment jenkins3
```

```bash
printf $(kubectl get secret --namespace jenkins jenkins3 -o jsonpath="{.data.jenkins-admin-password}" | base64 --decode);echo

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

#### Check for to many open files

* https://support.cloudbees.com/hc/en-us/articles/204246140-Too-many-open-files

```bash
vm_file_descriptor_ratio
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

### Ingress Performance

```bash
sum(rate(
  nginx_ingress_controller_request_duration_seconds_count{
    ingress=~"jenkins.*"
  }[5m]
)) 
by (ingress)
```


```bash
sum(rate(
  nginx_ingress_controller_request_duration_seconds_bucket{
    le="1.5", 
    ingress~="jenkins.*"
  }[5m]
)) 
by (ingress) / 
sum(rate(
  nginx_ingress_controller_request_duration_seconds_count{
    ingress~="jenkins.*"
  }[5m]
)) 
by (ingress)
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

### Number of Good Request vs. Request

```bash
sum(http_responseCodes_ok_total) 
by (kubernetes_pod_name) / 
sum(http_requests_count) 
by (kubernetes_pod_name)
```

## Other Performance metrics

* `http_responseCodes_badRequest`
* `http.activeRequests`
* `http.responseCodes.ok`

```bash
sum(jenkins_job_scheduled_total) 
by (kubernetes_pod_name) *
sum(jenkins_job_building_duration) 
by (kubernetes_pod_name)
```

```bash
sum(jenkins_runs_success_total)
by (kubernetes_pod_name) /
sum(jenkins_runs_success_total)
by (kubernetes_pod_name)
```

```bash
sum(rate(jenkins_job_scheduled_total[24h]))
by (kubernetes_pod_name)

sum(rate(jenkins_job_scheduled_total[5m]))
by (kubernetes_pod_name) *
sum(rate(jenkins_job_building_duration[5m]))
by (kubernetes_pod_name)


sum(rate(jenkins_job_building_duration[24h]))
by (kubernetes_pod_name)
```

### To implement

* ratio of http.responseCodes.ok from http.requests
** per 5m?
* `http.responseCodes.serverError`
* `jenkins.health-check.score`
* `jenkins.job.waiting.duration`

* time spend building:
* multiplying jenkins.job.scheduled by jenkins.job.building.duration
** `jenkins_job_scheduled * jenkins_job_building_duration`
* can we measure: number of builds since 00:00

```bash
jenkins_job_scheduled * jenkins_job_building_duration
```

### GC values to look for

* Garbage collection should not be running more often than once every 15 seconds on average, with one collection per 30 seconds being a good number to aim for.
* The GC throughput (the percentage of time spent running the application rather than doing garbage collection) should be above 98%
* The amount of the heap used (not just allocated) for old-generation data should not exceed 70% except for brief spikes and should be 50% or less in most cases


```bash
1 - sum(rate(vm_gc_G1_Young_Generation_time[5m]))  by (kubernetes_pod_name) / vm_uptime_milliseconds


sum(rate(
  vm_gc_PS_Scavenge_time[5m]
)) 
by (kubernetes_pod_name)
```

```bash
sum(vm_gc_PS_MarkSweep_time) by (kubernetes_pod_name)
```

```bash
sum(vm_gc_PS_Scavenge_time) by (kubernetes_pod_name)
```



```bash
vm.gc..count (gauge)

    The number of times the garbage collector has run. The names are supplied by and dependent on the JVM. There will be one metric for each of the garbage collectors reported by the JVM.
vm.gc..time (gauge)

    The amount of time spent in the garbage collector. The names are supplied by and dependent on the JVM. There will be one metric for each of the garbage collectors reported by the JVM.
```

## Grafana Variables

* cluster
** type: datasource
** datasource type: prometheus
* node
** type: query
** query: `label_values(node_boot_time{job="node-exporter"}, instance)`
** multivalue
** include all
* namespace
** type: query
** query: label_values(kube_pod_info, namespace)
** multivalue
** include all

## Alerts

* health score < 0.95
* ingress performance 
* vm heap usage ratio > 80%
* file descriptor > 75%
* job queue > 10 over x minutes
* job success ratio < 50%
* master executor count > 0
* good http request ratio < 90%
* offline nodes > 5 over 30 minutes
* healtcheck duration > 0.002
* plugin updates available > 10

* An alert that triggers if any of the health reports are failing
* An alert that triggers if the file descriptor usage on the master goes above 80%
** `vm.file.descriptor.ratio` -> `vm_file_descriptor_ratio`
* An alert that triggers if the JVM heap memory usage is over 80% for more than a minute
** `vm.memory.heap.usage` -> `vm_memory_heap_usage`
* An alert that triggers if the 5 minute average of HTTP/404 responses goes above 10 per minute for more than five minutes
** `http.responseCodes.badRequest` -> `http_responseCodes_badRequest`

## CloudBees Core

* add prometheus plugin to team-recipe
* update CJOC's Master Provisioning with prometheus annotations

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
```

## Additional Metrics

* [metrics-diskusage](https://plugins.jenkins.io/metrics-diskusage)
* [disk-usage](https://wiki.jenkins.io/display/JENKINS/Disk+Usage+Plugin)

## Next Steps

### Replace Node Builds

* make them a single metric, and calculate builds per label

### Match functionality from DevOptics

Can we?

* https://go.cloudbees.com/docs/cloudbees-documentation/devoptics-user-guide/run_insights/

* Average number of nodes: The Average Nodes column displays the average number of nodes that have each label over the selected time period
* Average number of executors: The Average Executors column displays the average number of executors on nodes that have each label over the selected time period
* Average executors in use %: The Average Executors in Use column displays the average percentage of used executor capacity for each label
* Average queue time: The Average Queue Time column displays the average time that jobs spend in the queue for each label over the selected time period
* Average queue length: The Average Queue Length column displays the average length of the job queue for each label over the selected time period
* Average tasks per day: The Average Task per Day column displays the average number of tasks that run per day for each label over the selected time period
* Average task duration: The Average Task Duration column displays the average duration of a task from start to finish on each label over the selected time period
* Average total execution time: The Average Total Execution Time column displays the average total execution time of all executors running in each job that run on each label over the selected time period

## Resources

* https://go.cloudbees.com/docs/cloudbees-documentation/devoptics-user-guide/run_insights/
* https://medium.com/@eng.mohamed.m.saeed/monitoring-jenkins-with-grafana-and-prometheus-a7e037cbb376
* https://stackoverflow.com/questions/52230653/graphite-jenkins-job-level-metrics
* https://towardsdatascience.com/jenkins-events-logs-and-metrics-7c3e8b28962b
* https://github.com/nvgoldin/jenkins-graphite
* https://www.weave.works/blog/promql-queries-for-the-rest-of-us/
* https://medium.com/quiq-blog/prometheus-relabeling-tricks-6ae62c56cbda
