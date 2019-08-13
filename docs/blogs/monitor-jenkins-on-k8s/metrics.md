Jenkins is a Java Web application, in this case running in Kubernetes.
Let's categorize the metrics we want to look at and deal with each group individually.

* `JVM`: the JVM metrics are exposed, we should leverage this for very specific queries and alerts
* `Jenkins Configuration`: some configuration elements are exposed, a few of these have very strong recommended values, such as `Master Executor Slots` (should always be **0**)
* `Jenkins Usage`: jobs running in Jenkins, or Jobs *not* running in Jenkins can also tell us about (potential) problems
* `Web`: although it is not the main function of Jenkins, web access will give us some hints about performance trends
* `Pod Metrics`: any generic metric from a Kubernetes Pod perspective will still be helpful to look at

### Types of Metrics to evaluate

In the age where SRE. DevOps Engineer and Platform Engineer are not only hype terms, there is written alot about which kinds of metrics to really look it. There's enough written about this - including Viktor Farcic' excellent DevOps Toolkit 2.5 - so lets just briefly evaluate these.

* `Latency`: response times of your application, in our case, both external access via Ingress and internal access. We can measure latency on internal access via Jenkins' own metrics, which also has percentile information (for example, p99)
* `Errors`: we can take a look at network errors such as http 500, which we get straight from Jenkins' webserver (Netty) and at failed jobs
* `Traffic`: the amount of connections to our service, in our case we have web traffic and jobs running, both we get from Jenkins
* `Saturation`: how much the system is used compared to the available resources, core resources such as CPU and Memory primarily depend on your Kubernetes Nodes. But we can take a look at the Pod's limits vs. requests and Jenkins' job wait time - which roughly translates to saturation

## JVM Metrics

We have some basic JVM metrics, such as CPU and Memory usage, and uptime. Uptime itself might not be very interresting, until a service has an uptime of less than an hour - Pod was restart - and never seems to be able to go beyond a few hours.

```
vm_cpu_load
```

```
(vm_memory_total_max - vm_memory_total_used) / vm_memory_total_max * 100.0
```

```
vm_uptime_milliseconds
```

### Garbage Collection

For fine tuning the JVM's garbage collection for Jenkins, there are two main guides from CloudBees. Which also explains the `JVM_OPTIONS` in the `jenkins-values.yaml` we used for the Helm installation.

* https://support.cloudbees.com/hc/en-us/articles/222446987-Prepare-Jenkins-for-Support
* https://www.cloudbees.com/blog/joining-big-leagues-tuning-jenkins-gc-responsiveness-and-stability (somewhat outdated)

The second article, while outdated, contains a lot of information on how to debug the Garbage Collection logs and metrics. To process the data thoroughly requires experts with specifically designed tools. I am not such an expert nor is this the document to guide you through this. Distilled from the two guides the conclusion is; measure core metrics (CPU, Memory) and Garbage Collection Throughput (see below) and if problems arise use the CloudBees guide to dive further.

```
1 - sum(rate(vm_gc_G1_Young_Generation_time{kubernetes_namespace=~"$namespace", app_kubernetes_io_instance=~"$instance"}[5m]))by (app_kubernetes_io_instance) 
/ 
sum (vm_uptime_milliseconds{kubernetes_namespace=~"$namespace", app_kubernetes_io_instance=~"$instance"}) by (app_kubernetes_io_instance)
```

### Check for to many open files

When looking at CloudBees guide on [tuning performance on Linux](https://support.cloudbees.com/hc/en-us/articles/115000486312-CloudBees-Core-Performance-Best-Practices-for-Linux) one of the main things to look are core metrics (Memory and CPU) and Open Files. There's even an explicit guide [on monitoring the number of open files](https://support.cloudbees.com/hc/en-us/articles/204246140-Too-many-open-files).

```
vm_file_descriptor_ratio
```

## Jenkins Config Metrics

### Plugins

```
sum(jenkins_plugins_active) by (app_kubernetes_io_instance)
```

### Jenkins Build Nodes

Jenkins should never build on a master, always on a node or agent.

```
jenkins_executor_count_value{kubernetes_namespace=~"$namespace", app_kubernetes_io_instance=~"$instance"}
```

You might use static agents or, while we're in Kubernetes, only have dynamic agents. Either way, having nodes offline for some period of time signifies a problem. Maybe the Node configuration is wrong, or the PodTemplate has a mistake, or maybe your ServiceAccount doesn't have the correct permissions.

```
jenkins_node_offline_value{kubernetes_namespace=~"$namespace", app_kubernetes_io_instance=~"$instance"}
```

## Jenkins Usage Metrics

### Builds Per Day

```
sum(increase(jenkins_runs_total_total[24h])) by (app_kubernetes_io_instance)
```

### Job duration

```
default_jenkins_builds_last_build_duration_milliseconds
```

### Job Count

```
jenkins_job_count_value
```

### Jobs in Queue

```
jenkins_job_queuing_duration
```

```
sum(jenkins_queue_size_value) by (app_kubernetes_io_instance)
```

## Web Metrics

### HTTP Requests

The 99th percentile of HTTP Requests handled by Jenkins masters.

```
sum(http_requests{quantile="0.99"} ) by (app_kubernetes_io_instance)
```

### Health Check Duration

How long the health check takes to complete at the 99th percentile.
Higher numbers signify problems

```python
sum(rate(jenkins_health_check_duration{ quantile="0.99"}[5m])) 
    by (app_kubernetes_io_instance)
```

### Ingress Performance

```
sum(rate(
  nginx_ingress_controller_request_duration_seconds_bucket{
    le="0.25"
  }[5m]
)) 
by (ingress) /
sum(rate(
  nginx_ingress_controller_request_duration_seconds_count[5m]
)) 
by (ingress)
```

### Number of Good Request vs. Request

```
sum(http_responseCodes_ok_total) 
    by (kubernetes_pod_name) / 
sum(http_requests_count) 
    by (kubernetes_pod_name)
```

## Pod Metrics

### CPU Usage

```
sum(rate(
  container_cpu_usage_seconds_total{
    container_name="jenkins"
  }[5m]
)) 
by (pod_name)
```

### Oversubscription of Pod memory

```
sum (label_join(container_memory_usage_bytes{
    container_name="jenkins"
  }, 
  "pod", 
  ",", 
  "pod_name"
)) by (pod) / 
sum (kube_pod_container_resource_requests_memory_bytes { 
        container="jenkins"
    }
) by (pod)
```

## DevOptics Metrics

* https://go.cloudbees.com/docs/cloudbees-documentation/devoptics-user-guide/run_insights/

### Active Runs

To know how many current builds there are, we can watch the executors that are in use.

```
sum(jenkins_executor_in_use_history) by (app_kubernetes_io_instance)
```

### Idle Executors

When using Kubernetes' Pods as agent, the only *idle* executors we'll have are Pods that are done with their build and in the process of being terminated. Not very useful, but in case you want to know how:

```
sum(jenkins_executor_free_history) by (app_kubernetes_io_instance)
```

### Average Time Waiting to Start

With Kubernetes PodTemplates we cannot calculate this.
The only wait time we get is the one that is between queue'ing a job and requesting the Pod, which isn't very meaningful.

### Completed Runs Per Day

```
sum(increase(jenkins_runs_total_total[24h])) by (app_kubernetes_io_instance)
```

#### Average Time to complete

```
sum(jenkins_job_building_duration) by (app_kubernetes_io_instance) /
    sum(jenkins_job_building_duration_count) by (app_kubernetes_io_instance)
```

