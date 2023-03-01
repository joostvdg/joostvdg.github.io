---
tags:
  - TKG
  - Vsphere
  - minio
  - TANZU
---

title: MinIO custom CA
description: MinIO with a Custom CA

# Minio custom CA

As a pre-requisite, make sure you have setup a Certificate Authirity with [CFSSL](https://github.com/cloudflare/cfssl).

If you not already done so, follow [Set up custom Certificate Authority](/tanzu/custom-ca/).

## Relocate Images

In case you are in an restricted environment, or you want to avoid DockerHub rate limits, relocate the images used in the Helm chart.

The tags of the images depend on the version of the Helm chart.
We will use version `12.1.8`, which comes with the version of the `bitnami/minio` and `bitnami/minio-client` images.

First, set the **hHostname** of your Registry:

```sh
export REGISTRY_HOSTNAME=
```

!!! Warning

    Make sure you are authenticated with your registry.

    For example, you can use `docker login` or Docker replacement equivalent commands:

    ```sh
    docker login $REGISTRY_HOSTNAME
    ```

Then you can relocate the `bitnami/minio` image:

```sh
docker pull bitnami/minio:2023.2.22-debian-11-r0
docker tag bitnami/minio:2023.2.22-debian-11-r0 ${REGISTRY_HOSTNAME}/bitnami/minio:2023.2.22-debian-11-r0
docker push ${REGISTRY_HOSTNAME}/bitnami/minio:2023.2.22-debian-11-r0
```

And the `bitnami/minio-client` image:

```sh
docker pull bitnami/minio-client:2023.2.16-debian-11-r1
docker tag bitnami/minio-client:2023.2.16-debian-11-r1 ${REGISTRY_HOSTNAME}/bitnami/minio-client:2023.2.16-debian-11-r1
docker push ${REGISTRY_HOSTNAME}/bitnami/minio-client:2023.2.16-debian-11-r1
```

## Create Certificate

Before we create the certificate, we need to be sure of the domain names to use for the MinIO API and the GUI.

```sh
export MINIO_HOSTNAME=
export MINIO_CONSOLE_HOSTNAME=
```

To ensure you can use MinIO within the cluster without going through the Ingress Controller, we also add internal hostnames.

```sh
cfssl gencert -ca ca.pem -ca-key ca-key.pem \
  -config cfssl.json \
  -profile=server \
  -cn="${MINIO_HOSTNAME}" \
  -hostname="${MINIO_HOSTNAME},${MINIO_CONSOLE_HOSTNAME},*.minio-headless.minio.svc.cluster.local,minio.minio.svc.cluster.local,localhost" \
   base-service-cert.json   | cfssljson -bare minio-server
```

We need to add the certificate, its key, and the CA certificate to Kubernetes secret.
We copy the files to reduce the complexity of the commands that follow.

```sh
mkdir minio-certs
cp minio-server-key.pem minio-certs/tls.key
cp minio-server.pem minio-certs/tls.crt
cp ca.crt minio-certs/ca.crt
cd minio-certs/
```

## Create Secrets

First, ensure the `minio` Namespace exists.

```sh
kubectl create namespace minio
```

Then you can create the secret for letting MinIO terminate TLS.

This is recommended, so you secure connections in your cluster as well.
That is also why we added the internal hostnames to the Certificate.

```sh
kubectl create secret generic tls-ssl-minio-unmanaged \
  --from-file=tls.crt \
  --from-file=tls.key \
  --from-file=ca.crt \
  --namespace minio
```

We then create a secret we use for the HTTPProxy resources, or Ingress CR depending on your Ingress Controller.

```sh
kubectl create secret tls tls-ssl-minio-for-proxy \
  --cert=tls.crt \
  --key=tls.key \
  --namespace minio
```

Then we create a secret with only the `ca.crt` for Contour, so it can verify the connection with TLS.

```sh
kubectl create secret generic client-root-ca \
  --from-file=ca.crt \
  --namespace minio
```

Next up is setting up the credentials for MinIO:

```sh
MINIO_USER=
MINIO_PASS=
```

```sh
kubectl create secret generic minio-credentials \
  --from-literal=root-user="${MINIO_USER}" \
  --from-literal=root-password="${MINIO_PASS}" \
  --namespace minio
```

## Helm Chart Install

We use the [Bitnami MinIO](https://artifacthub.io/packages/helm/bitnami/minio) Helm chart.

### Create Values File

Create `minio-values.yaml`.

The goal of using something like MinIO is to provide reliable storage.
So the assumption is that you need replica's and replication.

For this, we set `mode: distributed` and `statefulset.replicaCount: 4`.
If you are using it as a test in a non-production environment, you can set this lower values.

Consult the [helm chart docs](https://artifacthub.io/packages/helm/bitnami/minio) for more details

!!! Example "Helm Values"

    ```yaml title="minio-values.yaml"
    global:
      imageRegistry: REPLACE_WITH_IMAGE_REGISTRY
      storageClass: REPLACE_WITH_STORAGE_CLASS
    auth:
      existingSecret: minio-credentials
    mode: distributed
    statefulset:
      replicaCount: 4
    service:
      annotations:
        projectcontour.io/upstream-protocol.tls: "9000,9001"
    tls:
      enabled: true
      existingSecret: tls-ssl-minio-unmanaged
    ```

### Helm Chart Install

And then you can install the Helm chart.

!!! Example "Helm Install"

    ```sh
    helm upgrade --install \
      --namespace minio \
      --values minio-values.yaml \
      --version 12.1.8 \
      minio \
      bitnami/minio
    ```

## MinIO HTTPProxies

TODO: create YTT template and generate both files

We create two HTTPProxy resources, one for the GUI (console) and one for the backend (API).

!!! Warning
    If you do not use Contour as Ingress Controller,
    create the equiavalent Ingress CRs.


!!! Example "YTT Template for HTTPPRoxy"

    ```yaml title="minio-httpproxy.ytt.yml"
    #@ load("@ytt:data", "data")
    ---
    apiVersion: projectcontour.io/v1
    kind: HTTPProxy
    metadata:
      name: #@ data.values.name
      namespace: minio
    spec:
      virtualhost:
        fqdn: #@ data.values.fqdn
        tls:
          secretName: tls-ssl-minio-for-proxy
      routes:
        - services:
            - name: minio
              port: #@ data.values.port
              validation:
                caSecret: client-root-ca
                subjectName: #@ data.values.fqdn
    ```

* create `minio-console-httpproxy.yaml`

!!! Example "Web Console HTTPProxy"

    ```sh
    ytt -f minio-httpproxy.ytt.yml \
      -v fqdn="${MINIO_CONSOLE_HOSTNAME}" \
      -v name="minio-console" \
      -v port="9001" \
      > minio-console-httpproxy.yaml
    ```

    ```sh
    kubectl apply -f minio-console-httpproxy.yaml
    ```

* create `minio-api-httpproxy.yaml`:

!!! Example "API HTTPProxy"

    ```sh
    ytt -f minio-httpproxy.ytt.yml \
      -v fqdn="${MINIO_HOSTNAME}" \
      -v name="minio-api" \
      -v port="9000" \
      > minio-api-httpproxy.yaml
    ```

    ```sh
    kubectl apply -f minio-api-httpproxy.yaml
    ```
