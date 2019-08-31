title: Jenkins X - BuildPack
description: How To Create A BuildPack With Jenkins X

# Build Packs

There are multiple ways to create your own buildpack for Jenkins X.

* **Start from a working example**: either create a quickstart project or import your existing application. Make the build and promotions work and then create a new buildpack by making the same changes (parameterized where applicable) to a copy of the buildpack you started from.

## Start from a working example

We're going to build a buildpack for the following application:

* Micronaut framework
* build with Gradle
* with a Redis datastore
* with a TLS certificate for the ingress (https)

### Create Micronaut application

* create application via [Micronaut CLI](https://docs.micronaut.io/latest/guide/index.html)
* add a controller
* enable default healthendpoint
* import application with Jenkins X
* update helm chart: change healtcheck endpoint
* update helm chart: add dependency on Redis
* update values: set redis to not use a password

```bash
mn create-app example.micronaut.complete --features=kotlin,spek,tracing-jaeger,redis-lettuce
```

```bash
jx import
```

### Secrets

```bash
helm repo add soluto https://charts.soluto.io
helm repo update
```

```bash
helm upgrade --install kamus soluto/kamus
```