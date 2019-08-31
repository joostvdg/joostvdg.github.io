title: Kubernetes Service - AWS EKS 
description: Kubernetes Public Cloud Service AWS EKS Via EKSCTL

# AWS EKS via eksctl

## EKS Access Configuration

Some reference configuration, this is assuming you need temporary access tokens based on a `assume role` while having a MFA device configured. I seemed to have to create a new token every X minutes. If you don't run into this, ignore the configuration below and go straight to creating the cluster.

### EKS Keys Config

```bash
[cloudbees-eks]
aws_access_key_id = ASI...
aws_secret_access_key = NMAX...
aws_session_token =  FQoGZXIvYXdzEJr//////////wE..................... // one long ass token
```

### Generate Temporary Access Tokens With MFA

```bash
keys=($(aws sts assume-role --profile default --role-arn arn:aws:iam::<ROLE_ARN>:role/<ROLE_NAME> \
  --role-session-name MyEKSCTLSession \
  --serial-number arn:aws:iam::<MFA_ARN>:mfa/<USER> \
  --token-code <REPLACE_THIS_WITH_MFA_TOKEN> \
  --query 'Credentials.[AccessKeyId,SecretAccessKey,SessionToken]' --output text))
```

## Cluster Create

```bash
EKS_CLUSTER_NAME=mycluster
AWS_PROFILE=cloudbees-eks
AWS_REGION=us-east-1
AWS_SSH_KEY_LOCATION="~/.ssh/id_rsa.pub"
EKS_NUM_NODES=4
```

```bash
eksctl create cluster \
    --asg-access \
    --auto-kubeconfig \
    --full-ecr-access \
    --name ${EKS_CLUSTER_NAME} \
    --profile ${AWS_PROFILE} \
    --region ${AWS_REGION} \
    --set-kubeconfig-context \
    --ssh-public-key ${AWS_SSH_KEY_LOCATION} \
    --nodes=${EKS_NUM_NODES} \
    --verbose 4
```

```bash
alias eks="kubectl --kubeconfig=~/.kube/eksctl/clusters/mycluster"
```

### Encrypted Network With Weavenet

If you want your network to be encrypted, you can use Weavenet.

!!! Warning
    The price of the encrypted network is high. So you're probably better off with a Network Policy.

```bash
WEAVENET_PASS=vjStsrzC4q7xDnb1wZkYacnk
IPALLOC_RANGE=10.10.0.0/24
```

```bash
echo "${WEAVENET_PASS}" > weave-passwd
eks create secret -n kube-system generic weave-passwd --from-file=weave-passwd
eks apply -f "https://cloud.weave.works/k8s/net?k8s-version=$(kubectl version | base64 | tr -d '\n')&password-secret=weave-passwd&env.IPALLOC_RANGE=${IPALLOC_RANGE}"
```

### Helm & Tiller

```bash
alias helmks="helm --kubeconfig=~/.kube/eksctl/clusters/mycluster"
```

```bash
eks create serviceaccount --namespace kube-system tiller
eks create clusterrolebinding tiller-cluster-rule --clusterrole=cluster-admin --serviceaccount=kube-system:tiller
helmks init --service-account tiller --upgrade
```

### Nginx

[Nginx Ingress Docs, How to install on AWS](https://kubernetes.github.io/ingress-nginx/deploy/#aws)

[CloudBees AWS Docs](https://go.cloudbees.com/docs/cloudbees-core/cloud-install-guide/eks-install/#_nginx_ingress_controller)

```bash
eks apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/master/deploy/mandatory.yaml
eks apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/master/deploy/provider/aws/service-l4.yaml
eks apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/master/deploy/provider/aws/patch-configmap-l4.yaml
eks patch service ingress-nginx -p '{"spec":{"externalTrafficPolicy":"Local"}}' -n ingress-nginx
```

### Certmanager

```bash
helmks install --name cert-manager --namespace default stable/cert-manager

echo "apiVersion: certmanager.k8s.io/v1alpha1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prd
spec:
  acme:
    # The ACME server URL
    server: https://acme-v02.api.letsencrypt.org/directory
    # Email address used for ACME registration
    email: yourname@example.com
    # Name of a secret used to store the ACME account private key
    privateKeySecretRef:
      name: letsencrypt-prd
    # Enable the HTTP-01 challenge provider
    http01: {}" > cluster-issuer.yml

eks apply -f cluster-issuer.yml
```

### Storage class

Create a `gp2` storage class and set it as default.

```bash
echo "kind: StorageClass
apiVersion: storage.k8s.io/v1
metadata:
  name: gp2
provisioner: kubernetes.io/aws-ebs
parameters:
  type: gp2
  encrypted: \"true\"" > gp2-storage.yaml

eks patch storageclass gp2 -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'
eks patch storageclass default -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"false"}}}'
```  

### Confirm

Confirm the storage class is create and set as default.

```bash
kubectl get sc
```

Expected result.

```bash
NAME            PROVISIONER             AGE
gp2 (default)   kubernetes.io/aws-ebs   59
```
