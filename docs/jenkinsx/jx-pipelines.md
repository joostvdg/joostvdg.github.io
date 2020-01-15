title: Extending Jenkins X Pipelines
description: How to extend Jenkins X Pipelines

# Jenkins X Pipelines

## Verify Changes

```bash
jx step syntax effective
```

## Adding Steps

### Add Step Default

!!! info
    By default, adding a step to a Pipeline's stage will cause it to end up at the end of the stage.

```yaml
buildPack: maven-java11
pipelineConfig:
  pipelines:
    pullRequest:
      build:
        steps:
        - command: sonar-scanner
          image: fabiopotame/sonar-scanner-cli # newtmitch/sonar-scanner for JDK 10+?
          dir: /workspace/source/
          args:
           - -Dsonar.projectName=...
           - -Dsonar.projectKey=...
           - -Dsonar.organization=...
           - -Dsonar.sources=./src/main/java/
           - -Dsonar.language=java
           - -Dsonar.java.binaries=./target/classes
           - -Dsonar.host.url=https://sonarcloud.io
           - -Dsonar.login=...
```

### Add Step At Specific Place

If we want it explicity after or before a specific step, we have to "select" the `step` within a `stage` of a pipeline first.

We do that as follows:

```yaml
pipelineConfig:
  pipelines:
    overrides:
      - pipeline: [pipeline name: release, feature, pullRequest]
        stage: [stage name]
        name: [step name]
```

And then state of we want to replace the step (via `type: replace`), or execute it before or after the "selected" step, via the field `type`.

```yaml
pipelineConfig:
  pipelines:
    overrides:
      - name: mvn-deploy
        pipeline: release
        stage: build
        step:
          name: sonar
          command: sonar-scanner
          image: fabiopotame/sonar-scanner-cli # newtmitch/sonar-scanner for JDK 10+?
          dir: /workspace/source/
          args:
           - -Dsonar.projectName=...
           - -Dsonar.projectKey=...
           - -Dsonar.organization=...
           - -Dsonar.sources=./src/main/java/
           - -Dsonar.language=java
           - -Dsonar.java.binaries=./target/classes
           - -Dsonar.host.url=https://sonarcloud.io
           - -Dsonar.login=...
        type: after
```

## Overriding Steps

```yaml
pipelineConfig:
  pipelines:
    release:
      setup:
        preSteps:
        - sh: echo BEFORE BASE SETUP
        steps:
        - sh: echo AFTER BASE SETUP
      build:
        replace: true
        steps:
        - sh: mvn clean deploy -Pmyprofile
          comment: this command is overridden from the base pipeline
```

## Meta pipeline/run always for every pipeline

## JX Pipeline Converter

`JX Pipeline Converter` plugin for Jenkins X to assist in converting from the legacy Jenkinsfile-based pipelines to the modern jenkins-x.yml-based pipelines.

### Install

```bash tab="macos"
curl -L https://github.com/jenkins-x/jx-convert-jenkinsfile/releases/download/$(curl --silent https://api.github.com/repos/jenkins-x/jx-convert-jenkinsfile/releases/latest | jq -r '.tag_name')/jx-convert-jenkinsfile-darwin-amd64.tar.gz | tar xzv 
sudo mv jx-convert-jenkinsfile /usr/local/bin
```

```bash tab="linux"
curl -L https://github.com/jenkins-x/jx-convert-jenkinsfile/releases/download/$(curl --silent https://api.github.com/repos/jenkins-x/jx-convert-jenkinsfile/releases/latest | jq -r '.tag_name')/jx-convert-jenkinsfile-linux-amd64.tar.gz | tar xzv 
sudo mv jx-convert-jenkinsfile /usr/local/bin
```

!!! caution
    It seems some shells will escape the `(` in the above command.

    Make sure the command reads `.../download/$(curl --silent...`.

### Usage

```bash
jx convert jenkinsfile
```

## Loops

