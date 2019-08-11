# Monitor Jenkins on Kubernetes

## Get Data From Jobs

* Use Prometheus Push Gateway
** via shared lib
* JX sh step -> tekton -> write interceptor

## The Plan

* install one or more Jenkins instances
* get metrics from running Jenkins instance(s)
* have queries for understanding the state and performance of the Jenkins instance(s)
* have a dashboard to aid debugging an issue or determine new alerts
* have alerts that fire when (potential) problematic conditions occur
* get metrics from Jenkins Pipelines

## Get Metrics

To get Data from Jenkins in Kubernetes to monitor, we first need the following:

* a kubernetes cluster
* prometheus for collecting data and generating alerts
* grafana for dashboards that help debug issues
* one or more Jenkins instances

### Create GKE Cluster

```bash
REGION=europe-west4
CLUSTER_NAME=joostvdg-2019-08-1
K8S_VERSION=1.13.7-gke.8
REGION=europe-west4
PROJECT_ID=
```

```bash
gcloud container get-server-config --region $REGION
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

### Install Ingress Controller

```bash
kubectl apply \
    -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/1cd17cd12c98563407ad03812aebac46ca4442f2/deploy/mandatory.yaml

kubectl apply \
    -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/1cd17cd12c98563407ad03812aebac46ca4442f2/deploy/provider/cloud-generic.yaml
```

```bash
export LB_IP=$(kubectl -n ingress-nginx \
    get svc ingress-nginx \
    -o jsonpath="{.status.loadBalancer.ingress[0].ip}")

echo $LB_IP
```

### Install Helm

```bash
kubectl create \
    -f https://raw.githubusercontent.com/vfarcic/k8s-specs/master/helm/tiller-rbac.yml \
    --record --save-config

helm init --service-account tiller

kubectl -n kube-system \
    rollout status deploy tiller-deploy
```

### Install Cert-Manager (Optional)

```bash
kubectl apply -f https://raw.githubusercontent.com/jetstack/cert-manager/release-0.8/deploy/manifests/00-crds.yaml
```

```bash
kubectl create namespace cert-manager
kubectl label namespace cert-manager certmanager.k8s.io/disable-validation=true
```

```bash
helm repo add jetstack https://charts.jetstack.io
helm repo update
```

```bash
helm install \
    --name cert-manager \
    --namespace cert-manager \
    --version v0.8.0 \
    jetstack/cert-manager
```

```bash
kubectl apply -f cluster-issuer.yaml
```

## Install Monitoring Components

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
    hostName: jenkins.gke.kearos.net
    tls:
      - secretName: tls-jenkins-gke-kearos-net
        hosts:
          - jenkins.gke.kearos.net
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

### First Master

```bash
helm upgrade -i jenkins \
    stable/jenkins \
    --namespace jenkins\
    -f jenkins-values.1.yaml
