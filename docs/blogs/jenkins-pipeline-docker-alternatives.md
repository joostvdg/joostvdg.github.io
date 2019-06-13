# Pipelines With Docker Alternatives

Building pipelines with Jenkins on Docker has been common for a while.

But accessing the docker socket has always been a bit tricky.
The easiest solution is directly mounting the docker socket of the host into your build container.

However, this is a big security risk and something that is undesirable at best and, pretty dangerous at worst.

When you're using an orchestrator such as Kubernetes - which is where Jenkins is currently best put to work - the problem gets worse. Not only do you open up security holes, you also mess up the schedular's insight into available resources, and mess with it's ability to keep your cluster in a correct state.

In some sense, using docker directly in a Kubernetes cluster, is [likened to running with scissors](https://www.youtube.com/watch?v=ltrV-Qmh3oY).

## Potential Alternatives

So, directly running docker containers via a docker engine inside your cluster is out.
Let's look at some alternatives.

* **Kubernetes Pod and External Node**: the simple way out, use a cloud (such as EC2 Cloud) to provision a classic VM with docker engine as an agent and build there
* **JIB**: tool from Google, only works for Java applications and is supported directly from Gradle and Maven - [Link](https://github.com/GoogleContainerTools/jib)
* **Kaniko**: tool from Google, works as 1-on-1 replacement for docker image build (except *Windows Containers*) - [Link](https://github.com/GoogleContainerTools/kaniko)
* **IMG**: tool from Jess Frazelle to avoid building docker images with a root user involved [Link](https://github.com/genuinetools/img)

## Kubernetes Pod and External Node

One of the most used cloud environments is AWS, so I created this solution with AWS's [Amazon EC2 Plugin](https://wiki.jenkins.io/display/JENKINS/Amazon+EC2+Plugin).

!!! Warning
    Unfortunately, you cannot combine the Kubernetes plugin with external nodes (none pod container nodes) in a `Declarative` pipeline. So you have to use `Scripted`.

This can be done with various different cloud providers such as Digital Ocean, Google, AWS or Azure.
This guide will use AWS, as it has the most mature `Jenkins Cloud` plugin.

### Prerequisites

* AWS Account with rights to create AMI's and run EC2 instances
* [Packer](https://www.packer.io/)
* Jenkins with [Amazon EC2 Plugin](https://wiki.jenkins.io/display/JENKINS/Amazon+EC2+Plugin) installed

### Steps

* create AMI with Packer
* install and configure Amazon EC2 plugin
* create a test pipeline

### Create AMI with Packer

Packer needs to be able to access EC2 API's and be able to spin up an EC2 instance and create an AMI out of it.

#### AWS setup for Packer

You need to configure two things:

* account details for Packer to use
* security group where your EC2 instances will be running with
    * this security group needs to open port `22`
    * both Packer and Jenkins will use this for their connection

```bash
export AWS_DEFAULT_REGION=eu-west-1
export AWS_ACCESS_KEY_ID=XXX
export AWS_SECRET_ACCESS_KEY=XXX
```

```bash
aws ec2 --profile myAwsProfile create-security-group \
    --description "For building Docker images" \
    --group-name docker

{
    "GroupId": "sg-08079f78cXXXXXXX"
}
```

Export the security group ID.

```bash
export SG_ID=sg-08079f78cXXXXXXX
echo $SG_ID
```

#### Enable port 22

```bash
aws ec2 \
    --profile myAwsProfile \
    authorize-security-group-ingress \
    --group-name docker \
    --protocol tcp \
    --port 22 \
    --cidr 0.0.0.0/0
```

#### Packer AMI definition

Here's an example definition for Packer for a Ubuntu 18.04 LTS base image with JDK 8 (required by Jenkins) and Docker.

```json
{
    "builders": [{
        "type": "amazon-ebs",
        "region": "eu-west-1",
        "source_ami_filter": {
            "filters": {
                "virtualization-type": "hvm",
                "name": "*ubuntu-bionic-18.04-amd64-server-*",
                "root-device-type": "ebs"
            },
            "owners": ["679593333241"],
            "most_recent": true
        },
        "instance_type": "t2.micro",
        "ssh_username": "ubuntu",
        "ami_name": "docker",
        "force_deregister": true
    }],
    "provisioners": [{
        "type": "shell",
        "inline": [
            "sleep 15",
            "sudo apt-get clean",
            "sudo apt-get update",
            "sudo apt-get install -y apt-transport-https ca-certificates nfs-common",
            "curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -",
            "sudo add-apt-repository \"deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable\"",
            "sudo add-apt-repository -y ppa:openjdk-r/ppa",
            "sudo apt-get update",
            "sudo apt-get install -y docker-ce",
            "sudo usermod -aG docker ubuntu",
            "sudo apt-get install -y openjdk-8-jdk",
            "java -version",
            "docker version"
        ]
    }]
}
```

Build the new AMI with packer.

```bash
packer build docker-ami.json
export AMI=ami-0212ab37f84e418f4
```

#### EC2 Key Pair

Create EC2 key pair, this will be used by Jenkins to connect to the instances via ssh.

```bash
aws ec2 --profile myAwsProfile create-key-pair \
    --key-name jenkinsec2 \
    | jq -r '.KeyMaterial' \
    >jenkins-ec2-proton.pem
```

### EC2 Cloud Configuration

In a Jenkins' master main configuration, you add a new `cloud`.
In this case, we will use a `ec2-cloud` so we can instantiate our EC2 VM's with docker.

* use EC2 credentials for initial connection
* use key (`.pem`) for VM connection (jenkins <> agent)
* configure the following:
    * AMI: ami-0212ab37f84e418f4
    * availability zone: eu-west-1a
    * VPC SubnetID: subnet-aa54XXXX
    * Remote user: ubuntu
    * labels: docker ubuntu linux
    * SecurityGroup Name: (the id) sg-08079f78cXXXXXXX
    * public ip = true
    * connect via public ip = true

### Pipeline

```groovy
@Library('jenkins-pipeline-library@master') _

def scmVars
def label = "jenkins-slave-${UUID.randomUUID().toString()}"

podTemplate(
        label: label,
        yaml: """
apiVersion: v1
kind: Pod
spec:
  containers:
  - name: kubectl
    image: vfarcic/kubectl
    command: ["cat"]
    tty: true
"""
) {
    node(label) {
        node("docker") {
            stage('SCM & Prepare') {
                scmVars = checkout scm
            }
            stage('Lint') {
                dockerfileLint()
            }
            stage('Build Docker') {
                sh "docker image build -t demo:rc-1 ."
            }
            stage('Tag & Push Docker') {
                IMAGE = "${DOCKER_IMAGE_NAME}"
                TAG = "${DOCKER_IMAGE_TAG}"
                FULL_NAME = "${FULL_IMAGE_NAME}"

                withCredentials([usernamePassword(credentialsId: "dockerhub", usernameVariable: "USER", passwordVariable: "PASS")]) {
                    sh "docker login -u $USER -p $PASS"
                }
                sh "docker image tag ${IMAGE}:${TAG} ${FULL_NAME}"
                sh "docker image push ${FULL_NAME}"
            }
        } // end node docker
        stage('Prepare Pod') {
            // have to checkout on our kubernetes pod aswell
            checkout scm
        }
        stage('Check version') {
            container('kubectl') {
                sh 'kubectl version'
            }
        }
    } // end node random label
} // end pod def
```

## Maven JIB

If you use Java with either [Gradle](https://gradle.org/) or [Maven](https://maven.apache.org/), you can use [JIB](https://github.com/GoogleContainerTools/jib) to create docker image without requiring a docker client or docker engine.

JIB will communicate with DockerHub and Google's container registry for sending image layers back and forth.
The last layer will be created by the JIB plugin itself, adding your self-executing Jar to the layer and a `Entrypoint` with the correct flags.

For more information about the runtime options, see either [jib-maven-plugin documentation](https://github.com/GoogleContainerTools/jib/blob/master/jib-maven-plugin) or [jib-gradle-plugin](https://github.com/GoogleContainerTools/jib/blob/master/jib-gradle-plugin).

### Prerequisites

* Java project build with Gradle or Maven
* Java project that can start it self, such as [Spring Boot](https://spring.io/projects/spring-boot) or [Thorntail](https://thorntail.io/) (previously Wildfly Swarm, from the JBoss family)
* able to build either gradle or maven applications

The project used can be found at [github.com/demomon/maven-spring-boot-demo](https://github.com/demomon/maven-spring-boot-demo/).

### Steps

* configure the plugin for either Gradle or Maven
* build using an official docker image via the kubernetes pod template

### Pipeline

Using a bit more elaborate pipeline example here.

Using SonarCloud for static code analysis and then JIB to create a docker image.
We could then use that image either directly in anything that runs docker or in the same cluster via a Helm Chart.

```groovy
def scmVars
def tag

pipeline {
    options {
        buildDiscarder logRotator(artifactDaysToKeepStr: '5', artifactNumToKeepStr: '5', daysToKeepStr: '5', numToKeepStr: '5')
    }
    libraries {
        lib('core@master')
        lib('maven@master')
    }
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
    image: maven:3-jdk-11-slim
    command:
    - cat
    tty: true
"""
        }
    }
    stages {
        stage('Test versions') {
            steps {
                container('maven') {
                    sh 'uname -a'
                    sh 'mvn -version'
                }
            }
        }
        stage('Checkout') {
            steps {
                script {
                    scmVars = checkout scm
                }
                gitRemoteConfigByUrl(scmVars.GIT_URL, 'githubtoken')
                sh '''
                git config --global user.email "jenkins@jenkins.io"
                git config --global user.name "Jenkins"
                '''
            }
        }
        stage('Build') {
            steps {
                container('maven') {
                    sh 'mvn clean verify -B -e'
                }
            }
        }
        stage('Version & Analysis') {
            parallel {
                stage('Version Bump') {
                    when { branch 'master' }
                    environment {
                        NEW_VERSION = gitNextSemverTagMaven('pom.xml')
                    }
                    steps {
                        script {
                            tag = "${NEW_VERSION}"
                        }
                        container('maven') {
                            sh 'mvn versions:set -DnewVersion=${NEW_VERSION}'
                        }
                        gitTag("v${NEW_VERSION}")
                    }
                }
                stage('Sonar Analysis') {
                    when {branch 'master'}
                    environment {
                        SONAR_HOST='https://sonarcloud.io'
                        KEY='spring-maven-demo'
                        ORG='demomon'
                        SONAR_TOKEN=credentials('sonarcloud')
                    }
                    steps {
                        container('maven') {
                            sh '''mvn sonar:sonar \
                                -Dsonar.projectKey=${KEY} \
                                -Dsonar.organization=${ORG} \
                                -Dsonar.host.url=${SONAR_HOST} \
                                -Dsonar.login=${SONAR_TOKEN}
                            '''
                        }
                    }
                }
            }
        }
        stage('Publish Artifact') {
            when { branch 'master' }
            environment {
                DHUB=credentials('dockerhub')
            }
            steps {
                container('maven') {
                    // we should never come here if the tests have not run, as we run verify before
                    sh 'mvn clean compile -B -e jib:build -Djib.to.auth.username=${DHUB_USR} -Djib.to.auth.password=${DHUB_PSW} -DskipTests'
                }
            }
        }
    }
    post {
        always {
            cleanWs()
        }
    }
}
```

## Kaniko

Google loves Kubernetes and Google prefers people building docker images in Kubernetes without Docker.

As JIB is only available for Java projects, there's needs to be an alternative for any other usecase/programming language.

The answer to that is [Kaniko](https://github.com/GoogleContainerTools/kaniko), a specialized Docker image to create Docker images.

Kaniko isn't the most secure way to create docker images, it barely beats mounting a Docker Socket, or might even be worse if you ask others (such as [Jess Frazelle](https://twitter.com/jessfraz/status/985947353981976576)). 

That said, it is gaining some traction being used by [JenkinsX](https://jenkins-x.io) and having an example in [Jenkins' Kubernetes Plugin](https://github.com/jenkinsci/kubernetes-plugin/blob/master/examples/kaniko-declarative.groovy).

!!! Info
    When building more than one image inside the kaniko container, make sure to use the `--cleanup` flag.
    So it cleans its temporary cache data before building the next image, as discussed in [this google group](https://groups.google.com/forum/#!topic/kaniko-users/_7LivHdMdy0).

### Prerequisites

### Steps

* Create docker registry secret
* Configure pod container template
* Configure stage

#### Create docker registry secret

This is an example for DockerHub inside the `build` namespace.

```bash
kubectl create secret docker-registry -n build regcred \
    --docker-server=index.docker.io \
    --docker-username=myDockerHubAccount \
    --docker-password=myDockerHubPassword \
    --docker-email=myDockerHub@Email.com
```

##### Example Ppeline

!!! Warning
    Although multi-stage `Dockerfile`'s are supported, it did fail in my case.
    So I created a second Dockerfile which is only for running the application (`Dockerfile.run`).

```groovy
pipeline {
    agent {
        kubernetes {
            //cloud 'kubernetes'
            label 'kaniko'
            yaml """
kind: Pod
metadata:
  name: kaniko
spec:
  containers:
  - name: golang
    image: golang:1.11
    command:
    - cat
    tty: true
  - name: kaniko
    image: gcr.io/kaniko-project/executor:debug
    imagePullPolicy: Always
    command:
    - /busybox/cat
    tty: true
    volumeMounts:
      - name: jenkins-docker-cfg
        mountPath: /root
      - name: go-build-cache
        mountPath: /root/.cache/go-build
      - name: img-build-cache
        mountPath: /root/.local
  volumes:
  - name: go-build-cache
    emptyDir: {}
  - name: img-build-cache
    emptyDir: {}
  - name: jenkins-docker-cfg
    projected:
      sources:
      - secret:
          name: regcred
          items:
            - key: .dockerconfigjson
              path: .docker/config.json
"""
        }
    }
    stages {
        stage('Checkout') {
            steps {
                git 'https://github.com/joostvdg/cat.git'
            }
        }
        stage('Build') {
            steps {
                container('golang') {
                    sh './build-go-bin.sh'
                }
            }
        }
        stage('Make Image') {
            environment {
                PATH = "/busybox:$PATH"
            }
            steps {
                container(name: 'kaniko', shell: '/busybox/sh') {
                    sh '''#!/busybox/sh
                    /kaniko/executor -f `pwd`/Dockerfile.run -c `pwd` --cache=true --destination=index.docker.io/caladreas/cat
                    '''
                }
            }
        }
    }
}
```

## IMG

`img` is the brainchild of Jess Frazelle, a prominent figure in the container space.

The goal is to be the safest and best way to build OCI compliant images, as outlined in her blog [building container images securely on kubernetes](https://blog.jessfraz.com/post/building-container-images-securely-on-kubernetes/).


### Not working (for me) yet

It does not seem to work for me on AWS's EKS.
To many little details with relation to runc, file permissions and other configuration.

For those who want to give it a spin, here are some resources to take a look at.

* https://blog.jessfraz.com/post/building-container-images-securely-on-kubernetes/
* https://github.com/genuinetools/img
* https://github.com/opencontainers/runc
* https://git.j3ss.co/genuinetools/img/+/d05b3e4e10cd0e3c074ffb03dc22d7bb6cde1e78

### Pipeline Example

```groovy
pipeline {
    agent {
        kubernetes {
            label 'img'
            yaml """
kind: Pod
metadata:
  name: img
  annotations:
    container.apparmor.security.beta.kubernetes.io/img: unconfined  
spec:
  containers:
  - name: golang
    image: golang:1.11
    command:
    - cat
    tty: true
  - name: img
    workingDir: /home/jenkins
    image: caladreas/img:0.5.1
    imagePullPolicy: Always
    securityContext:
        rawProc: true
        privileged: true
    command:
    - cat
    tty: true
    volumeMounts:
      - name: jenkins-docker-cfg
        mountPath: /root
  volumes:
  - name: temp
    emptyDir: {}
  - name: jenkins-docker-cfg
    projected:
      sources:
      - secret:
          name: regcred
          items:
            - key: .dockerconfigjson
              path: .docker/config.json
"""
        }
    }
    stages {
        stage('Checkout') {
            steps {
                git 'https://github.com/joostvdg/cat.git'
            }
        }
        stage('Build') {
            steps {
                container('golang') {
                    sh './build-go-bin.sh'
                }
            }
        }
        stage('Make Image') {
            steps {
                container('img') {
                    sh 'mkdir cache'
                    sh 'img build -s ./cache -f Dockerfile.run -t caladreas/cat .'
                }
            }
        }
    }
}
```
