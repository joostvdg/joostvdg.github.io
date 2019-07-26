# CKA Exam Prep

* https://github.com/dgkanatsios/CKAD-exercises
* https://github.com/kelseyhightower/kubernetes-the-hard-way
* https://github.com/walidshaari/Kubernetes-Certified-Administrator
* https://github.com/kubernetes/community/blob/master/contributors/devel/e2e-tests.md
* https://www.cncf.io/certification/cka/
* https://oscon2018.container.training
* https://github.com/ahmetb/kubernetes-network-policy-recipes
* https://github.com/ramitsurana/awesome-kubernetes
* https://sysdig.com/blog/kubernetes-security-guide/
* https://severalnines.com/blog/installing-kubernetes-cluster-minions-centos7-manage-pods-services
* https://docs.google.com/presentation/d/1Gp-2blk5WExI_QR59EUZdwfO2BWLJqa626mK2ej-huo/edit#slide=id.g27a78b354c_0_0
* https://engineering.bitnami.com/articles/a-deep-dive-into-kubernetes-controllers.html

## Some basic commands

```bash
kubectl -n kube-public get secrets
```

## Test network policy

For some common recipes, look at [Ahmet's recipe repository](https://github.com/ahmetb/kubernetes-network-policy-recipes).

!!! warning
    Make sure you have CNI enabled and you have a network plugin that enforces the policies.

!!! note
    You can check current existing policies like this: ```kubectl get netpol --all-namespaces```

### Example Ingress Policy

```yaml
kind: NetworkPolicy
apiVersion: networking.k8s.io/v1
metadata:
  name: dui-network-policy
  namespace: dui
spec:
  podSelector:
    matchLabels:
      app: dui
      distribution: server
  ingress: []
```

### Run test pod

Apply above network policy, and then test in the same `dui` namespace, and in the `default` namespace.

!!! note
    Use `alpine:3.6` because telnet was dropped starting 3.7.

```bash
kubectl -n dui get pods -l app=dui -o wide
kubectl run --rm -i -t --image=alpine:3.6 -n dui test -- sh
telnet 10.32.0.7 8888
```

This should now fail - timeout - due the packages being dropped.

### Egress

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: dui-network-policy-egress
  namespace: dui
spec:
  podSelector:
    matchLabels:
      app: dui
  policyTypes:
  - Egress
  egress:
  - ports:
    - port: 7777
      protocol: TCP
  - to:
    - podSelector:
        matchLabels:
            app: dui
```

!!! warning
    This should in theory, block our test pod from reading this.
    As it doesn't have the label `app=dui`. But it seems it is working just fine.

#### Allow DNS

If it should also be able to do DNS calls, we have to enable port 53.

```yaml

  - ports:
    - port: 53
      protocol: UDP
    - port: 53
      protocol: TCP
    - port: 7777
      protocol: TCP
  - to:
    - namespaceSelector: {}
```

#### Create a test pod with curl

```bash
kubectl run --rm -i -t --image=alpine:3.6 -n dui test -- sh
apk --no-cache add curl
curl 10.32.0.11:7777/servers
```


## Run minikube cluster

```bash
######################
# Create The Cluster #
######################

# Make sure that your minikube version is v0.25 or higher

# WARNING!!!
# Some users experienced problems starting the cluster with minikuber v0.26 and v0.27.
# A few of the reported issues are https://github.com/kubernetes/minikube/issues/2707 and https://github.com/kubernetes/minikube/issues/2703
# If you are experiencing problems creating a cluster, please consider downgrading to minikube v0.25.

minikube start \
    --vm-driver virtualbox \
    --cpus 4 \
    --memory 12228 \
    --network-plugin=cni \
    --extra-config=kubelet.network-plugin=cni

###############################
# Install Ingress and Storage #
###############################

minikube addons enable ingress

minikube addons enable storage-provisioner

minikube addons enable default-storageclass

##################
# Install Tiller #
##################

kubectl create \
    -f https://raw.githubusercontent.com/vfarcic/k8s-specs/master/helm/tiller-rbac.yml \
    --record --save-config

helm init --service-account tiller

kubectl -n kube-system \
    rollout status deploy tiller-deploy

##################
# Get Cluster IP #
##################

export LB_IP=$(minikube ip)

#######################
# Install ChartMuseum #
#######################

CM_ADDR="cm.$LB_IP.nip.io"

echo $CM_ADDR

CM_ADDR_ESC=$(echo $CM_ADDR \
    | sed -e "s@\.@\\\.@g")

echo $CM_ADDR_ESC

helm install stable/chartmuseum \
    --namespace charts \
    --name cm \
    --values helm/chartmuseum-values.yml \
    --set ingress.hosts."$CM_ADDR_ESC"={"/"} \
    --set env.secret.BASIC_AUTH_USER=admin \
    --set env.secret.BASIC_AUTH_PASS=admin

kubectl -n charts \
    rollout status deploy \
    cm-chartmuseum

# http "http://$CM_ADDR/health" # It should return `{"healthy":true}

######################
# Install Weave Net ##
######################

kubectl apply -f "https://cloud.weave.works/k8s/net?k8s-version=$(kubectl version | base64 | tr -d '\n')"
kubectl -n kube-system rollout status daemonset weave-net
```

## Weave Net

### On minikube

> To run Weave Net on minikube, after upgrading minikube, you need to overwrite the default CNI config shipped with minikube: mkdir -p ~/.minikube/files/etc/cni/net.d/ && touch ~/.minikube/files/etc/cni.net.d/k8s.conf and then to start minikube with CNI enabled: minikube start --network-plugin=cni --extra-config=kubelet.network-plugin=cni. Afterwards, you can install Weave Net.

```bash
kubectl apply -f "https://cloud.weave.works/k8s/net?k8s-version=$(kubectl version | base64 | tr -d '\n')"
```

## Install stern

* [Stern - aggregate log rendering tool](https://github.com/wercker/stern)

### via brew

```bash
brew install stern
```

### Binary release

```bash
sudo curl -L -o /usr/local/bin/stern \
   https://github.com/wercker/stern/releases/download/1.6.0/stern_linux_amd64
sudo chmod +x /usr/local/bin/stern
```

## Sysdig

### Install Sysdig

### Run Sysdig for Kubernetes

* collect API server address
* collect client cert + key
* https://www.digitalocean.com/community/tutorials/how-to-monitor-your-ubuntu-16-04-system-with-sysdig

```bash
certificate-authority: /home/joostvdg/.minikube/ca.crt
server: https://192.168.99.100:8443
client-certificate: /home/joostvdg/.minikube/client.crt
client-key: /home/joostvdg/.minikube/client.key
```

```bash
sysdig -k https://192.168.99.100:8443 -K /home/joostvdg/.minikube/client.crt:/home/joostvdg/.minikube/client.key

sysdig -k https://192.168.99.100:8443 -K /home/joostvdg/.minikube/client.crt:/home/joostvdg/.minikube/client.key syslog.severity.str=info
```

### CSysdig

```bash
sudo csysdig -k https://192.168.99.100:8443 -K /home/joostvdg/.minikube/client.crt:/home/joostvdg/.minikube/client.key
```

## From Udemy Course