```

```bash
kubectl apply -f jenkins-certificate.1.yaml
```

```bash
kubectl -n jenkins rollout status deployment jenkins
```

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

```bash
kubectl -n jenkins rollout status deployment jenkins2
```

```bash
kubectl apply -f jenkins-certificate.2.yaml
```

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

```bash
kubectl -n jenkins rollout status deployment jenkins3
```

```bash
kubectl apply -f jenkins-certificate.3.yaml
```

```bash
printf $(kubectl get secret --namespace jenkins jenkins3 -o jsonpath="{.data.jenkins-admin-password}" | base64 --decode);echo
```

## Prometheus Queries

Jenkins is a Java Web application, in this case running in Kubernetes.
Let's categorize the metrics we want to look at and deal with each group individually.

* `JVM`: the JVM metrics are exposed, we should leverage this for very specific queries and alerts
* `Web`: although it is not the main function of Jenkins, web access will give us some hints about performance trends
* `Jenkins Configuration`: some configuration elements are exposed, a few of these have very strong recommended values, such as `Master Executor Slots` (should always be **0**)
* `Jenkins Usage`: jobs running in Jenkins, or Jobs *not* running in Jenkins can also tell us about (potential) problems
* `Pod Metrics`: any generic metric from a Kubernetes Pod perspective will still be helpful to look at

### Types of Metrics to evaluate

In the age where SRE. DevOps Engineer and Platform Engineer are not only hype terms, there is written alot about which kinds of metrics to really look it. There's enough written about this - including Viktor Farcic' excellent DevOps Toolkit 2.5 - so lets just briefly evaluate these.

* `Latency`: response times of your application, in our case, both external access via Ingress and internal access. We can measure latency on internal access via Jenkins' own metrics, which also has percentile information (for example, p99)
* `Errors`: we can take a look at network errors such as http 500, which we get straight from Jenkins' webserver (Netty) and at failed jobs
* `Traffic`: the amount of connections to our service, in our case we have web traffic and jobs running, both we get from Jenkins
* `Saturation`: how much the system is used compared to the available resources, core resources such as CPU and Memory primarily depend on your Kubernetes Nodes. But we can take a look at the Pod's limits vs. requests and Jenkins' job wait time - which roughly translates to saturation

### JVM

We have some basic JVM metrics, such as CPU and Memory usage, and uptime. Uptime itself might not be very interresting, until a service has an uptime of less than an hour - Pod was restart - and never seems to be able to go beyond a few hours.

```bash
vm_cpu_load
```

```bash
(vm_memory_total_max - vm_memory_total_used) / vm_memory_total_max * 100.0
```

```bash
vm_uptime_milliseconds
```

#### Garbage Collection

For fine tuning the JVM's garbage collection for Jenkins, there are two main guides from CloudBees. Which also explains the `JVM_OPTIONS` in the `jenkins-values.yaml` we used for the Helm installation.

* https://support.cloudbees.com/hc/en-us/articles/222446987-Prepare-Jenkins-for-Support
* https://www.cloudbees.com/blog/joining-big-leagues-tuning-jenkins-gc-responsiveness-and-stability (somewhat outdated)

The second article, while outdated, contains a lot of information on how to debug the Garbage Collection logs and metrics. To process the data thoroughly requires experts with specifically designed tools. I am not such an expert nor is this the document to guide you through this. Distilled from the two guides the conclusion is; measure core metrics (CPU, Memory) and Garbage Collection Throughput (see below) and if problems arise use the CloudBees guide to dive further.

```bash
1 - sum(rate(vm_gc_G1_Young_Generation_time{kubernetes_namespace=~"$namespace", app_kubernetes_io_instance=~"$instance"}[5m]))by (app_kubernetes_io_instance) 
/ 
sum (vm_uptime_milliseconds{kubernetes_namespace=~"$namespace", app_kubernetes_io_instance=~"$instance"}) by (app_kubernetes_io_instance)
```

### Check for to many open files

When looking at CloudBees guide on [tuning performance on Linux](https://support.cloudbees.com/hc/en-us/articles/115000486312-CloudBees-Core-Performance-Best-Practices-for-Linux) one of the main things to look are core metrics (Memory and CPU) and Open Files. There's even an explicit guide [on monitoring the number of open files](https://support.cloudbees.com/hc/en-us/articles/204246140-Too-many-open-files).

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

#### Active Runs

#### Idle Executors

#### Average Time Waiting to Start

#### Completed Runs Per Day

```bash
sum(increase(jenkins_runs_total_total[24h])) by (app_kubernetes_io_instance)
```

#### Average Time to complete

```bash
sum(jenkins_job_building_duration) by (kubernetes_pod_name) /
```

## Resources

* https://go.cloudbees.com/docs/solutions/jvm-troubleshooting/
* https://go.cloudbees.com/docs/cloudbees-documentation/devoptics-user-guide/run_insights/
* https://medium.com/@eng.mohamed.m.saeed/monitoring-jenkins-with-grafana-and-prometheus-a7e037cbb376
* https://stackoverflow.com/questions/52230653/graphite-jenkins-job-level-metrics
* https://towardsdatascience.com/jenkins-events-logs-and-metrics-7c3e8b28962b
* https://github.com/nvgoldin/jenkins-graphite
* https://www.weave.works/blog/promql-queries-for-the-rest-of-us/
* https://medium.com/quiq-blog/prometheus-relabeling-tricks-6ae62c56cbda
* https://docs.google.com/presentation/d/1gtqEfTKM3oLr1N9zjAeXtOcS1eAQS--Xz0D4hwlo_KQ/edit#slide=id.g5bbd4fcccc_10_10
* https://go.cloudbees.com/docs/cloudbees-documentation/devoptics-user-guide/security_privacy/#_verification_of_connection_to_the_devoptics_service
* https://sysdig.com/blog/golden-signals-kubernetes/?utm_campaign=kaptain%20-%20The%20Best%20Distributed%20Systems%20Stories&utm_content=Faun%20%F0%9F%A6%88%20Kaptain%20%23175%3A%20Monitoring%20Golden%20Signals%2C%20The%20Ultimate%20Guide%20to%20K8s%20Deployments%20%26%20K8s%20Federation%20v2&utm_medium=email&utm_source=faun