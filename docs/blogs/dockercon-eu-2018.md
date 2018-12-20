# DockerCon EU 2018 - Recap

* Java maven build (docker-assemble) includes a bill of materials (Docker EE?)
* CAT interoperability with this bom?
* Docker app == CNAB
![](../images/dockerconeu2018/)

## Docker Build with Build-Kit

Instead of investing in improving docker image building via the Docker Client, Docker created a new API and client library.

This library called BuildKit, is completely independent. With Docker 18.09, it is included in the Docker Client allowing anyone to use it as easily as the traditional `docker image build`.

BuildKit is already used by some other tools, such as Buildah and IMG, and allows you to create custom DSL "Frontends". As long as the API of BuikdKit is adhered to, the resulting image will be OCI compliant.

So further remarks below and how to use it.

* [BuildKit](https://github.com/moby/buildkit)
* In-Depth session [Supercharged Docker Build with BuildKit](https://europe-2018.dockercon.com/videos-hub)
* Usable from Docker `18.09`
* HighLights:
    * allows custom DSL for specifying image (BuildKit) to still be used with Docker client/daemon
    * build cache for your own files during build, think Go, Maven, Gradle...
    * much more optimized, builds less, quicker, with more cache in less time
    * support mounts (cache) such as secrets, during build phase

```bash
# Set env variable to enable
# Or configure docker's json config
export DOCKER_BUILDKIT=1
```

```dockerfile
# syntax=docker/dockerfile:experimental
#######################################
## 1. BUILD JAR WITH MAVEN
FROM maven:3.6-jdk-8 as BUILD
WORKDIR /usr/src
COPY . /usr/src
! RUN --mount=type=cache,target=/root/.m2/  mvn clean package -e
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

![BuildKit Slide](../images/dockerconeu2018/buildkit-1.jpg)

## Secure your Kubernetes

* https://www.openpolicyagent.org + admission controller
* Network Policies
* Service Accounts
* 

## CNAB: cloud native application bundle

* Bundle.json
* invocation image (oci) = installer
* https://cnab.io
* docker app implements it
* helm support
* https://github.com/deislabs

![CNAB](../images/dockerconeu2018/cnab-1.jpg)

## Multi-Cloud as Code

* Pulumi.io (typescript, python)
* install: `brew install pulumi`
* take over files from [Pulumi's Jenkins Demo](https://github.com/demomon/pulumi-demo-1)
* init stack `pulumi stack init demomon-pulumi-demo-1`
    * connect to GitHub
* set kubernetes config `pulumi config set kubernetes:context gke_ps-dev-201405_europe-west4_joostvdg-reg-dec18-1`
* `pulumi config set isMinikube false`
* `npm install`
* `pulumi config set username administrator`
* `pulumi config set password 3OvlgaockdnTsYRU5JAcgM1o --secret`
* `pulumi preview`
* incase pulumi loses your stack: `pulumi stack select demomon-pulumi-demo-1`
* `pulumi destroy`

```bash
     Type                                         Name                                         Status
 +   pulumi:pulumi:Stack                          demomon-pulumi-demo-2-demomon-pulumi-demo-2  created
 +   └─ kubernetes:helm.sh:Chart                  jenkins-pulumi                               created
 +      ├─ kubernetes:core:ConfigMap              jenkins-pulumi-tests                         created
 +      ├─ kubernetes:core:ConfigMap              jenkins-pulumi                               created
 +      ├─ kubernetes:core:Secret                 jenkins-pulumi                               created
 +      ├─ kubernetes:core:Service                jenkins-pulumi-agent                         created
 +      ├─ kubernetes:core:Service                jenkins-pulumi                               created
 +      ├─ kubernetes:core:PersistentVolumeClaim  jenkins-pulumi                               created
 +      ├─ kubernetes:extensions:Ingress          jenkins-pulumi                               created
 +      ├─ kubernetes:core:Pod                    jenkins-pulumi-ui-test-j2dtf                 created
 +      └─ kubernetes:apps:Deployment             jenkins-pulumi                               created

Resources:
    + 11 created

Duration: 1m39s

Permalink: https://app.pulumi.com/joostvdg/demomon-pulumi-demo-2/updates/4
```

## JFrog Jenkins Challenge

Visited the stand of JFrog where they had stories about two main products: Artifactory and X-Ray.

For both there is a Challenge, [an X-Ray Challenge](https://jfrog.com/content/xray-challenge/) and [a Jenkins & Artifactory Challenge](https://jfrog.com/content/jenkins-challenge).

### Jenkins Challenge

The instructions for the Challenge were simply, follow what is stated [in their GitHub repository](https://github.com/jbaruch/jenkins-challenge) and email a screenshot of the result.

The instruction were as follows:

1. Get an Artifactory instance (you can start a free trial on prem or in the cloud)
1. Install Jenkins
1. Install Artifactory Jenkins Plugin
1. Add Artifactory credentials to Jenkins Credentials
1. Create a new pipeline job
1. Use the Artifactory Plugin DSL documentation to complete the following script:

With a Scripted Pipeline as starting point:

```groovy
node {
    def rtServer
    def rtGradle
    def buildInfo
    stage('Preparation') {
        git 'https://github.com/jbaruch/gradle-example.git'
        // create a new Artifactory server using the credentials defined in Jenkins 
        // create a new Gradle build
        // set the resolver to the Gradle build to resolve from Artifactory
        // set the deployer to the Gradle build to deploy to Artifactory
        // declare that your gradle script does not use Artifactory plugin
        // declare that your gradle script uses Gradle wrapper
    }
    stage('Build') {
        //run the artifactoryPublish gradle task and collect the build info
    }
    stage('Publish Build Info') {
        //collect the environment variables to build info
        //publish the build info
    }
}
```

I don't like scripted, so I opted for Declarative with Jenkins in Kubernetes with the Jenkins Kubernetes plugin.

Steps I took:

* get a trial license from the [JFrog website](https://www.jfrog.com/artifactory/free-trial/)
* install Artifactory
    * and copy in the license when prompted
    * change admin password
    * create local maven repo 'libs-snapshot-local'
    * create remote maven repo 'jcenter' (default remote value is jcenter, so only have to set the name)
* install Jenkins
    * Artifactory plugin
    * Kubernetes plugin
* add Artifactory username/password as credential in Jenkins
* create a gradle application (Spring boot via start.spring.io) which [you can find here](https://github.com/demomon/gradle-jenkins-challenge)
* create a Jenkinsfile

#### Installing Artifactory

I installed Artifactory via Helm. JFrog has their own Helm repository - of course, would weird otherwise tbh - and you have to add that first.

```bash
helm repo add jfrog https://charts.jfrog.io
helm install --name artifactory stable/artifactory
```

#### Jenkinsfile

This uses the Gradle wrapper - as per instructions in the challenge.

So we can use the standard JNLP container, which is default, so `agent any` will do.

```groovy
pipeline {
    agent any
    environment {
        rtServer  = ''
        rtGradle  = ''
        buildInfo = ''
        artifactoryServerAddress = 'http://..../artifactory'
    }
    stages {
        stage('Test Container') {
            steps {
                container('gradle') {
                    sh 'which gradle'
                    sh 'uname -a'
                    sh 'gradle -version'
                }
            }
        }
        stage('Checkout'){
            steps {
                git 'https://github.com/demomon/gradle-jenkins-challenge.git'
            }
        }
        stage('Preparation') {
            steps {
                script{
                    // create a new Artifactory server using the credentials defined in Jenkins 
                    rtServer = Artifactory.newServer url: artifactoryServerAddress, credentialsId: 'art-admin'

                    // create a new Gradle build
                    rtGradle = Artifactory.newGradleBuild()

                    // set the resolver to the Gradle build to resolve from Artifactory
                    rtGradle.resolver repo:'jcenter', server: rtServer
                    
                    // set the deployer to the Gradle build to deploy to Artifactory
                    rtGradle.deployer repo:'libs-snapshot-local',  server: rtServer

                    // declare that your gradle script does not use Artifactory plugin
                    rtGradle.usesPlugin = false

                    // declare that your gradle script uses Gradle wrapper
                    rtGradle.useWrapper = true
                }
            }
        }
        stage('Build') {
            steps {
                script {
                    //run the artifactoryPublish gradle task and collect the build info
                    buildInfo = rtGradle.run buildFile: 'build.gradle', tasks: 'clean build artifactoryPublish'
                }
            }
        }
        stage('Publish Build Info') {
            steps {
                script {
                    //collect the environment variables to build info
                    buildInfo.env.capture = true
                    //publish the build info
                    rtServer.publishBuildInfo buildInfo
                }
            }
        }
    }
}
```

#### Jenkinsfile without Gradle Wrapper

I'd rather not install the Gradle tool if I can just use a pre-build container with it.

Unfortunately, to use it correctly with the Artifactory plugin and a Jenkins Kubernetes plugin, we need to do two things.

1. create a `Gradle` Tool in the Jenkins master
    * because the Artifactory plugin expects a `Jenkins Tool` object, not a location
    * Manage Jenkins -> Global Tool Configuration -> Gradle -> Add
    * As value supply `/usr`, the Artifactory build will add `/gradle/bin` to it automatically
1. set the user of build Pod to id `1000` explicitly
    * else the build will not be allowed to touch files in `/home/jenkins/workspace`

```groovy
pipeline {
    agent {
        kubernetes {
        label 'mypod'
        yaml """apiVersion: v1
kind: Pod
spec:
  securityContext:
    runAsUser: 1000
    fsGroup: 1000
  containers:
  - name: gradle
    image: gradle:4.10-jdk-alpine
    command: ['cat']
    tty: true
"""
        }
    }
    environment {
        rtServer  = ''
        rtGradle  = ''
        buildInfo = ''
        CONTAINER_GRADLE_TOOL = '/usr/bin/gradle'
    }
    stages {
        stage('Test Container') {
            steps {
                container('gradle') {
                    sh 'which gradle'
                    sh 'uname -a'
                    sh 'gradle -version'
                }
            }
        }
        stage('Checkout'){
            steps {
                // git 'https://github.com/demomon/gradle-jenkins-challenge.git'
		checkout scm
            }
        }
        stage('Preparation') {
            steps {
                script{
                    // create a new Artifactory server using the credentials defined in Jenkins 
                    rtServer = Artifactory.newServer url: 'http://35.204.238.14/artifactory', credentialsId: 'art-admin'

                    // create a new Gradle build
                    rtGradle = Artifactory.newGradleBuild()

                    // set the resolver to the Gradle build to resolve from Artifactory
                    rtGradle.resolver repo:'jcenter', server: rtServer
                    
                    // set the deployer to the Gradle build to deploy to Artifactory
                    rtGradle.deployer repo:'libs-snapshot-local',  server: rtServer

                    // declare that your gradle script does not use Artifactory plugin
                    rtGradle.usesPlugin = false

                    // declare that your gradle script uses Gradle wrapper
                    rtGradle.useWrapper = true
                }
            }
        }
        stage('Build') {
            //run the artifactoryPublish gradle task and collect the build info
            steps {
                script {
                    buildInfo = rtGradle.run buildFile: 'build.gradle', tasks: 'clean build artifactoryPublish'
                }
            }
        }
        stage('Publish Build Info') {
            //collect the environment variables to build info
            //publish the build info
            steps {
                script {
                    buildInfo.env.capture = true
                    rtServer.publishBuildInfo buildInfo
                }
            }
        }
    }
}
```

## Docker security & standards

* security takes place in every layer/lifecycle phase
* for scaling, security needs to be part of developer's day-to-day
* as everything is code, anything part of the sdlc should be secure and auditable
* use an admission controller
* network policies
* automate your security processes
* expand your security automation by adding learnings

![Secure 1](../images/dockerconeu2018/secure-1.jpg)

![Secure 2](../images/dockerconeu2018/secure-2.jpg)

## Docker & Java & CICD

* telepresence
* Distroless (google mini os)
* OpenJ9
* Portala (for jdk 12)
* wagoodman/dive
* use jre for the runtime instead of jdk
* buildkit can use mounttarget for local caches
* add labels with Metadata (depency trees)
* grafeas & kritis
* FindSecBugs
* org.owasp:dependency-check-maven
* arminc/clair-scanner
* jlink = in limbo

## Docker & Windows

* specific base images for different use cases
* Docker capabilities heavily depend on Windows Server version

![Windows 1](../images/dockerconeu2018/windows-1.jpg)

![Windows 2](../images/dockerconeu2018/windows-2.jpg)

![Windows 3](../images/dockerconeu2018/windows-3.jpg)

![Windows 4](../images/dockerconeu2018/windows-4.jpg)

## Other

### Docker pipeline

* Dind + privileged
* mount socket
* windows & linux
* Windows build agent provisioning with docker EE & Jenkins
* Docker swarm update_config

### Idea: build a dynamic ci/cd platform with kubernetes

* jenkins evergreen + jcasc
* kubernetes plugin
* gitops pipeline
* AKS + virtual kubelet + ACI
* Jenkins + EC2 Pluging + ECS/Fargate
* jenkins agent as ecs task (fargate agent)
* docker on windows, only on ECS

### Apply Diplomacy to Code Review

* apply diplomacy to code review
* always positive
* remove human resistantance with inclusive language
* improvement focused
* persist, kindly

![Diplomacy Language](../images/dockerconeu2018/diplomacy-1.jpg)

### Citizens Bank journey

* started with swarm, grew towards kubernetes (ucp)
* elk stack, centralised operations cluster

![Citizens 1](../images/dockerconeu2018/citizens-1.jpg)

![Citizens 2](../images/dockerconeu2018/citizens-2.jpg)

### Docker EE - Assemble

Docker EE now has a binary called `docker-assemble`.
This allows you to build a Docker image directly from something like a pom.xml, much like JIB.

![DockerAssemble MetaData](../images/dockerconeu2018/metadata-1.jpg)

### Other

![Random](../images/dockerconeu2018/random-1.jpg)
