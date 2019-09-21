
title: Jenkins Kubernetes Monitoring
description: Monitoring Jenkins On Kubernetes - Metrics - 4/8
hero: Metrics - 4/8

# Metrics

Jenkins is a Java Web application, in this case running in Kubernetes.
Let's categorize the metrics we want to look at and deal with each group individually.

* `JVM`: the JVM metrics are exposed, we should leverage this for particular queries and alerts
* `Jenkins Configuration`: the default configuration exposes some configuration elements, a few of these have strong recommended values, such as `Master Executor Slots` (should always be **0**)
* `Jenkins Usage`: jobs running in Jenkins, or Jobs *not* running in Jenkins can also tell us about (potential) problems
* `Web`: although it is not the primary function of Jenkins, web access gives hints about performance trends
* `Pod Metrics`: any generic metric from a Kubernetes Pod perspective can be helpful to look at

!!!	caution "Kubernetes Labels"
	This guide assumes you install Jenkins via the Helm chart as explained elsewhere in the guide. This means it assumes the Jenkins instances all have the label `app.kubernetes.io/instance`. In Prometheus, this becomes `app_kubernetes_io_instance`. 

	If you install your applications (such as Jenkins) in other ways, either change the queries presented here accordingly or add the label.

## Types of Metrics to evaluate

We are in the age where SRE, DevOps Engineer, and Platform Engineer are hyped terms. Hyped they may be, there is a good reason people are making noise about monitoring. A lot is written about which kinds of metrics to observe and which to ignore. There's enough written about this - including Viktor Farcic's excellent DevOps Toolkit 2.5 - so we skip diving into these. In case you haven't read anything about it, let's briefly look at the types of metrics.

* `Latency`: response times of your application, in our case, both external access via Ingress and internal access. We can measure latency on internal access via Jenkins' own metrics, which also has percentile information (for example, p99)
* `Errors`: we can take a look at network errors such as HTTP 500, which we get straight from Jenkins' webserver (Netty) and at failed jobs
* `Traffic`: the number of connections to our service, in our case we have web traffic and jobs running, both we get from Jenkins
* `Saturation`: how much the system is used compared to the available resources, core resources such as CPU and Memory primarily depend on your Kubernetes Nodes. However, we can take a look at the Pod's limits vs. requests and Jenkins' job wait time - which roughly translates to saturation

## JVM Metrics

We have some basic JVM metrics, such as CPU and Memory usage, and uptime. 

!!! note "Uptime"
	In the age of containers,  `uptime` is not a very useful or *sexy* metric to observe. I include it because we can use `uptime` as a proxy metric. For example, if a service never goes beyond a particular value - Prometheus records Max values - it can signify a problem elsewhere.

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

For fine-tuning the JVM's garbage collection for Jenkins, there are two central guides from CloudBees. Which also explain the `JVM_OPTIONS` in the `jenkins-values.yaml` we used for the Helm installation.

