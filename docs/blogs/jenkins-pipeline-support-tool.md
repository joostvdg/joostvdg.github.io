title: Jenkins Pipeline Support Tools
description: How To Create Better Jenkins Pipelines With Compact CLI's

# Jenkins Pipeline Support Tools

With Jenkins now becoming Cloud Native and a first class citizen of Kubernetes, it is time to review how we use build tools.

This content assumes you're using Jenkins in a Kubernetes cluster, but most of it should also work in other Docker-based environments.

## Ideal Pipeline

Anyway, one thing we often see people do wrong with Jenkins pipelines is to use the Groovy Scripts as a general-purpose programming language. This creates many problems, bloated & complicated pipelines, much more stress on the master instead of on the build agent and generally making things unreliable.

A much better way is to use Jenkins pipelines only as orchestration and lean heavily on your build tools - e.g., Maven, Gradle, Yarn, Bazel - and shell scripts. Alas, if you created complicated pipelines in Groovy scripts, it is likely you'll end up the same with Bash scripts. An even better solution would be to create custom CLI applications that take care of large operations and convoluted logic. You can test and reuse them.

```groovy
pipeline {
    agent any
    stages {
        stage('Build') {
            steps {
                sh './build.sh'
            }
        }
        stage('Test') {
            steps {
                sh './test.sh'
            }
        }
        stage('Deploy') {
            steps {
                sh './deploy.sh'
            }
        }
    }
    post  {
        success {
      	    sh './successNotification.sh'
        }
        failure {
          sh './failureNotification.sh'
        }
    }
}
```

