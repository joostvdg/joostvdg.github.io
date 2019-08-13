# Alerts

## Potential Alerts

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

All the configuration elements below, are part of the `prom-values.yaml` we used to when installing Prometheus via Helm.

### Get Slack Endpoint

TODO

### Base Configuration


```yaml
serverFiles:
  alerts:
    groups:
    # alerts come here
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

### Too Many Jobs Queued

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

### Jobs Stuck In Queue

```yaml
- alert: JenkinsTooManyJobsStuckInQueue
  expr: sum(jenkins_queue_stuck_value) by (app_kubernetes_io_instance) > 5
  for: 1m
  labels:
    severity: notify
  annotations:
    summary: " {{ $labels.app_kubernetes_io_instance }} too many jobs queued"
    description: " {{ $labels.app_kubernetes_io_instance }} has {{ $value }} jobs in queue"
```

### Jobs Waiting Too Long To Start

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

### Http Requests Too Slow

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

### Job Wait Duration

```yaml
- alert: JenkinsTooLowJobSuccessRate
  expr: sum(jenkins_runs_success_total) by (app_kubernetes_io_instance) / sum(jenkins_runs_total_total) by (app_kubernetes_io_instance) < 0.60
  for: 1m
  labels:
    severity: notify
  annotations:
    summary: " {{ $labels.app_kubernetes_io_instance }} has a too low job success rate"
    description: " {{ $labels.app_kubernetes_io_instance }} instance has {{ $value }}% of jobs being successful"
```

### Offline nodes > 5 over 10 minutes

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

### plugin updates available > 10

```yaml
- alert: JenkinsTooManyPluginsNeedUpate
  expr: sum(jenkins_plugins_withUpdate) by (app_kubernetes_io_instance) > 10
  for: 72h
  labels:
    severity: notify
  annotations:
    summary: "{{ $labels.app_kubernetes_io_instance }} too many plugins updates"
    description: "{{ $labels.app_kubernetes_io_instance }} has too many plugins that require an update"
```

### GCP ThroughPut Too Low

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

### Uptime < 2

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