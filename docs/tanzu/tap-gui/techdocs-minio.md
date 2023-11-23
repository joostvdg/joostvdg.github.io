---
tags:
  - TAP
  - Tanzu
  - Backstage
  - Developer Portal
  - MinIO
  - TechDocs
---

title: TAP GUI - TechDocs with MinIO
description: Tanzu Application Platform GUI - Hosting the TechDocs with MinIO

# TAP GUI - TechDocs with MinIO

[TechDocs](https://backstage.io/docs/features/techdocs/) is a core feature of BackStage, allowing you to host documentation related to applications in a central place[^1].

> TechDocs is Spotify’s homegrown docs-like-code solution built directly into Backstage. Engineers write their documentation in Markdown files which live together with their code - and with little configuration get a nice-looking doc site in Backstage.

For more information, [read the announcement blog](https://backstage.io/blog/2020/09/08/announcing-tech-docs/)[^2].

The least amount of work to host the TechDocs is to use [AWS S3](https://s3.console.aws.amazon.com/s3/home)[^3].
You can find a complete example [in the TAP GUI TechDocs](https://docs.vmware.com/en/VMware-Tanzu-Application-Platform/1.5/tap/tap-gui-techdocs-usage.html) documentation[^4].

In the scenario that you cannot use S3 for one or another reason, we recommend using an S3 compatible API.
One tool we recommend to host such an S3 compatible API is [MinIO](https://min.io/)[^5].

In this guide, we'll do the following:

* Install MinIO with a Helm chart
* Create the Docs configuration for the application (TechDocs expect a specific format)
* Build the TechDocs for an example application
* Publish these TechDocs in MinIO
* Host the TechDocs in TAP GUI

## Install MinIO

We use the [Bitnami Helm Chart](https://artifacthub.io/packages/helm/bitnami/minio) to install MinIO[^6].

There is also a direct [VMware Tanzu integration](https://core.vmware.com/resource/minio-object-storage-vmware-cloud-foundation-tanzu#business-case) but this is out of scope[^7].

I make several assumptions with installing this Helm chart:

1. I use **FluxCD** to manage the Helm Releases ([see TAP GitOps services cluster](/tanzu/tap-gitops/services/))
1. The admin secret is created outside of the Helm Values
    * e.g., with **FluxCD** and its SOPS encryption
1. We use Cert-Manager to generate a valid certifcate for the MinIO endpoints
1. We use **Contour** as Ingress Controller
    * we disable the Ingress resource, and instead create the appropriate `HTTPProxy`s

### Existing Credentials

Let's create a Kubernetes `Secret` with the literal keys `root-user` and `root-password` (keys MinIO expects):

```sh
kubectl create secret generic minio-credentials \
  --from-literal=root-user="admin" \
  --from-literal=root-password='MySecretPassword' \
  --namespace minio \
  --dry-run=client \
  -oyaml > minio-credentials.yaml
```

!!! Warning "Password must be 8+ characters"
    While not clearly documented, the password for MinIO must be eight or more characters.

    Else the application fails to start.

If you prefer the YAML form, you can use this as the base for encrypting (assuming you're using GitOps with SOPS).

```yaml
apiVersion: v1
data:
  root-password: TXlTZWNyZXRQYXNzd29yZA==
  root-user: YWRtaW4=
kind: Secret
metadata:
  creationTimestamp: null
  name: minio-credentials
  namespace: minio
```

### Certificate

For TLS, I assume there's a `ClusterIssuer` that can create a certificate for us.

If not, you can create your own.

Either way, ensure both addresses that we're going to use are part of the associated DNS entries:

```yaml
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: minio
  namespace: minio
spec:
  secretName: minio-tls
  issuerRef:
    name: kearos-issuer
    kind: "ClusterIssuer"
  commonName: minio.services.my-domain.com
  dnsNames:
  - minio.services.my-domain.com
  - minio-console.services.my-domain.vmware.com
---
```

### HTTPProxy

While you can add both into a singular `HTTPProxy` if you really want,
I prefer separating each entry point.

```yaml
---
apiVersion: projectcontour.io/v1
kind: HTTPProxy
metadata:
  name: minio-api
  namespace: minio
spec:
  ingressClassName: contour
  virtualhost:
    fqdn: minio.services.my-domain.com
    tls:
      secretName: minio-tls
  routes:
  - services:
    - name: minio
      port: 9000
---
apiVersion: projectcontour.io/v1
kind: HTTPProxy
metadata:
  name: minio-console
  namespace: minio
spec:
  ingressClassName: contour
  virtualhost:
    fqdn: minio-console.services.my-domain.com
    tls:
      secretName: minio-tls
  routes:
  - services:
    - name: minio
      port: 9001
```

!!! Info "API and GUI ports"

    To be clear, MinIO as two ports: API and Console (or Web GUI).

    1. **9000**: is the API port, to be used by the `techdocs` CLI, and the MinIO CLI (`mc`)
    1. **9001**: is the Console port, where you find the Web GUI

    For using the browser to explore the files in the Buckets we need to expose and configure the Websocket port as well.

    So either you do that, or use the MinIO CLI (`mc`) to explore the buckets:

    ```sh
    mc ls ${MINIO_ALIAS}/${BUCKET}
    mc tree ${MINIO_ALIAS}/${BUCKET}
    ```

### FluxCD HelmRelease

Then we create the HelmRelease.

```yaml
kind: HelmRelease
metadata:
  name: minio
  namespace: minio
spec:
  interval: 5m
  timeout: 25m0s
  chart:
    spec:
      chart: minio
      version: "12.6.4"
      sourceRef:
        kind: HelmRepository
        name: bitnami
        namespace: default
      interval: 5m
  values:
    auth:
      existingSecret: minio-credentials
    mode: distributed
    statefulset:
      replicaCount: 4
```

!!! Info "If Using Helm"

    ```yaml title="minio-values.yaml"
    auth:
      existingSecret: minio-credentials
    mode: distributed
    statefulset:
      replicaCount: 4
    ```

    ```sh
    helm repo add bitnami https://charts.bitnami.com/bitnami
    ```
    
    ```sh
    helm repo update
    ```

    ```sh
    kubectl create namespace minio
    ```

    ```sh
    helm upgrade --install \
      minio bitnami/minio \
      --version 12.10.1 \
      --namespace minio \
      --values minio-values.yaml
    ```

## Create the Docs configuration

In the application itself, we create the ***Documentation as Code*** that we'll turn into the TechDocs.

Backstage relies on the [TechDocs plugin](https://backstage.io/docs/features/techdocs/) for hosting the site, and [TechDocs CLI](https://backstage.io/docs/features/techdocs/cli/) for building the site[^1] [^8].

The TechDocs has a specific format, as described in the [Backstage docs](https://backstage.io/docs/features/techdocs/creating-and-publishing) for how to create and publish the TechDocs[^9].

It is an extension of the popular [MKdocs](https://www.mkdocs.org/) which is a static site generator that takes Markdown as input and generates a static HTML adhering to all the latest browser expectations[^10].

### Example Docs

As the format is quite explicit, let me share an example that I've used for a personal [TAP test application](https://github.com/joostvdg/spring-boot-postgres) [^11].

We need a specific folder structure, a configuration file, and a appropriate MarkDown file.

The folder structure, including only what is relevant for the docs:

```sh
.
├── docs
│   └── index.md
└── mkdocs.yml
```

Next, let us look at the configuration file: `mkdocs.yml`.

```yaml
site_name: 'example-docs'

nav:
  - Home: index.md

plugins:
  - techdocs-core
```

Next, the mentioned `index.md`:

```markdown
---
hide:
- navigation
- toc
---

Welcome.

This is a demo project for Spring Boot with Postgresql &amp; [Service Bindings](https://servicebinding.io/) for [Tanzu Application Platform](https://docs.vmware.com/en/VMware-Tanzu-Application-Platform/index.html) (or TAP).
...
```

## Build the Docs

The TechDocs expand on the MKDocs tool, which has its own CLI and supported Docker container for building.

The TechDocs CLI can do both as well, so it is up to you which you prefer to use.

!!! Warning "Old Version of MKDocs"

    The TechDocs relies on a somewhat outdated MKDocs version, so if you use MKDocs or MKDocs + Material with newer versions use the Docker container.

### Test Locally

Before building the publishable site, we recommend to run the Live view locally first.

You can either use the `mkdocs` CLU directly:

```sh
mkdocs serve
```

Or run the TechDocs CLI, which runs it via Docker.

```sh
npx @techdocs/cli serve
```

If you do not want to use Docker, you can supply the `--no-docker` flag.
Instead of using Docker, it relies on the `mkdocs` CLI, so then you might as well use that directly.

### Build Site

In terms of building the site for publication, both CLIs offter the same _build_ command.
Both generate the site in the folder `./site`:

=== "mkdocs"

    ```sh
    mkdocs build
    ```

=== "techdocs"

    ```sh
    npx @techdocs/cli build
    ```

## Publish the Docs to MinIO

To publish the Docs to MinIO we need several steps:

* Build the docs
* Ensure the Bucket exists
* MinIO has a Region configured
* Know the Entity UID
* Ensure we have an [Access Key](https://min.io/docs/minio/linux/administration/identity-access-management/minio-user-management.html#access-keys) to write to the Bucket[^13]
* Use TechDocs CLI to upload the Site

As we just finished building the docs, we proceed with creating a Bucket.

### Create Bucket

We should have build the docs, so let's start with creating the Bucket.

My recommended way to do so, is via the `mc` CLI (MinIOs CLI)[^12]

First, we set an alias so we don't need to set our credentials everytime.

```sh
export MINIO_HOSTNAME=minio.services.my-domain.com
mc alias set minio_h20 https://$MINIO_HOSTNAME admin 'REPLACE_ME'
```

Then we create the Bucket called `docs`.

```sh
mc mb --ignore-existing minio_h20/docs
```

The `--ignore-existing` flag ensures the command does not fail if the Bucket already exists.

To verify the Bucket is created, we can do an `ls` on the root directory:

```sh
mc ls minio_h20/
```

### Set Region

To set the Region, you can either set the environment variable `MINIO_REGION` or by using the Console.

In the MinIO Console, navigate to `Settings` -> `Region`.
Once you set a Region, you need to restart the application for it to take effect.

### Know the Entity UID

Next, we need to know the Entity's UID.

The entity being the [Software Catalog](https://backstage.io/docs/features/software-catalog/) entry.

Our application is a [Component](https://backstage.io/docs/features/software-catalog/system-model#component), and in order for Backstage to tie the documentation to that Component, we need to upload it to a particular folder structure[^16].

> Entity uid separated by / in namespace/kind/name order (case-sensitive).
> Example: default/Component/myEntity

The path of a Component is related to its Software Catalog entry, and how it fits in within the larger [model](https://backstage.io/docs/features/software-catalog/system-model)[^14].

And unless you've created different Namespaces, it is safe to assume you can use `default`.

The name of my Component is `spring-boot-postgres`, so our entity UID becomes: `default/Component/spring-boot-postgres`.

This is the location the TechDocs feature in Backstage attempts to find your Component's docs.

### Access Key

Assuming you have an Access Key to use, set them as environment variables along with the Region:

```sh
export AWS_ACCESS_KEY_ID=Yc6VrJP....rcCbeAANj
export AWS_SECRET_ACCESS_KEY=IIvBAU4..........4oTFbMK5egWpZ3v5LOX4fcA
export AWS_REGION=us-east-1
```

### Publish Docs

These are then used by TechDocs CLI to publish the docs:

```sh
npx @techdocs/cli publish --publisher-type awsS3 \
  --awsEndpoint https://minio.my-domain.com \
  --storage-name docs \
  --entity default/Component/spring-boot-postgres \
  --awsS3ForcePathStyle
```

!!! Warning "Use awsS3 with Path Style"
    While MinIO implements the AWS S3 API, it isn't compatible with its newer version.

   We set the `--awsS3ForcePathStyle` flag to ensure it works with MinIO.

Alternatively, you can use the `mc cp` command to upload the docs.

```sh
mc cp --recursive ./site/ minio_h20/techdocs/default/Component/spring-boot-postgres
```

## Hosting the Docs in TAP GUI

Now that the TechDocs exist in the right place, it is time to show them.

To achieve this, we need to make TAP GUI host them.
This requires several more steps:

1. Add an annotation to the Software Catalog `Component` 
    * the annotation being `'backstage.io/techdocs-ref': 'dir:.'`
1. Register the Component in the Software Catalog
1. Configure TAP GUI to retrieve the TechDocs from our MinIO Bucket

### Create Component Manifest

Let's start with creating the Component manifest[^16], including the required annotation:

Below is an example generated by the TAP included Accelerator, witht he annotation added:

```yaml
apiVersion: backstage.io/v1alpha1
kind: Component
metadata:
  name: spring-boot-postgres
  description: Tanzu Java Web App with Spring Boot 3, using a PostgreSQL database.
  tags:
    - app-accelerator
    - java                                                   
    - spring
    - web
    - tanzu
  annotations:
    'backstage.io/kubernetes-label-selector': 'app.kubernetes.io/part-of=spring-boot-postgres'
    'backstage.io/techdocs-ref': 'dir:.'
spec:
  type: service
  lifecycle: experimental
  owner: teal
```

You can find out more about what you can configure in the Component manifest in the [Backstage docs](https://backstage.io/docs/features/software-catalog/system-model#component).

### Configure TAP GUI

The Backstage configuration is handled via the `tap_gui.app_config` property of the TAP install values.

In there, we can [configure the TechDocs](https://backstage.io/docs/features/techdocs/configuration) via the `techdocs` property[^17].

```yaml
tap_gui:
  app_config:
    techdocs:
      builder: 'external'
      publisher:
        type: 'awsS3'
        awsS3:
          bucketName: 'docs'
          credentials:
            accessKeyId: 'Yc6VrJP....rcCbeAANj'
            secretAccessKey: 'IIvBAU4..........4oTFbMK5egWpZ3v5LOX4fcA'
          region: 'us-east-1'
          s3ForcePathStyle: true                  
          forcePathStyle: true
          endpoint: https://minio.my-domain.com
```

By default, Backstage assumes it builds the TechDocs for you using the Docker Daemon and the MKdocs config and sources.

Alas, in Kubernetes that is a distinct anti-pattern.
We cannot use Docker without some complicated workarounds.

The alternative is what we've done.
Build the docs ourselves and publish the site to a storage location Backstage can read from.

This is why we set the `builder` to `external`, we build the docs outside of Backstage.

Next, we configure the publisher type `awsS3` with the special properties of `s3ForcePathStyle` and `forcePathStyle`.
Which one you need depends on the version of the AWS Client Library that is included, it is harmless to add both.

Once the TAP GUI server restarts, you can visit the TechDocs via two routes:

1. Open the Component via the Software Catalog (the `Home` page), then select the tab called `Docs`
1. Open the Docs menu via the menu bar on the left and find your Component

## References

[^1]: [Backstage docs - TechDocs feature](https://backstage.io/docs/features/techdocs/)
[^2]: [Backstage blog - TechDocs introduction](https://backstage.io/blog/2020/09/08/announcing-tech-docs/)
[^3]: [Amazon Webservices - S3 docs](https://s3.console.aws.amazon.com/s3/home)
[^4]: [TAP Docs - TAP GUI TechDocs](https://docs.vmware.com/en/VMware-Tanzu-Application-Platform/1.5/tap/tap-gui-techdocs-usage.html)
[^5]: [MinIO](https://min.io/)
[^6]: [ArtifactHub - MinIO Helm Chart](https://artifacthub.io/packages/helm/bitnami/minio)
[^7]: [VMware Tanzu - MinIO Integration](https://core.vmware.com/resource/minio-object-storage-vmware-cloud-foundation-tanzu#business-case)
[^8]: [Backstage - TechDocs CLI](https://backstage.io/docs/features/techdocs/cli/)
[^9]: [Backstage - TechDocs create and publish](https://backstage.io/docs/features/techdocs/creating-and-publishing)
[^10]: [MkDocs - is a fast, simple and downright gorgeous static site generator that's geared towards building project documentation](https://www.mkdocs.org/)
[^11]: [Joostvdg GitHub - Spring Boot Postgres example project](https://github.com/joostvdg/spring-boot-postgres)
[^12]: [MinIO - mc client](https://min.io/docs/minio/linux/reference/minio-mc.html)
[^13]: [MinIO - Manage Access Keys](https://min.io/docs/minio/linux/administration/identity-access-management/minio-user-management.html#access-keys)
[^14]: [Backstage - Software Catalog Model](https://backstage.io/docs/features/software-catalog/system-model)
[^15]: [Backstage - Software Catalog Overview](https://backstage.io/docs/features/software-catalog/)
[^16]: [Backstage - Software Catalog - Component](https://backstage.io/docs/features/software-catalog/system-model#component)
[^17]: [Backstage - TechDocs Configuration Options](https://backstage.io/docs/features/techdocs/configuration)
