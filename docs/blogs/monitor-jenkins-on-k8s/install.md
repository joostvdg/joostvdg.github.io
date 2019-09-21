title: Jenkins Kubernetes Monitoring
description: Monitoring Jenkins On Kubernetes - Install Tools - 3/8
hero: Install Tools - 3/8

# Install Components for Monitoring

This chapter is about installing all the tools we need for completing this guide. If you already have these tools installed, feel free to skip the actual installations. However, do make sure to confirm you have a compatible configuration.

!!! important
    This guide is written during August/September 2019, during which Helm 3 entered Beta. This guide assumes Helm 2, be mindful of the Helm version you are running!

## Prepare

First, we make sure we have hostnames for our services, including Prometheus, Alertmanager, and Grafana.

```bash
export DOMAIN=
```

```bash
export PROM_ADDR=mon.${DOMAIN}
export AM_ADDR=alertmanager.${DOMAIN}
export GRAFANA_ADDR="grafana.${DOMAIN}"
```

Then we create a namespace to host the monitoring tools.

```bash
kubectl create namespace mon
kubens mon
```

## Install Prometheus & Alertmanager

By default, the Helm chart of Prometheus installs Alertmanager as well. To access the UI of Alertmanager, we also set its Ingress' hostname.

```bash
helm upgrade -i prometheus \
 stable/prometheus \
 --namespace mon \
 --version 7.1.3 \
 --set server.ingress.hosts={$PROM_ADDR} \
 --set alertmanager.ingress.hosts={$AM_ADDR} \
 -f prom-values.yaml
```

Use the below command to wait for the deployment of Prometheus to be completed.

```bash
kubectl -n mon \
 rollout status \
 deploy prometheus-server
```

??? example "prom-values.yaml"

    Below is an example helm `values.yaml` for Prometheus. It shows how to set resources limits and request, some alerts, and how to configure sending these alerts to Slack.
    
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

## Install Grafana

!!!    note
    At the time of writing (September 2019) we cannot use the latest version of the Grafana helm chart.

    * https://github.com/helm/charts/pull/15702
    * https://github.com/helm/charts/issues/15725

We install Grafana in the same namespace as Prometheus and Alertmanager.

```bash
helm upgrade -i grafana stable/grafana \
 --version 3.5.5 \
 --namespace mon \
 --set ingress.hosts="{$GRAFANA_ADDR}" \
 --values grafana-values.yaml
```

```bash
kubectl -n mon rollout status deployment grafana
```

Once the deployment is rolled out, we can either directly open the Grafana UI or echo the address and copy & paste it.

```bash
echo "http://$GRAFANA_ADDR"
```

```bash
open "http://$GRAFANA_ADDR"
```

By default, the Grafana helm chart generates a password for you, with the command below you can retrieve it.

```bash
kubectl -n mon \
 get secret grafana \
 -o jsonpath="{.data.admin-password}" \
 | base64 --decode; echo
```

```bash
open "https://grafana.com/dashboards"
```

??? example "grafana-values.yaml"

    Below is an example configuration for a helm `values.yaml`, which also includes some useful dashboards by default.  We've also configured a default Datasource, pointing to the Prometheus installed earlier.

    ```yaml
    ingress:
      enabled: true
    persistence:
      enabled: true
      accessModes:
      - ReadWriteOnce
      size: 1Gi
    resources:
      limits:
        cpu: 20m
        memory: 50Mi
      requests:
        cpu: 5m
        memory: 25Mi
    datasources:
      datasources.yaml:
        apiVersion: 1
        datasources:
        - name: Prometheus
          type: prometheus
          url: http://prometheus-server
          access: proxy
          isDefault: true
    dashboardProviders:
      dashboardproviders.yaml:
        apiVersion: 1
        providers:
        - name: 'Default'
          orgId: 1
          folder: 'default'
          type: file
          disableDeletion: true
          editable: true
          options:
            path: /var/lib/grafana/dashboards/default
    dashboards:
      default:
        Costs-Pod:
          gnetId: 6879
          revision: 1
          datasource: Prometheus
        Costs:
          gnetId: 8670
          revision: 1
          datasource: Prometheus
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

## Install Jenkins

Now that we've taken care of the monitoring tools, we can install Jenkins. We start by creating a namespace for Jenkins to land in.

```bash
kubectl create namespace jenkins
kubens jenkins
```

There are many ways of installing Jenkins. There is a very well maintained Helm chart, which is well suited for what we want to achieve.

!!!  note
    It is recommended to spread teams and applications across Jenkins masters rather than put everything into a single instance. So in this guide we create two identical Jenkins Masters, each with a unique hostname, to simulate this and show that the alerts and dashboards work for **one or more** Jenkins masters.

Although the Helm chart is a very good starting point, we still need a `values.yaml` file to configure a few things.

### Helm Values Explained

Let's explain some of the values:

* `installPlugins`: we want `blueocean` for a more beautiful Pipeline UI and `prometheus` to expose the metrics in a Prometheus format
* `resources`: always specify your resources, if these are wrong, our monitoring alerts and dashboard should help use tweak these values
* `javaOpts`: for some reason, the default configuration doesn't have the recommended JVM and Garbage Collection configuration, so we have to specify this, see [CloudBees' JVM Troubleshoot Guide](https://go.cloudbees.com/docs/solutions/jvm-troubleshooting/) for more details
* `ingress`: because I believe every publicly available service should only be accessible via TLS, we have to configure TLS and certmanager annotations (as we're using Certmanager to manage our certificate)
* `podAnnotations`: the default metrics endpoint that Prometheus scrapes from is `/metrics`, unfortunately, the by default included Metrics Plugin exposes the metrics on that endpoint in the wrong format. This means we have to inform Prometheus how to retrieve the metrics

Make sure both `jenkins-values.X.yaml` and `jenkins-certificate.X.yaml` are created according to the template files below. Replace the X for each master, if you want three, you'll have `.1.yaml`, `.2.yaml` and `.3.yaml` for each of the files. Replace the `<ReplaceWithYourDNS>` with your DNS Host name and the `X` with the appropriate number.

For example, if your host name is `example.com`, you will have the following:

```yaml
 hostName: jenkins1.example.com
 tls:
 - secretName: tls-jenkins-1
 hosts:
 - jenkins1.example.com
