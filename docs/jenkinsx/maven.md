title: Jenkins X For Maven
description: How To Use Jenkins X With Maven Projects

# Jenkins X + Maven + Nexus

The goal of this article it to demonstrate how [Jenkins X](https://jenkins-x.io/) works with [Maven](https://maven.apache.org/) and [Sonatype Nexus](https://www.sonatype.com/nexus-repository-sonatype).

Unless you configure otherwise, Jenkins X comes with a Nexus instance pre-configure out-of-the-box.

## Create Jenkins X Cluster

### Static

See:

#### Example

Here's an example for creating a standard Jenkins X installation in Google Cloud with GKE.
This example uses [Google Cloud](https://cloud.google.com/) and it's CLI, [gcloud](https://cloud.google.com/sdk/gcloud/).

Where:

* **CLUSTER_NAME**: the name of your GKE cluster
* **PROJECT**: the project ID of your Google Project/account (`gcloud config list`)
* **REGION**: the region in Google Cloud where you want to run this cluster, if you don't know, use `us-east1`

```bash
jx create cluster gke \
    --cluster-name ${CLUSTER_NAME} \
    --project-id ${PROJECT} \
    --region ${REGION} \
    --machine-type n1-standard-2 \
    --min-num-nodes 1 \
    --max-num-nodes 2 \
    --default-admin-password=admin \
    --default-environment-prefix jx-rocks \
    --git-provider-kind github \
    --skip-login \
    --batch-mode
```

### Serverless

See: 

## Nexus

### Open

To open Nexus' Web UI, you can use `jx open` to see it's URL.

By default, the URL will be `nexus.jx.<domain>`, for example `http://nexus.jx.${LB_IP}.nip.io`.

I recommend using a proper Domain name and use TLS via Let's Encrypt.
Jenkins X has built in support for this, via the `jx upgrade ingress` command.
This is food for another article though.

### Credentials

The username will be `admin`, the password depends on you.
If you specified the `--default-admin-password`, it will be that.

If you didn't specify the password, you can find it in a Kubernetes secret.

```bash
kubectl get secret nexus -o yaml
```

Which should look like this:

```yaml
apiVersion: v1
data:
  password: YWRtaW4=
kind: Secret
```

To retrieve the password, we have to decode the value of `password` with Base64.
On Mac or Linux, this should be as easy as the command below.

```bash
echo "YWRtaW4=" | base64 -D
```

### Use

Log in as Administrator and you get two views.
Either browse, which allows you to discover and inspect packages.

Or, Administrate (the Gear Icon) which allows you to manage the repositories.

For more information, [read the Nexus 3 documentation](https://help.sonatype.com/repomanager3).

## Use Nexus with Maven in Jenkins X

### Maven Library

#### Steps

* create new Jenkins X buildpack
* create new maven application
* import application into Jenkins X (with the Build Pack)
    * double check job in Jenkins
    * double check webhook in GitHub
* build the application in Jenkins
* verify package in Nexus

### Maven Application


#### Steps

* create new maven application
* add repository for local dev
* add dependency on library
* build locally
* import application into Jenkins X
* build application in Jenkins

## How the magic works

* build image
    * let's dig to see whats in it
* kubernetes secret with settings.xml
* maven repo
* maven distribution management
* maven mirror

## How would you do this yourself

### Options

* adjust Jenkins X's solution
* bridge Jenkins X's solution to your existing repo's
* create something yourself

### Adjust Jenkins X solution

* ?

### Bridge to existing

### Only to external


## Library

* buildpack https://github.com/jenkins-x-buildpacks/jenkins-x-classic/blob/master/packs/maven/pipeline.yaml

### Create new application

```bash
mvn archetype:generate -DarchetypeGroupId=org.apache.maven.archetypes -DarchetypeArtifactId=maven-archetype-quickstart -DarchetypeVersion=1.4
```

### Import JX

```bash
jx import --pack maven-lib -b
```

### Do we need it?

Seems to work without it as well.
Perhaps its inside the build image?

### Edit secret

* secret: jenkins-maven-settings
* add labels:
    * jenkins.io/credentials-type: secretFile
* https://jenkinsci.github.io/kubernetes-credentials-provider-plugin/examples/
* https://jenkinsci.github.io/kubernetes-credentials-provider-plugin/

### Pom xml config

In order to publish stuff, we need to make sure we have our distribution config setup.

```xml
<profiles>
    <profile>
        <id>jx-nexus</id>
        <distributionManagement>
            <repository>
                <id>nexus</id>
                <name>nexus</name>
                <url>${altReleaseDeploymentRepository}</url>
            </repository>
        </distributionManagement>
    </profile>
</profiles>
```

### Pipeline example

```groovy
pipeline {
    agent {
        label "jenkins-maven-java11"
    }
    stages {
        stage('Test') {
            environment {
                SETTINGS = credentials('another-test-file2')
            }
            steps {
                sh "echo ${SETTINGS}"
                sh 'cat ${SETTINGS}'
                container('maven') {
                    sh 'mvn clean javadoc:aggregate verify -C -e'
                    sh "mvn deploy --show-version --errors --activate-profiles jx-nexus --strict-checksums --settings ${SETTINGS}"
                }
            }
        }
    }
}
```

### Config example

```yaml
apiVersion: v1
kind: Secret
metadata:
# this is the jenkins id.
  name: "another-test-file2"
  labels:
# so we know what type it is.
    "jenkins.io/credentials-type": "secretFile"
  annotations:
# description - can not be a label as spaces are not allowed
    "jenkins.io/credentials-description" : "secret file credential from Kubernetes"
type: Opaque
stringData:
  filename: mySecret.txt
data:
# base64 encoded bytes
  data: PHNldHRpbmdzPgogICAgICA8IS0tIHNldHMgdGhlIGxvY2FsIG1hdmVuIHJlcG9zaXRvcnkgb3V0c2lkZSBvZiB0aGUgfi8ubTIgZm9sZGVyIGZvciBlYXNpZXIgbW91bnRpbmcgb2Ygc2VjcmV0cyBhbmQgcmVwbyAtLT4KICAgICAgPGxvY2FsUmVwb3NpdG9yeT4ke3VzZXIuaG9tZX0vLm12bnJlcG9zaXRvcnk8L2xvY2FsUmVwb3NpdG9yeT4KICAgICAgPCEtLSBsZXRzIGRpc2FibGUgdGhlIGRvd25sb2FkIHByb2dyZXNzIGluZGljYXRvciB0aGF0IGZpbGxzIHVwIGxvZ3MgLS0+CiAgICAgIDxpbnRlcmFjdGl2ZU1vZGU+ZmFsc2U8L2ludGVyYWN0aXZlTW9kZT4KICAgICAgPG1pcnJvcnM+CiAgICAgICAgICA8bWlycm9yPgogICAgICAgICAgICAgIDxpZD5uZXh1czwvaWQ+CiAgICAgICAgICAgICAgPG1pcnJvck9mPmV4dGVybmFsOio8L21pcnJvck9mPgogICAgICAgICAgICAgIDx1cmw+aHR0cDovL25leHVzL3JlcG9zaXRvcnkvbWF2ZW4tZ3JvdXAvPC91cmw+CiAgICAgICAgICA8L21pcnJvcj4KICAgICAgPC9taXJyb3JzPgogICAgICA8c2VydmVycz4KICAgICAgICAgIDxzZXJ2ZXI+CiAgICAgICAgICAgICAgPGlkPm5leHVzPC9pZD4KICAgICAgICAgICAgICA8dXNlcm5hbWU+YWRtaW48L3VzZXJuYW1lPgogICAgICAgICAgICAgIDxwYXNzd29yZD5hZG1pbjwvcGFzc3dvcmQ+CiAgICAgICAgICA8L3NlcnZlcj4KICAgICAgPC9zZXJ2ZXJzPgogICAgICA8cHJvZmlsZXM+CiAgICAgICAgICA8cHJvZmlsZT4KICAgICAgICAgICAgICA8aWQ+bmV4dXM8L2lkPgogICAgICAgICAgICAgIDxwcm9wZXJ0aWVzPgogICAgICAgICAgICAgICAgICA8YWx0RGVwbG95bWVudFJlcG9zaXRvcnk+bmV4dXM6OmRlZmF1bHQ6Omh0dHA6Ly9uZXh1cy9yZXBvc2l0b3J5L21hdmVuLXNuYXBzaG90cy88L2FsdERlcGxveW1lbnRSZXBvc2l0b3J5PgogICAgICAgICAgICAgICAgICA8YWx0UmVsZWFzZURlcGxveW1lbnRSZXBvc2l0b3J5Pm5leHVzOjpkZWZhdWx0OjpodHRwOi8vbmV4dXMvcmVwb3NpdG9yeS9tYXZlbi1yZWxlYXNlcy88L2FsdFJlbGVhc2VEZXBsb3ltZW50UmVwb3NpdG9yeT4KICAgICAgICAgICAgICAgICAgPGFsdFNuYXBzaG90RGVwbG95bWVudFJlcG9zaXRvcnk+bmV4dXM6OmRlZmF1bHQ6Omh0dHA6Ly9uZXh1cy9yZXBvc2l0b3J5L21hdmVuLXNuYXBzaG90cy88L2FsdFNuYXBzaG90RGVwbG95bWVudFJlcG9zaXRvcnk+CiAgICAgICAgICAgICAgPC9wcm9wZXJ0aWVzPgogICAgICAgICAgPC9wcm9maWxlPgogICAgICAgICAgPHByb2ZpbGU+CiAgICAgICAgICAgICAgPGlkPnJlbGVhc2U8L2lkPgogICAgICAgICAgICAgIDxwcm9wZXJ0aWVzPgogICAgICAgICAgICAgICAgICA8Z3BnLmV4ZWN1dGFibGU+Z3BnPC9ncGcuZXhlY3V0YWJsZT4KICAgICAgICAgICAgICAgICAgPGdwZy5wYXNzcGhyYXNlPm15c2VjcmV0cGFzc3BocmFzZTwvZ3BnLnBhc3NwaHJhc2U+CiAgICAgICAgICAgICAgPC9wcm9wZXJ0aWVzPgogICAgICAgICAgPC9wcm9maWxlPgogICAgICA8L3Byb2ZpbGVzPgogICAgICA8YWN0aXZlUHJvZmlsZXM+CiAgICAgICAgICA8IS0tbWFrZSB0aGUgcHJvZmlsZSBhY3RpdmUgYWxsIHRoZSB0aW1lIC0tPgogICAgICAgICAgPGFjdGl2ZVByb2ZpbGU+bmV4dXM8L2FjdGl2ZVByb2ZpbGU+CiAgICAgIDwvYWN0aXZlUHJvZmlsZXM+CiAgPC9zZXR0aW5ncz4K
```

## Create App

* create new java application with maven or gradle
* add dependency
* add repo: https://nexus.jx.kearos.net/repository/maven-public/

## Know Issues

* Jenkins X doesn't have a `kubernetes` buildpack for Maven libraries, so I'm not sure how to import that directly
    * which is why, for now, we create a new build pack first
* Jenkins X cannot import more than one application into static Jenkins within the same folder
    * requires GitHub issue + PR