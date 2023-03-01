---
tags:
  - TKG
  - TAP
  - TANZU
  - DevSecOps
  - Grype
---

title: Use Grype In Restricted Environments
description: Tanzu Application Platform - Use Grype In Restricted Environments

# Use Grype In Restricted Environments


!!! Warning
    This guide is aimed at TAP version `1.3.4`.
    While some things might be applicable to other versions, it is best to verify.

One of the key components of the Scanning and Testing Supply Chain, is [Grype](https://github.com/anchore/grype).

It cross references packages from [SBOM](https://www.cisa.gov/sbom) files with CVE databases.

In restricted environments, Grype cannot retrieve these databases.
So we bring it to Grype instead.

What we want to achieve:

* Grype has access to an up-to-date CVE database
* TAP's Scanning & Testing pipeline uses Grype

To achieve that, we do the following:

* retrieve the database **listing** file, containing the index of vulnerability database files
* strip the listing to the latest files relevant to our version of Grype (version 5)
* relocate the database file(s) from our listing to an in-cluster storage solution
* update the listing to point to the relocated database file(s)
* upload the listing to the same in-cluster storage solution
* configure TAP so its Grype tasks, use the relocated listing and database files

!!! Warning "Pre-Requisites"

    As for the in-cluster storage solution, VMware supports and recommends MinIO.

    MinIO supports everything we need, so we use it for this guide.

    For installing MinIO, you can follow the [MinIO with custom CA](tanzu/minio-ca/) guide.

    To store the files we need, create a Bucket in MinIO named `grype`.

## Relocate Grype Database

### Verify MinIO Connection

First, make sure you have the [MinIO Client](https://min.io/docs/minio/linux/reference/minio-mc.html) installed.

Next, ensure your connection works by setting an alias.

```sh
export MINIO_HOSTNAME="minio-console.view.h2o-2-4864.h2o.vmware.com"
mc alias set minio_h20 https://$MINIO_HOSTNAME administrator 'VMware123!'
```

### Download Database Listing

The database listing of Grype is hosted by Anchor, the company behind the project.

First, ensure your current directory does not have an existing file.

```sh
rm listing.json
```

Next, download the listing with your favorite CLI.

=== "HTTPie"

    ```sh
    http --download https://toolbox-data.anchore.io/grype/databases/listing.json
    ```

=== "Curl"

    ```sh
    curl -O https://toolbox-data.anchore.io/grype/databases/listing.json
    ```

### Limit Listing

The listing file contains all the versions of the vulnerability database of the last couple of years.
Some of those are in different formats, to support older versions of Grype.

The current format is `v5`.
And, assuming you use the latest file, we can create a new `listing.json` file to limit it to the latest entry of `v5`.

```sh
cp listing.json listing_original.json
echo '{"available": {"5": [' > listing_tmp.json
cat listing_original.json | jq '.available."5"[0]' >> listing_tmp.json
echo ']}}' >> listing_tmp.json
cat listing_tmp.json | jq > listing.json
```

### Relocate Database File

Oke, so we now have the listing limited to the only database file we need.

We need to relocate the Database file(s) in the listing to MinIO.

The first step is to download them.
The script below generates a script with the download instructions per database file.

=== "HTTPie"

    ```sh
    cat listing.json |jq -r '.available[] | values[].url' \
      | awk '{print "http --download " $1}' > grype_down.sh
    ```

=== "Curl"

    ```sh
    cat listing.json |jq -r '.available[] | values[].url' \
      | awk '{print "curl -O " $1}' > grype_down.sh
    ```

=== "Wget"

    ```sh
    cat listing.json |jq -r '.available[] | values[].url' \
      | awk '{print "wget " $1}' > grype_down.sh
    ```

Make the script executable and run it, to download the database file.

```sh
chmod +x ./grype_down.sh
./grype_down.sh
```

We then upload the file to MinIO.

```sh
mc cp *.tar.gz minio_h20/grype/databases/
```

### Update Listing Addresses

Now that the database file is in MinIO, we update the Listing file with the new address.

We're using trusted old `sed` to replace the original URL with our MinIO one.

```sh
cp listing.json listing_copy.json
sed -i -e \
  "s/https:\/\/toolbox-data.anchore.io\/grype/https:\/\/$MINIO_HOSTNAME\/grype/g" \
  listing.json
```

Then we upload the updated listing file to MinIO as well.

```sh
mc cp listing.json minio_h20/grype/databases/
```

#### Verify Storage

You can use the MinIO Client to verify all the files are where they need to be.

```sh
mc ls minio_h20/grype/databases/
```

Which in my case looks like this:

```sh
[2023-02-24 12:30:11 CET]   362B STANDARD listing.json
[2023-02-24 12:30:08 CET] 115MiB STANDARD vulnerability-db_v5_2023-02-22T08:14:22Z_cdcf8d5090cea7f88618.tar.gz
[2023-02-24 12:30:06 CET] 115MiB STANDARD vulnerability-db_v5_2023-02-24T08:14:14Z_c949c91133733755c359.tar.gz
```

Make sure to verify the download address.
We need this for the **Grype** configuration in the **TAP** install values.

For example, like this:

```sh
http --verify=false \
  https://$MINIO_HOSTNAME/grype/databases/listing.json
```

## Update TAP Install

It's great we have the database and listing file internally now.

Unfortunately, unless the supply chain uses this, Grype still fails.

!!! Warning "Pre-requisites"

    Using Grype with TAP van be done manually, or via the pre-defined Scanning & Testing supply chain.

    The rest of the guide assumes you are have the following installed via TAP:
    * OOTB Scanning & Testing supply chain
    * Metadata Store

### Changes Required

The steps related to Grype, are the **Source Scan** and the **Image Scan**.

Both of these are configured via a Kubernetes CR, ***ScanTemplate***.

There are a couple of things we have to change in those Scan Templates, to get our supply chain to work.

* Trust the certificate Metadata Store
* Tell Grype to use our Listing file in MinIO
* Force Grype to update its database

We have two ways of doing this:

1. we can create a new supply chain, with alternatieve ***ScanTemplate***'s
1. we use a **YTT Overlay** to patch the existing ***ScanTemplate***'s

Customizing the Supply Chain and creating new Scan Templates requires more work.
So let us stick to the Overlay solution.

We first explain each component we add to the Overlay before showing the end result.

If you are impatient, you can go directly to the [overlay YAML](#overlay-yaml)

### Overlay For Scan Templates

To ensure Grype trusts the Metadata Store's certificate, we do the following:

* create a **ConfigMap** with the CA certificate in the Developer namespace
* add the ConfigMap to **volumes** and a **volumeMount** of the Scan Template task definition

The first one is straight forward:

```sh
kubectl create configmap ca-cert --from-file=ca.crt \
  --namespace ${TAP_DEVELOPER_NAMESPACE}
```

For each ScanTemplate we want to change, we have to add the volume, volumeMount, and set the `GRYPE_DB_CA_CERT` environment variable.

```yaml
    volumeMounts:
      #@overlay/append
      - name: ca-cert
        mountPath: /etc/ssl/certs/custom-ca.crt
        subPath: "ca.crt"
volumes:
#@overlay/append
- name: ca-cert
  configMap:
    name: ca-cert 
```

```yaml
- name: GRYPE_DB_CA_CERT
  value: /etc/ssl/certs/custom-ca.crt
```

Next, we configure Grype to use our in-cluster hosted database listing.

We do this by setting several environment variables.

Set environment vars for the scanning:

* **GRYPE_CHECK_FOR_APP_UPDATE**: Grype runs as part of a fixed container, updating won't work
* **GRYPE_DB_AUTO_UPDATE**: the automatic database update doesn't seem to work, so disable it and do it manually
* **GRYPE_DB_UPDATE_URL**: this is where we specify the location of our `listing.json` (e.g., `https://minio.view.h2o-2-4864.h2o.vmware.com/grype/databases/listing.json`)
* **GRYPE_DB_MAX_ALLOWED_BUILT_AGE**: specify how old the database is allowed to be, assuming you refresh the database every X period, specify X*2 to be safe (e.g., `240h`)
* **GRYPE_DB_VALIDATE_AGE**: or you can disable the database age check all together

This will look as follows:

```yaml
- name: GRYPE_CHECK_FOR_APP_UPDATE
  value: "false"
- name: GRYPE_DB_AUTO_UPDATE
  value: "false"
- name: GRYPE_DB_UPDATE_URL
  value: https://minio.view.h2o-2-4864.h2o.vmware.com/grype/databases/listing.json
- name: GRYPE_DB_MAX_ALLOWED_BUILT_AGE #! see note on best practices
  value: "1200h"
- name: GRYPE_DB_VALIDATE_AGE
  value: "false"
```

Next, we override the container commands, to force **Grype** to update its database.

We add the additional command `grype db update -vv`, which forces Grype to update its database with the current settings.
The `-vv` ensures verbose logging, which is especially useful when setting this up the first time.

It will look like this for the **Image Scan**, i.e. the ScanTemplate named `private-image-scan-template`.

```yaml
#@overlay/match by=overlay.subset({"name": "scan-plugin"}), expects="1+"
- name: scan-plugin
  #@overlay/replace
  args:
    - -c
    - |
      grype db update -vv
      ./image/scan-image.sh /workspace /workspace/scan.xml true
```

!!! Danger "Verify Commands On Upgrades"

    We are also overriding the command used by the ScanTemplate.

    When upgrading TAP, ensure these commands have not changed!

For the **Source Scan**, we do something similar.
It has a different command, so when it comes to the Overlay itself, you'll see more than one `#@overlay/match`.

For the **Source Scan**, we override two commands.
One for the `scan-plugin`, and one for the `metadatastore-plugin-config`.

For the `scan-plugin`, we add the same `grype db update -vv`.

```yaml
#@overlay/match by=overlay.subset({"name": "scan-plugin"}), expects="1+"
- name: scan-plugin
  #@overlay/replace
  args:
    - -c
    - |
      grype db update -vv
      ./source/scan-source.sh /workspace/source/scan.xml /workspace/source/out.yaml /workspace/source/repo blob
```

For the `metadata-store-plugin-config`, we add `/insight health` after the `/insight config` command, to verify the connection is working.

```yaml
#@overlay/match by=overlay.subset({"name": "metadata-store-plugin-config"}), expects="1+"
- name: metadata-store-plugin-config
  #@overlay/replace
  args:
    - -c
    - |
      set -euo pipefail
      /insight config set-target $METADATA_STORE_URL --ca-cert /metadata-store/ca.crt --access-token $METADATA_STORE_ACCESS_TOKEN
      /insight health
```

!!! Note "Insight command"
    The `/insight` command in the above Overlay snippet, is the [Tanzu CLI Insight plug-in](https://docs.vmware.com/en/VMware-Tanzu-Application-Platform/1.3/tap/GUID-cli-plugins-insight-cli-overview.html).

Before showing you the full overlay YAML, let's look at the overlay **match** statements.

For the **Image Scan**, we do the following:

```yaml
#@overlay/match by=overlay.subset({"kind":"ScanTemplate","metadata":{"namespace":"default", "name": "private-image-scan-template"}}),expects="1+"
```

This matches a `ScanTemplate` CR, in the developer namespace (in my case, `default`), named `private-image-scan-template`.

We then select the `scan-plugin` **initContainer**, with the following spec:

```yaml
spec:
  template:
    initContainers:
      #@overlay/match by=overlay.subset({"name": "scan-plugin"}), expects="1+"
      - name: scan-plugin
```

For the **Soure Scan**, we do something similar enough, it does not need to be repeated.

#### Overlay YAML

??? Example "Overlay YAML"

    ```yaml title="grype-airgap-overlay.yaml"
    apiVersion: v1
    kind: Secret
    metadata:
      name: grype-airgap-overlay
      namespace: tap-install #! namespace where tap is installed
    stringData:
      patch.yaml: |
        #@ load("@ytt:overlay", "overlay")

        #@overlay/match by=overlay.subset({"kind":"ScanTemplate","metadata":{"namespace":"default", "name": "private-image-scan-template"}}),expects="1+"
        #! developer namespace you are using
        ---
        spec:
          template:
            initContainers:
              #@overlay/match by=overlay.subset({"name": "scan-plugin"}), expects="1+"
              - name: scan-plugin
                #@overlay/match missing_ok=True
                env:
                  - name: GRYPE_CHECK_FOR_APP_UPDATE
                    value: "false"
                  - name: GRYPE_DB_AUTO_UPDATE
                    value: "false"
                  - name: GRYPE_DB_UPDATE_URL
                    value: https://minio.view.h2o-2-4864.h2o.vmware.com/grype/databases/listing.json
                  - name: GRYPE_DB_MAX_ALLOWED_BUILT_AGE #! see note on best practices
                    value: "1200h"
                  - name: GRYPE_DB_VALIDATE_AGE
                    value: "false"
                  - name: GRYPE_DB_CA_CERT
                    value: /etc/ssl/certs/custom-ca.crt
                #@overlay/replace
                args:
                  - -c
                  - |
                    grype db update -vv
                    ./image/scan-image.sh /workspace /workspace/scan.xml true
                volumeMounts:
                  #@overlay/append
                  - name: ca-cert
                    mountPath: /etc/ssl/certs/custom-ca.crt
                    subPath: "ca.crt" #! key pointing to ca certificate
            volumes:
            #@overlay/append
            - name: ca-cert
              configMap:
                name: ca-cert #! name of the configmap created

        #@overlay/match by=overlay.subset({"kind":"ScanTemplate","metadata":{"namespace":"default", "name": "blob-source-scan-template"}}),expects="1+"
        #! developer namespace you are using
        ---
        spec:
          template:
            initContainers:
              #@overlay/match by=overlay.subset({"name": "scan-plugin"}), expects="1+"
              - name: scan-plugin
                #@overlay/match missing_ok=True
                env:
                  - name: GRYPE_CHECK_FOR_APP_UPDATE
                    value: "false"
                  - name: GRYPE_DB_AUTO_UPDATE
                    value: "false"
                  - name: GRYPE_DB_UPDATE_URL
                    value: https://minio.view.h2o-2-4864.h2o.vmware.com/grype/databases/listing.json
                  - name: GRYPE_DB_MAX_ALLOWED_BUILT_AGE #! see note on best practices
                    value: "1200h"
                  - name: GRYPE_DB_VALIDATE_AGE
                    value: "false"
                  - name: GRYPE_DB_CA_CERT
                    value: /etc/ssl/certs/custom-ca.crt
                #@overlay/replace
                args:
                  - -c
                  - |
                    grype db update -vv
                    ./source/scan-source.sh /workspace/source/scan.xml /workspace/source/out.yaml /workspace/source/repo blob
                volumeMounts:
                  #@overlay/append
                  - name: ca-cert
                    mountPath: /etc/ssl/certs/custom-ca.crt
                    subPath: "ca.crt" #! key pointing to ca certificate

              #@overlay/match by=overlay.subset({"name": "metadata-store-plugin-config"}), expects="1+"
              - name: metadata-store-plugin-config
                #@overlay/replace
                args:
                  - -c
                  - |
                    set -euo pipefail
                    /insight config set-target $METADATA_STORE_URL --ca-cert /metadata-store/ca.crt --access-token $METADATA_STORE_ACCESS_TOKEN
                    /insight health

              #@overlay/match by=overlay.subset({"name": "metadata-store-plugin"}), expects="1+"
              - name: metadata-store-plugin
                #@overlay/match missing_ok=True
                env:
                  - name: METADATA_STORE_URL
                    value: https://metadata-store.view.h2o-2-4864.h2o.vmware.com/
                  - name: METADATA_STORE_ACCESS_TOKEN
                    valueFrom:
                      secretKeyRef:
                        key: auth_token
                        name: store-auth-token
                volumeMounts:
                  #@overlay/append
                  - mountPath: /metadata-store
                    name: metadata-store-ca-cert
                    readOnly: true
            volumes:
            #@overlay/append
            - name: ca-cert
              configMap:
                name: ca-cert #! name of the configmap created
    ```

    ```sh
    kubectl apply -f grype-airgap-overlay.yaml
    ```

### Debug Scanning Steps

If you want to debug the Grype commands, you have three ways of doing so.

1. you can create a custom supply chain with custom ScanTemplate CRs
1. you can add debug statements to the Overlay from the previous chapter
1. you can create a temporary **Pod**, with the same container and a `sleep` command

Below is an example of the debug Pod.

??? Example "Tanzu Insight CLI Debug Container"

    Dont't forget to replace the `METADATA_STORE_URL` and `image` values to your situation.

    ```yaml title="tanzu-insight-cli-debug.yaml"
    apiVersion: v1
    kind: Pod
    metadata:
      labels:
        app: tanzu-insight-cli
      name: tanzu-insight-cli
    spec:
      containers:
      - image: harbor.h2o-2-4864.h2o.vmware.com/tap/tap-packages@sha256:be7283548e81621899bd69b43b5b2cdf367eb82b111876690cea7cdca51bb9a2
        name: tanzu-insight-cli
        command: ['bash', '-c', 'echo "Hello, Kubernetes!" && sleep 3600']
        env:
          - name: METADATA_STORE_URL
            value: http://metadata-store.view.h2o-2-4864.h2o.vmware.com/
          - name: METADATA_STORE_ACCESS_TOKEN
            valueFrom:
              secretKeyRef:
                key: auth_token
                name: store-auth-token
        volumeMounts:
        - mountPath: /workspace
          name: workspace
          readOnly: false
        - mountPath: /.config
          name: insight-config
          readOnly: false
        - mountPath: /metadata-store
          name: metadata-store-ca-cert
          readOnly: true
      volumes:
      - emptyDir: {}
        name: workspace
      - emptyDir: {}
        name: insight-config
      - emptyDir: {}
        name: cache
      - name: metadata-store-ca-cert
        secret:
          secretName: store-ca-cert
      - configMap:
          name: ca-cert
        name: ca-cert
    ```

Create the Pod as usual:

```sh
kubectl apply -f tanzu-insight-cli-debug.yaml
```

And enter the Pod via `kubectl exec`.

```sh
kubectl exec tanzu-insight-cli -ti -- /bin/bash
```

Once inside the Pod, you can use the same commands we overide in the Overlay.
So you can debug the commands from there, and tweak your configuration before going through supply chain runs.
