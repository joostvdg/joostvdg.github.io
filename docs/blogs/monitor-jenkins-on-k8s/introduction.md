# Introduction

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
* https://sysdig.com/blog/golden-signals-kubernetes/
* https://stackoverflow.com/questions/47141967/how-to-use-the-selected-period-of-time-in-a-query/47173828#47173828
* https://www.robustperception.io/rate-then-sum-never-sum-then-rate
* https://www.innoq.com/en/blog/prometheus-counters/
* https://www.robustperception.io/dont-put-the-value-in-alert-labels
* https://blog.pvincent.io/2017/12/prometheus-blog-series-part-5-alerting-rules/
* https://docs.google.com/document/d/199PqyG3UsyXlwieHaqbGiWVa8eMWi8zzAn0YfcApr8Q/edit
* https://wiki.jenkins.io/display/JENKINS/Metrics+Plugin
* https://www.robustperception.io/controlling-the-instance-label
* https://www.robustperception.io/target-labels-are-for-life-not-just-for-christmas
* https://prometheus.io/docs/alerting/notifications/
* https://piotrminkowski.wordpress.com/2017/08/29/visualizing-jenkins-pipeline-results-in-grafana/
* https://medium.com/@jotak/designing-prometheus-metrics-72dcff88c2e5
* https://github.com/prometheus/pushgateway
* https://github.com/prometheus/client_golang
* https://blog.pvincent.io/2017/12/prometheus-blog-series-part-2-metric-types/
* https://prometheus.io/docs/concepts/jobs_instances/
