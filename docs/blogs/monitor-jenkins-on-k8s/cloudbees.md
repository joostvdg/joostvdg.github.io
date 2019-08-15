# CloudBees Core

* add prometheus plugin to team-recipe
* update CJOC's Master Provisioning with prometheus annotations

```yaml
apiVersion: "apps/v1"
kind: "StatefulSet"
spec:
  template:
    metadata:
      annotations:
        prometheus.io/path: /${name}/prometheus
        prometheus.io/port: "8080"
        prometheus.io/scrape: "true"
      labels:
        app.kubernetes.io/component: Managed-Master
        app.kubernetes.io/instance: ${name}
        app.kubernetes.io/managed-by: CloudBees-Core-Cloud-Operations-Center
        app.kubernetes.io/name: ${name}
```
