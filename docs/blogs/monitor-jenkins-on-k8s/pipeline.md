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

## Pipeline Example

The tool [Jenkins Pipeline Binary - Monitoring](https://github.com/joostvdg/jpb-mon-go) will retrieve the [Stages Nodes](https://github.com/jenkinsci/blueocean-plugin/tree/master/blueocean-rest#get-pipeline-run-nodes) from Jenkins and translate them to Gauges in Prometheus.

```groovy
pipeline {
    agent {
        kubernetes {
        label 'jpb-mon'
        yaml """
kind: Pod
metadata:
  labels:
    build: prom-test
spec:
  containers:
  - name: jpb
    image: caladreas/jpb-mon:0.17.0
    command: ['/bin/jpb-mon', 'sleep', '--sleep', '3m']
    tty: true
    resources:
      requests:
        memory: "50Mi"
        cpu: "100m"
      limits:
        memory: "50Mi"
        cpu: "100m"
"""
        }
    }
    environment {
        CREDS = credentials('api')
    }
    stages {
        stage('Test1') {
            steps {
                sh 'env'
            }
        }
        stage('Test2') {
            environment {
                MASTER = 'jenkins1'
            }
            steps {
                sh 'echo "Hello World!"'
            }
        }
    }
    post {
        always {
            container('jpb') {
                sh "/bin/jpb-mon get-run --host ${JENKINS_URL} --job ${JOB_BASE_NAME} --run ${BUILD_ID} --username ${CREDS_USR} --password ${CREDS_PSW} --push"
            }
        }
    }
}
```

## Resources

* https://stackoverflow.com/questions/37009906/access-stage-results-in-workflow-pipeline-plugin
* https://github.com/jenkinsci/blueocean-plugin/tree/master/blueocean-rest#get-pipeline-run-nodes
* https://github.com/jenkinsci/pipeline-model-definition-plugin/wiki/Getting-Started