Now, this might look a bit like a pipe dream, but it illustrates how you should use Jenkins Pipeline. The groovy script engine allows for a lot of freedom, but only rarely is its use justified. To create robust, modular and generic pipelines, it is recommended to use build tools, shell scripts, [Shared Libraries](https://jenkins.io/doc/book/pipeline/shared-libraries/) and **custom CLI's**.

It was always a bit difficult to manage generic scripts and tools across instances of Jenkins, pipelines, and teams. But with  Pod Templates we have an excellent mechanism for using, versioning and distributing them with ease.

## Kubernetes Pods

When Jenkins runs in Kubernetes, it can leverage it via the [Kubernetes Plugin](https://github.com/jenkinsci/kubernetes-plugin). I realize Jenkins conjures up mixed emotions when it comes to plugins, but this setup might replace most of them.

How so? By using a [Kubernetes Pod](https://kubernetes.io/docs/concepts/workloads/pods/pod/) as the agent where instead of putting all your tools into a single VM you can use multiple small scoped containers.

You can specify Pod Templates in multiple ways, where my personal favorite is to define it as yaml inside a **declarative pipeline** - see example below. For each tool you need, you specify the container and its configuration - if required.  By default, you will always get a container with a [Jenkins JNLP client](https://hub.docker.com/r/jenkinsci/jnlp-slave/) and the workspace mounted as a volume in the pod.

This allows you to create several tiny containers, each containing only the tools you need for a specific job. Now, it could happen you use two or more tools together a lot - let's say npm and maven - so it is ok to sometimes deviate from this to lower the overall memory of the pod.

When you need custom logic, you will have to create a script or tool. This is where PodTemplate, Docker images and our desire for small narrow focus tools come together.

### PodTemplate example

```groovy
pipeline {
    agent {
        kubernetes {
        label 'mypod'
        defaultContainer 'jnlp'
        yaml """
apiVersion: v1
kind: Pod
metadata:
  labels:
    some-label: some-label-value
spec:
  containers:
  - name: maven
    image: maven:alpine
    command:
    - cat
    tty: true
  - name: busybox
    image: busybox
    command:
    - cat
    tty: true
        """
        }
    }
    stages {
        stage('Run maven') {
            steps {
                container('maven') {
                    sh 'mvn -version'
                }
                container('busybox') {
                    sh '/bin/busybox'
                }
            }
        }
    }
}
```

## Java Example

I bet most people do not think about Java when it comes lightweight CLI applications, but I think that is a shame. Java has excellent tooling to help you build well-tested applications which can be understood and maintained by a vast majority of developers.

To make the images small, we will use some of the new tools available in Java land. We will first dive into using Java Modularity and JLink to create a compact and strict binary package, and then we move onto Graal for creating a Native image.

### Custom JDK Image

All the source code of this example application is at [github.com/joostvdg/jpb](https://github.com/joostvdg/jpb).

It is a small CLI which does only one thing; it parses a git commit log to see which folders changed. Quite a useful tool for Monorepo's or other repositories containing more than one changeable resource.

Such a CLI should have specific characteristics:
* testable
* small memory footprint
* small disk footprint
* quick start
* easy to setup
* easy to maintain

These points sound like an excellent use case for Java Modules and JLink. 
For those who don't know, [read up on Java Modules here](https://www.baeldung.com/java-9-modularity) and [read up on JLink here](https://dzone.com/articles/jlink-in-java-9). JLink will create a binary image that we can use with Alpine Linux to form a minimal Java (Docker) Image.

Unfortunately, the plugins for Maven (JMod and JLink) seem to have died. The support on Gradle side is not much better.

So I created a solution myself with a multi-stage Docker build. Which does detract a bit from the ease of setup. But overall, it hits the other characteristics spot on. 

#### Application Model

For ease of maintenance and testing, we separate the parts of the CLI into Java Modules, as you can see in the model below. For using JLink, we need to be a module ourselves. So I figured to expand the exercise to use it to not only create boundaries via packages but also with Modules.

![Model](../images/jpb.png)

#### Build

The current LTS version of Java is 11, which means we need at least that if we want to be up-to-date. As we want to run the application in Alpine Linux, we need to build it with Alpine Linux - if you create a custom JDK image its OS specific. To my surprise, the official LTS release is not released for Alpine, so we use OpenJDK 12.

Everything is built via a Multi-Stage Docker Build. This Dockerfile can be divided into five segments.

1. creation of the base with a JDK 11+ on Alpine Linux
1. compiling our Java Modules in into Module Jars
1. test our code
1. create our custom JDK image with just our code and whatever we need from the JDK
1. create the runtime Docker image

The Dockerfile looks a bit complicated, but we did get a Java runtime that is about 44MB in size and can run as a direct binary with no startup time.
The Dockerfile can be much short if we use only a single module, but as our logic grows it is a thoughtful way to separate different concerns.

Still, I'm not too happy with this for creating many small CLI's. To much handwork goes into creating the images like this. Relying on unmaintained Maven or Gradle Plugins doesn't seem a better choice.

Luckily, there's a new game in town, [GraalVM](https://github.com/oracle/graal). We'll make an image with Graal next, stay tuned.

##### Dockerfile

```dockerfile
###############################################################
###############################################################
##### 1. CREATE ALPINE BASE WITH JDK11+
#### OpenJDK image produces weird results with JLink (400mb + sizes)
FROM alpine:3.8 AS build
ENV JAVA_HOME=/opt/jdk \
    PATH=${PATH}:/opt/jdk/bin \
    LANG=C.UTF-8

RUN set -ex && \
    apk add --no-cache bash && \
    wget https://download.java.net/java/early_access/alpine/18/binaries/openjdk-12-ea+18_linux-x64-musl_bin.tar.gz -O jdk.tar.gz && \
    mkdir -p /opt/jdk && \
    tar zxvf jdk.tar.gz -C /opt/jdk --strip-components=1 && \
    rm jdk.tar.gz && \
    rm /opt/jdk/lib/src.zip
####################################
## 2.a PREPARE COMPILE PHASE
RUN mkdir -p /usr/src/mods/jars
RUN mkdir -p /usr/src/mods/compiled
COPY . /usr/src
WORKDIR /usr/src

## 2.b COMPILE ALL JAVA FILES
RUN javac -Xlint:unchecked -d /usr/src/mods/compiled --module-source-path /usr/src/src $(find src -name "*.java")
## 2.c CREATE ALL JAVA MODULE JARS
RUN jar --create --file /usr/src/mods/jars/joostvdg.jpb.api.jar --module-version 1.0 -C /usr/src/mods/compiled/joostvdg.jpb.api .
RUN jar --create --file /usr/src/mods/jars/joostvdg.jpb.core.jar --module-version 1.0 -C /usr/src/mods/compiled/joostvdg.jpb.core .
RUN jar --create --file /usr/src/mods/jars/joostvdg.jpb.cli.jar --module-version 1.0  -e com.github.joostvdg.jpb.cli.JpbApp\
    -C /usr/src/mods/compiled/joostvdg.jpb.cli .
RUN jar --create --file /usr/src/mods/jars/joostvdg.jpb.core.test.jar --module-version 1.0  -e com.github.joostvdg.jpb.core.test.ParseChangeListTest \
    -C /usr/src/mods/compiled/joostvdg.jpb.core.test .
####################################
## 3 RUN TESTS
RUN rm -rf /usr/bin/jpb-test-image
RUN jlink \
    --verbose \
    --compress 2 \
    --no-header-files \
    --no-man-pages \
    --strip-debug \
    --limit-modules java.base \
    --launcher jpb-test=joostvdg.jpb.core.test \
    --module-path /usr/src/mods/jars/:$JAVA_HOME/jmods \
    --add-modules joostvdg.jpb.core.test \
    --add-modules joostvdg.jpb.core \
    --add-modules joostvdg.jpb.api \
     --output /usr/bin/jpb-test-image
RUN /usr/bin/jpb-test-image/bin/java --list-modules
RUN /usr/bin/jpb-test-image/bin/jpb-test
####################################
## 4 BUILD RUNTIME - CUSTOM JDK IMAGE
RUN rm -rf /usr/bin/jpb-image
RUN jlink \
    --verbose \
    --compress 2 \
    --no-header-files \
    --no-man-pages \
    --strip-debug \
    --limit-modules java.base \
    --launcher jpb=joostvdg.jpb.cli \
    --module-path /usr/src/mods/jars/:$JAVA_HOME/jmods \
    --add-modules joostvdg.jpb.cli \
    --add-modules joostvdg.jpb.api \
    --add-modules joostvdg.jpb.core \
     --output /usr/bin/jpb-image
RUN /usr/bin/jpb-image/bin/java --list-modules
####################################
##### 5. RUNTIME IMAGE - ALPINE
FROM panga/alpine:3.8-glibc2.27
LABEL authors="Joost van der Griendt <joostvdg@gmail.com>"
LABEL version="0.1.0"
LABEL description="Docker image for running Jenkins Pipeline Binary"
ENV DATE_CHANGED="20181014-2035"
ENV JAVA_OPTS="-XX:+UseCGroupMemoryLimitForHeap -XX:+UnlockExperimentalVMOptions"
COPY --from=build /usr/bin/jpb-image/ /usr/bin/jpb
ENTRYPOINT ["/usr/bin/jpb/bin/jpb"]
```

#### Image disk size

```bash
REPOSITORY                                   TAG                 IMAGE ID            CREATED              SIZE
jpb                                          latest              af7dda45732a        About a minute ago   43.8MB
```

### Graal

> GraalVM is a universal virtual machine for running applications written in JavaScript, Python, Ruby, R, JVM-based languages like Java, Scala, Kotlin, Clojure, and LLVM-based languages such as C and C++.   - [graalvm.org](https://www.graalvm.org)

 Ok, that doesn't tell you why using GraalVM is excellent for creating small CLI docker images. Maybe this quote helps:

> Native images compiled with GraalVM ahead-of-time improve the startup time and reduce the memory footprint of JVM-based applications. 

Where JLink allows you to create a custom JDK image and embed your application as a runtime binary, Graal goes one step further. It replaces the VM altogether and uses [Substrate VM](https://github.com/oracle/graal/tree/master/substratevm) to run your binary. It can't do a lot of the fantastic things the JVM can do and isn't suited for long running applications or those with a large memory footprint and so on. Well, our CLI applications are single shot executions with low memory footprint, the perfect fit for Graal/Substrate!

All the code from this example can is on GitHub at [github.com/demomon/jpc-graal--maven](https://github.com/demomon/jpc-graal--maven).

#### Application Model

While building modular Java applications is excellent, the current tooling support terrible. So this time the application is a single Jar - Graal can create images from classes or jars - where packages do the separation.

```
.
├── Dockerfile
├── LICENSE
├── README.md
├── docker-graal-build.sh
├── pom.xml
└── src
    ├── main
       └── java
           └── com
               └── github
                   └── joostvdg
                       └── demo
                           ├── App.java
                           └── Hello.java
```

#### Build

Graal can build a native image based on a Jar file. This allows us to use any standard Java build tool such as Maven or Gradle to build the jar. The actual Graal build will be done in a Dockerfile.

The people over at Oracle have created an [official Docker image](https://hub.docker.com/r/oracle/graalvm-ce/) reducing effort spend on our side.

The Dockerfile has three segments:

* build the jar with Maven
* build the native image with Graal
* assembly the runtime Docker image based on Alpine

As you can see below, the Graal image is only half the size of the JLink image! Let's see how that stacks up to other languages such as Go and Python.

##### Dockerfile

```dockerfile
#######################################
## 1. BUILD JAR WITH MAVEN
FROM maven:3.6-jdk-8 as BUILD
WORKDIR /usr/src
COPY . /usr/src
RUN mvn clean package -e
#######################################
## 2. BUILD NATIVE IMAGE WITH GRAAL
FROM oracle/graalvm-ce:1.0.0-rc9 as NATIVE_BUILD
WORKDIR /usr/src
COPY --from=BUILD /usr/src/ /usr/src
RUN ls -lath /usr/src/target/
COPY /docker-graal-build.sh /usr/src
RUN ./docker-graal-build.sh
RUN ls -lath
#######################################
## 3. BUILD DOCKER RUNTIME IMAGE
FROM alpine:3.8
CMD ["jpc-graal"]
COPY --from=NATIVE_BUILD /usr/src/jpc-graal /usr/local/bin/
RUN chmod +x /usr/local/bin/jpc-graal
#######################################
```

#### Image disk size

```bash
REPOSITORY                                   TAG                 IMAGE ID            CREATED             SIZE
jpc-graal-maven                              latest              dc33ebb10813        About an hour ago   19.6MB
```

## Go Example

### Application Model

### Build

#### Dockerfile

#### Image Disk size

```bash
REPOSITORY                                   TAG                 IMAGE ID            CREATED             SIZE
jpc-go                                       latest              bb4a8e546601        6 minutes ago       12.3MB
```

## Python Example

### Application Model

### Build

#### Dockerfile

#### Image Disk size

## Container footprint

```bash
kubectl top pods mypod-s4wpb-7dz4q --containers
POD                 NAME         CPU(cores)   MEMORY(bytes)
mypod-7lxnk-gw1sj   jpc-go       0m           0Mi
mypod-7lxnk-gw1sj   java-jlink   0m           0Mi
mypod-7lxnk-gw1sj   java-graal   0m           0Mi
mypod-7lxnk-gw1sj   jnlp         150m         96Mi
```

So, the 0Mi memory seems wrong. So I decided to dive into the Google Cloud Console, to see if there's any information in there.
What I found there, is the data you can see below. The memory is indeed 0Mi, as they're using between 329 and 815 Kilobytes and not hitting the MB threshold (and thus get listed as 0Mi).

We do see that graal uses more CPU and slightly less memory than the JLink setup.
Both are still significantly larger than the Go CLI tool, but as long as the JNLP container takes ~100MB, I don't think we should worry about 400-500KB.

```bash
CPU 
container/cpu/usage_time:gke_container:REDUCE_SUM(, ps-dev-201405): 0.24
 java-graal: 5e-4
 java-jlink: 3e-3
 jnlp: 0.23
 jpc-go: 2e-4
Memory 
 java-graal: 729,088.00
 java-jlink: 815,104.00
 jnlp: 101.507M
 jpc-go: 327,680.00
Disk 
 java-graal: 49,152.00
 java-jlink: 49,152.00
 jnlp: 94,208.00
 jpc-go: 49,152.00
```

## Pipeline

```groovy
pipeline {
    agent {
        kubernetes {
        label 'mypod'
        defaultContainer 'jnlp'
        yaml """
apiVersion: v1
kind: Pod
metadata:
  labels:
    some-label: some-label-value
spec:
  containers:
  - name: java-graal
    image: caladreas/jpc-graal:0.1.0-maven-b1
    command:
    - cat
    tty: true
  - name: java-jlink
    image: caladreas/jpc-jlink:0.1.0-b1
    command:
    - cat
    tty: true
  - name: jpc-go
    image: caladreas/jpc-go:0.1.0-b1
    command:
    - cat
    tty: true
        """
        }
    }
    stages {
        stage('Test Versions') {
            steps {
                container('java-graal') {
                    echo "java-graal"
                    sh '/usr/local/bin/jpc-graal'
                    sleep 5
                }

                container('java-jlink') {
                    echo "java-jlink"
                    sh '/usr/bin/jpb/bin/jpb GitChangeListToFolder abc abc'
                    sleep 5
                }

                container('jpc-go') {
                    sh 'jpc-go sayHello -n joost'
                    sleep 5
                }
                sleep 60
            }
        }
    }
}
```
