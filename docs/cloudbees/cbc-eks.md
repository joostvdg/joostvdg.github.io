# CloudBees Core on AWS EKS

* https://go.cloudbees.com/docs/cloudbees-core/cloud-install-guide/eks-install/#
* https://go.cloudbees.com/docs/cloudbees-core/cloud-reference-architecture/ra-for-eks/#_ingress_tls_termination

## Create EKS Cluster

See my guide on creating a [EKS cluster with EKSCTL](kubernetes/distributions/eks-eksctl/) 

### Certmanager

```bash
echo "apiVersion: certmanager.k8s.io/v1alpha1
kind: Certificate
metadata:
  name: cloudbeescore-kearos-net
  namespace: cje
spec:
  secretName: cjoc-tls-prd
  dnsNames:
  - cloudbees-core.kearos.net
  acme:
    config:
    - http01:
        ingressClass: nginx
      domains:
      - cloudbees-core.kearos.net
  issuerRef:
    name: letsencrypt-prd
    kind: ClusterIssuer" > cjoc-cert.yml
eks apply -f cjoc-cert.yml
```

### Create Namespace CJE

```bash
echo "apiVersion: v1
kind: Namespace
metadata:
  labels:
    name: cje
  name: cje" > cje-namespace.yaml

eks create  -f cje-namespace.yaml
eks config set-context $(eks config current-context) --namespace=cje
```

## CB Core Install

[Download from downloads.cloudbees.com](https://downloads.cloudbees.com/cloudbees-core/cloud/)

### Configure DNS

```bash
DOMAIN_NAME=cloudbees-core.kearos.net
sed -e s,cje.example.com,$DOMAIN_NAME,g < cloudbees-core.yml > tmp && mv tmp cloudbees-core.yml
```

Configure k8s yaml file:

* add `certmanager.k8s.io/cluster-issuer: letsencrypt-prd` to cjoc ingress's `metadata.annotations`
* add `secretName: cjoc-tls-prd` to cjoc ingress' `spec.tls.host[0]`
* confirm cjoc ingress's host and tls host is `cloudbees-core.kearos.net`

### Install

```bash
eks apply -f cloudbees-core.yml
eks rollout status sts cjoc
```

### Retrieve initial password

```bash
eks exec cjoc-0 -- cat /var/jenkins_home/secrets/initialAdminPassword
```

### Jenkins CLI

```bash
export CJOC_URL=https://cloudbees-core.kearos.net/cjoc/
http --download ${CJOC_URL}/jnlpJars/jenkins-cli.jar --verify false
```

```bash
export USR=jvandergriendt
export TKN=11b1016f80ddbb8a35bcbb5389599f7881
```

```bash
alias cbc="java -jar jenkins-cli.jar -noKeyAuth -auth ${USR}:${TKN} -s ${CJOC_URL}"
cbc teams
```

### Create team CAT

```bash
cbc teams cat --put < team-cat.json
```

## Use EFS

https://go.cloudbees.com/docs/cloudbees-core/cloud-reference-architecture/kubernetes-efs/

* Create EFS in AWS
    * performance: general purpose
    * throughput: provisioned, 160mb/s
    * encrypted: yes


```bash
EFS_KEY_ARN=arn:aws:kms:eu-west-1:324005994172:key/4bfd8d70-c7de-4e7a-ab83-10792be5daaa
```

## Destroy cluster


## External Client - The Hard Way

* create a new master (hat)
* confirm remoting works on expected port
  * 50000+n, where `n` is incremental count of number of masters
  * for example, if `hat` is the first new "team", it will be ```50001```
* create a new node
  * external-agent
  * launch via java webstart
* download client jar
* confirm port is NOT accessable
* open port on LB
* confirm port is open

### Open Port on LB

```bash
export DOMAIN_NAME=cloudbees-core.example.com
export TEAM_NAME=hat
export MASTER_NAME=teams-${TEAM_NAME}
export USR=
export PSS=
```

#### Test Port

```bash

```

#### Get Remoting Port

```bash
http --print=hH --auth $USR:$PSS https://$DOMAIN_NAME/$MASTER_NAME/ | grep X-Jenkins-CLI-Port
```

#### Configure Config Map

> If you already configured tcp-services before, you will need to retrieve the current configmap using kubectl get configmap tcp-services -n ingress-nginx -o yaml > tcp-services.yaml and edit it accordingly

```bash
kubectl get configmap tcp-services -n ingress-nginx -o yaml > tcp-services.yaml
```

Else:

```bash
export JNLP_MASTER_PORT=50001

```

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: tcp-services
  namespace: ingress-nginx
data:
  $JNLP_MASTER_PORT: \"$NAMESPACE/$MASTER_NAME:$JNLP_MASTER_PORT:PROXY\"
```

For example:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: tcp-services
  namespace: ingress-nginx
data:
  50001: "default/teams-hat:50001:PROXY"
```

#### Create Patch for Deployment (ingress)

```yaml
spec:
  template:
    spec:
      containers:
        - name: nginx-ingress-controller
          ports:
          - containerPort: $JNLP_MASTER_PORT
            name: $JNLP_MASTER_PORT-tcp
            protocol: TCP
```

Example:

```yaml
spec:
  template:
    spec:
      containers:
        - name: nginx-ingress-controller
          ports:
          - containerPort: 50001
            name: 50001-tcp
            protocol: TCP
```

#### Create Patch for Service (ingress)

```yaml
spec:
  ports:
  - name: $JNLP_MASTER_PORT-tcp
    port: $JNLP_MASTER_PORT
    protocol: TCP
    targetPort: $JNLP_MASTER_PORT-tcp
```

Example:

```yaml
spec:
  ports:
  - name: 50001-tcp
    port: 50001
    protocol: TCP
    targetPort: 50001-tcp
```

#### Apply patches

```bash
export NGINX_POD=$(kubectl get deployment -l app.kubernetes.io/name=ingress-nginx -n ingress-nginx -o jsonpath="{.items[0].metadata.name}")
kubectl apply -f tcp-services.yaml
kubectl patch deployment ${NGINX_POD} -n ingress-nginx -p "$(cat deployment-patch.yaml)"
kubectl patch service ingress-nginx -n ingress-nginx -p "$(cat service-patch.yaml)"
kubectl annotate -n ingress-nginx service/ingress-nginx  service.beta.kubernetes.io/aws-load-balancer-connection-idle-timeout="3600" --overwrite
```

## Delete cluster

```bash
aws cloudformation delete-stack --stack-name ${STACK_NAME} --region ${REGION} --profile ${PROFILE}
```
