# GCE

## GKE Install

### Set env

```bash
ZONE=$(gcloud compute zones list --filter "region:(europe-west4)" | awk '{print $1}' | tail -n 1)
ZONES=$(gcloud compute zones list --filter "region:(europe-west4)"  | tail -n +2 | awk '{print $1}' | tr '\n' ',')

MACHINE_TYPE=n1-highcpu-2
MACHINE_TYPE=n1-standard-2

echo ZONE=$ZONE
echo ZONES=$ZONES
echo MACHINE_TYPE=$MACHINE_TYPE
```

### Get supported K8s versions

```bash
gcloud container get-server-config --zone=$ZONE --format=json
```
```bash
MASTER_VERSION="1.10.5-gke.0"
```

### Create cluster

```bash
gcloud container clusters \
    create devops24 \
    --zone $ZONE \
    --node-locations $ZONES \
    --machine-type $MACHINE_TYPE \
    --enable-autoscaling \
    --num-nodes 1 \
    --max-nodes 1 \
    --min-nodes 1 \
    --cluster-version $MASTER_VERSION
```

### Kubernetes post install

* create cluster role binding
* install nginx as ingress controller
* install tiller
* configure helm

```bash
kubectl create clusterrolebinding cluster-admin-binding --clusterrole cluster-admin --user $(gcloud config get-value account)
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/master/deploy/mandatory.yaml
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/master/deploy/provider/cloud-generic.yaml
kubectl create -f https://raw.githubusercontent.com/vfarcic/k8s-specs/master/helm/tiller-rbac.yml --record --save-config
kubectl create serviceaccount --namespace kube-system tiller
kubectl create clusterrolebinding tiller-cluster-rule --clusterrole=cluster-admin --serviceaccount=kube-system:tiller
helm init --service-account tiller
```

### Install Weave net

```bash
kubectl apply -f "https://cloud.weave.works/k8s/net?k8s-version=$(kubectl version | base64 | tr -d '\n')"
```

#### Encryption

You can run Weave Net with encryption on.
This requires a Kubernetes secret containing the encryption password.

```bash
cat > weave-secret << EOF
MSjNDSC6Rw7F3P3j8klHZq1v
EOF

kubectl create secret -n kube-system generic weave-secret --from-file=./weave-secret
kubectl apply -f "https://cloud.weave.works/k8s/net?k8s-version=$(kubectl version | base64 | tr -d '\n')&password-secret=weave-secret"
kubectl get pods -n kube-system -l name=weave-net -o wide
kubectl exec -n kube-system weave-net- -c weave -- /home/weave/weave --local status
```

#### Installation error

Note, that installing Weave Net on GKE requires the cluster-admin role to be bound to yourself.
Else you will not have enough rights.

If you see:

```bash
rror from server (Forbidden): clusterroles.rbac.authorization.k8s.io "weave-net" is forbidden: attempt to grant extra privileges: [PolicyRule{APIGroups:[""], Resources:["pods"], Verbs:["get"]} PolicyRule{APIGroups:[""], Resources:["pods"], Verbs:["list"]} PolicyRule{APIGroups:[""], Resources:["pods"], Verbs:["watch"]} PolicyRule{APIGroups:[""], Resources:["namespaces"], Verbs:["get"]} PolicyRule{APIGroups:[""], Resources:["namespaces"], Verbs:["list"]} PolicyRule{APIGroups:[""], Resources:["namespaces"], Verbs:["watch"]} PolicyRule{APIGroups:[""], Resources:["nodes"], Verbs:["get"]} PolicyRule{APIGroups:[""], Resources:["nodes"], Verbs:["list"]} PolicyRule{APIGroups:[""], Resources:["nodes"], Verbs:["watch"]} PolicyRule{APIGroups:["networking.k8s.io"], Resources:["networkpolicies"], Verbs:["get"]} PolicyRule{APIGroups:["networking.k8s.io"], Resources:["networkpolicies"], Verbs:["list"]} PolicyRule{APIGroups:["networking.k8s.io"], Resources:["networkpolicies"], Verbs:["watch"]} PolicyRule{APIGroups:[""], Resources:["nodes/status"], Verbs:["patch"]} PolicyRule{APIGroups:[""], Resources:["nodes/status"], Verbs:["update"]}] user=&{joostvdg@gmail.com  [system:authenticated] map[]} ownerrules=[PolicyRule{APIGroups:["authorization.k8s.io"], Resources:["selfsubjectaccessreviews" "selfsubjectrulesreviews"], Verbs:["create"]} PolicyRule{NonResourceURLs:["/api" "/api/*" "/apis" "/apis/*" "/healthz" "/openapi" "/openapi/*" "/swagger-2.0.0.pb-v1" "/swagger.json" "/swaggerapi" "/swaggerapi/*" "/version" "/version/"], Verbs:["get"]}] ruleResolutionErrors=[]
Error from server (Forbidden): roles.rbac.authorization.k8s.io "weave-net" is forbidden: attempt to grant extra privileges: [PolicyRule{APIGroups:[""], Resources:["configmaps"], ResourceNames:["weave-net"], Verbs:["get"]} PolicyRule{APIGroups:[""], Resources:["configmaps"], ResourceNames:["weave-net"], Verbs:["update"]} PolicyRule{APIGroups:[""], Resources:["configmaps"], Verbs:["create"]}] user=&{joostvdg@gmail.com  [system:authenticated] map[]} ownerrules=[PolicyRule{APIGroups:["authorization.k8s.io"], Resources:["selfsubjectaccessreviews" "selfsubjectrulesreviews"], Verbs:["create"]} PolicyRule{NonResourceURLs:["/api" "/api/*" "/apis" "/apis/*" "/healthz" "/openapi" "/openapi/*" "/swagger-2.0.0.pb-v1" "/swagger.json" "/swaggerapi" "/swaggerapi/*" "/version" "/version/"], Verbs:["get"]}] ruleResolutionErrors=[]
```

