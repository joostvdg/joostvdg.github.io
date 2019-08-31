title: Kubernetes The Hard Way (KHW) - Google Cloud 
description: Kubernetes The Hard Way - Encryption (5/11)
hero: Encryption (5/11)

# Encryption

> Kubernetes stores a variety of data including cluster state, application configurations, and secrets. Kubernetes supports the ability to encrypt cluster data at rest.

In order to use this ability to encrypt data at rest, each member of the control plane has to know the encryption key.

So we will have to create one.

## Encryption configuration

We have to create a encryption key first.
For the sake of embedding it into a yaml file, we will have to encode it to `base64`.

```bash
ENCRYPTION_KEY=$(head -c 32 /dev/urandom | base64)
```

```yaml

```

## Install scripts

Make sure you're in `k8s-the-hard-way/scripts`

```bash
./encryption.sh
```
