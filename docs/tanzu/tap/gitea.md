---
tags:
  - Gitea
  - Git
  - TAP
---

title: Setup Gitea
description: Setup Gitea for TAP in Build profile cluster

# Setup Gitea

For testing purposes, or in case there is no Git server yet, you can use [Gitea](https://gitea.io/en-us/).

> Gitea is a community managed lightweight code hosting solution written in Go. It is published under the MIT license.

This is especially useful for testing things like SSH access with TAP in restricted environments.

## Relocate Images

### Helm decomposer to list images

[Helm Decomposer](https://github.com/jkosik/helm-decomposer) is a small project that helps you list images used in a particular helm chart.

The Helm chart from Bitnami was a bit confusing, so I opted to use the official one instead.

Helm Decomposer requires the Helm chart binary, which we can get by running `helm pull <chartRepo>/<chartName>`.

```sh
helm pull gitea-charts/gitea --version 7.0.2
```

We then run Helm Decomposer on the file.

```sh
./helm-decomposer -chart gitea-7.0.2.tgz -i -o
```

Which gives us a complete list of the images used.

```sh
→ docker.io/bitnami/memcached:1.6.9-debian-10-r114
→ docker.io/bitnami/postgresql:11.11.0-debian-10-r62
→ busybox
→ gitea/gitea:1.18.3
```

### Copy Images

Assuming you want to relocate the images directly from Dockerhub to a Harbor instance, you can run the commands below.

!!! Warning
    These commands expect that you have a project in Harbor named `bitnami`.

```sh
docker pull docker.io/bitnami/memcached:1.6.9-debian-10-r114  --platform linux/amd64
docker tag docker.io/bitnami/memcached:1.6.9-debian-10-r114 $HARBOR_HOSTNAME/bitnami/memcached:1.6.9-debian-10-r114
docker push $HARBOR_HOSTNAME/bitnami/memcached:1.6.9-debian-10-r114
```

```sh
docker pull docker.io/bitnami/postgresql:11.11.0-debian-10-r62  --platform linux/amd64
docker tag docker.io/bitnami/postgresql:11.11.0-debian-10-r62 $HARBOR_HOSTNAME/bitnami/postgresql:11.11.0-debian-10-r62
docker push $HARBOR_HOSTNAME/bitnami/postgresql:11.11.0-debian-10-r62
```

```sh
docker pull docker.io/gitea/gitea:1.18.3  --platform linux/amd64
docker tag docker.io/gitea/gitea:1.18.3 $HARBOR_HOSTNAME/gitea/gitea:1.18.3
docker push $HARBOR_HOSTNAME/gitea/gitea:1.18.3
```

```sh
docker pull docker.io/library/busybox:1.36.0 --platform linux/amd64
docker tag docker.io/library/busybox:1.36.0 $HARBOR_HOSTNAME/library/busybox:1.36.0
docker push $HARBOR_HOSTNAME/library/busybox:1.36.0
docker tag docker.io/library/busybox:1.36.0 $HARBOR_HOSTNAME/library/busybox:latest
docker push $HARBOR_HOSTNAME/library/busybox:latest
```

## Certificate

It is recommended to always use a certificate with a Git server.

If you haven't setup an CA yet, [follow this guide first](/tanzu/custom-ca/).

Set the env variables that make sense for you.

```sh
export DOMAIN=h2o-2-4864.h2o.vmware.com
export BUILD_DOMAIN="build.${DOMAIN}"
export GITEA_HOSTNAME="gitea.${BUILD_DOMAIN}"
```

Then run the `cfssl` command to generate your certificate.

```sh
cfssl gencert -ca ssl/ca.pem -ca-key ssl/ca-key.pem \
  -config ssl/cfssl.json \
  -profile=server \
  -cn="${GITEA_HOSTNAME}" \
  -hostname="${GITEA_HOSTNAME},gitea.gitea.svc.cluster.local,localhost" \
   ssl/base-service-cert.json   | cfssljson -bare gitea
```

```sh
mv gitea-key.pem ssl/
mv gitea.pem ssl/
```

## Setup Secrets

### TLS Secret

First ensure the namespace exists.

```sh
kubectl create namespace gitea | true
```

Then create the TLS secret with your certificate.

```sh
kubectl create secret tls gitea-tls \
  --cert=ssl/gitea.pem \
  --key=ssl/gitea-key.pem \
  --namespace gitea
```

### Admin secret

First, ensure the namespace exists.

```sh
kubectl create namespace gitea | true
```

Then set the env variables so they make sense for you.

```sh
GITEA_ADMIN_USERNAME="gitea"
GITEA_ADMIN_PASSWORD='gitea'
GITEA_ADMIN_EMAIL="gitea@local.domain"
GITEA_ADMIN_SECRET="gitea-admin"
```

And then create the admin secret for Gitea to use.

```sh
kubectl create secret generic ${GITEA_ADMIN_SECRET} \
  --namespace gitea \
  --from-literal=password=${GITEA_PASSWORD} \
  --from-literal=username=${GITEA_ADMIN_PASSWORD} \
  --from-literal=email=${GITEA_ADMIN_EMAIL} 
```

## Install Gitea Helm Chart

First add the repository to your Helm client.

```sh
helm repo add gitea-charts https://dl.gitea.io/charts/
helm repo update
```

Assuming you still have the env variables setup, run the `ytt` command to generat the Helm values.

```sh
ytt -f ytt/gitea.ytt.yml \
  -v tlsSecret="gitea-tls" \
  -v passwordSecret="$GITEA_ADMIN_SECRET" \
  -v hostname="$GITEA_HOSTNAME" \
  > "gitea-values.yml"
```

!!! Info
    I always recommend using `helm upgrade --install` over `helm install`.

    As this means you will always use the same command for installing and updating that install.

    Else you run the risk of the install and update command diverging.

And then run the `helm upgrade --install` command.

```sh
helm upgrade --install \
  --values gitea-values.yml \
  --namespace gitea \
  gitea \
  gitea-charts/gitea
```

??? Example "Gitea YTT Template"

    ```yaml
    #@ load("@ytt:data", "data")
    ---
    global:
      imageRegistry: harbor.h2o-2-4864.h2o.vmware.com

    gitea:
      admin:
        existingSecret: #@ data.values.passwordSecret

    ingress:
      enabled: true
      className: contour
      hosts:
        - host: #@ data.values.hostname
          paths:
            - path: /
              pathType: Prefix
      tls:
      - secretName: #@ data.values.tlsSecret
        hosts:
          - #@ data.values.hostname
    ```

## References

* [Gitea Official Helm Chart](https://artifacthub.io/packages/helm/gitea/gitea)
* [Bitnami Gitea Helm chart](https://artifacthub.io/packages/helm/bitnami/gitea)
* [Blog post on using SSH keys with Gitea](https://medium.com/@gokhan.tenekecioglu/ssh-key-setup-for-gitea-6980101fc22e)