# Kubernetes Post Install

What to do after you've installed your Kubernetes cluster, whether that was EKS via eksctl or GKE via gcloud.

* make network more secure with encryption
    * weavenet for example
* install package manager
    * install helm & tiller
* use nginx for ssl termination together with Let's Encrypt
    * install nginx
    * install cert-manager

## Helm & Tiller

Helm is the defacto standard package manager for Kubernetes.

Its current iteration is version 2, which has a client component - Helm - and a serverside component, Tiller.

There's a problem with that, due this setup with Helm and Tiller, Tiller is aking to a cluster admin.
This isn't very secure and there are several ways around that.

* **JenkinsX**: its binary (`jx`) can install helm charts without using Tiller. It generates the kubernetes resource files and installs these directly
* **custom RBAC setup**: you can also setup RBAC in such a way that every separate namespace gets its own Tiller, limiting the reach of any Tiller

### Tiller Custom RBAC Example


#### Namespaces

```yaml
kind: Namespace
apiVersion: v1
metadata:
  name: sre
---
kind: Namespace
apiVersion: v1
metadata:
  name: dev1
---
kind: Namespace
apiVersion: v1
metadata:
  name: dev2
```

#### Service Accounts

```yaml
kind: ServiceAccount
apiVersion: v1
metadata:
  name: tiller
  namespace: dev1
---
kind: ServiceAccount
apiVersion: v1
metadata:
  name: tiller
  namespace: dev2
---
kind: ServiceAccount
apiVersion: v1
metadata:
  name: helm
  namespace: sre
```

#### Roles

```yaml
kind: Role
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: tiller-manager
  namespace: dev1
rules:
- apiGroups: ["", "batch", "extensions", "apps"]
  resources: ["*"]
  verbs: ["*"]
---
kind: Role
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: tiller-manager
  namespace: dev2
rules:
- apiGroups: ["", "batch", "extensions", "apps"]
  resources: ["*"]
  verbs: ["*"]
---
kind: ClusterRole
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: helm-clusterrole
rules:
  - apiGroups: [""]
    resources: ["pods/portforward"]
    verbs: ["create"]
  - apiGroups: [""]
    resources: ["pods"]
    verbs: ["list", "get"]
```

#### RoleBindings

```yaml
kind: RoleBinding
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: tiller-binding
  namespace: dev1
subjects:
- kind: ServiceAccount
  name: tiller
  namespace: dev1
roleRef:
  kind: Role
  name: tiller-manager
  apiGroup: rbac.authorization.k8s.io
---
kind: RoleBinding
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: tiller-binding
  namespace: dev2
subjects:
- kind: ServiceAccount
  name: tiller
  namespace: dev2
roleRef:
  kind: Role
  name: tiller-manager
  apiGroup: rbac.authorization.k8s.io
---
kind: ClusterRoleBinding
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: helm-clusterrolebinding
roleRef:
  kind: ClusterRole
  apiGroup: rbac.authorization.k8s.io
  name: helm-clusterrole
subjects:
  - kind: ServiceAccount
    name: helm
    namespace: sre
```

#### Install Tiller

```bash
helm init --service-account tiller --tiller-namespace dev1
helm init --service-account tiller --tiller-namespace dev2
```

#### Create KubeConfig for Helm client

```bash
# Find the secret associated with the Service Account
SECRET=$(kubectl -n sre get sa helm -o jsonpath='{.secrets[].name}')

# Retrieve the token from the secret and decode it
TOKEN=$(kubectl get secrets -n sre $SECRET -o jsonpath='{.data.token}' | base64 -D)

# Retrieve the CA from the secret, decode it and write it to disk
kubectl get secrets -n sre $SECRET -o jsonpath='{.data.ca\.crt}' | base64 -D > ca.crt

# Retrieve the current context
CONTEXT=$(kubectl config current-context)

# Retrieve the cluster name
CLUSTER_NAME=$(kubectl config get-contexts $CONTEXT --no-headers=true | awk '{print $3}')

# Retrieve the API endpoint
SERVER=$(kubectl config view -o jsonpath="{.clusters[?(@.name == \"${CLUSTER_NAME}\")].cluster.server}")

# Set up variables
KUBECONFIG_FILE=config USER=helm CA=ca.crt

# Set up config
kubectl config set-cluster $CLUSTER_NAME \
    --kubeconfig=$KUBECONFIG_FILE \
    --server=$SERVER \
    --certificate-authority=$CA \
    --embed-certs=true

# Set token credentials
kubectl config set-credentials \
    $USER \
    --kubeconfig=$KUBECONFIG_FILE \
    --token=$TOKEN

# Set context entry
kubectl config set-context \
    $USER \
    --kubeconfig=$KUBECONFIG_FILE \
    --cluster=$CLUSTER_NAME \
    --user=$USER

# Set the current-context
kubectl config use-context $USER \
    --kubeconfig=$KUBECONFIG_FILE
```

#### Helm Install

```bash
helm install \
    --name prometheus \
    stable/prometheus \
    --tiller-namespace dev1 \
    --kubeconfig config \
    --namespace dev1 \
    --set rbac.create=false

NAME:   prometheus
LAST DEPLOYED: Sun Oct 28 16:22:46 2018
NAMESPACE: dev1
STATUS: DEPLOYED
```

```bash
helm install --name grafana \
    stable/grafana \
    --tiller-namespace dev2 \
    --kubeconfig config \
    --namespace dev2 \
    --set rbac.pspEnabled=false \
    --set rbac.create=false

NAME:   grafana
LAST DEPLOYED: Sun Oct 28 16:25:18 2018
NAMESPACE: dev2
STATUS: DEPLOYED
```

### References

* https://medium.com/@elijudah/configuring-minimal-rbac-permissions-for-helm-and-tiller-e7d792511d10
* https://medium.com/virtuslab/think-twice-before-using-helm-25fbb18bc822
* https://jenkins-x.io/architecture/helm3/
* https://gist.github.com/innovia/fbba8259042f71db98ea8d4ad19bd708#file-kubernetes_add_service_account_kubeconfig-sh

