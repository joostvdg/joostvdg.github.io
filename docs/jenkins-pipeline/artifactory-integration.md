title: Jenkins & Artifactory
description: Jenkins & Artifactory Integration Based On JFrog's Jenkins Challenge

# JFrog Jenkins Challenge

Visited the stand of JFrog where they had stories about two main products: Artifactory and X-Ray.

For both there is a Challenge, [an X-Ray Challenge](https://jfrog.com/content/xray-challenge/) and [a Jenkins & Artifactory Challenge](https://jfrog.com/content/jenkins-challenge).

## Jenkins Challenge

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

## Installing Artifactory

I installed Artifactory via Helm. JFrog has their own Helm repository - of course, would weird otherwise tbh - and you have to add that first.

```bash
helm repo add jfrog https://charts.jfrog.io
helm install --name artifactory stable/artifactory
```

## Jenkinsfile

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

## Jenkinsfile without Gradle Wrapper

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