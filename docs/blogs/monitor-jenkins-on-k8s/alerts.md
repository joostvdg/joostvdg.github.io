
title: Jenkins Kubernetes Monitoring
description: Monitoring Jenkins On Kubernetes - Alerts - 5/8
hero: Alerts - 5/8# Alerts

# Alerts With Alertmanager

## List Of Alerts

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
 * `vm.file.descriptor.ratio` -> `vm_file_descriptor_ratio`
* An alert that triggers if the JVM heap memory usage is over 80% for more than a minute
 * `vm.memory.heap.usage` -> `vm_memory_heap_usage`
* An alert that triggers if the 5 minute average of HTTP/404 responses goes above 10 per minute for more than five minutes
 * `http.responseCodes.badRequest` -> `http_responseCodes_badRequest`

## Alert Manager Configuration

We can configure Alert Manager via the Prometheus Helm Chart.

All the configuration elements below are part of the `prom-values.yaml` we used to when installing Prometheus via Helm.

### Get Slack Endpoint

There are many ways to get the Alerts out, for all options you [can read the Prometheus documentation](https://prometheus.io/docs/alerting/configuration/#receiver). 

In this guide, I've chosen to use slack, as I find it convenient personally. [Slack has a guide on creating webhooks](https://api.slack.com/incoming-webhooks), once you've created an `App` you can retrieve an endpoint which you can use directly in the Alertmanager configuration.

### Alerts Configuration

We configure the alerts within Prometheus itself via a `ConfigMap`. We configure the body of the alert configuration file via `serverFiles`.`alerts`.`groups` and `serverFiles`.`rules`. 

We can have a list of *rules* and a list of *groups* of rules. For more information how you can configure these rules, [consult the Prometheus documentation](https://prometheus.io/docs/prometheus/latest/configuration/alerting_rules/).

```yaml
serverFiles:
  alerts:
    groups:
    # alerts come here
  rules: {}
```
### Alert Example

Below is an example of an Alert. We have the following fields:

* **alert**: the name of the alert
* **expr**: the query that should evaluate to `true` or `false`
* **for** (optional): duration of the expressions equating to `true` before it fires
* **labels**(optional): you can add key-value pairs to encode more information on the alert, you can use this to select different receiver (e.g., email vs. slack, or different slack channels)
* **annotations**: we're expected to fill in `summary` and `description` as shown below, they will header and body of the alert

```yaml
- alert: JenkinsTooManyJobsQueued
  expr: sum(jenkins_queue_size_value) > 5
  for: 1m
  labels:
    severity: notify
  annotations:
    summary: " {{ $labels.app_kubernetes_io_instance }} too many jobs queued"
    description: "{{ $labels.app_kubernetes_io_instance }} has {{ $value }} jobs stuck in the queue"
```

### Alertmanager Configuration

We use Alertmanager for what to do with alerts once they happen. We configure this in the same `prom-values.yaml` file, in this under `alertmanagerFiles`.`alertmanager.yml`.

We can create different routes that match on labels or other values. For simplicity sake - this guide is not on Alertmanager's capabilities - we stick to the most straightforward example without any such matching or grouping. For more information on configuring routes, please [read the Prometheus configuration documentation](https://prometheus.io/docs/alerting/configuration/).

```yaml
alertmanagerFiles:
  alertmanager.yml:
    global: {}
    route:
      group_by: [alertname, app_kubernetes_io_instance]
      receiver: default
    receivers:
    - name: default
      slack_configs:
      - api_url: '<REPLACE_WITH_YOUR_SLACK_API_ENDPOINT>'
        username: 'Alertmanager'
        channel: '#notify'
        send_resolved: true
        title: "{{ .CommonAnnotations.summary }} " 
        text: "{{ .CommonAnnotations.description }} {{ .CommonLabels.app_kubernetes_io_instance}} "
        title_link: http://my-prometheus.com/alerts
```

### Group Alerts

You can group alerts if they are similar or the same with different trigger values (warning vs critical).

```yaml
serverFiles:
  alerts:
    groups:
    - name: healthcheck
      rules:
      - alert: JenkinsHealthScoreToLow
        # alert info
      - alert: JenkinsTooSlowHealthCheck
        # alert info
    - name: jobs
      rules:
      - alert: JenkinsTooManyJobsQueued
        # alert info
      - alert: JenkinsTooManyJobsStuckInQueue
        # alert info
```

## The Alerts

Behold, my awesome - eh, simple example - alerts. These are by no means the best alerts to create and are by no means alerts you should directly put into production. Please see them as examples to learn from!

!!! caution
    One thing to note especially, the values for the `exp` and `for` are generally set very low. This is intentional, so they are easy to copy past and test. They should be relatively easy to trigger so you can learn about the relationship between the situation in your master and the alert firing.

### Too Many Jobs Queued

If there are too many **Jobs** queued in the Jenkins Master. This event fires if there's more than `10` jobs in the queue for at least 10 minutes.

```yaml
- alert: JenkinsTooManyJobsQueued
  expr: sum(jenkins_queue_size_value) > 10
  for: 10m
  labels:
    severity: notify
  annotations:
    summary: " {{ $labels.app_kubernetes_io_instance }} too many jobs queued"
    description: "{{ $labels.app_kubernetes_io_instance }} has {{ $value }} jobs stuck in the queue"
```

### Jobs Stuck In Queue

Sometimes Jobs depend on other Jobs, which means they're not just in the queue, they're **stuck** in the queue.

```yaml
- alert: JenkinsTooManyJobsStuckInQueue
  expr: sum(jenkins_queue_stuck_value) by (app_kubernetes_io_instance) > 5
  for: 5m
  labels:
    severity: notify
  annotations:
    summary: " {{ $labels.app_kubernetes_io_instance }} too many jobs queued"
    description: " {{ $labels.app_kubernetes_io_instance }} has {{ $value }} jobs in queue"
```

### Jobs Waiting Too Long To Start

If Jobs are generally waiting a long time to start, waiting for a build agent to be available or otherwise, we want to know. This value is not very useful - although not completely useless - if you only have PodTemplates as build agents. When you use PodTemplates, this value is the time between the job being scheduled and when the Pod is scheduled in Kubernetes.

```yaml
- alert: JenkinsWaitingTooMuchOnJobStart
  expr: sum (jenkins_job_waiting_duration) by (app_kubernetes_io_instance) > 0.05
  for: 1m
  labels:
    severity: notify
  annotations:
    summary: "{{ $labels.app_kubernetes_io_instance }} waits too long for jobs"
    description: "{{ $labels.app_kubernetes_io_instance }} is waiting on average {{ $value }} seconds to start a job"
```

### health score < 1

By default, each Jenkins Master has a health check consisting out of four values. Some plugins will add an entry, such as the CloudBees ElasticSearch Reporter for CloudBees Core. This values range from 0-1, and likely will show `0.25`, `0.50`, `0.75` and `1` as values.

```yaml
- alert: JenkinsHealthScoreToLow
  expr: sum(jenkins_health_check_score) by (app_kubernetes_io_instance) < 1
  for: 5m
  labels:
    severity: notify
  annotations:
    summary: " {{ $labels.app_kubernetes_io_instance }} has a to low health score"
    description: " {{ $labels.app_kubernetes_io_instance }} a health score lower than 100%"
```

### Ingress Too Slow

This alert looks at the ingress controller request duration. It fires if the request duration in 0.25 seconds or faster is not achieved for the 95% percentile.

```yaml
- alert: AppTooSlow
  expr: sum(rate(nginx_ingress_controller_request_duration_seconds_bucket{le="0.25"}[5m])) by (ingress) / sum(rate(nginx_ingress_controller_request_duration_seconds_count[5m])) by (ingress) < 0.95
  for: 5m
  labels:
    severity: notify
  annotations:
    summary: "Application - {{ $labels.ingress }} - is too slow"
    description: " {{ $labels.ingress }} - More then 5% of requests are slower than 0.25s"
```

### HTTP Requests Too Slow

These are the HTTP requests in Jenkins' webserver itself. We should hold this by must stricter standards than the Ingress controller - which goes through many more layers.

```yaml
- alert: JenkinsTooSlow
  expr: sum(http_requests{quantile="0.99"} ) by (app_kubernetes_io_instance) > 1
  for: 3m
  labels:
    severity: notify
  annotations:
    summary: "{{ $labels.app_kubernetes_io_instance }} is too slow"
    description: "{{ $labels.app_kubernetes_io_instance }}  More then 1% of requests are slower than 1s (request time: {{ $value }})"
```

### Too Many Plugin Updates

I always prefer having my instance up-to-date, don't you? So why not send an alert if there's more than X number of plugins waiting for an update.

```yaml
- alert: JenkinsTooManyPluginsNeedUpate
  expr: sum(jenkins_plugins_withUpdate) by (app_kubernetes_io_instance) > 3
  for: 1m
  labels:
    severity: notify
  annotations:
    summary: " {{ $labels.app_kubernetes_io_instance }} too many plugins updates"
    description: " {{ $labels.app_kubernetes_io_instance }} has {{ $value }} plugins that require an update"
```

### File Descriptor Ratio > 40%

According to CloudBees' documentation, the File Descriptor Ratio should not exceed 40%.

!!! warning
    I don't truly know the correct value level of this metric. So wether this should be `0.0040` or `0.40` I'm not sure. Also, does this make sense in Containers with remote storage? So before you put this in production, please re-evaluate this!

```yaml
- alert: JenkinsToManyOpenFiles
  expr: sum(vm_file_descriptor_ratio) by (app_kubernetes_io_instance) > 0.040
  for: 5m
  labels:
    severity: notify
  annotations:
    summary: " {{ $labels.app_kubernetes_io_instance }} has a to many open files"
    description: " {{ $labels.app_kubernetes_io_instance }} instance has used {{ $value }} of available open files"
```

### Job Success Ratio < 50%

Please, please do not use Job success ratios to punish people. But if it is at all possible - which it almost certainly is - keep a respectable level of success. When practicing Continuous Integration, a broken build is a *stop the world* event, fix it before moving on. 

100% success rate should be strived for. It is ok, not to achieve it, yet, one should be as close as possible and not let broken builds rot.

```yaml
- alert: JenkinsTooLowJobSuccessRate
  expr: sum(jenkins_runs_success_total) by (app_kubernetes_io_instance) / sum(jenkins_runs_total_total) by (app_kubernetes_io_instance) < 0.5
  for: 5m
  labels:
    severity: notify
  annotations:
    summary: "{{$labels.app_kubernetes_io_instance}} has a too low job success rate"
    description: "{{$labels.app_kubernetes_io_instance}} instance has less than 50% of jobs being successful"
```

### Offline nodes > 5 over 10 minutes

Having nodes offline for quite some time is usually a bad sign. It can be a static agent that can be enabled or reconnect at will, so it isn't bad on its own. Having multiple offline for a long period is likely an issue somewhere, though.

```yaml
- alert: JenkinsTooManyOfflineNodes
  expr: sum(jenkins_node_offline_value) by (app_kubernetes_io_instance) > 5
  for: 10m
  labels:
    severity: notify
  annotations:
    summary: "{{ $labels.app_kubernetes_io_instance }} has a too many offline nodes"
    description: "{{ $labels.app_kubernetes_io_instance }} has {{ $value }} nodes that are offline for some time (5 minutes)" 
```

### healtcheck duration > 0.002

The health check within Jenkins is talking to itself. This means it is generally really fast. We should be very very strict here, if Jenkins start having trouble measuring its own health, it is a first sign of trouble.

```yaml
- alert: JenkinsTooSlowHealthCheck
  expr: sum(jenkins_health_check_duration{quantile="0.999"})
    by (app_kubernetes_io_instance) > 0.001
  for: 1m
  labels:
    severity: notify
  annotations:
    summary: " {{ $labels.app_kubernetes_io_instance }} responds too slow to health check"
    description: " {{ $labels.app_kubernetes_io_instance }} is responding too slow to the regular health check"
```

### GC ThroughPut Too Low

Ok, here I am on thin ice. I'm not a JVM expert, so this is just an inspiration. I do not know what would be a reasonable value for triggering an alert here. I'd say, test it!

```yaml
- alert: JenkinsTooManyPluginsNeedUpate
  expr: 1 - sum(vm_gc_G1_Young_Generation_time)by (app_kubernetes_io_instance)  /  sum (vm_uptime_milliseconds) by (app_kubernetes_io_instance) < 0.99
  for: 30m
  labels:
    severity: notify
  annotations:
    summary: "{{ $labels.instance }} too low GC throughput"
    description: "{{ $labels.instance }} has too low Garbage Collection throughput"
```

### vm heap usage ratio > 70%

According to the CloudBees guide on tuning the JVM - which redirects to Oracle - the ration of JVM Heap memory usage should not exceed about 60%. So if we get over 70% for quite some time, expect trouble. As with any of these values, please do not take my word on it, and understand it yourself.

```yaml
- alert: JenkinsVMMemoryRationTooHigh
  expr: sum(vm_memory_heap_usage) by (app_kubernetes_io_instance) > 0.70
  for: 3m
  labels:
    severity: notify
  annotations:
    summary: "{{$labels.app_kubernetes_io_instance}} too high memory ration"
    description: "{{$labels.app_kubernetes_io_instance}} has a too high VM memory ration"
```

### Uptime Less Than Two Hours

I absolutely love servers that have excellent uptime. Running services in Containers makes that a thing of the past, such a shame. Still, I'd like my applications - such as Jenkins - to be up for reasonable lengths of time.

In this case we can get notifications on Masters that have restart - for example, when OOMKilled by Kubernetes. We also get an alert when a new Master is created, which if there's selfservice involved is a nice bonus.

```yaml
- alert: JenkinsNewOrRestarted
  expr: sum(vm_uptime_milliseconds) by (app_kubernetes_io_instance) / 3600000 < 2
  for: 3m
  labels:
    severity: notify
  annotations:
    summary: " {{ $labels.app_kubernetes_io_instance }} has low uptime"
    description: " {{ $labels.app_kubernetes_io_instance }} has low uptime and was either restarted or is a new instance (uptime: {{ $value }} hours)"
```

## Full Example

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
    - name: jobs
      rules:
      - alert: JenkinsTooManyJobsQueued
        expr: sum(jenkins_queue_size_value) > 5
        for: 1m
        labels:
          severity: notify
        annotations:
          summary: " {{ $labels.app_kubernetes_io_instance }} too many jobs queued"
          description: "{{ $labels.app_kubernetes_io_instance }} has {{ $value }} jobs stuck in the queue"
      - alert: JenkinsTooManyJobsStuckInQueue
        expr: sum(jenkins_queue_stuck_value) by (app_kubernetes_io_instance) > 5
        for: 1m
        labels:
          severity: notify
        annotations:
          summary: " {{ $labels.app_kubernetes_io_instance }} too many jobs queued"
          description: " {{ $labels.app_kubernetes_io_instance }} has {{ $value }} jobs in queue"
      - alert: JenkinsWaitingTooMuchOnJobStart
        expr: sum (jenkins_job_waiting_duration) by (app_kubernetes_io_instance) > 0.05
        for: 1m
        labels:
          severity: notify
        annotations:
          summary: "{{ $labels.app_kubernetes_io_instance }} waits too long for jobs"
          description: "{{ $labels.app_kubernetes_io_instance }} is waiting on average {{ $value }} seconds to start a job"
      - alert: JenkinsTooLowJobSuccessRate
        expr: sum(jenkins_runs_success_total) by (app_kubernetes_io_instance) / sum(jenkins_runs_total_total) by (app_kubernetes_io_instance) < 0.60
        for: 1m
        labels:
          severity: notify
        annotations:
          summary: " {{ $labels.app_kubernetes_io_instance }} has a too low job success rate"
          description: " {{ $labels.app_kubernetes_io_instance }} instance has {{ $value }}% of jobs being successful"
    - name: uptime
      rules:
      - alert: JenkinsNewOrRestarted
        expr: sum(vm_uptime_milliseconds) by (app_kubernetes_io_instance) / 3600000 < 2
        for: 3m
        labels:
          severity: notify
        annotations:
          summary: " {{ $labels.app_kubernetes_io_instance }} has low uptime"
          description: " {{ $labels.app_kubernetes_io_instance }} has low uptime and was either restarted or is a new instance (uptime: {{ $value }} hours)"
    - name: plugins
      rules:
      - alert: JenkinsTooManyPluginsNeedUpate
        expr: sum(jenkins_plugins_withUpdate) by (app_kubernetes_io_instance) > 3
        for: 1m
        labels:
          severity: notify
        annotations:
          summary: " {{ $labels.app_kubernetes_io_instance }} too many plugins updates"
          description: " {{ $labels.app_kubernetes_io_instance }} has {{ $value }} plugins that require an update"
    - name: jvm
      rules:
      - alert: JenkinsToManyOpenFiles
        expr: sum(vm_file_descriptor_ratio) by (app_kubernetes_io_instance) > 0.040
        for: 5m
        labels:
          severity: notify
        annotations:
          summary: " {{ $labels.app_kubernetes_io_instance }} has a to many open files"
          description: " {{ $labels.app_kubernetes_io_instance }} instance has used {{ $value }} of available open files"
      - alert: JenkinsVMMemoryRationTooHigh
        expr: sum(vm_memory_heap_usage) by (app_kubernetes_io_instance) > 0.70
        for: 3m
        labels:
          severity: notify
        annotations:
          summary: "{{$labels.app_kubernetes_io_instance}} too high memory ration"
          description: "{{$labels.app_kubernetes_io_instance}} has a too high VM memory ration"
      - alert: JenkinsTooManyPluginsNeedUpate
        expr: 1 - sum(vm_gc_G1_Young_Generation_time)by (app_kubernetes_io_instance)  /  sum (vm_uptime_milliseconds) by (app_kubernetes_io_instance) < 0.99
        for: 30m
        labels:
          severity: notify
        annotations:
          summary: "{{ $labels.instance }} too low GC throughput"
          description: "{{ $labels.instance }} has too low Garbage Collection throughput"
    - name: web
      rules:
      - alert: JenkinsTooSlow
        expr: sum(http_requests{quantile="0.99"} ) by (app_kubernetes_io_instance) > 1
        for: 3m
        labels:
          severity: notify
        annotations:
          summary: "{{ $labels.app_kubernetes_io_instance }} is too slow"
          description: "{{ $labels.app_kubernetes_io_instance }}  More then 1% of requests are slower than 1s (request time: {{ $value }})"
      - alert: AppTooSlow
        expr: sum(rate(nginx_ingress_controller_request_duration_seconds_bucket{le="0.25"}[5m])) by (ingress) / sum(rate(nginx_ingress_controller_request_duration_seconds_count[5m])) by (ingress) < 0.95
        for: 5m
        labels:
          severity: notify
        annotations:
          summary: "Application - {{ $labels.ingress }} - is too slow"
          description: " {{ $labels.ingress }} - More then 5% of requests are slower than 0.25s"
    - name: healthcheck
      rules:
      - alert: JenkinsHealthScoreToLow
        expr: sum(jenkins_health_check_score) by (app_kubernetes_io_instance) < 1
        for: 5m
        labels:
          severity: notify
        annotations:
          summary: " {{ $labels.app_kubernetes_io_instance }} has a to low health score"
          description: " {{ $labels.app_kubernetes_io_instance }} a health score lower than 100%"
      - alert: JenkinsTooSlowHealthCheck
        expr: sum(jenkins_health_check_duration{quantile="0.999"})
          by (app_kubernetes_io_instance) > 0.001
        for: 1m
        labels:
          severity: notify
        annotations:
          summary: " {{ $labels.app_kubernetes_io_instance }} responds too slow to health check"
          description: " {{ $labels.app_kubernetes_io_instance }} is responding too slow to the regular health check"
    - name: nodes
      rules:
      - alert: JenkinsTooManyOfflineNodes
        expr: sum(jenkins_node_offline_value) by (app_kubernetes_io_instance) > 3
        for: 1m
        labels:
          severity: notify
        annotations:
          summary: "{{ $labels.app_kubernetes_io_instance }} has a too many offline nodes"
          description: "{{ $labels.app_kubernetes_io_instance }} has {{ $value }} nodes that are offline for some time (5 minutes)"
alertmanagerFiles:
  alertmanager.yml:
    global: {}
    route:
      group_by: [alertname, app_kubernetes_io_instance]
      receiver: default
    receivers:
    - name: default
      slack_configs:
      - api_url: '<REPLACE_WITH_YOUR_SLACK_API_URL>'
        username: 'Alertmanager'
        channel: '#notify'
        send_resolved: true
        title: "{{ .CommonAnnotations.summary }} " 
        text: "{{ .CommonAnnotations.description }} {{ .CommonLabels.app_kubernetes_io_instance}} "
        title_link: http://my-prometheus.com/alerts
```