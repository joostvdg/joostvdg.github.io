title: Jenkins X - Java Native Image Prod
description: Creating a Java Native Image application and run it as Production with Jenkins X - Pipeline Improvements - 7/8
hero: Pipeline Improvements - 7/8

# Pipeline Improvements

Now that the application runs in staging as a Native Image, it is time to make further improvements to our pipeline.

There are a dozen additional checks I'd like to add to the pipeline to increase confidence in my application. For now, we will dive into three extra steps:

1. Static Code Analysis with SonarQube
1. Dependency Vulnerability Scan with OSS Index
1. Integration Test with PostMan

## Static Code Analysis with SonarQube

For me, [SonarQube](https://www.sonarqube.org/) has been a tool I've almost always used to help me guard the quality of whatever I am writing. While it might not be your cup of tea, I do recommend you to follow along to understand _how_ you can integrate such tools into a Jenkins X Pipeline.

At the outset, we have two choice for doing SonarQube analysis.
We can host SonarQube ourselves, [via a Helm Chart for example](https://github.com/oteemo/charts), or we can choose to use SonarSource's (the company behind SonarQube) cloudservice [sonarcloud.io](https://sonarcloud.io/).

Which ever route you take, Self-Hosted or SonarCloud, both [continue at Steps](#steps).

### SonarCloud

1. sign up at [sonarcloud.io](https://sonarcloud.io/)
1. [register the application within your organization](https://sonarcloud.io/documentation/analysis/overview/#prepare-your-organization) (within SonarCloud)
1. [create an API token](https://sonarcloud.io/documentation/user-guide/user-token/)

### Self-Hosted

* ensure SonarQube is running with at least the Java plugin
* create an API token

If you don't have SonarQube running yet, below we give you some hints for how to do so with Helm.
Alternatively, you can add the [SonarQube Helm Chart](https://github.com/oteemo/charts) as a dependency to a Jenkins X Environment.

#### Helm Install

As the Helm Chart doesn't live in the default repository, we have to add the Oteemo Char Repository.

After that, we run `helm repo update` and we can install the tool.

```sh
helm repo add oteemocharts https://oteemo.github.io/charts
helm repo update
```

=== "Helm v3"
    ```sh
    helm install sonar oteemocharts/sonarqube -f values.yaml
    ```
=== "Helm v2"
    ```sh
    helm install --name sonar oteemocharts/sonarqube
    ```

#### Helm Values

Here's an example Helm values for hosting SonarQube in Kubernetes via the [Oteemo helm chart](https://github.com/oteemo/charts). This includes a set of basic plugins to start with, as the Helm installation by default comes without plugins - meaning, you can't run any analysis.

??? example "values.yaml"

    ```yaml
    ingress:
      enabled: true
      hosts:
        - name: sonar.example.com
          path: /
      tls:
      - hosts:
        - sonar.sonar.example.com
        secretName: tls-sonar-p
      annotations: 
        kubernetes.io/ingress.class: nginx
        kubernetes.io/tls-acme: "true"
        nginx.ingress.kubernetes.io/proxy-body-size: "8m"
        cert-manager.io/issuer: letsencrypt-prod
    persistence:
      enabled: true
      size: 25Gi
    plugins:
      install:
        - https://binaries.sonarsource.com/Distribution/sonar-java-plugin/sonar-java-plugin-6.3.0.21585.jar
        - https://binaries.sonarsource.com/Distribution/sonar-javascript-plugin/sonar-javascript-plugin-6.2.1.12157.jar
        - https://binaries.sonarsource.com/Distribution/sonar-go-plugin/sonar-go-plugin-1.6.0.719.jar
        - https://github.com/Coveros/zap-sonar-plugin/releases/download/sonar-zap-plugin-1.2.0/sonar-zap-plugin-1.2.0.jar
        - https://binaries.sonarsource.com/Distribution/sonar-typescript-plugin/sonar-typescript-plugin-2.1.0.4359.jar
    ```

### Steps

* create Kubernetes secrets
* configure secrets in the Jenkins X Pipeline
* add build step to do Sonar Analysis

### Create Secrets

At the time of writing - May 2020 - Jenkins X doesn't support reading secrets from Vault into the Pipeline. To have secrets in the pipeline we create a Kubernetes secret.

```sh
kubectl create secret generic my-sonar-token -n jx \
  --from-literal=SONAR_API_TOKEN='mytoken' \
  --from-literal=SONAR_HOST_URL='myurl'
```

If you don't like this, there are ways of having [HashiCorp Vault integrated into Kubernetes](https://www.hashicorp.com/blog/injecting-vault-secrets-into-kubernetes-pods-via-a-sidecar/) so that injects values from Vault into your Kubernetes secrets. This is out of scope of the guide.

### Configure Secrets In Pipeline

We are now going to use the Kubernetes secret we created earlier. As the Sonar CLI automatically picks up some environments variables - such as the `SONAR_API_TOKEN` in our secret - we inject the secret as environment variables.

We do this via the `envFrom` construction:

```yaml
envFrom:
  - secretRef:
      name: my-sonar-token
```

!!! example "jenkins-x.yml"

    Which means the `jenkins-x.yml` will look like this.

    ```yml
    buildPack:  maven-java11
    pipelineConfig:
      containerOptions:
        envFrom:
          - secretRef:
              name: my-sonar-token
    ```

### Create Sonar Analysis Build Step

To run the SonarQube analysis, we add another step to the pipeline, in the `jenkins-x.yml` file.
There are various ways to do it, in this case I'm using the `overrides` mechanic to add a new step _after_ `mvn-deploy`. We do this, by setting the `type` of the override to `after`. 

!!! note
    The default `type` of the pipeline override is `override`. 
    This is set implicitly, which is why we did not set this when overriding steps.

We can add any Kubernetes container configuration to our stage's container, via Jenkins X's `containerOptions` key.

```yaml hl_lines="21"
pipelineConfig:
  pipelines:
    overrides:
      - name: mvn-deploy
        pipeline: release
        stage: build
        containerOptions:
          envFrom:
            - secretRef:
                name: my-sonar-token
        step:
          name: sonar
          command: mvn
          args:
            - compile
            - org.sonarsource.scanner.maven:sonar-maven-plugin:3.6.0.1398:sonar
            - -Dsonar.host.url=$SONAR_HOST_URL
            - -e
            - --show-version
            - -DskipTests=true
        type: after
```

For more syntax details, see the [Jenkins X Pipeline page](https://jenkins-x.io/docs/reference/pipeline-syntax-reference/#containerOptions).

## Dependency Vulnerability Scan with OSS Index

While SonarQube - and many other tools - can help us identify issues in _our_ code, we should also validate the code we import via Maven dependencies.

Luckily, there are a lot of options now, such as [Snyk](https://github.com/snyk/snyk-maven-plugin), or [Sonatype's OSS Index](https://sonatype.github.io/ossindex-maven/maven-plugin/), [GitHub has it even embedded in their repositories now](https://help.github.com/en/github/managing-security-vulnerabilities/about-security-alerts-for-vulnerable-dependencies).

I've always been a fan of Sonatype, I'm molded by the Jenkins+Sonar+Nexus triumvirate, so in this guide we include Sonatype's OSS Index scanning. But feel free to find a solution you prefer.

This is a similar process as with SonarQube:

* create Kubernetes secret
* add secret to our pipeline
* add build step

### Create Secrets

At the time of writing - May 2020 - Jenkins X doesn't support reading secrets from Vault into the Pipeline. To have secrets in the pipeline we create a Kubernetes secret.

The OSS Index scanner automatically uses the environment variable XXX, so we use that as our secret Key.

```sh
kubectl create secret generic my-oss-index-token -n jx \
  --from-literal=OSS_INDEX_TOKEN='mytoken'
```

### Configure Secrets In Pipeline

Again, we inject the secret as environment variable via the `envFrom` construction:

```yaml
envFrom:
  - secretRef:
      name: my-oss-index-token
```

!!! example "jenkins-x.yml"

    Which means the `jenkins-x.yml` will look like this.

    ```yml
    buildPack:  maven-java11
    pipelineConfig:
      containerOptions:
        envFrom:
          - secretRef:
              name: my-sonar-token
          - secretRef:
              name: my-oss-index-token
    ```

### Add Pipeline Step

In this case, we're going to run this build step after our `sonar` analysis. 
So the name we match on, is set to `sonar` and type to `after`.

```yaml
  - name: sonar
    stage: build
    containerOptions:
      envFrom:
        - secretRef:
            name: sonatype-oss-index
    step:
      name: sonatype-ossindex
      command: mvn 
      args: 
        - org.sonatype.ossindex.maven:ossindex-maven-plugin:audit 
        - -f
        - pom.xml
        - -Dossindex.scope=compile
        - -Dossindex.reportFile=ossindex.json
        - -Dossindex.cvssScoreThreshold=4.0
        - -Dossindex.fail=false
    type: after
```

### Analysis Error

There's currently a vulnerability related to `org.apache.thrift:libthrift`, which is part of `quarkus-smallrey-opentracing`.
Replacing `libthrift` with a version that is not vulnerable causes errors.

So, we can:

1. not use open tracing -> non negiotiable
1. implement open tracing with another library -> risk, might not be Native Image compatible
1. ignore this particular vulnerability -> risk, high chance we forget this
1. not fail the build -> risk, only acceptable if people are actively pursuing a clean build (meaning, no warnings)

In the example I've gone for option #4, but I recommend you make your own choice.

## Integration Test with PostMan