* [Guide On Preparing Jenkins For Support](https://support.cloudbees.com/hc/en-us/articles/222446987-Prepare-Jenkins-for-Support)
* [JVM Troubleshooting Guide](https://go.cloudbees.com/docs/solutions/jvm-troubleshooting/) 

The second article contains much information on how to analyze the Garbage Collection logs and metrics. To process the data thoroughly requires experts with specially designed tools. I am not such an expert, nor is this the document to guide you through this. Summarizing the two guides: measure core metrics and Garbage Collection Throughput. If you need more, consult experts.

!!!	example "Garbage Collection Throughput"
	```
    1 -sum(
        rate(
            vm_gc_G1_Young_Generation_time[5m]
        )
    ) by (app_kubernetes_io_instance) 
    / 
    sum (
        vm_uptime_milliseconds
    ) by (app_kubernetes_io_instance)
	```

### Check for too many open files

When looking at the CloudBees guide on [tuning performance on Linux](https://support.cloudbees.com/hc/en-us/articles/115000486312-CloudBees-Core-Performance-Best-Practices-for-Linux), one of the main things to look are core metrics (Memory and CPU) and Open Files. There's even an explicit guide [on monitoring the number of open files](https://support.cloudbees.com/hc/en-us/articles/204246140-Too-many-open-files).

```
vm_file_descriptor_ratio
```

## Jenkins Config Metrics

Some of the metrics are derived from the configuration of a Jenkins Master.

### Plugins

While Jenkins' extensive community is often praised for the number of plugins created and maintained, the plugins are also a big source of risk. You probably want to set a baseline and determine a value for when to send an alert.

```
jenkins_plugins_active
```

### Jenkins Build Nodes

Jenkins should never build on a master, always on a node or agent.

```
jenkins_executor_count_value
```

You might use static agents or, while we're in Kubernetes, only have dynamic agents. Either way, having nodes offline for a while signifies a problem. Maybe the Node configuration is wrong, or the PodTemplate has a mistake, or maybe your ServiceAccount doesn't have the correct permissions.

```
jenkins_node_offline_value
```

## Jenkins Usage Metrics

Most of Jenkins' metrics relate to its usage, though. Think about metrics regarding HTTP request duration, number server errors (HTTP 500), and all the metrics related to builds.

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

If a Jenkins master is overloaded, it is likely to fall behind building jobs that are scheduled. Jenkins observes the duration a job spends in the queue (`jenkins_job_queuing_duration`) and the current queue size (`jenkins_queue_size_value`).

```
jenkins_job_queuing_duration
```

```
sum(jenkins_queue_size_value) by (app_kubernetes_io_instance)
```

## Web Metrics

As Jenkins is also a web application, it makes to look at its HTTP related metrics as well. 

!!!	important "Route Of External Traffic"
	It is important to note that the HTTP traffic of user interaction with Jenkins when running in Kubernetes can contain quite a lot of layers. Problems can arise in any of these layers, so it is crucial to monitor traffic to a service on multiple layers to speed debug time. Tracing is a great solution but out of scope for this guide.

### HTTP Requests

The 99th percentile of HTTP Requests handled by Jenkins masters. 

```
sum(http_requests{quantile="0.99"} ) by (app_kubernetes_io_instance)
```

!!!	note "99th percentile"
	We look at percentiles because average times are not very helpful. For more information on why this is so, please [consult the Google SRE book](https://landing.google.com/sre/sre-book/chapters/monitoring-distributed-systems/) which is free online.

### Health Check Duration

How long the health check takes to complete at the 99th percentile.
Higher numbers signify problems.

```python
sum(rate(jenkins_health_check_duration{ quantile="0.99"}[5m])) 
 by (app_kubernetes_io_instance)
```

### Ingress Performance

In this case, we look at the metrics of the Nginx Ingress Controller. If you use a different controller, rewrite the query to a sensible alternative.

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

These metrics are purely related to the Kubernetes Pods. They are as such, applicable to more applications than just Jenkins.

### CPU Usage

```
sum(rate(
 container_cpu_usage_seconds_total{
 container_name="jenkins*"
 }[5m]
)) 
by (pod_name)
```

!!!	note "Query Filters"
	In this case, we filter on those containers with name `jenkins*`, which means any container whose name has *jenkins* as the prefix. If you want to have more than one prefix or suffix, you can use `||`. 

	So, if you would want to combine Jenkins with, let's say, `prometheus`, you will get the following.

	```
	container_name="jenkins*||prometheus*"
	```

### Oversubscription of Pod memory

While `requests` are not meant to be binding, if you think your application requests around 1GB and it is using well over 3GB, something is off. Either you are too naive and should update the `requests`, or something is wrong, and you need to take action.

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

CloudBees made parts of its DevOptics product free. This product contains - amongst other things - a feature set called [Run Insights](https://go.cloudbees.com/docs/cloudbees-documentation/devoptics-user-guide/run_insights/). This is a monitoring solution where your Jenkins Master uploads its metrics to the CloudBees service, and you get a dashboard with many of the same things already discussed.

You might not want to leverage this free service but like some of its dashboard features. I've tried to recreate some of these - in a minimal fashion.

### Active Runs

To know how many current builds there are, we can watch the executors that are in use.

```
sum(jenkins_executor_in_use_history) by (app_kubernetes_io_instance)
```

### Idle Executors

When using Kubernetes' Pods as an agent, the only *idle* executors we'll have are Pods that are done with their build and in the process of being terminated. Not very useful, but in case you want to know how:

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

