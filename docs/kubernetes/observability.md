# Kubernetes Observability

## Monitoring

## Metrics Server

* Helm chart: https://github.com/helm/charts/tree/master/stable/metrics-server
* Home: https://github.com/kubernetes-incubator/metrics-server

```bash
helm install stable/metrics-server \
    --name metrics-server \
    --version 2.0.3 \
    --namespace metrics

kubectl -n metrics \
    rollout status \
    deployment metrics-server
```

## Prometheus & Alert Manager

### Prometheus Helm Values

```
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
```

## Grafana

## Application Metrics



## Resources

* https://blog.freshtracks.io/a-deep-dive-into-kubernetes-metrics-b190cc97f0f6
* https://brancz.com/2018/01/05/prometheus-vs-heapster-vs-kubernetes-metrics-apis/
* https://rancher.com/blog/2018/2018-06-26-measuring-metrics-that-matter-in-kubernetes-clusters/