title: Jenkins X - Java Native Image Prod
description: Creating a Java Native Image application and run it as Production with Jenkins X - Native Image - 6/10
hero: Native Image - 6/10

# Build Native Image

We've now reached the point that our application is build and deployed with Jenkins X.
If everything went allright, it now runs in the staging environment.

It is time to run our application as a Native Image, rather than a Jar in a JVM.

## What is Java Native Image

> GraalVM Native Image allows you to ahead-of-time compile Java code to a standalone executable, called a **native image**. This executable includes the application classes, classes from its dependencies, runtime library classes from JDK and statically linked native code from JDK. It does not run on the Java VM, but includes necessary components like memory management and thread scheduling from a different virtual machine, called “Substrate VM”. Substrate VM is the name for the runtime components (like the deoptimizer, garbage collector, thread scheduling etc.). The resulting program has faster startup time and lower runtime memory overhead compared to a Java VM. - [GraalVM reference manual](https://www.graalvm.org/docs/reference-manual/native-image/)

In short, its makes your Java code into a runnable executable build for a specific environment. In our cse, we use RedHat's [Universal Base Image](https://www.redhat.com/en/blog/introducing-red-hat-universal-base-image), and as such, we know the application - or at least the Native Image distribution - always runs on this particular environment.

## Why

You might wonder, what is wrong with using a runnable Jar - such as Spring Boot, or Quarkus - or using a JVM?
Nothing in and on itself. However, there are cases where having a long running process with a slow start-up time hurts you.

In a Cloud Native world, including Kubernetes, this is far more likely than in traditional - read, VM's - environments. With the advent of creating many smaller services that may or may not be stateless, and should be capable of scaling horizontally from 0 to infinity, different characteristics are required.

Some of these characterics:

* minimal resource use as we pay per usage (to a degree)
* fast startup time
* perform as expected on startup (JVM needs to warm up)

A Native Image performs better on the above metrics than a classic Java application with a JVM.
Next to that, when you have a fixed runtime, the benefit of Java's "build once, run everywhere" is not as useful. When you always run your application in the same container in similar Kubernetes environments, a Native Image is perfectly fine.

On top of that, we distribute our application as a Helm Chart + Container Image. When we also ship a runtime environment, such as a JRE, our Container Image is larger in disk size and larger in runtime memory. We can run more Native Image applications in the same Kubernetes cluster than JVM based applications. Unless we share the JVM, but the whole point of using Containers was to avoid that.

Wether a Native Image performs better for your application depends on your application and its usage. The Native Image is no silver bullet. So it is still on you to do load and performance tests to ensure you're not degrading your performance for no reason!

## Code Start

If you do not have a working version after the previous chapter, you can find the complete working code in the [branch 05-db-and-secrets](https://github.com/joostvdg/quarkus-fruits/tree/05-db-and-secrets).

## How

One of the reasons for using Quarkus is the built-in support for [building a native executable](https://quarkus.io/guides/building-native-image). 

### Native Profile

When you use Maven as builder for your Quarkus application, there is a profile called `native` pre-configured. By using the profile, `mvn package -Pnative`, the Quarkus (Maven) plugin uses GraalVM to generate the native image.

You can do this by having GraalVM installed on your local machine, or use a Container Image.

### Native Image Build Container

For most people, I recommend using the build container provided by Quarkus. These are kept up-to-date and it reduces the number of things you need in your development environment.

Quarkus provides a flag for building the native image via a container. And, depending on your needs to can explicitly set the container runtime to be used.

=== "default container runtime" 
    ```bash
    ./mvnw package -Pnative -Dquarkus.native.container-build=true
    ```
=== "docker runtime"
    ```bash
    ./mvnw package -Pnative -Dquarkus.native.container-runtime=docker
    ```
=== "podman runtime"
    ```bash
    ./mvnw package -Pnative -Dquarkus.native.container-runtime=podman
    ```

### Build Native Image Container

By default, this file resides in `src/main/docker/Dockerfile.native`. As Jenkins X uses the `Dockerfile` from the root of the project, we update that `Dockerfile` to the contents below.

I recommend using it, as it is well tested and does everything we need in minimal fashion and according to Docker's best practices.

!!! example "Dockerfile"

    ```Dockerfile
    FROM registry.access.redhat.com/ubi8/ubi-minimal:8.1
    WORKDIR /work/
    COPY target/*-runner /work/application

    # set up permissions for user `1001`
    RUN chmod 775 /work /work/application \
        && chown -R 1001 /work \
        && chmod -R "g+rwX" /work \
        && chown -R 1001:root /work

    EXPOSE 8080
    USER 1001

    CMD ["./application", "-Dquarkus.http.host=0.0.0.0", "-Xmx64m"]
    ```

## Update Jenkins X Pipeline

Now that we have a `Dockerfile` Jenkins X can use to build the Native Image end-result, we need to ensure the build steps are update - for both the release and pullrequest pipeline.

As our current build pack does not contain GraalVM for building the Native Image, we will also change the image used for those steps. Images used for build steps are called `Jenkins X Builders`.

### Jenkins X Builder

At the time of writing, there is no Jenkins X Builder image for Java 11 with Maven and GraalVM.
There is an [open pullrequest](https://github.com/jenkins-x/jenkins-x-builders/pull/1299) to make this happen. Untill this is merged, [read here how to create a Jenkins X Builder Image](/jenkinsx/builder-image/).

Alternatively, you can use my image:

* **Image URI**: `caladreas/jx-builder-graalvm-maven-jdk11:v0.10.0`
* [Dockerhub](https://hub.docker.com/repository/docker/caladreas/jx-builder-graalvm-maven-jdk11)
* [GitHub source code](https://github.com/joostvdg/jenkins-x-builders/tree/master/graalvm-maven-jdk11)

### Change Build steps

At this point, our Jenkins X pipeline should look like this:

!!! example "jenkins-x.yml" 

    ```yaml
    buildPack:  maven-java11
    ```

We update the builds steps for pipelines (pullrequest and release). The release pipeline's build stage is called `mvn-deploy`, the equivalent for the pullrequest pipeline (don't ask me why they're different) is `mvn-install`.

Three changes are required:

1. the (Maven) command to include the `native` profile
1. the image to use a Container Image that includes GraalVM
1. container options to set the memory to required levels

We can do each of the three changes by overriding the mentioned build steps.

To override a step, we start with this initial syntax:

```yaml
    pipelineConfig:
      pipelines:
        overrides:
```

After which we supply the list of steps we want to override.
For each step, we state the `pipeline`, `stage` and the step `name`.

```yaml
- pipeline: release
  stage: build
  name: mvn-deploy
```

We go over each change we make below, but for the full reference, I recommened [reading the Jenkins X Pipeline Syntax page](https://jenkins-x.io/docs/reference/pipeline-syntax-reference/).

#### Step Override

To override a a step, we start from the above mentioned override, add `steps:` and then include the list of steps to override. For each step, we can set the `name`, `command`, and `image` (the build container used). There are more options, but these are sufficient for now.

```yaml
steps:
  - name: mvn-deploy
    command: mvn clean package -Pnative --show-version -DskipDocs
    image: caladreas/jx-builder-graalvm-maven-jdk11:v0.9.0
```

#### Container Options

To change the configuration of the Container Image used for our step, such as environment varibiables or resources, we set `containerOptions`. Again, please refer to the [Jenkins X Pipeline Syntax page](https://jenkins-x.io/docs/reference/pipeline-syntax-reference/) for the options available and where you can leverage this configuration element.

The options we need to set, are the resources for the container - we need at least 8GB - and the environment variable `_JAVA_OPTIONS`. The latter is required, because the default JAVA_OPTIONS is set to a very low number (`192mb`) which is insufficient for our build. Both Maven and GraalVM's Native Image build pick up this environment variable. Included are also some other JVM flags, which I've come across in several GitHub Issues as recommended.

The required options are `-Xms8g -Xmx8g -XX:+UseSerialGC`, but I recommend using the other flags as well.

```yaml
containerOptions:
  env:
    - name: _JAVA_OPTIONS
      value: >-
        -XX:+UnlockExperimentalVMOptions -XX:+EnableJVMCI -XX:+UseJVMCICompiler
        -Xms8g -Xmx8g -XX:+PrintCommandLineFlags -XX:+UseSerialGC
  resources:
    requests:
      cpu: "2"
      memory: 10Gi
    limits:
      cpu: "2"
      memory: 10Gi
```

#### Release Pipeline

!!! example "jenkins-x.yml"

    ```yaml
    - pipeline: release
      stage: build
      name: mvn-deploy
      steps:
        - name: mvn-deploy
          command: mvn clean package -Pnative --show-version -DskipDocs
          image: caladreas/jx-builder-graalvm-maven-jdk11:v0.9.0
      containerOptions:
        env:
          - name: _JAVA_OPTIONS
            value: >-
              -XX:+UnlockExperimentalVMOptions -XX:+EnableJVMCI -XX:+UseJVMCICompiler
              -Xms8g -Xmx8g -XX:+PrintCommandLineFlags -XX:+UseSerialGC
        resources:
          requests:
            cpu: "2"
            memory: 10Gi
          limits:
            cpu: "2"
            memory: 10Gi
    ```

#### PullRequest Pipeline

!!! example "jenkins-x.yml"

    ```yaml
    - pipeline: pullRequest
      stage: build
      name: mvn-install
      steps:
        - name: mvn-deploy
          command: mvn clean package -Pnative --show-version -DskipDocs
          image: caladreas/jx-builder-graalvm-maven-jdk11:v0.9.0
      containerOptions:
        env:
          - name: _JAVA_OPTIONS
            value: >-
              -XX:+UnlockExperimentalVMOptions -XX:+EnableJVMCI -XX:+UseJVMCICompiler
              -Xms8g -Xmx8g -XX:+PrintCommandLineFlags -XX:+UseSerialGC
        resources:
          requests:
            cpu: "2"
            memory: 10Gi
          limits:
            cpu: "2"
            memory: 10Gi
    ```

#### Full Example

??? example "jenkins-x.yml"

    ```yaml
    buildPack:  maven-java11
    pipelineConfig:
      pipelines:
        overrides:
          - pipeline: pullRequest
            stage: build
            name: mvn-install
            steps:
              - name: mvn-deploy
                command: mvn clean package -Pnative --show-version -DskipDocs
                image: caladreas/jx-builder-graalvm-maven-jdk11:v0.9.0
            containerOptions:
              env:
                - name: _JAVA_OPTIONS
                  value: >-
                    -XX:+UnlockExperimentalVMOptions -XX:+EnableJVMCI -XX:+UseJVMCICompiler
                    -Xms8g -Xmx8g -XX:+PrintCommandLineFlags -XX:+UseSerialGC
              resources:
                requests:
                  cpu: "2"
                  memory: 10Gi
                limits:
                  cpu: "2"
                  memory: 10Gi
          - pipeline: release
            stage: build
            name: mvn-deploy
            steps:
              - name: mvn-deploy
                command: mvn clean package -Pnative --show-version -DskipDocs
                image: caladreas/jx-builder-graalvm-maven-jdk11:v0.9.0
            containerOptions:
              env:
                - name: _JAVA_OPTIONS
                  value: >-
                    -XX:+UnlockExperimentalVMOptions -XX:+EnableJVMCI -XX:+UseJVMCICompiler
                    -Xms8g -Xmx8g -XX:+PrintCommandLineFlags -XX:+UseSerialGC
              resources:
                requests:
                  cpu: "2"
                  memory: 10Gi
                limits:
                  cpu: "2"
                  memory: 10Gi
    ```

## Update Container Resources

If we look at our `charts/Name-of-your-Application/values.yaml` file, we can see it defines the CPU and Memory requests & limits. These correspond to the expected bounds for our application.

```yaml
resources:
  limits:
    cpu: 500m
    memory: 512Mi
  requests:
    cpu: 400m
    memory: 512Mi
```

The bounds that are in there, are set for a Java 11 application running on a JVM.
Now that we changed our application to run as a Native Image, we can drastically reduce them.

Please set them accordingly:

!!! example "values.yaml"

    ```yaml
    resources:
      limits:
        cpu: 250m
        memory: 64Mi
      requests:
        cpu: 250m
        memory: 64Mi
    ```

### Worker Node Capity

!!! important

    As stated in the pre-requisites, to have the builds work well, your Kubernetes worker nodes need at least 10GB of memory. If you do not have those at the moment, you can add an additional Node Pool with these machine types.

    If you're in GKE, as the guide assumes, the following machine types work:

    * `e2-highmem-2`
    * `n2-highmem-2`
    * `e2-standard-4`
    * `n2-standard-4`