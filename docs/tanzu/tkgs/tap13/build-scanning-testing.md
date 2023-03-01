---
tags:
  - TKG
  - Vsphere
  - TAP
  - 1.3.4
  - TANZU
  - Grype
---

title: TAP Build Profile - Testing & Scanning Supply Chain
description: TAP Build Profile with Testing & Scanning Supply Chain on vSphere with Tanzu

# TAP Build Profile - Scanning & Testing Supply Chain

Make sure you go through the [Satisfy Pre-requisites](/tanzu/tkgs/tap13-overview/#satisfy-pre-requisites) section of the main guide first.

Now that we have all the pre-requisites out of the way, we can install the actual profile.

!!! Warning "SSH Access to Git Server"

    We recommend having access to your git server via SSH.

    You can take a look at TAP's [official docs](https://docs.vmware.com/en/VMware-Tanzu-Application-Platform/1.3/tap/GUID-scc-git-auth.html) or my [guide using Gitea](tanzu/tap/fluxcd-ssh/).

    To install Gitea, [look here](/tanzu/tap/gitea/).

## Metadata Store

As the name implies, the Testing & Scanning contains components that scan.

After the scans, it needs to put the result somewhere.

That somewhere is the **Metadata Store**.

The **Metadata Store** is part of the View profile, is it makes the scan results viewable.

### Collect Metadata Store Secrets

In order for the scanning tools to talk to the Metadata Store, they need a write token and its CA (to trust its certificate).

We collect these with from the cluster the **View** profile is installed on.

Run these commands on the view cluster (assuming the View profile is already installed).

```sh
AUTH_TOKEN_SECRET_NAME=$(kubectl get secret -n metadata-store -o name | grep metadata-store-app-auth-token-)
export METADATA_STORE_CA=$(kubectl get -n metadata-store ${AUTH_TOKEN_SECRET_NAME} -o yaml | yq '.data."ca.crt"')
export METADATA_STORE_ACCESS_TOKEN=$(kubectl get secrets metadata-store-read-write-client -n metadata-store -o jsonpath="{.data.token}" | base64 -d)
```

### Create Build Secrets

Now, go back to the cluster you aim to install (or update) the Build profile with the Testing & Scanning supply chain.

First, create the namespace to hold the secrets.

```sh
kubectl create namespace metadata-store-secrets
```

Create the certificate secret file.

```sh
cat <<EOF > store_ca.yaml
---
apiVersion: v1
kind: Secret
type: Opaque
metadata:
  name: store-ca-cert
  namespace: metadata-store-secrets
data:
  ca.crt: $METADATA_STORE_CA
EOF
```

And apply it to the cluster.

```sh
kubectl apply -f store_ca.yaml
```

And now create the access Token secret.

```sh
kubectl create secret generic store-auth-token \
  --from-literal=auth_token=$METADATA_STORE_ACCESS_TOKEN -n metadata-store-secrets
```

!!! Warning "Naming Conventions"
    The convention used here, is that both secrets are created in the `metadata-store-secrets` namespace.

    * The CA secret is called `store-ca-cert`, with the key `ca.crt`
    * The Token secret is called `store-auth-token`, and its key is `auth_token`

    These values are used in the TAP package values. If you change them here, you need to change them there as well

## Install Script

The install script encapsulates installed the Cluster Essentials, if required, and the TAP Fundamentals (secrets, namespace etc.) if required.

It also creates a package values file via a YTT template.

```sh title="tap-build-install-scan-test.sh"
#!/usr/bin/env bash
set -euo pipefail

TAP_VERSION=${TAP_VERSION:-"1.3.4"}
TAP_INSTALL_NAMESPACE="tap-install"
SECRET_GEN_VERSION=${SECRET_GEN_VERSION:-"v0.9.1"}
DOMAIN_NAME=${DOMAIN_NAME:-"127.0.0.1.nip.io"}
DEVELOPER_NAMESPACE=${DEVELOPER_NAMESPACE:-"default"}
INSTALL_TAP_FUNDAMENTALS=${INSTALL_TAP_FUNDAMENTALS:-"true"}
INSTALL_CLUSTER_ESSENTIALS=${INSTALL_CLUSTER_ESSENTIALS:-"false"}
VIEW_DOMAIN_NAME=${VIEW_DOMAIN_NAME:-"127.0.0.1.nip.io"}
GIT_SSH_SECRET_KEY=${GIT_SSH_SECRET_KEY:-"tap-build-ssh"}
METADATA_STORE_URL="metadata-store.${VIEW_DOMAIN_NAME}"
METADATA_STORE_SECRETS_NAMESPACE=${METADATA_STORE_SECRETS_NAMESPACE:-"metadata-store-secrets"}

if [ "$INSTALL_CLUSTER_ESSENTIALS" = "true" ]; then
  echo "> Installing Cluster Essentials (Kapp Controller, SecretGen Controller)"
  ./install-cluster-essentials.sh
fi

if [ "$INSTALL_TAP_FUNDAMENTALS" = "true" ]; then
  echo "> Installing TAP Fundamentals (namespace, secrets)"
  ./install-tap-fundamentals.sh
fi

kubectl create namespace ${METADATA_STORE_SECRETS_NAMESPACE} | true

kubectl create secret generic store-ca-cert \
  --namespace $METADATA_STORE_SECRETS_NAMESPACE \
  --from-literal=ca.crt=${METADATA_STORE_CA}

kubectl create secret generic store-auth-token \
  --namespace $METADATA_STORE_SECRETS_NAMESPACE \
  --from-literal=token="${METADATA_STORE_AUTH}"

ytt -f ytt/tap-build-profile-scan-test.ytt.yml \
  -v tbsRepo="$TBS_REPO" \
  -v buildRegistry="$BUILD_REGISTRY" \
  -v buildRegistrySecret="$BUILD_REGISTRY_SECRET" \
  -v buildRepo="$BUILD_REGISTRY_REPO" \
  -v domainName="$DOMAIN_NAME" \
  -v devNamespace="$DEVELOPER_NAMESPACE" \
  -v metadatastoreUrl="${METADATA_STORE_URL}" \
  -v sshSecret="${GIT_SSH_SECRET_KEY}" \
  -v caCert="${CA_CERT}" \
  > "tap-build-scan-test-values.yml"


tanzu package installed update --install tap \
  -p tap.tanzu.vmware.com \
  -v $TAP_VERSION \
  --values-file tap-build-scan-test-values.yml \
  -n ${TAP_INSTALL_NAMESPACE}
```

## YTT Template

The YTT template makes it easy to generate different configurations over time and for different environments.

!!! Warning "Grype in Internet Restricted environments"
    The main scanning tool used, is [Grype](https://github.com/anchore/grype).

    If your environment has restricted internet access, Grype requires some additional steps to work.

    Follow the [guide to Airgapped Grype](/tanzu/grype-airgapped/), and then come back.

    If you do **not** need this, remove the `package_overlays` section from the YTT and this values file.

Other notable elements, are `grype`, `supply_chain`, and `ootb_supply_chain_testing_scanning` configuration items.

It is through these settings we configure the Testing & Scanning supply chain.

```yaml title="tap-build-profile-scan-test.ytt.yml"
#@ load("@ytt:data", "data")
#@ dv = data.values
#@ kpRegistry = "{}/{}".format(dv.buildRegistry, dv.tbsRepo)
---
profile: build
buildservice:
  pull_from_kp_default_repo: true
  exclude_dependencies: true
  kp_default_repository: #@ kpRegistry
  kp_default_repository_secret:
    name: #@ dv.buildRegistrySecret
    namespace: tap-install

supply_chain: testing_scanning
ootb_supply_chain_testing_scanning:
  registry:
    server: #@ dv.buildRegistry
    repository: #@ dv.buildRepo
  gitops:
    ssh_secret: #@ dv.sshSecret

shared:
  ingress_domain: #@ dv.domainName
  ca_cert_data: #@ dv.caCert

ceip_policy_disclosed: true

grype:
  namespace: #@ dv.devNamespace
  targetImagePullSecret: #@ dv.buildRegistrySecret
  metadataStore:
    url: #@ dv.metadatastoreUrl
    caSecret:
        name: store-ca-cert
        importFromNamespace: metadata-store-secrets
    authSecret:
        name: store-auth-token
        importFromNamespace: metadata-store-secrets
scanning:
  metadataStore:
    url: "" #! this config has changed, but this value is still required 'for historical reasons'
package_overlays:
  - name: "grype"
    secrets:
      - name: "grype-airgap-overlay" #! see warning
```

!!! Note
    The configuration element `scanning.metadataStore.url` is a left over from previous versions.

    Unfortunately, we have to set it to `""`, to avoid problems.

    If it is set to a value, it will trigger an automation for configuring components which is no longer functional, causing the installation to fail.

## Script Input

The install script it designed to be fed with environment variables.

The script has some sane defaults, and where applicable we override them.

!!! Warning
    Don't forget to fill in the values for the registry secret passwords!

```sh
export INSTALL_TAP_FUNDAMENTALS="true" # creates namespace and secrets
export INSTALL_REGISTRY_HOSTNAME=${HARBOR_HOSTNAME}
export INSTALL_REGISTRY_USERNAME=admin
export INSTALL_REGISTRY_PASSWORD=''

export BUILD_REGISTRY=${HARBOR_HOSTNAME}
export BUILD_REGISTRY_REPO=tap-apps
export BUILD_REGISTRY_USER=admin
export BUILD_REGISTRY_PASS=''

export TAP_VERSION=1.3.4
export TBS_REPO=buildservice/tbs-full-deps

export DOMAIN_NAME=""
export DEVELOPER_NAMESPACE="default"
export CA_CERT=$(cat ssl/ca.pem)

export INSTALL_CLUSTER_ESSENTIALS="false"
```

!!! Info "Disable Cluster Essentials when using TMC"

    Clusters created via TMC get the Cluster Essentials installed automatically.
    
    So you set `INSTALL_CLUSTER_ESSENTIALS` to false, to avoid installing them twice.

    You do now have to create the **ConfigMap** for the **Kapp** controller for trusting the registry's CA.

    ```yaml
    #@ load("@ytt:data", "data")
    ---
    apiVersion: v1
    kind: Secret
    metadata:
      name: kapp-controller-config
      namespace: #@ data.values.namespace
    stringData:
      caCerts: #@ data.values.caCert
    ```

    ```sh
    KAPP_CONTROLLER_NAMESPACE=kapp-controller
    CA_CERT=$(cat ssl/ca.pem)
    ```

    ```sh
    ytt -f ytt/kapp-controller-config.ytt.yml \
      -v namespace=kapp-controller \
      -v caCert="${CA_CERT}" \
      > "kapp-controller-config.yml" 
    ```

    ```sh
    kubectl apply -f kapp-controller-config.yml --namespace $KAPP_CONTROLLER_NAMESPACE
    ```

## Values File Output

When running the install script, `tap-build-install-scan-test.sh`, it will generate the package value file.

The file, `tap-build-scan-test-values.yml`, will contain the translated values from the environment variables.

Below is an example from my own installation.

!!! Example "Resulting Values File"

    ```yaml title="tap-build-scan-test-values.yml"
    profile: build
    buildservice:
      pull_from_kp_default_repo: true
      exclude_dependencies: true
      kp_default_repository: harbor.h2o-2-4864.h2o.vmware.com/buildservice/tbs-full-deps
      kp_default_repository_secret:
        name: registry-credentials
        namespace: tap-install
    supply_chain: testing_scanning
    ootb_supply_chain_testing_scanning:
      registry:
        server: harbor.h2o-2-4864.h2o.vmware.com
        repository: tap-apps
      gitops:
        ssh_secret: tap-build-ssh
    shared:
      ingress_domain: build.h2o-2-4864.h2o.vmware.com
      ca_cert_data: |-
        -----BEGIN CERTIFICATE-----
        ...
        vhs=
        -----END CERTIFICATE-----
    ceip_policy_disclosed: true
    grype:
      namespace: default
      targetImagePullSecret: registry-credentials
      metadataStore:
        url: "https://metadata-store.view.h2o-2-4864.h2o.vmware.com/"
        caSecret:
          name: store-ca-cert
          importFromNamespace: metadata-store-secrets
        authSecret:
          name: store-auth-token
          importFromNamespace: metadata-store-secrets
    scanning:
      metadataStore:
        url: "" 
    package_overlays:
      - name: "grype"
        secrets:
          - name: "grype-airgap-overlay"
    ```

## Run Install

```sh
./tap-build-install-basic.sh
```

## Testing Pipeline

In TAP `1.3.x`, the Testing & Scanning Supply Chain does **not** contain a Testing ***Pipeline*** OOTB.

It expects that you create your own [Tekton Pipeline](https://tekton.dev/docs/pipelines/pipelines/) which can be found via the `apps.tanzu.vmware.com/pipeline: test ` label.

### Tekton Introduction

Tekton has a large number of CRs that let you create complex Continuous Delivery workflows.

For the sake of brevity, and to stick close to TAP, we'll limit this to the five most relevant ones.

* **Pipeline**: defines one or more tasks to be run, the order and how the tasks relate, essentially a **template**
* **PipelineRun**: a single run of a Pipeline, supplying the workspaces and parameters, an instance of a Pipeline (template)
* **Task**: a collection of one or more steps, using container images to execute commands, essentially a **template**
* **TaskRun**: a single run of a Task, supplying the workspaces and parameters, an instance of a Task (template)
* **Workspace**: not a CR itself, but an important concept, workspaces are volumes mounted into the container to do and share their work

``` mermaid
classDiagram
  Pipeline --> Task
  PipelineRun --> Pipeline
  TaskRun --> Task
  class Pipeline{
    +Task[] tasks
    +Parameter[] params
    +Workspace[] workspaces
  }
  class Task {
    +Parameter[] params
    +Workspace[] workspaces
    +Step[] steps
  }
  class TaskRun {
    +Task taskRef
    +Workspace[] workspaces
  }
  class PipelineRun {
    +Pipeline pipelineRef
    +Workspace[] workspaces
    +Parameter[] params
  }
```

The reason we explain this, is because you will find these resources (bar the `workspace`) in your namespace.

And in the event of failures or other problems, you need to take a lookt at their events.

With regard to creating **Task** CRs, there is the [Tekton Catalog](https://github.com/tektoncd/catalog) with a user friendly [GUI for exploring community Tasks](https://hub.tekton.dev/).

!!! Tip "Pipeline and Task are Namespaced"
    How the Tekton CRs work, can be confusing at first.

    Remember that both the Pipeline and Task CRs are _namespaces_.
    Meaning, they exist per namespace.

    So a Pipeline runs in a namespace (via its twin, PipelineRun) and can only use Tasks that live in the same Namspace!

    You can also create ***ClusterTask***s, which are as the name implied, cluster wide. 

    We recommend sticking to Pipelines and Tasks until you get more familliar with Tekton.

### Tekton and TAP

You migth wonder, "how does TAP trigger my Tekton Pipeline?".

The route is follows:

``` mermaid
graph LR
  A[ClusterSupplyChain] --> B[ClusterSourceTemplate];
  B --> C[ClusterRunTemplate]
  C --> D[PipelineRun]
  D --> E[Pipeline]
```

Don't worry if that sounds very daunting.

For a first iteration, you only need to create a `Pipeline` CR yourself.
The rest is taken care of by TAP and the OOTB Testing & Scanning Supply Chain.

For anything other than a POC, I recommend diving in a little more.

### Official Docs Example

Eventhough TAP doesn't ship with a default Tekton Pipeline CR, there is one listed in the [official docs](https://docs.vmware.com/en/VMware-Tanzu-Application-Platform/1.3/tap/GUID-getting-started-add-test-and-security.html#tekton-pipeline-config-example-3).

You can see the example below:

```yaml
apiVersion: tekton.dev/v1beta1
kind: Pipeline
metadata:
  name: developer-defined-tekton-pipeline
  labels:
    apps.tanzu.vmware.com/pipeline: test     # (!) required
spec:
  params:
    - name: source-url                       # (!) required
    - name: source-revision                  # (!) required
  tasks:
    - name: test
      params:
        - name: source-url
          value: $(params.source-url)
        - name: source-revision
          value: $(params.source-revision)
      taskSpec:
        params:
          - name: source-url
          - name: source-revision
        steps:
          - name: test
            image: gradle
            script: |-
              cd `mktemp -d`

              wget -qO- $(params.source-url) | tar xvz -m
              ./mvnw test
```

Assuming that you use a Java application build with Maven, this will work.

But I recommend learning how to create a proper Tekton Pipeline

## Create Tekton Pipeline

As described before, a Tekton Pipeline consists of Tasks, Parameters, and Workspaces.

The official docs example doesn't use a workspace, because it runs a single inline task.

In anyother scenario, you will want to define a Workspace, and that means we'll override the default **ClusterRunTemplate**.
We'll come to that later, for now, let's define a conceptual pipeline.

Let's say I have a Java application with Maven as its build tool.

For this application I want to run multiple tests and scans not included in TAP (e.g., SonarQube, Snyk).

We will need the following:

* a Workspace we can share between tasks (so we only checkout the code once)
* a Task that checks out our code (we can leverage the example for the docs)
* a Task that runs our tests
* a Task that runs other steps

The base Pipeline resource looks as like this:

```yaml
apiVersion: tekton.dev/v1beta1
kind: Pipeline
metadata:
  name: fluxcd-maven-test
spec:
  workspaces: []
  params: []
  tasks: []
```

TAP by default expects a label on the Pipeline, and uses two paramaters.
As those parameters make sense, let's add those pre-defined elements to the Pipeline.

```yaml hl_lines="6 10 11"
apiVersion: tekton.dev/v1beta1
kind: Pipeline
metadata:
  name: fluxcd-maven-test
  labels:
    apps.tanzu.vmware.com/pipeline: test     # (!) required
spec:
  workspaces: []
  params:
    - name: source-url                       # (!) required
    - name: source-revision                  # (!) required
  tasks: []
```

We need two workspaces.
One for Maven settings, and one for sharing the source copy between tasks.

```yaml hl_lines="9 10"
apiVersion: tekton.dev/v1beta1
kind: Pipeline
metadata:
  name: fluxcd-maven-test
  labels:
    apps.tanzu.vmware.com/pipeline: test     # (!) required
spec:
  workspaces:
    - name: shared-workspace
    - name: maven-settings
  params:
    - name: source-url                       # (!) required
    - name: source-revision                  # (!) required
  tasks: []
```

With TAP, FluxCD is constantly polling and updating its storage of GitRepositories.
So instead of having to do a Git checkout, we can instead opt to download the sources from FluxCD.

This is not recommended for Production, but its oke to get started.
And it saves us the trouble of having to setup a lot more resources and make a lot more changes to the OOTB Supply Chain.

Let's call that task `fetch-repository`.

For now, let's stick to a single Maven task which runs our tests.

Let's call that task `maven`.

```yaml hl_lines="15 16"
apiVersion: tekton.dev/v1beta1
kind: Pipeline
metadata:
  name: fluxcd-maven-test
  labels:
    apps.tanzu.vmware.com/pipeline: test     # (!) required
spec:
  workspaces:
    - name: shared-workspace
    - name: maven-settings
  params:
    - name: source-url                       # (!) required
    - name: source-revision                  # (!) required
  tasks:
    - name: fetch-repository
    - name: maven
```

Oke, but these tasks only have names so far.
We can either define them inline, or reference an existing Task (recommend).

We'll create the `fetch-repository` Task in the next section.
But for now, let's assume we'll give it the `source-url` parameter as input, as it contains the URL from where we can download the sources from FluxCD.

We'll also have to give it the `shared-workspace` Workspace, so it can copy the sources onto the shared workspace.

```yaml hl_lines="16-23"
apiVersion: tekton.dev/v1beta1
kind: Pipeline
metadata:
  name: fluxcd-maven-test
  labels:
    apps.tanzu.vmware.com/pipeline: test     # (!) required
spec:
  workspaces:
    - name: shared-workspace
    - name: maven-settings
  params:
    - name: source-url                       # (!) required
    - name: source-revision                  # (!) required
  tasks:
    - name: fetch-repository
      taskRef:
        name: fluxcd-repo-download
      workspaces:
        - name: output
          workspace: shared-workspace
      params:
        - name: source-url  
          value: $(params.source-url)
    - name: maven
```

For the maven Task, we have provide the Workspace, Parameters, and tell Tekton to run it _after_ `fetch-repository`.
Else, we cannot guarantee the shared workspace contains the source code.

We do this with the `runAfter` property.

```yaml hl_lines="25-40"
apiVersion: tekton.dev/v1beta1
kind: Pipeline
metadata:
  name: fluxcd-maven-test
  labels:
    apps.tanzu.vmware.com/pipeline: test     # (!) required
spec:
  workspaces:
    - name: shared-workspace
    - name: maven-settings
  params:
    - name: source-url                       # (!) required
    - name: source-revision                  # (!) required
  tasks:
    - name: fetch-repository
      taskRef:
        name: fluxcd-repo-download
      workspaces:
        - name: output
          workspace: shared-workspace
      params:
        - name: source-url  
          value: $(params.source-url)
    - name: maven
      taskRef:
        name: maven
      runAfter:
        - fetch-repository
      params:
        - name: CONTEXT_DIR
          value: tanzu-java-web-app
        - name: GOALS
          value:
            - clean
            - verify
      workspaces:
        - name: maven-settings
          workspace: maven-settings
        - name: output
          workspace: shared-workspace
```

Verify the Pipeline exists with the correct label.

```sh
kubectl get pipeline -l apps.tanzu.vmware.com/pipeline=test
```

This should yield:

```sh
NAME                 AGE
fluxcd-maven-test    7h8m
```

We now have a complete **Pipeline**, but we are referencing Tasks, via the `taskRef.name`, that don't exist.

### Tasks

Let us define the tasks that we refered to in the Pipeline.

#### fluxcd-repo-download

Normally, we would start a Pipeline with checking out the source with the relevant revision.
In the case of TAP, that is done for us by FluxCD.

Instead, we'll convert the inline Task, the `taskSpec`, from the official docs example into a propert Tekton Task.
In our Pipeline, we refered to it as `fluxcd-repo-download`, so let us use that name.

```yaml title="task-fluxcd-repo-download.yaml"
apiVersion: tekton.dev/v1beta1
kind: Task
metadata:
  name: fluxcd-repo-download
spec:
  params:
    - name: source-url
      type: string
      description: |
        the source url to download the code from, 
        in the form of a FluxCD repository checkout .tar.gz
  workspaces:
    - name: output
      description: The git repo will be cloned onto the volume backing this Workspace.
  steps:
    - name: download-source
      image: public.ecr.aws/docker/library/gradle:jdk17-focal
      script: |
        #!/usr/bin/env sh
        cd $(workspaces.output.path)
        wget -qO- $(params.source-url) | tar xvz -m
```

Some things to note:

* we define a workspace and a parameter, the Pipeline (via a PipelineRun) will provide these
* we use an image from AWS's public repository, to avoid rate limits at DockerHub
* we use a script, where we first change directory into our shared Workspace

Don't forget to apply this Task into TAP Developer Namespace.

```sh
kubectl apply -f task-fluxcd-repo-download.yaml \
  --namespace $TAP_DEVELOPER_NAMESPACE
```

#### maven

The second and last task, is the Maven task.

Here we can leverage the work of others, by starting with the [community task](https://hub.tekton.dev/tekton/task/maven).

In my case, something didn't align with the workspaces, so I renamed the Workspace in the Task to `output`, the same as in other common tasks (such as git-clone).

??? Example "Maven Task"

    ```yaml title="task-maven.yaml"
    apiVersion: tekton.dev/v1beta1
    kind: Task
    metadata:
      name: maven
      labels:
        app.kubernetes.io/version: "0.2"
      annotations:
        tekton.dev/pipelines.minVersion: "0.12.1"
        tekton.dev/categories: Build Tools
        tekton.dev/tags: build-tool
        tekton.dev/platforms: "linux/amd64,linux/s390x,linux/ppc64le"
    spec:
      description: >-
        This Task can be used to run a Maven build.

      workspaces:
        - name: output
          description: The workspace consisting of maven project.
        - name: maven-settings
          description: >-
            The workspace consisting of the custom maven settings
            provided by the user.
      params:
        - name: MAVEN_IMAGE
          type: string
          description: Maven base image
          default: gcr.io/cloud-builders/mvn@sha256:57523fc43394d6d9d2414ee8d1c85ed7a13460cbb268c3cd16d28cfb3859e641 #tag: latest
        - name: GOALS
          description: maven goals to run
          type: array
          default:
            - "package"
        - name: MAVEN_MIRROR_URL
          description: The Maven repository mirror url
          type: string
          default: ""
        - name: SERVER_USER
          description: The username for the server
          type: string
          default: ""
        - name: SERVER_PASSWORD
          description: The password for the server
          type: string
          default: ""
        - name: PROXY_USER
          description: The username for the proxy server
          type: string
          default: ""
        - name: PROXY_PASSWORD
          description: The password for the proxy server
          type: string
          default: ""
        - name: PROXY_PORT
          description: Port number for the proxy server
          type: string
          default: ""
        - name: PROXY_HOST
          description: Proxy server Host
          type: string
          default: ""
        - name: PROXY_NON_PROXY_HOSTS
          description: Non proxy server host
          type: string
          default: ""
        - name: PROXY_PROTOCOL
          description: Protocol for the proxy ie http or https
          type: string
          default: "http"
        - name: CONTEXT_DIR
          type: string
          description: >-
            The context directory within the repository for sources on
            which we want to execute maven goals.
          default: "."
      steps:
        - name: mvn-settings
          image: registry.access.redhat.com/ubi8/ubi-minimal:8.2
          script: |
            #!/usr/bin/env bash

            [[ -f $(workspaces.maven-settings.path)/settings.xml ]] && \
            echo 'using existing $(workspaces.maven-settings.path)/settings.xml' && exit 0

            cat > $(workspaces.maven-settings.path)/settings.xml <<EOF
            <settings>
              <servers>
                <!-- The servers added here are generated from environment variables. Don't change. -->
                <!-- ### SERVER's USER INFO from ENV ### -->
              </servers>
              <mirrors>
                <!-- The mirrors added here are generated from environment variables. Don't change. -->
                <!-- ### mirrors from ENV ### -->
              </mirrors>
              <proxies>
                <!-- The proxies added here are generated from environment variables. Don't change. -->
                <!-- ### HTTP proxy from ENV ### -->
              </proxies>
            </settings>
            EOF

            xml=""
            if [ -n "$(params.PROXY_HOST)" -a -n "$(params.PROXY_PORT)" ]; then
              xml="<proxy>\
                <id>genproxy</id>\
                <active>true</active>\
                <protocol>$(params.PROXY_PROTOCOL)</protocol>\
                <host>$(params.PROXY_HOST)</host>\
                <port>$(params.PROXY_PORT)</port>"
              if [ -n "$(params.PROXY_USER)" -a -n "$(params.PROXY_PASSWORD)" ]; then
                xml="$xml\
                    <username>$(params.PROXY_USER)</username>\
                    <password>$(params.PROXY_PASSWORD)</password>"
              fi
              if [ -n "$(params.PROXY_NON_PROXY_HOSTS)" ]; then
                xml="$xml\
                    <nonProxyHosts>$(params.PROXY_NON_PROXY_HOSTS)</nonProxyHosts>"
              fi
              xml="$xml\
                  </proxy>"
              sed -i "s|<!-- ### HTTP proxy from ENV ### -->|$xml|" $(workspaces.maven-settings.path)/settings.xml
            fi

            if [ -n "$(params.SERVER_USER)" -a -n "$(params.SERVER_PASSWORD)" ]; then
              xml="<server>\
                <id>serverid</id>"
              xml="$xml\
                    <username>$(params.SERVER_USER)</username>\
                    <password>$(params.SERVER_PASSWORD)</password>"
              xml="$xml\
                  </server>"
              sed -i "s|<!-- ### SERVER's USER INFO from ENV ### -->|$xml|" $(workspaces.maven-settings.path)/settings.xml
            fi

            if [ -n "$(params.MAVEN_MIRROR_URL)" ]; then
              xml="    <mirror>\
                <id>mirror.default</id>\
                <url>$(params.MAVEN_MIRROR_URL)</url>\
                <mirrorOf>central</mirrorOf>\
              </mirror>"
              sed -i "s|<!-- ### mirrors from ENV ### -->|$xml|" $(workspaces.maven-settings.path)/settings.xml
            fi

        - name: mvn-goals
          image: $(params.MAVEN_IMAGE)
          workingDir: $(workspaces.output.path)/$(params.CONTEXT_DIR)
          command: ["/usr/bin/mvn"]
          args:
            - -s
            - $(workspaces.maven-settings.path)/settings.xml
            - "$(params.GOALS)"
    ```

Don't forget to apply this Task into TAP Developer Namespace.

```sh
kubectl apply -f task-maven.yaml \
  --namespace $TAP_DEVELOPER_NAMESPACE
```

### Override TAP Templates

Unfortuantely, we're not there yet.

The predefined setup from TAP, creates a **PipelineRun** that does not match our **Pipeline**.

We have two options here, we can either update the existing **ClusterRunTemplate** `tekton-source-pipelinerun`, or create a new one.

If we create a new one, we also have to update the relevant **ClusterSupplyChain** and **ClusterSourceTemplate**.
The benefit, is that it gives a better understanding on how Cartographer's Supply Chains work.
Because of that, I recommend the first option: creating a new **ClusterRunTemplate**.

We can start by copying the existing **ClusterRunTemplate**; `tekton-source-pipelinerun`.

```sh
kubectl get ClusterRunTemplate tekton-source-pipelinerun \
   -o yaml > tekton-source-pipelinerun.yaml
```

#### Create ClusterRunTemplate

We have to add the two Workspaces, `maven-settings` and `shared-workspace`.

These are essentially container Volumes.
The Maven settings Workspace can be an `emptyDir: {}`, which is the minimum required to satisfy the requirement.

For the Shared Workspace, we do not want to have a volume automatically generated.
So we'll use a `volumeClaimTemplate`:

```yaml
workspaces:
- name: maven-settings
  emptyDir: {}
- name: shared-workspace
  volumeClaimTemplate:
    spec:
      accessModes:
      - ReadWriteOnce
      resources:
        requests:
          storage: 500Mi
      volumeMode: Filesystem
```

The cleaned up end-result looks like this.

```yaml title="tekton-source-pipelinerun-workspace.yaml"
apiVersion: carto.run/v1alpha1
kind: ClusterRunTemplate
metadata:
  name: tekton-source-pipelinerun-workspace
spec:
  outputs:
    revision: spec.params[?(@.name=="source-revision")].value
    url: spec.params[?(@.name=="source-url")].value
  template:
    apiVersion: tekton.dev/v1beta1
    kind: PipelineRun
    metadata:
      generateName: $(runnable.metadata.name)$-
      labels: $(runnable.metadata.labels)$
    spec:
      params: $(runnable.spec.inputs.tekton-params)$
      pipelineRef:
        name: $(selected.metadata.name)$
      podTemplate:
        securityContext:
          fsGroup: 65532
      workspaces:
      - name: maven-settings
        emptyDir: {}
      - name: shared-workspace
        volumeClaimTemplate:
          spec:
            accessModes:
            - ReadWriteOnce
            resources:
              requests:
                storage: 500Mi
            volumeMode: Filesystem
```

And apply it to your cluster.

```sh
kubectl apply -f tekton-source-pipelinerun-workspace
```

#### Create ClusterSourceTemplate

Now we either create a new **ClusterSourceTemplate** or we update the existing one.

There is not much different to do here, but in order to show where it is used in the Supply Chain, I recommend creating a new one.

The difficulty is that the value we need to change is inside a flattened YTT template.
There's a reference to our **ClusterRunTemplate**, the property being `runTemplateRef`.

I found it easiest to get export the existing one to a file, do a find & replace of the existing value, and apply the new file.

Don't forget to cleanup ids, annotations, and other managed fields.

```sh
kubectl get ClusterSourceTemplate testing-pipeline \
  -o yaml > testing-pipeline-workspace.yaml
```

Use your tool of choice, or refer back to `sed`.

First, we'll rename the resource.

```sh
sed -i -e "s/testing-pipeline/testing-pipeline-workspace/g" testing-pipeline-workspace.yaml
```

And then we'll update the reference to our **ClusterRunTemplate**.

```sh
sed -i -e "s/tekton-source-pipelinerun/tekton-source-pipelinerun-workspace/g" testing-pipeline-workspace.yaml
```

And apply it to your cluster.

```sh
kubectl apply -f testing-pipeline-workspace.yaml
```

#### Update ClusterSupplyChain

Last but not least, we update to **ClusterSupplyChain**, `source-test-scan-to-url`, to use the new **ClusterSourceTemplate**.

Retrieve the file.

```sh
kubectl get ClusterSupplyChain source-test-scan-to-url \
  -o yaml > source-test-scan-to-url.yaml
```

Don't forget to cleanup ids, annotations, and other managed fields.

```sh
sed -i -e "s/testing-pipeline/testing-pipeline-workspace/g" source-test-scan-to-url.yaml
```

## Scan Policies

We cannot yet run our Testing & Scanning pipeline, we need a Scan Policy!

The Scan Policy contains the rules by which to judge the outcome of the vulnerability scans.

For more information about this policy, [refer to the TAP docs](https://docs.vmware.com/en/VMware-Tanzu-Application-Platform/1.3/tap/GUID-scc-ootb-supply-chain-testing-scanning.html).

```yaml title="scan-policy.yaml"
apiVersion: scanning.apps.tanzu.vmware.com/v1beta1
kind: ScanPolicy
metadata:
  name: scan-policy
  labels:
    'app.kubernetes.io/part-of': 'enable-in-gui'
spec:
  regoFile: |
    package main

    # Accepted Values: "Critical", "High", "Medium", "Low", "Negligible", "UnknownSeverity"
    notAllowedSeverities := ["Critical", "High", "UnknownSeverity"]
    ignoreCves := []

    contains(array, elem) = true {
      array[_] = elem
    } else = false { true }

    isSafe(match) {
      severities := { e | e := match.ratings.rating.severity } | { e | e := match.ratings.rating[_].severity }
      some i
      fails := contains(notAllowedSeverities, severities[i])
      not fails
    }

    isSafe(match) {
      ignore := contains(ignoreCves, match.id)
      ignore
    }

    deny[msg] {
      comps := { e | e := input.bom.components.component } | { e | e := input.bom.components.component[_] }
      some i
      comp := comps[i]
      vulns := { e | e := comp.vulnerabilities.vulnerability } | { e | e := comp.vulnerabilities.vulnerability[_] }
      some j
      vuln := vulns[j]
      ratings := { e | e := vuln.ratings.rating.severity } | { e | e := vuln.ratings.rating[_].severity }
      not isSafe(vuln)
      msg = sprintf("CVE %s %s %s", [comp.name, vuln.id, ratings])
    }
```

!!! Info "Update The Policy To Reflect Reality"
    It is better to fix the leak before attempting to clear the bucket.

    So you might want to setup lest strict rules to start with, so that people get time to resolve them.

    For example, in our test application (see next section) there are some vulnerabilities.

    As I don't care too much about those at this point in time, I will update the policy.

    First, I'll restrict the `notAllowedSeverities` to `Critical` only.

    And then I add the known vulnerabilities in that category.
    If new Criticals show up, it will fail, but for now, we can start the pipeline

    ```yaml
    notAllowedSeverities := ["Critical"]
    ignoreCves := ["CVE-2016-1000027", "CVE-2016-0949","CVE-2017-11291","CVE-2018-12805","CVE-2018-4923","CVE-2021-40719","CVE-2018-25076","GHSA-45hx-wfhj-473x","GHSA-jvfv-hrrc-6q72","CVE-2018-12804","GHSA-36p3-wjmg-h94x","GHSA-36p3-wjmg-h94x","GHSA-6v73-fgf6-w5j7"]
    ```

    Read the [Triaging and Remediating CVEs](https://docs.vmware.com/en/VMware-Tanzu-Application-Platform/1.3/tap/GUID-scst-scan-triaging-and-remediating-cves.html) guide for more information.

When you're satistfied, apply the policy to the cluster.

```sh
kubectl apply -f scan-policy.yaml
```

## Test Workload

We first set the name of the developer namespace you have setup for TAP.

When creating a test Workload for the Testing & Scanning Suuply Chain, you need to set an additional label.

```sh
--label apps.tanzu.vmware.com/has-tests=true
```

This will trigger the Supply Chain and start your build.
If you omit this label, the TAP will say it cannot find a matching Supply Chain.

```sh
DEVELOPER_NAMESPACE=${DEVELOPER_NAMESPACE:-"default"}
```

!!! Info "Set up Developer Namespace"

    If you have not setup the developer namespace yet, you can do so in [this section](/tanzu/tkgs/tap13-overview/#setup-developer-namespace) of the main guide.

We can then either use the CLI or the `Workload` CR to create our test workload.

=== "Tanzu CLI"
    ```sh
    tanzu apps workload create smoke-app \
      --git-repo https://github.com/sample-accelerators/tanzu-java-web-app.git \
      --git-branch main \
      --type web \
      --label app.kubernetes.io/part-of=smoke-app \
      --label apps.tanzu.vmware.com/has-tests=true \
      --annotation autoscaling.knative.dev/minScale=1 \
      --yes \
      -n "$DEVELOPER_NAMESPACE"
    ```
=== "Kubernetes Manifest"
    ```sh
    echo "apiVersion: carto.run/v1alpha1
    kind: Workload
    metadata:
      labels:
        app.kubernetes.io/part-of: smoke-app
        apps.tanzu.vmware.com/workload-type: web
        apps.tanzu.vmware.com/has-tests=true
      name: smoke-app
      namespace: ${DEVELOPER_NAMESPACE}
    spec:
      params:
      - name: annotations
        value:
          autoscaling.knative.dev/minScale: \"1\"
      source:
        git:
          ref:
            branch: main
          url: https://github.com/sample-accelerators/tanzu-java-web-app.git
    " > workload.yml
    ```

    ```sh
    kubectl apply -f workload.yml
    ```

Use `kubectl wait` to wait for the app to be ready.

```sh
kubectl wait --for=condition=Ready Workload smoke-app --timeout=10m -n "$DEVELOPER_NAMESPACE"
```

To see the logs:

```sh
tanzu apps workload tail smoke-app
```

To get the status:

```sh
tanzu apps workload get smoke-app
```

And then we can delete our test workload if want to.

```sh
tanzu apps workload delete smoke-app -y -n "$DEVELOPER_NAMESPACE"
```

### Gitea & SSH

If you've setup Gitea and SSH, you can upload the example application to Gitea.

```sh
git clone https://github.com/vmware-tanzu/application-accelerator-samples && cd application-accelerator-samples
git remote add gitea https://gitea.build.h2o-2-4864.h2o.vmware.com/gitea/application-accelerator-samples.git
git push -u gitea main
```
