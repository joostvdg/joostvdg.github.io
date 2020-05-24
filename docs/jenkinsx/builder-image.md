title: Jenkins X - Create Builder Image
description: How to create a Jenkins X builder Image

# Create Jenkins X Builder Image

Jenkins X leverages [Tekton pipelines](https://github.com/tektoncd/pipeline) to create a Kubernetes native Pipeline experience. Every step is run in its own container.

People comonly start using Jenkins X via its pre-defined build packs.
These build packs already have a default Container Image defined, and use some specific containers for certain specific tasks - such as Kaniko for building Container Images. We call these Container Images: ***Builders***.

## Create Custom Builder

Sometimes you need to use a different container for a specific step. First, [look at the available builder](https://github.com/jenkins-x/jenkins-x-builders). If what you need does not exist yet, you will have to create one yourself.

Jenkins X [has a guide on how to create a custom Builder](https://jenkins-x.io/docs/guides/managing-jx/common-tasks/create-custom-builder/).

In essence, you create a Container Image that extends from `gcr.io/jenkinsxio/builder-base:0.0.81`, includes your tools and packages of choice, and may or may not include the `jx` binary.

What comes after, is your choice. You can add [your Builder to Jenkins X's list of Builders](https://jenkins-x.io/docs/guides/managing-jx/common-tasks/create-custom-builder/#install-the-builder), or directly use it in your Jenkins X Pipeline by FQN.

The main difference, is that when you add the Builder to Jenkins X you can include default configuration for the entire Pod. Otherwise, you have to specify any unique configuration in the Jenkins X Pipeline where you use the image.

## Dockerfile Example

!!! example "Dockerfile"

    ```Dockerfile
    FROM gcr.io/jenkinsxio/builder-base:0.0.81

    RUN yum install -y java-11-openjdk-devel && yum update -y && yum clean all

    # Maven
    ENV MAVEN_VERSION 3.6.3
    RUN curl -f -L https://repo1.maven.org/maven2/org/apache/maven/apache-maven/$MAVEN_VERSION/apache-maven-$MAVEN_VERSION-bin.tar.gz | tar -C /opt -xzv
    ENV M2_HOME /opt/apache-maven-$MAVEN_VERSION
    ENV maven.home $M2_HOME
    ENV M2 $M2_HOME/bin
    ENV PATH $M2:$PATH

    # GraalVM
    ARG GRAAL_VERSION=20.0.0
    ENV GRAAL_CE_URL=https://github.com/graalvm/graalvm-ce-builds/releases/download/vm-${GRAAL_VERSION}/graalvm-ce-java11-linux-amd64-${GRAAL_VERSION}.tar.gz
    ARG INSTALL_PKGS="gzip"

    ENV GRAALVM_HOME /opt/graalvm
    ENV JAVA_HOME /opt/graalvm

    RUN yum install -y ${INSTALL_PKGS} && \
        ### Installation of GraalVM
        mkdir -p ${GRAALVM_HOME} && \
        cd ${GRAALVM_HOME} && \
        curl -fsSL ${GRAAL_CE_URL} | tar -xzC ${GRAALVM_HOME} --strip-components=1  && \
        ### Cleanup     
        yum clean all && \
        rm -f /tmp/graalvm-ce-amd64.tar.gz && \
        rm -rf /var/cache/yum
        ###

    ENV PATH $GRAALVM_HOME/bin:$PATH
    RUN gu install native-image

    # jx
    ENV JX_VERSION 2.1.30
    RUN curl -f -L https://github.com/jenkins-x/jx/releases/download/v${JX_VERSION}/jx-linux-amd64.tar.gz | tar xzv && \
    mv jx /usr/bin/

    CMD ["mvn","-version"]
    ```

## Usage

The example above is my [Jenkins X Builder for Maven + JDK 11 + GraalVM](https://github.com/joostvdg/jenkins-x-builders/tree/master/graalvm-maven-jdk11). My Dockerhub ID is `caladreas`, and the image is `jx-builder-graalvm-maven-jdk11`. 

### Override Default Container

To use this Container Image as the default container:

!!! example "jenkins-x.yml"

    ```yaml
    buildPack:  maven-java11
    pipelineConfig:
      agent:
        image: caladreas/jx-builder-graalvm-maven-jdk11:v0.7.0
    ```

### Override Step Container

!!! example "jenkins-x.yml"

    ```yaml hl_lines="10"
    buildPack:  maven-java11
    pipelineConfig:
      pipelines:
        overrides:
          - pipeline: pullRequest
            stage: build
            name: mvn-install
            steps:
              - name: mvn-deploy
                image: caladreas/jx-builder-graalvm-maven-jdk11:v0.9.0
    ```