```yaml
buildPack: go
pipelineConfig:
  pipelines:
    overrides:
    - pipeline: release
      # This is new
      stage: build
      name: make-build
      steps:
      - loop:
          variable: GOOS
          values:
          - darwin
          - linux
          - windows
          steps:
          - name: build
            command: CGO_ENABLED=0 GOOS=\${GOOS} GOARCH=amd64 go build -o bin/jx-go-loops_\${GOOS} main.go
```

Borrowed from [Viktor Farcic's blog on Jenkins X Pipelines](https://technologyconversations.com/2019/06/30/overriding-pipelines-stages-and-steps-and-implementing-loops-in-jenkins-x-pipelines/).

## Replace Whole Pipeline

If you want to write your pipeline from scratch, you can specify you do _not_ use a Build Pack.

```yaml
buildPack: none
pipelineConfig:
  pipelines:
    release:
      pipeline:
        agent:
          image: busybox
        stages:
          - name: ci
            steps:
              - name: echo-version
                image: mvn
                command: mvn version
```

## Parallelization

```yaml
pipelineConfig:
  pipelines:
    release:
      pipeline:
        stages:
          - name: "Parallelsss"
            agent:
              image: maven
            parallel:
              - name: "Parallel1"
                agent:
                  image: maven
                steps:
                  - command: echo
                    args:
                      - test one a
                  - command: sleep
                    args:
                      - "60"
              - name: "Parallel2"
                agent:
                  image: maven
                steps:
                  - command: echo
                    args:
                      - test two a
                  - command: sleep
                    args:
                      - "60"
```

!!! caution
    Each parallel stage will have its own Pod and thus they do not share the same workspace!

Which in the activity log will look like this:

```bash
joostvdg/jx-spring-boot-11/master #13                      1m58s          Running
  meta pipeline                                            1m58s      49s Succeeded
    Credential Initializer T6bkh                           1m58s       0s Succeeded
    Working Dir Initializer 7qqhg                          1m58s       0s Succeeded
    Place Tools                                            1m58s       1s Succeeded
    Git Source Meta Joostvdg Jx Spring Boot 11 Bj2lh       1m57s       7s Succeeded 
    Git Merge                                              1m50s       0s Succeeded
    Merge Pull Refs                                        1m50s       0s Succeeded
    Create Effective Pipeline                              1m50s       8s Succeeded
    Create Tekton Crds                                     1m42s      33s Succeeded
  Parallelsss                                               1m8s          Running
  Parallelsss / Parallel1                                   1m8s     1m7s Succeeded
    Credential Initializer H2lh9                            1m8s       0s Succeeded
    Working Dir Initializer Nlk6b                           1m8s       0s Succeeded
    Place Tools                                             1m8s       2s Succeeded
    Git Source Joostvdg Jx Spring Boot 11 Mast 96j7m        1m6s       4s Succeeded 
    Git Merge                                               1m2s       1s Succeeded
    Step2                                                   1m1s       0s Succeeded
    Step3                                                   1m1s     1m0s Succeeded
  Parallelsss / Parallel2                                   1m8s          Running
    Credential Initializer Shc5t                            1m8s       0s Succeeded
    Working Dir Initializer Tsx5j                           1m8s       2s Succeeded
    Place Tools                                             1m6s       1s Succeeded
    Git Source Joostvdg Jx Spring Boot 11 Mast 8dbcl        1m5s       5s Succeeded
    Git Merge                                               1m0s       1s Succeeded
    Step2                                                    59s       0s Succeeded
```

## Other Resources

* https://jenkins-x.io/docs/concepts/jenkins-x-pipelines/
* https://jenkins-x.io/docs/reference/pipeline-syntax-reference/
* https://jenkins-x.io/docs/reference/components/build-packs//#pipeline-extension-model
* https://technologyconversations.com/2019/06/30/overriding-pipelines-stages-and-steps-and-implementing-loops-in-jenkins-x-pipelines/
* https://docs.cloudbees.com/docs/cloudbees-jenkins-x-distribution/latest/pipelines/#_extending_pipelines