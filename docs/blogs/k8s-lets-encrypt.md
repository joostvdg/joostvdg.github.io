title: Let's Encrypt For Kubernetes
description: How To Leverage Let's Encrypt For Free And Stress-Free Certificate Management

# Let's Encrypt for Kubernetes

[Let's Encrypt](https://letsencrypt.org/) is a free, automated and open Certificate Authority. The kind of service you need if you want to have a secure website with https - yes I know that requires more than that - and it's now more straightforward to use than ever.

This about using Let's Encrypt for generating a certificate for your service on Kubernetes. There are several ways to do this, with more or less automation, cluster-wide or namespace bound or with a DNS or HTTP validation check.

I'll choose the route that was the easiest for me, and then I'll briefly look at the other options.

## Prerequisites

There are some prerequisites required, that are best discussed on their own.
So we will continue with the assumption that you have these in order.

* valid Class A or CNAME domain name
* kubernetes cluster
    * with ingress controller (such as nginx)
    * with helm and tiller installed in the cluster
* web application

## Steps

The steps to take to get a web application to get a certificate from Let's Encrypt are the following.

* install cert-manager from the [official helm chart](https://github.com/kubernetes/charts/tree/master/stable/cert-manager)
* deploy a `Issuer` resource
* deploy a certificate resource
* confirm certificate and secret are created/filled
* use in web app

## Install Cert Manager

For more details on Cert Manager, I recommend [reading their introduction](https://cert-manager.readthedocs.io/en/latest/index.html).

In essence, it's a tool that helps you initiate a certificate request with a service such as Let's Encrypt.

You can install it via Helm, and it's meant to be installed only once per cluster. 
The once per cluster restriction is due to the usage of Custom Resource Definitions (CRD's) which will block any (re-)installation.

To confirm if there are any CRD's from cert-manager, you can issue the following command.

```bash
kubectl get customresourcedefinitions.apiextensions.k8s.io
```

The CRD's belonging to cert-manager are the following:

* certificates.certmanager.k8s.io
* clusterissuers.certmanager.k8s.io
* issuers.certmanager.k8s.io

You will notice later, that we will use these CRD's for getting our certificate, so keep them in mind.
To remove them in case of a re-install, you can issue the command below.

```bash
kubectl delete customresourcedefinitions.apiextensions.k8s.io \
    certificates.certmanager.k8s.io \
    clusterissuers.certmanager.k8s.io \
    issuers.certmanager.k8s.io
```

When you're sure there are no CRD's left, you can install cert-manager via it's helm chart.
It has some options in case you need them, you read about them [here](https://github.com/helm/charts/tree/master/stable/cert-manager), but in my case that wasn't needed.

```bash
helm install --name cert-manager --namespace default stable/cert-manager
```

## Deploy Issuer

To be able to use a certificate we need to have a Certificate Issuer.

If you remember from our `cert-manager`, there are two CRD's that can take this role:

* **ClusterIssuer**: clusterissuers.certmanager.k8s.io
* **Issuer**: issuers.certmanager.k8s.io

Both issuer type can use two ways of providing the proof of ownership, either by `dns-01` or `http-01`.

We'll be using the `http-01` method, for the `dns-01` method, refer to the [cert-manager documenation](https://cert-manager.readthedocs.io/en/latest/tutorials/acme/dns-validation.html).

### ClusterIssuer

As the resource `Kind` implies, a `ClusterIssuer` is a cluster-wide resource and not bound to a specific namespace.

```YAML
apiVersion: certmanager.k8s.io/v1alpha1
kind: ClusterIssuer
metadata:
  name: letsencrypt-staging
spec:
  acme:
    # The ACME server URL
    server: https://acme-staging.api.letsencrypt.org/directory
    # Email address used for ACME registration
    email: user@example.com
    # Name of a secret used to store the ACME account private key
    privateKeySecretRef:
      name: letsencrypt-staging
    # Enable the HTTP-01 challenge provider
    http01: {}
```

### Issuer

Not everyone wants a cluster-wide resource, and not everyone has the rights to install something elsewhere than their namespace.

I prefer having as much as possible tied to a namespace - either a team or an application - I will use this type.

```YAML
apiVersion: certmanager.k8s.io/v1alpha1
kind: Issuer
metadata:
  name: myapp-letsencrypt-staging
  namespace: myapp
spec:
  acme:
    # The ACME server URL
    server: https://acme-staging-v02.api.letsencrypt.org/directory
    # Email address used for ACME registration
    email: myadmin@myapp.com
    # Name of a secret used to store the ACME account private key
    privateKeySecretRef:
      name: myapp-letsencrypt-staging
    # Enable the HTTP-01 challenge provider
    http01: {}
```

There's a few things to note here:

* **server**: this refers to the server executing the ACME test, in this case: Let's Encrypt Staging (with the v2 API)
* **email**: this will be the account it will use for registering the certificate
* **privateKeySecretRef**: this is the Kubernetes `secret` resource in which the privateKey will be stored, just in case you need or want to remove it

## Deploy Certificate Resource

Next up is our `Certificate` resource, this is where `cert-manager` will store our certificate details to be used by our application.

In case you forgot, this is one of the three CRD's provided by cert-manager.

```YAML
apiVersion: certmanager.k8s.io/v1alpha1
kind: Certificate
metadata:
  name: myapp-example-com
  namespace: myapp
spec:
  secretName: myapp-tls
  dnsNames:
  - myapp.example.com
  acme:
    config:
    - http01:
        ingressClass: nginx
      domains:
      - myapp.example.com
  issuerRef:
    name: myapp-letsencrypt-staging
    kind: Issuer
```

The things to note here:

* **name**: so far I've found it a naming convention to write the domain name where `-` replaces the `.`'s.
* **secretName**: the name of the Kubernetes secret that will house the certificate and certificate key
* **dnsNames**: you can specify more than one name, in our case just a single one, should match `acme.config.domains`
* **acme.config**: this defines the configuration for how the ownership proof should be done, this should match the method defined in the `Issuer`
* **issuerRef**: in good Kubernetes fashion, we reference the `Issuer` that should issue our certificate, the name and kind should match our Issue resource

## Confirm Resources

We have defined our set of resources that should create our valid - though not trusted, as it is staging - certificate.
Before we use it, we should confirm our secret and our certificate are both valid.

```bash
kubectl describe certificate myapp-example-com --namespace myapp
```

The response includes the latest status, which looks like this:

```YAML
Status:
  Acme:
    Order:
      URL:  https://acme-staging-v02.api.letsencrypt.org/acme/order/705.../960...
  Conditions:
    Last Transition Time:  2018-10-02T21:17:34Z
    Message:               Certificate issued successfully
    Reason:                CertIssued
    Status:                True
    Type:                  Ready
```

Next up is our secret, containing the actual certificate and the certificate key.

```bash
kubectl describe secret myapp-tls --namespace myapp
```

Which results in something like this:

```bash
Name:         myapp-tls
Namespace:    myapp
Labels:       certmanager.k8s.io/certificate-name=myapp-example-com
Annotations:  certmanager.k8s.io/alt-names: myapp.example.com
              certmanager.k8s.io/common-name: myapp.example.com
              certmanager.k8s.io/issuer-kind: Issuer
              certmanager.k8s.io/issuer-name: myapp-letsencrypt-staging

Type:  kubernetes.io/tls

Data
====
tls.crt:  3797 bytes
tls.key:  1679 bytes
```

## Use certificate to enable https

Assuming the secret and the certificate are correct, we can use them to enable https on our web app.

We put the tls certificate on the ingress of the application, in this case, Nginx, which assumes the following about the app:

* it has a deployment or stateful set
* it has a service which provides and endpoint to one or more instances
* it has an nginx ingress which points to the service

### Deployment

```yaml

kind: Deployment
apiVersion: apps/v1
metadata:
  name: myapp
  namespace: myapp
  labels:
    app: myapp
spec:
  replicas: 3
  selector:
    matchLabels:
      app: myapp
  template:
    metadata:
      labels:
        app: myapp
    spec:
      containers:
      - name: myapp
        image: caladreas/catnip-master
        imagePullPolicy: Always
        ports:
        - containerPort: 8087
```

You should always include livenessprobe, resource limits and so on.
But for the sake of brevity, these are omitted!

### Service

```yaml
apiVersion: v1
kind: Service
metadata:
  name: myapp
  namespace: myapp
  labels:
    app: myapp
spec:
  selector:
    app: myapp
  ports:
  - name: http
    port: 80
    targetPort: 8087
    protocol: TCP
```

### Ingress for Issuer

```yaml
apiVersion: extensions/v1beta1
kind: Ingress
metadata:
  name: myapp
  namespace: myapp
  annotations:
    kubernetes.io/ingress.class: "nginx"
    ingress.kubernetes.io/ssl-redirect: "true"
    certmanager.k8s.io/issuer: myapp-letsencrypt-staging
    certmanager.k8s.io/acme-challenge-type: http01
spec:
  rules:
  - host: myapp.example.com
    http:
      paths:
      - path: /
        backend:
          serviceName: myapp
          servicePort: 80
  tls:
  - hosts:
    - myapp.example.com
    secretName: myapp-tls
```

### Ingress for ClusterIssuer

```yaml
apiVersion: extensions/v1beta1
kind: Ingress
metadata:
  name: myapp
  namespace: myapp
  annotations:
    kubernetes.io/ingress.class: "nginx"
    ingress.kubernetes.io/ssl-redirect: "true"
    certmanager.k8s.io/cluster-issuer: letsencrypt-staging
    certmanager.k8s.io/acme-challenge-type: http01
spec:
  rules:
  - host: myapp.example.com
    http:
      paths:
      - path: /
        backend:
          serviceName: myapp
          servicePort: 80
  tls:
  - hosts:
    - myapp.example.com
    secretName: myapp-tls
```

## Further resources

* [How Does Let's Encrypt Work](https://letsencrypt.org/how-it-works/)
* [Tutorial that inspired this page](https://hk.saowen.com/a/c045f2a12e66d94d7addce9101a61887e7f904aaa8efaed07a0e0a1325ab8c55)
* [Amazone EKS Ingress Guide](https://medium.com/@dmaas/amazon-eks-ingress-guide-8ec2ec940a70)
* [Kuberetes EKS Ingress and TLS](https://stackoverflow.com/questions/51363674/kubernetes-eks-ingress-and-tls)
* [How To Configure LTS for Nginx Ingress](https://github.com/kubernetes/contrib/tree/master/ingress/controllers/nginx/examples/tls)
