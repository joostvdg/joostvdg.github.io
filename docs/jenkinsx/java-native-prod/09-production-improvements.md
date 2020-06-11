title: Jenkins X - Java Native Image Prod
description: Creating a Java Native Image application and run it as Production with Jenkins X - Production Improvements - 9/10
hero: Production Improvements - 9/10

# Production Improvements

Now that we have more tests and validations in our application, we focus our attention on how the application is running. Things like logging, metrics, and tracing.

There are again, more than a dozen things we can do to keep tabs on our application in Production. Instead, we will dive into three common things that are easy to do in Kubernetes and supported by Quarkus.

1. Logging, with Sentry
1. Monitoring Metrics with Prometheus & Grafana
1. Tracing with OpenTracing & Jaeger

## Code Start

If you do not have a working version after the previous chapter, you can find the complete working code in the [branch 08-previews](https://github.com/joostvdg/quarkus-fruits/tree/08-previews).

## Logging

There are a many ways you can deal with Logging. You can make use of the [ELK Stack](https://www.elastic.co/elastic-stack) (ElasticSearch, Logstash and Kibana), [Grafana's Loki](https://grafana.com/oss/loki/), or Public Cloud services such as [Google's Operations](https://cloud.google.com/products/operations) (formerly Stackdriver) or [AWS's CloudWatch](https://docs.aws.amazon.com/AmazonCloudWatch/latest/logs/WhatIsCloudWatchLogs.html).

While they're great for a whole class or problems, depending on your needs, there are free SaaS solutions that can cover what you need. Two that I've used are [Papertrail](https://www.papertrail.com) and [Sentry](https://sentry.io/). Personally, I'm quite happy with my hobby applications using Sentry - in the Free tier. Add the fact that it is [natively supported by Quarkus](https://quarkus.io/guides/logging-sentry), and I think I can get away with selecting Sentry for this exercise.

If you don't agree, or want to use an alternative solution, [skip ahead to the monitoring paragraph](#Monitoring).

!!! info
    Sentry also has a self-hosting option, so you do not _have_ to use the SaaS if you don't want to.

    I recommend to use the SaaS, but if you can't or prefer to selve host, you can use the official docker container or the [Helm Chart](https://github.com/helm/charts/tree/master/stable/sentry).

### Steps

* Create an account on [sentry.io](sentry.io) and create a new `project`. 
    * or, host your own, and then create a new `project`
* add sentry dependency to `pom.xml`
* retrieve Sentry DSN for you application
* add Sentry DSN into Vault
* add Kubernetes secret to templates mounting the vault secret as Kubernetes secret
* bind Kubernetes secret to Deployment
* configure Sentry logging

### Create Sentry Project & Retrieve SDN

First, create a new Project.

Then, to retrieve the DSN:

* `Settings` -> `Projects` -> `<Select Your Project>` -> `Client Keys(DSN)`

### Quarkus Sentry Dependency

!!! example "pom.xml"

    ```xml
    <dependency>
        <groupId>io.quarkus</groupId>
        <artifactId>quarkus-logging-sentry</artifactId>
    </dependency>
    ```

### Add secret to Vault

We have to add the secret to Vault.

If you've forgotten how to do this, you can ask Jenkins X for the URL and the Token to login.

```sh
jx get vault-config
```

After that, nagivate to `secrets/quarkus-fruits`, and create a new version of the secret.
Add a new Key/Value pair with `SENTRY_DSN` as the Key, the DSN value as the Value.

### Add secret placeholder to values.yaml

As Sentry can automatically detect which environment the application is running in, you don't need to have different authentication per environment. So we're free to use a _global_ secret - one secret for all environment.

!!! example "charts/Name-Of-Your-Application/value.yaml"

    ```yaml hl_lines="5"
    secrets:
      sql_password: ""
      sql_connection: ""
      sqlsa: ""
      sentry_dsn: vault:quarkus-fruits:SENTRY_DSN
    ```

### Sentry DSN Secret

We create a Kubernetes secret in our Chart's template folder.
This way we can mount the secret as an environment variable 

The Sentry SDK automatically picks up the environment variable `SENTRY_DSN`, so we don't have to configure anything 7else to get it to work. The SDK is OK with not having the configuration as well, so for local tests or our builds we're fine without it.

!!! example "charts/Your-Application-Name/templates/sentry-dsn-secret.yaml"

    ```yaml
    apiVersion: v1
    kind: Secret
    metadata:
      name: {{ template "fullname" . }}-sentry-dsn
    type: Opaque
    data:
      SENTRY_DSN: {{ .Values.secrets.sentry_dsn | b64enc }}
    ```

### Update Deployment manifest

Now that we have the Kubernetes secret, have to add the Sentry secret to our application's Container in the Deployment manifest.

```yaml
envFrom:
  - secretRef:
      name: {{ template "fullname" . }}-sentry-dsn
```

Our Deployment now looks like this (at least, the section related to our container):

!!! example "charts/Name-Of-Your-Application/templates/deployment.yaml"
    
    ```yaml hl_lines="12 13"
          - name: {{ .Chart.Name }}
            image: "{{ .Values.image.repository }}:{{ .Values.image.tag }}"
            imagePullPolicy: {{ .Values.image.pullPolicy }}
            env:
    {{- range $pkey, $pval := .Values.env }}
            - name: {{ $pkey }}
              value: {{ quote $pval }}
    {{- end }}
            envFrom:
            - secretRef:
                name: {{ template "fullname" . }}-sql-secret
            - secretRef:
                name: {{ template "fullname" . }}-sentry-dsn
    ```

### Configure Logging

The last bit to get Sentry & Quarkus work their magic, is to configure the logging in our applications's properties file.

!!! example "src/main/resources/application.properties"

    ```properties
    quarkus.log.sentry=true
    quarkus.log.sentry.dsn=${SENTRY_DSN}
    quarkus.log.sentry.level=WARN
    quarkus.log.sentry.in-app-packages=com.github.joostvdg
    ```

!!! important
    I've configured my personal package root, `com.github.joostvdg`, replace this with the package name of your application!

## Monitoring

As we're running Jenkins X, we run in Kubernetes. 
The most commonly used monitoring solution with Kubernetes is Prometheus and Grafana.

Quarkus has out-of-the-box support for exposing prometheus metrics, via the `smallrye-metrics` library.

To create a Grafana dashboard for our application, we need to take the following steps:

* ensure we have Prometheus and Grafana installed in our cluster
* add dependency on Quarkus' `smallrye-metrics` library
* add (Kubernetes) annotations to our Helm Chart's Deployment manifest
* add (Java) annotations to our code, specifying the metrics

For more information on adding metrics to your Quarkus application, [read the Quarkus Metrics guide](https://quarkus.io/guides/microprofile-metrics).

### Install Promtheus & Grafana

The easiest way to install Promtheus and Grafana is via a Helm Chart.

While they are commonly used together, they have their own Helm Charts.

#### Prometheus

Prometheus is part of Helm's stable charts, and [you can find it here](https://github.com/helm/charts/tree/master/stable/prometheus).

The Prometheus Helm Chart is weldefined, so for testing purposes, there's nothing you need to configure. 
I recommend you go through the options if this will be a (near)permanent installation.

=== "Helm v3"
    ```sh
    helm install prometheus stable/prometheus  --namespace ${NAMESPACE}
    ```
=== "Helm v2"
    ```sh
    helm install --name prometheus stable/prometheus  --namespace ${NAMESPACE}
    ```

#### Grafana

[Grafana's Helm Chart](https://github.com/helm/charts/tree/master/stable/grafana) is also part Helm's stable chart list.

##### Values

Grafana does have some [values](https://github.com/helm/charts/tree/master/stable/grafana#configuration) we have to set. I recommend setting the persistence to enabled and the persistence type to `statefulset`. This ensures that dashboards you install or create survice restarts, quite useful.

One thing you have to configure, is the `ingress`, else you cannot access your Grafana installation. Below is an example configuration, you have to replace the hosts' configuration with yours. And if you do not have TLS enabled, remove the TLS segment.

I also included how you can configure dashboards out of the box. One of doing so that is, this allows you to add public dashboards by their ID. Visit the [Grafana public Dashboards page](https://grafana.com/grafana/dashboards) to explore what the community has to offer.

!!! example "grafana-values.yaml"

    ```yaml    
    persistence:
      enabled: true
      type: statefulset
    ingress:
      annotations:
        kubernetes.io/ingress.class: nginx
        kubernetes.io/tls-acme: "true"
      enabled: true
      hosts:
      - grafana.example.com
      tls:
      - hosts:
        - grafana.example.com
        secretName: tls-grafana-p
    dashboardProviders:
      dashboardproviders.yaml:
        apiVersion: 1
        providers:
        - disableDeletion: true
          editable: true
          folder: default
          name: Default
          options:
            path: /var/lib/grafana/dashboards/default
          orgId: 1
          type: file
    dashboards:
      default:
        Capacity:
          datasource: Prometheus
          gnetId: 5228
          revision: 6
    ```

##### Install

=== "Helm v3"
    ```sh
    helm install grafana stable/grafana -f grafana-values.yaml  --namespace ${NAMESPACE}
    ```
=== "Helm v2"
    ```sh
    helm install --name grafana stable/grafana -f grafana-values.yaml  --namespace ${NAMESPACE}
    ```

#### Prometheus & Grafana in Jenkins X Environment

You can also opt for installing Prometheus and Grafana as a dependency in a Jenkins X environment. There are two ways of creating custom - e.g. not Dev, Staging or Production - environment in Jenkins X. If you want the environment to be part of your `jx boot` installation, [I've written a how to guide on that](https://joostvdg.github.io/jenkinsx/jxboot/#add-environment).

If you want a shortcut, there's the [jx create environment](https://jenkins-x.io/commands/jx_create_environment/) command. This creates a proper Jenkins X environment, but it isn't managed via `jx boot`. 

Either way, the end result is pretty similar. You end up with a Git repository for this environment. In here, you can add Helm Chart dependencies in `env/requirements.yaml`, and specify their values in `env/values.yaml`.

As this is written, May 2020, Jenkins X still relies on Helm v2.
You can read about how [Helm v2 works with dependencies here](https://v2.helm.sh/docs/glossary/#chart-dependency-subcharts).

### Add quarkus-smallrye-metrics Dependency

To make our application expose metrics, default or custom, in a way that Prometheus can scrape, we add the `quarkus-smallrye-metrics` dependency.

!!! example "pom.xml"

    ```xml
    <dependency>
      <groupId>io.quarkus</groupId>
      <artifactId>quarkus-smallrye-metrics</artifactId>
    </dependency>
    ```

### Update Deployment manifest

By default, Prometheus is a bit shy and doesn't scrape your metrics. If you want Prometheus to do so, you have to tell it, it's ok. We do so by setting an annotation in the `templates/deployment.yaml`. 

We add two annotations, we add `prometheus.io/port: "8080"` to tell Prometheus on which port to talk to our application. And `prometheus.io/scrape: "true"`, to say that it is oke to scrape our application.

!!! example "templates/deployment.yaml"

    ```yaml hl_lines="6 7 8"
      template:
        metadata:
          labels:
            draft: {{ default "draft-app" .Values.draft }}
            app: {{ template "fullname" . }}
          annotations:
            prometheus.io/port: "8080"
            prometheus.io/scrape: "true"
    {{- if .Values.podAnnotations }}
    {{ toYaml .Values.podAnnotations | indent 8 }} #Only for pods
    {{- end }}
        spec:
    ```

!!! important
    Be sure to move the line `{{- if .Values.podAnnotations }}` so that `annotations:` is always set.


### Add Metrics Annotations to our Code

When you add the metrics dependency, some metrics are exposed by default. These might not say much about your application, so it is advisable to investigate what information you want to get and how to configure that.

For example, on the `findAll()` method, for the `/fruits` endpoint, we can add a counter - how many times is this endpoint called - and a timer - various percentile buckets on the duration of the call:

```java
@Counted(name = "fruit_get_all_count", description = "How many times all Fruits have been retrieved.")
@Timed(name = "fruit_get_all_timer", description = "A measure of how long it takes to retrieve all Fruits.", unit = MetricUnits.MILLISECONDS)
```

Look at [FruitResource.java](https://github.com/joostvdg/jx-quarkus-demo-01/blob/master/src/main/java/com/github/joostvdg/jx/quarkus/fruits/FruitResource.java) for all the metrics I've added as examples.

For information on these, I recommend taking another look at [the Quarkus Metrics guide](https://quarkus.io/guides/microprofile-metrics).

### Configure Grafana

If you used this guide's examples for installing Prometheus and Grafana, you have to configure at least a datasource.

We do this by logging into Grafana, and opening the Data Sources screen: left hand side, `Configuration` -> `Data Sources`.

Click `Add data source`, and select `Prometheus` as the type of data source.
The only field you have to change, is `URL`. Set the value below, and hit `Save & Test`.

```sh
http://prometheus-server:80
```

Now we can go to the `Dashboards` screen and create a dashboard.
I leave it up to you to create one to your liking, visit [grafana.com/tutorials](https://grafana.com/tutorials/) to learn more.

If you want to be lazy, use the dashboard JSON below.
Hover over the `Dashboards` menu, and select `Manage`.

Click on `Import`, and paste the `JSON` in the `Import via panel json` field and hit `Load`.

Visit [grafana.com/grafana/dashboards](https://grafana.com/grafana/dashboards?orderBy=name&direction=asc) for more pre-designed dashboards.

!!! info

    If you've used the Helm install above to install Grafana, you can retrieve its password with the command below.

    ```sh
    kubectl get secret --namespace ${NAMESPACE} grafana -o jsonpath="{.data.admin-password}" | base64 --decode ; echo
    ```

### Empty Dashboard

If you have an empty dashboard, it could be because your application has a different name.

If this is the case, go to the `dashboard settings` - top right, gear icon - -> `Variables` (left menu) -> `app`, and hit `Update` at the bottom. 

In the section `Preview of values`, the name of your application should now be visible.

### Dashboard JSON

This is an example Grafana dashboard for the this application. You likely have to change the queries to reflect the name of your applcation.

??? example "grafana-quarkus-app-dashboard-example.json"

    ```json
    {
      "annotations": {
        "list": [
          {
            "builtIn": 1,
            "datasource": "-- Grafana --",
            "enable": true,
            "hide": true,
            "iconColor": "rgba(0, 211, 255, 1)",
            "name": "Annotations & Alerts",
            "type": "dashboard"
          }
        ]
      },
      "editable": true,
      "gnetId": null,
      "graphTooltip": 0,
      "id": 3,
      "iteration": 1591881137283,
      "links": [],
      "panels": [
        {
          "cacheTimeout": null,
          "datasource": null,
          "fieldConfig": {
            "defaults": {
              "custom": {},
              "mappings": [],
              "thresholds": {
                "mode": "absolute",
                "steps": [
                  {
                    "color": "green",
                    "value": null
                  },
                  {
                    "color": "red",
                    "value": 80
                  }
                ]
              }
            },
            "overrides": []
          },
          "gridPos": {
            "h": 3,
            "w": 7,
            "x": 0,
            "y": 0
          },
          "id": 4,
          "links": [],
          "options": {
            "colorMode": "value",
            "graphMode": "area",
            "justifyMode": "auto",
            "orientation": "auto",
            "reduceOptions": {
              "calcs": [
                "mean"
              ],
              "values": false
            }
          },
          "pluginVersion": "7.0.1",
          "targets": [
            {
              "expr": "sum(base_thread_count{app=\"$app\"}) by (app)",
              "interval": "",
              "legendFormat": "{{app}}",
              "refId": "A"
            }
          ],
          "timeFrom": null,
          "timeShift": null,
          "title": "Threads",
          "type": "stat"
        },
        {
          "cacheTimeout": null,
          "colorBackground": true,
          "colorPostfix": false,
          "colorPrefix": false,
          "colorValue": false,
          "colors": [
            "#d44a3a",
            "rgba(237, 129, 40, 0.89)",
            "#299c46"
          ],
          "datasource": null,
          "decimals": 1,
          "fieldConfig": {
            "defaults": {
              "custom": {}
            },
            "overrides": []
          },
          "format": "s",
          "gauge": {
            "maxValue": 100,
            "minValue": 0,
            "show": false,
            "thresholdLabels": false,
            "thresholdMarkers": true
          },
          "gridPos": {
            "h": 3,
            "w": 10,
            "x": 7,
            "y": 0
          },
          "id": 6,
          "interval": null,
          "links": [],
          "mappingType": 1,
          "mappingTypes": [
            {
              "name": "value to text",
              "value": 1
            },
            {
              "name": "range to text",
              "value": 2
            }
          ],
          "maxDataPoints": 100,
          "nullPointMode": "connected",
          "nullText": null,
          "postfix": "",
          "postfixFontSize": "50%",
          "prefix": "",
          "prefixFontSize": "50%",
          "rangeMaps": [
            {
              "from": "null",
              "text": "N/A",
              "to": "null"
            }
          ],
          "sparkline": {
            "fillColor": "rgba(31, 118, 189, 0.18)",
            "full": false,
            "lineColor": "rgb(31, 120, 193)",
            "show": false,
            "ymax": null,
            "ymin": null
          },
          "tableColumn": "jx-quarkus-fruits ",
          "targets": [
            {
              "expr": "sum(base_jvm_uptime_seconds{app=\"$app\"}) by (app)",
              "interval": "",
              "legendFormat": "{{app}} ",
              "refId": "A"
            }
          ],
          "thresholds": "0,3600",
          "timeFrom": null,
          "timeShift": null,
          "title": "Uptime",
          "type": "singlestat",
          "valueFontSize": "150%",
          "valueMaps": [
            {
              "op": "=",
              "text": "N/A",
              "value": "null"
            }
          ],
          "valueName": "current"
        },
        {
          "cacheTimeout": null,
          "colorBackground": true,
          "colorValue": false,
          "colors": [
            "#299c46",
            "rgba(237, 129, 40, 0.89)",
            "#d44a3a"
          ],
          "datasource": null,
          "fieldConfig": {
            "defaults": {
              "custom": {}
            },
            "overrides": []
          },
          "format": "none",
          "gauge": {
            "maxValue": 100,
            "minValue": 0,
            "show": false,
            "thresholdLabels": false,
            "thresholdMarkers": true
          },
          "gridPos": {
            "h": 3,
            "w": 6,
            "x": 17,
            "y": 0
          },
          "id": 10,
          "interval": null,
          "links": [],
          "mappingType": 1,
          "mappingTypes": [
            {
              "name": "value to text",
              "value": 1
            },
            {
              "name": "range to text",
              "value": 2
            }
          ],
          "maxDataPoints": 100,
          "nullPointMode": "connected",
          "nullText": null,
          "pluginVersion": "6.7.3",
          "postfix": "",
          "postfixFontSize": "50%",
          "prefix": "",
          "prefixFontSize": "150%",
          "rangeMaps": [
            {
              "from": "null",
              "text": "N/A",
              "to": "null"
            }
          ],
          "sparkline": {
            "fillColor": "rgba(31, 118, 189, 0.18)",
            "full": false,
            "lineColor": "rgb(31, 120, 193)",
            "show": false,
            "ymax": null,
            "ymin": null
          },
          "tableColumn": "{app=\"jx-quarkus-fruits\"}",
          "targets": [
            {
              "expr": "sum(application_com_github_joostvdg_demo_jx_quarkusfruits_FruitResource_fruit_get_all_count_total{ app=\"$app\"}) by (app)",
              "interval": "",
              "legendFormat": "",
              "refId": "A"
            }
          ],
          "thresholds": "",
          "timeFrom": null,
          "timeShift": null,
          "title": "Fruits GetAll Counter",
          "type": "singlestat",
          "valueFontSize": "150%",
          "valueMaps": [
            {
              "op": "=",
              "text": "N/A",
              "value": "null"
            }
          ],
          "valueName": "current"
        },
        {
          "aliasColors": {},
          "bars": false,
          "dashLength": 10,
          "dashes": false,
          "datasource": null,
          "fieldConfig": {
            "defaults": {
              "custom": {}
            },
            "overrides": []
          },
          "fill": 1,
          "fillGradient": 0,
          "gridPos": {
            "h": 7,
            "w": 12,
            "x": 0,
            "y": 3
          },
          "hiddenSeries": false,
          "id": 8,
          "legend": {
            "avg": false,
            "current": false,
            "max": false,
            "min": false,
            "show": true,
            "total": false,
            "values": false
          },
          "lines": true,
          "linewidth": 1,
          "nullPointMode": "null",
          "options": {
            "dataLinks": []
          },
          "percentage": false,
          "pointradius": 2,
          "points": false,
          "renderer": "flot",
          "seriesOverrides": [],
          "spaceLength": 10,
          "stack": false,
          "steppedLine": false,
          "targets": [
            {
              "expr": "sum(rate(base_gc_time_total_seconds{app=\"$app\"}[5m])) by (app)",
              "interval": "",
              "legendFormat": "{{app}}",
              "refId": "A"
            }
          ],
          "thresholds": [],
          "timeFrom": null,
          "timeRegions": [],
          "timeShift": null,
          "title": "GC Time Spent Rate",
          "tooltip": {
            "shared": true,
            "sort": 0,
            "value_type": "individual"
          },
          "type": "graph",
          "xaxis": {
            "buckets": null,
            "mode": "time",
            "name": null,
            "show": true,
            "values": []
          },
          "yaxes": [
            {
              "format": "s",
              "label": null,
              "logBase": 1,
              "max": null,
              "min": null,
              "show": true
            },
            {
              "format": "s",
              "label": null,
              "logBase": 1,
              "max": null,
              "min": null,
              "show": true
            }
          ],
          "yaxis": {
            "align": false,
            "alignLevel": null
          }
        },
        {
          "aliasColors": {},
          "bars": false,
          "dashLength": 10,
          "dashes": false,
          "datasource": null,
          "fieldConfig": {
            "defaults": {
              "custom": {}
            },
            "overrides": []
          },
          "fill": 2,
          "fillGradient": 6,
          "gridPos": {
            "h": 7,
            "w": 11,
            "x": 12,
            "y": 3
          },
          "hiddenSeries": false,
          "id": 2,
          "legend": {
            "alignAsTable": true,
            "avg": false,
            "current": false,
            "max": false,
            "min": false,
            "show": true,
            "total": false,
            "values": false
          },
          "lines": true,
          "linewidth": 2,
          "nullPointMode": "null",
          "options": {
            "dataLinks": []
          },
          "percentage": false,
          "pointradius": 2,
          "points": false,
          "renderer": "flot",
          "seriesOverrides": [],
          "spaceLength": 10,
          "stack": false,
          "steppedLine": false,
          "targets": [
            {
              "expr": "sum(base_memory_usedHeap_bytes{ app=~\"$app\"}) by (app)",
              "interval": "",
              "legendFormat": "{{app}}",
              "refId": "A"
            }
          ],
          "thresholds": [],
          "timeFrom": null,
          "timeRegions": [],
          "timeShift": null,
          "title": "Heap Size",
          "tooltip": {
            "shared": true,
            "sort": 0,
            "value_type": "individual"
          },
          "type": "graph",
          "xaxis": {
            "buckets": null,
            "mode": "time",
            "name": null,
            "show": true,
            "values": []
          },
          "yaxes": [
            {
              "format": "decbytes",
              "label": null,
              "logBase": 1,
              "max": null,
              "min": null,
              "show": true
            },
            {
              "format": "decbytes",
              "label": null,
              "logBase": 1,
              "max": null,
              "min": null,
              "show": true
            }
          ],
          "yaxis": {
            "align": false,
            "alignLevel": null
          }
        },
        {
          "aliasColors": {},
          "bars": false,
          "dashLength": 10,
          "dashes": false,
          "datasource": null,
          "fieldConfig": {
            "defaults": {
              "custom": {}
            },
            "overrides": []
          },
          "fill": 2,
          "fillGradient": 6,
          "gridPos": {
            "h": 8,
            "w": 12,
            "x": 0,
            "y": 10
          },
          "hiddenSeries": false,
          "id": 16,
          "legend": {
            "avg": false,
            "current": false,
            "max": false,
            "min": false,
            "show": true,
            "total": false,
            "values": false
          },
          "lines": true,
          "linewidth": 2,
          "nullPointMode": "null",
          "options": {
            "dataLinks": []
          },
          "percentage": false,
          "pointradius": 2,
          "points": false,
          "renderer": "flot",
          "seriesOverrides": [],
          "spaceLength": 10,
          "stack": false,
          "steppedLine": false,
          "targets": [
            {
              "expr": "sum(rate(container_cpu_system_seconds_total{container_name=\"$container\"}[5m])) by (container_name)",
              "interval": "",
              "legendFormat": "{{container_name}}",
              "refId": "A"
            }
          ],
          "thresholds": [],
          "timeFrom": null,
          "timeRegions": [],
          "timeShift": null,
          "title": "Container CPU Over Time",
          "tooltip": {
            "shared": true,
            "sort": 0,
            "value_type": "individual"
          },
          "type": "graph",
          "xaxis": {
            "buckets": null,
            "mode": "time",
            "name": null,
            "show": true,
            "values": []
          },
          "yaxes": [
            {
              "format": "short",
              "label": null,
              "logBase": 1,
              "max": null,
              "min": null,
              "show": true
            },
            {
              "format": "short",
              "label": null,
              "logBase": 1,
              "max": null,
              "min": null,
              "show": true
            }
          ],
          "yaxis": {
            "align": false,
            "alignLevel": null
          }
        },
        {
          "aliasColors": {},
          "bars": false,
          "dashLength": 10,
          "dashes": false,
          "datasource": null,
          "fieldConfig": {
            "defaults": {
              "custom": {}
            },
            "overrides": []
          },
          "fill": 2,
          "fillGradient": 5,
          "gridPos": {
            "h": 8,
            "w": 11,
            "x": 12,
            "y": 10
          },
          "hiddenSeries": false,
          "id": 14,
          "legend": {
            "avg": false,
            "current": false,
            "max": false,
            "min": false,
            "show": true,
            "total": false,
            "values": false
          },
          "lines": true,
          "linewidth": 2,
          "nullPointMode": "null",
          "options": {
            "dataLinks": []
          },
          "percentage": false,
          "pointradius": 2,
          "points": false,
          "renderer": "flot",
          "seriesOverrides": [],
          "spaceLength": 10,
          "stack": false,
          "steppedLine": true,
          "targets": [
            {
              "expr": "sum(container_memory_usage_bytes{container_name=~\"$container\"}) by (container_name)",
              "interval": "",
              "legendFormat": "{{container_name}",
              "refId": "A"
            }
          ],
          "thresholds": [],
          "timeFrom": null,
          "timeRegions": [],
          "timeShift": null,
          "title": "Container Memory",
          "tooltip": {
            "shared": true,
            "sort": 0,
            "value_type": "individual"
          },
          "type": "graph",
          "xaxis": {
            "buckets": null,
            "mode": "time",
            "name": null,
            "show": true,
            "values": []
          },
          "yaxes": [
            {
              "format": "decbytes",
              "label": null,
              "logBase": 1,
              "max": null,
              "min": null,
              "show": true
            },
            {
              "format": "decbytes",
              "label": null,
              "logBase": 1,
              "max": null,
              "min": null,
              "show": true
            }
          ],
          "yaxis": {
            "align": false,
            "alignLevel": null
          }
        },
        {
          "aliasColors": {},
          "bars": false,
          "dashLength": 10,
          "dashes": false,
          "datasource": null,
          "fieldConfig": {
            "defaults": {
              "custom": {}
            },
            "overrides": []
          },
          "fill": 3,
          "fillGradient": 6,
          "gridPos": {
            "h": 8,
            "w": 23,
            "x": 0,
            "y": 18
          },
          "hiddenSeries": false,
          "id": 12,
          "legend": {
            "avg": false,
            "current": false,
            "max": false,
            "min": false,
            "show": true,
            "total": false,
            "values": false
          },
          "lines": true,
          "linewidth": 2,
          "nullPointMode": "null",
          "options": {
            "dataLinks": []
          },
          "percentage": false,
          "pointradius": 2,
          "points": false,
          "renderer": "flot",
          "seriesOverrides": [],
          "spaceLength": 10,
          "stack": false,
          "steppedLine": true,
          "targets": [
            {
              "expr": "sum(rate(application_com_github_joostvdg_demo_jx_quarkusfruits_FruitResource_fruit_get_all_count_total{app=\"$app\"}[5m])) by (app)",
              "interval": "",
              "legendFormat": "{{app}}",
              "refId": "A"
            }
          ],
          "thresholds": [],
          "timeFrom": null,
          "timeRegions": [],
          "timeShift": null,
          "title": "Fruits GetAll Call Rate",
          "tooltip": {
            "shared": true,
            "sort": 0,
            "value_type": "individual"
          },
          "type": "graph",
          "xaxis": {
            "buckets": null,
            "mode": "time",
            "name": null,
            "show": true,
            "values": []
          },
          "yaxes": [
            {
              "format": "short",
              "label": null,
              "logBase": 1,
              "max": null,
              "min": null,
              "show": true
            },
            {
              "format": "short",
              "label": null,
              "logBase": 1,
              "max": null,
              "min": null,
              "show": true
            }
          ],
          "yaxis": {
            "align": false,
            "alignLevel": null
          }
        }
      ],
      "refresh": "5m",
      "schemaVersion": 25,
      "style": "dark",
      "tags": [],
      "templating": {
        "list": [
          {
            "allValue": null,
            "current": {
              "selected": false,
              "text": "jx-quarkus-fruits",
              "value": "jx-quarkus-fruits"
            },
            "datasource": "Prometheus",
            "definition": "label_values(base_memory_usedHeap_bytes, app)",
            "hide": 0,
            "includeAll": false,
            "label": "App",
            "multi": false,
            "name": "app",
            "options": [
              {
                "selected": true,
                "text": "jx-quarkus-fruits",
                "value": "jx-quarkus-fruits"
              }
            ],
            "query": "label_values(base_memory_usedHeap_bytes, app)",
            "refresh": 0,
            "regex": "",
            "skipUrlSync": false,
            "sort": 0,
            "tagValuesQuery": "",
            "tags": [],
            "tagsQuery": "",
            "type": "query",
            "useTags": false
          },
          {
            "allValue": null,
            "current": {
              "selected": false,
              "text": "POD",
              "value": "POD"
            },
            "datasource": "Prometheus",
            "definition": "label_values(container_memory_usage_bytes, container_name)\n",
            "hide": 0,
            "includeAll": false,
            "label": "Container",
            "multi": false,
            "name": "container",
            "options": [],
            "query": "label_values(container_memory_usage_bytes, container_name)\n",
            "refresh": 1,
            "regex": "",
            "skipUrlSync": false,
            "sort": 0,
            "tagValuesQuery": "",
            "tags": [],
            "tagsQuery": "",
            "type": "query",
            "useTags": false
          }
        ]
      },
      "time": {
        "from": "now-5m",
        "to": "now"
      },
      "timepicker": {
        "refresh_intervals": [
          "10s",
          "30s",
          "1m",
          "5m",
          "15m",
          "30m",
          "1h",
          "2h",
          "1d"
        ]
      },
      "timezone": "",
      "title": "JX Quarkus Demo",
      "uid": "6ne5tiRGk",
      "version": 3
    }
    ```

## Tracing

While both Monitoring and Logging are important, they're not the full story in understand your application's behaviour. Your log might reveal there's an issue, and the metrics can show which calls are slowing down. They can't tell you what part of the code is slowing down!

To get further information, you need to implement tracing. Well, isn't it just great that Quarkus has you covered here as well? Quarkus omplements [OpenTracing](https://opentracing.io/) via [SmallRye OpenTracing](https://github.com/smallrye/smallrye-opentracing). 

To display the traces, we'll use [Jaeger](https://www.jaegertracing.io/). If you're interrested, [Quarkus has a guide on the implementation](https://quarkus.io/guides/opentracing), or read on and get to work right away.


### Steps

* install Jaeger
* add dependency
* change logger
* update the container environment variables
* update the application's properties

* https://github.com/opentracing-contrib/java-jdbc

### Install Jaeger

Jaeger has an [official Helm Chart](https://github.com/jaegertracing/helm-charts/tree/master/charts/jaeger), which has very sensible defaults. For production use, I do recommend investigation the options available, especially related to its data storage!

```sh
helm repo add jaegertracing https://jaegertracing.github.io/helm-charts
helm repo update
```

```sh
helm install jaeger jaegertracing/jaeger \
  --namespace ${NAMESPACE} \
  -f jaeger-values.yaml
```

!!! example "jaeger-values.yaml"

    ```yaml
    query:
      ingress:
        enabled: true
        hosts:
          - chart-example.local
    ```

### Set Logger

To automatically have our traces logged in Jaeger, it seems - I can be wrong - that we have to use the JBoss Logger that Quarkus ships with. As it is there by default, we don't have to add any new dependency.

!!! example "FruitResource.java"

    ```java hl_lines="1 7 17"
    import org.jboss.logging.Logger;

    @RestController
    @RequestMapping(value = "/fruits")
    public class FruitResource {

        private static final Logger LOG = Logger.getLogger(FruitResource.class);

        @GetMapping("/")
        @Counted(name = "fruit_get_all_count", description = "How many times all Fruits have been retrieved.")
        @Timed(name = "fruit_get_all_timer", description = "A measure of how long it takes to retrieve all Fruits.", unit = MetricUnits.MILLISECONDS)
        public List<Fruit> findAll() {
            var it = fruitRepository.findAll();
            List<Fruit> fruits = new ArrayList<Fruit>();
            it.forEach(fruits::add);
            fruits.sort(Comparator.comparing(Fruit::getId));
            LOG.infof("Found {} fruits", fruits.size());
            return fruits;
        }
    }
    ```

### Add Tracing Dependencies

Speaking of dependencies, we do have to add not one, but two for tracing itself.
The first one being `quarkus-smallrye-opentracing` for the tracing basics. 

If we also add `io.opentracing.contrib:opentracing-jdbc`, our trace spans will include our JDBC calls as well, how neat!

!!! example "pom.xml"

    ```xml
    <dependency>
      <groupId>io.quarkus</groupId>
      <artifactId>quarkus-smallrye-opentracing</artifactId>
    </dependency>
    <dependency>
      <groupId>io.opentracing.contrib</groupId>
      <artifactId>opentracing-jdbc</artifactId>
    </dependency>
    ```

### Update Application Properties

As you're probably used to by now, to ensure Quarkus does the right thing, we have to update the Application Properties. Most of these values are copied from the Quarkus tracing guide, including the log format. 

I've made two of the values a variable controllable via environment varibles.

1. `quarkus.jaeger.sampler-param`: this ensure the percentage of calls that is traced, ranging from 0 (0%) to 1 (100%).
1. `quarkus.jaeger.endpoint`: which is something that can vary per environment


!!! example "src/main/resources/application.properties"

    ```properties hl_lines="5"
    quarkus.jaeger.service-name=quarkus-fruits
    quarkus.jaeger.sampler-type=const
    quarkus.jaeger.sampler-param=${JAEGER_SAMPLER_RATE}
    quarkus.log.console.format=%d{HH:mm:ss} %-5p traceId=%X{traceId}, spanId=%X{spanId}, sampled=%X{sampled} [%c{2.}] (%t) %s%e%n
    quarkus.datasource.jdbc.driver=io.opentracing.contrib.jdbc.TracingDriver
    quarkus.jaeger.endpoint=${JAEGER_COLLECTOR_ENDPOINT}
    ```

### Update Container Env

As I've set two variables in the Application Properties file that come from environment variables, we also have to set a default value in our Chart's `values.yml`.

* **JAEGER_COLLECTOR_ENDPOINT**: The endpoint where we send our jaeger metrics too
* **JAEGER_SAMPLER_RATE**: Sample all requests. Set sampler-param to somewhere between 0 and 1, e.g. 0.50, if you do not wish to sample all requests.

Another change is the `GOOGLE_SQL_CONN` variable. In order for the tracing to work for the JDBC calls, we have to add `tracing` into the JDBC URL.

!!! example "charts/Name-Of-Your-Application/values.yaml"

    ```yaml hl_lines="3"
    env:
      GOOGLE_SQL_USER: vault:quarkus-fruits:GOOGLE_SQL_USER
      GOOGLE_SQL_CONN: jdbc:tracing:mysql://127.0.0.1:3306/fruits
      JAEGER_COLLECTOR_ENDPOINT: http://jaeger-collector.jaeger:14268/api/traces
      JAEGER_SAMPLER_RATE: 1
    ```

!!! caution
    I've installed Jaeger via the Helm chart in the Namespace `jaeger`.
    So the _Service_ name is `jaeger-collector.jaeger`, change this to reflect your installation.

    To be sure, you can always verify the service name via `kubectl`.

    ```sh
    kubectl get svc -n $NAMESPACE
    ```

### See It In Action

I you have the Jaeger Query UI running with an Ingress, you can access the interface.

Make several calls to the application, and you should see it come up under the `Service` tab in the UI.

Select the service and you see the traces, including the database calls made to the CloudSQL Proxy container!

## Code Snapshots

There's a branch for the status of the code after:

* adding Sentry for logging, in the [branch 09-sentry](https://github.com/joostvdg/quarkus-fruits/tree/09-sentry).
* adding Monitoring with Prometheus, in the branch [09-monitoring](https://github.com/joostvdg/quarkus-fruits/tree/09-monitoring)
* adding Jaeger with OpenTracing, in the branch [09-tracing](https://github.com/joostvdg/quarkus-fruits/tree/09-tracing)

## Next Steps

Now that we have (more) control over our application and the environment it runs in, we can promote the application to Production.
