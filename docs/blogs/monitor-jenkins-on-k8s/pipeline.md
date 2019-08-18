# Track Metrics of Pipelines

## Get Data From Jobs

* Use Prometheus Push Gateway
** via shared lib
* JX sh step -> tekton -> write interceptor

## Configure Prometheus Push Gateway

* Make sure it is enabled in the `prometheus` helm chart

```yaml
pushgateway:
  enabled: true
```

## Identification Data

* canonical FQN:
    * application ID
    * source URI

## Questions to answer

### Metrics to gather

* test coverage
* shared libraries used
* duration of stages
* duration of job
* status of job
* status of stage
* time-to-fix
* git source
* node label
* languages (github languages parser)

#### Test Coverage

Send a `Gauge` with coverage as value.

Potential Labels:

* Application ID
* Source URI
* Job
* Instance
* RunId

## Send Metric From Jenkins Pipeline

### Bash

### Go lang client

## Queries

### Total Stages Duration In Seconds

```
sum(jenkins_pipeline_run_stage) by (jobName, runId) / 1000
```


## Resources

* https://stackoverflow.com/questions/37009906/access-stage-results-in-workflow-pipeline-plugin
* https://github.com/jenkinsci/blueocean-plugin/tree/master/blueocean-rest#get-pipeline-run-nodes
* https://github.com/jenkinsci/pipeline-model-definition-plugin/wiki/Getting-Started