Execute the following before attempting to install Weave Net again.

```bash
kubectl create clusterrolebinding cluster-admin-binding --clusterrole cluster-admin --user $(gcloud config get-value account)
```

### Prometheus & Grafana

https://rohanc.me/monitoring-kubernetes-prometheus-grafana/

```bash
helm install stable/prometheus --name my-prometheus
```

#### Grafana config

```yaml
persistence:
  enabled: true
  accessModes:
    - ReadWriteOnce
  size: 5Gi

datasources: 
 datasources.yaml:
   apiVersion: 1
   datasources:
   - name: Prometheus
     type: prometheus
     url: http://my-prometheus-server
     access: proxy
     isDefault: true

dashboards:
    default:
      kube-dash:
        gnetId: 6663
        revision: 1
        datasource: Prometheus
      kube-official-dash:
        gnetId: 2
        revision: 1
        datasource: Prometheus

dashboardProviders:
  dashboardproviders.yaml:
    apiVersion: 1
    providers:
    - name: 'default'
      orgId: 1
      folder: ''
      type: file
      disableDeletion: false
      editable: true
      options:
        path: /var/lib/grafana/dashboards
```

Other dashboards to import:
* 3131
* 5309
* 5312
* 315

### Get Cluster IP

```bash
export LB_IP=$(kubectl -n ingress-nginx \
    get svc ingress-nginx \
    -o jsonpath="{.status.loadBalancer.ingress[0].ip}")

echo $LB_IP

export DNS=${LB_IP}.nip.io
echo $DNS

export JENKINS_DNS="jenkins.${DNS}"
echo $JENKINS_DNS
```

### Install CJE

#### Create SSD SC

```bash
echo "apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: ssd
provisioner: kubernetes.io/gce-pd
parameters:
  type: pd-ssd" > ssd-storage.yaml

kubectl create -f ssd-storage.yaml
```

#### Setup CJE Namespace

```bash
kubectl create namespace cje
kubectl label namespace cje name=cje
kubectl config set-context $(kubectl config current-context) --namespace=cje
```

#### Adjust Domain name

```bash
export PREV_DOMAIN_NAME=
```

```bash
sed -e s,$PREV_DOMAIN_NAME,$JENKINS_DNS,g < cje.yml > tmp && mv tmp cje.yml
```

### Install Jenkins

```bash
kubectl apply -f cje.yml
kubectl rollout status sts cjoc
sleep 180
kubectl exec cjoc-0 -- cat /var/jenkins_home/secrets/initialAdminPassword
```

### Install Jenkins - k8s-specs

```bash
kubectl apply -f joost/jenkins.yml
sleep 180
kubectl exec -it --namespace jenkins jenkins-0 cat /var/jenkins_home/secrets/initialAdminPassword
```

### Install Keycloak - k8s-specs

```bash
kubectl apply -f joost/keycloak.yml
sleep 120
kubectl -n jenkins exec -it keycloak-0 -- /bin/bash 
keycloak/bin/add-user-keycloak.sh -u somekindofuser -p X5qpLMnWKUx7
ps -ef | grep java
kill -9 <PID>
```

#### Follow log

```bash
k -n jenkins logs -f keycloak
```

#### Jenkins Keycloak config

```json
{
    "realm": "master",
    "auth-server-url": "http://35.204.112.229/auth",
    "ssl-required": "external",
    "resource": "jenkins",
    "public-client": true
}
```

### Destroy cluster

```bash
gcloud container clusters \
    delete devops24 \
    --zone $ZONE \
    --quiet
```