```

Use this file as the starting point for each of the masters. I would recommend making your changes in this file first and then make two copies and update the `X` value with `1` and `2` respectively.

??? example "jenkins-values.X.yaml"

    ```yaml
    master:
      serviceType: ClusterIP
      installPlugins:
        - blueocean:1.17.0
        - prometheus:2.0.0
        - kubernetes:1.17.2
      resources:
        requests:
          cpu: "250m"
          memory: "1024Mi"
        limits:
          cpu: "1000m"
          memory: "2048Mi"
      javaOpts: "-XX:+AlwaysPreTouch -XX:+UseG1GC -XX:+UseStringDeduplication -XX:+ParallelRefProcEnabled -XX:+DisableExplicitGC -XX:+UnlockDiagnosticVMOptions -XX:+UnlockExperimentalVMOptions"
      ingress:
        enabled: true
        hostName: jenkinsX.<ReplaceWithYourDNS>
        tls:
          - secretName: tls-jenkins-X
            hosts:
              - jenkinsX.<ReplaceWithYourDNS>
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

If you want to use TLS for Jenkins, this is an example Certificate. If you don't already have `certmanager` configured, take a look at [my guide on leveraging Let's Encrypt in Kubernetes](/blogs/k8s-lets-encrypt/).

??? example "jenkins-certificate.X.yaml"
    ```yaml
    apiVersion: certmanager.k8s.io/v1alpha1
    kind: Certificate
    metadata:
      name: jenkinsX.<ReplaceWithYourDNS>
    spec:
      secretName: tls-jenkins-X
      dnsNames:
      - jenkinsX.<ReplaceWithYourDNS>
      acme:
        config:
        - http01:
            ingressClass: nginx
          domains:
          - jenkinsX.<ReplaceWithYourDNS>
      issuerRef:
        name: letsencrypt-prod
        kind: ClusterIssuer
    ```

### Master One

Assuming you've created unique Helm values files for both Master One and Master Two, we can start with creating the first one.

```bash
helm upgrade -i jenkins \
 stable/jenkins \
 --namespace jenkins\
 -f jenkins-values.1.yaml
```

#### Apply Certificate

If you have the certificate, apply it to the cluster.

```bash
kubectl apply -f jenkins-certificate.1.yaml
```

#### Wait for rollout

If you want to wait for the Jenkins deployment to be completed, use the following command.

```bash
kubectl -n jenkins rollout status deployment jenkins1
```

#### Retrieve Password

The Jenkins Helm chart also generates a admin password for you. See the command below on how to retrieve it.

```bash
printf $(kubectl get secret --namespace jenkins jenkins1 -o jsonpath="{.data.jenkins-admin-password}" | base64 --decode);echo
```

### Master Two

Let's create Master Two as well, same deal as before. The commands are here for convenience, so you can use the `[]` in the top right to copy and paste easily.

```bash
helm upgrade -i jenkins2 \
 stable/jenkins \
 --namespace jenkins\
 -f jenkins-values.2.yaml
```

#### Wait for rollout

```bash
kubectl -n jenkins rollout status deployment jenkins2
```

#### Apply Certificate

```bash
kubectl apply -f jenkins-certificate.2.yaml
```

#### Retrieve Password

```bash
printf $(kubectl get secret --namespace jenkins jenkins2 -o jsonpath="{.data.jenkins-admin-password}" | base64 --decode);echo
```


