# Track Metrics of Pipelines

## Get Data From Jobs

* Use Prometheus Push Gateway
    * via shared lib
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

#### Simple

```bash
echo "some_metric 3.14" | curl --data-binary @- http://pushgateway.example.org:9091/metrics/job/some_job
```

#### Complex

```bash
cat <<EOF | curl --data-binary @- http://pushgateway.example.org:9091/metrics/job/some_job/instance/some_instance
  # TYPE some_metric counter
  some_metric{label="val1"} 42
  # TYPE another_metric gauge
  # HELP another_metric Just an example.
  another_metric 2398.283
  EOF
```

#### Delete by instance

```bash
curl -X DELETE http://pushgateway.example.org:9091/metrics/job/some_job/instance/some_instance
```

#### Delete by (prometheus) job

```bash
curl -X DELETE http://pushgateway.example.org:9091/metrics/job/some_job
```

### Go lang client

## Queries

### Total Stages Duration In Seconds

```
sum(jenkins_pipeline_run_stages_hist_sum) by (jobName, runId) / 1000
```

### Coverage Metric

```bash
jenkins_pipeline_run_test_coverage
```

### Last Push Of Metric

```bash
time() - push_time_seconds
```


### Stage Statusses

```
m
```

### ??

```bash
(sum(jenkins_pipeline_run_hist_sum) by (jobName) / 1000) / 
    sum(jenkins_pipeline_run_hist_count) by  (jobName)
```

```
sum(jenkins_pipeline_run_hist_sum) by (jobName, runId)
```

```
sum(jenkins_pipeline_run_hist_count) by (instance, appId)
```

```
sum(jenkins_pipeline_run_stages_hist_sum) by (instance, jobName, runId)
```

```
sum(jenkins_pipeline_run_hist_count  offset 3d) by (jobName) 
```

```
sum(jenkins_pipeline_run_hist_count) by (jobName) 
```

### Success Rate of Stages

```
 count(jenkins_pipeline_run_hist_sum{ result="SUCCESS"}) by (jobName, runId) /  count(jenkins_pipeline_run_hist_sum) by (jobName, runId)
```

## Github Autostatus

* install influxDB
    * configure influxDB into Grafana as Datasource
* install plugin in Jenkins
    * Plugin: https://plugins.jenkins.io/github-autostatus
    * configure in jenkins config to us influxdb
* import dashboard into Grafana
    * `5786`
    * `SELECT "jobtime", "buildnumber", "passed", "branch", "buildurl" FROM "job" WHERE ("owner" = 'joostvdg') AND $timeFilter GROUP BY "repo"`

## Things to look at

* Scraping of Gateway means metrics are retrieved more often than they are created
    * you can reduce the error by creating a rewrite rule
    * https://www.robustperception.io/aggregating-across-batch-job-runs-with-push_time_seconds
* Counter does not aggregate
    * https://stackoverflow.com/questions/50923880/prometheus-intrumentation-for-distributed-accumulated-batch-jobs
    * if you want aggregation, use Prometheus Aggregation Gateway from Weaveworks
    * https://github.com/weaveworks/prom-aggregation-gateway
* 

## Pipeline Example - Curl

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
  - name: curl
    image: byrnedo/alpine-curl
    command: ["cat"]
    tty: true
  - name: golang
    image: golang:1.9
    command: ["cat"]
    tty: true
"""
        }
    }
    environment {
        CREDS           = credentials('api')
        TEST_COVERAGE   = ''
        PROM_URL        = 'http://prometheus-pushgateway.obs:9091/metrics/job/devops25'
    }
    stages {
        stage('Checkout') {
            steps {
                git 'https://github.com/joostvdg/go-demo-5.git'
            }
        }
        stage('Prepare') {
            steps {
                container('golang') {
                    sh 'go get -d -v -t'
                }
            }
        }
        stage('Build & Test') {
            steps {
                container('golang') {
                    script {
                        sh 'go build'
                        def coverage = sh encoding: 'UTF-8', label: 'go test', returnStdout: true, script: 'go test --cover -v ./... --run UnitTest | grep coverage:'
                        coverage = coverage.trim()
                        coverage = coverage.replace('coverage: ', '')
                        coverage = coverage.replace('% of statements', '')
                        TEST_COVERAGE = "${coverage}"
                        println "coverage=${coverage}"
                    }
                    sh 'ls -lath'
                }
            }
        }
        stage('Push Metrics') {
            environment {
                COVERAGE = "${TEST_COVERAGE}"
            }
            steps {
                println "COVERAGE=${COVERAGE}"
                container('curl') {
                    sh 'echo "TEST_COVERAGE=${COVERAGE}"'
                    sh 'echo "PROM_URL=${PROM_URL}"'
                    sh 'echo "BUILD_ID=${BUILD_ID}"'
                    sh 'echo "JOB_NAME=${JOB_NAME}"'
                    sh 'echo "jenkins_pipeline_run_test_coverage{instance=\"$JENKINS_URL\",jobName=\"$JOB_NAME\", run=\"$BUILD_ID\"} ${TEST_COVERAGE}" | curl --data-binary @- ${PROM_URL}'
                }
            }
        }
    }
}
```

## Pipeline Example - CLI

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
    build: prom-test-4
spec:
  containers:
  - name: jpb
    image: caladreas/jpb-mon:0.23.0
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
                print 'Hello World'
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
                sh "/bin/jpb-mon get-run --verbose --host ${JENKINS_URL} --job ${JOB_NAME} --run ${BUILD_ID} --username ${CREDS_USR} --password ${CREDS_PSW} --push"
            }
        }
    }
}
```

## Resources

* https://stackoverflow.com/questions/37009906/access-stage-results-in-workflow-pipeline-plugin
* https://github.com/jenkinsci/blueocean-plugin/tree/master/blueocean-rest#get-pipeline-run-nodes
* https://github.com/jenkinsci/pipeline-model-definition-plugin/wiki/Getting-Started
