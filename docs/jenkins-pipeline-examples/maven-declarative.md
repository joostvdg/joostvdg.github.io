# Maven Declarative Examples

## Basics

We have to wrap the entire script in ``` pipeline { }```, for it to be marked a declarative script.

As we will be using different agents for different stages, we select *none* as the default.

For house keeping, we add the ``` options{} ``` block, where we configure the following:

* timeout: make sure this jobs succeeds in 10 minutes, else just cancel it
* timestamps(): to make sure we have timestamps in our logs
* buildDiscarder(): this will make sure we will only keep the latest 5 builds 

```groovy
pipeline {
    agent none
    options {
        timeout(time: 10, unit: 'MINUTES')
        timestamps()
        buildDiscarder(logRotator(numToKeepStr: '5'))
    }
}
```

## Checkout

There are several ways to checkout the code.

Let's assume our code is somewhere in a git repository.

### Full Checkout command

The main command for checking out is the Checkout command.

It will look like this.

```groovy
stage('SCM') {
    checkout([
        $class: 'GitSCM', 
        branches: [[name: '*/master']], 
        doGenerateSubmoduleConfigurations: false, 
        extensions: [], 
        submoduleCfg: [], 
        userRemoteConfigs: 
            [[credentialsId: 'MyCredentialsId', 
            url: 'https://github.com/joostvdg/keep-watching']]
    ])
}
```

### Git shorthand

Thats a lot of configuration for a simple checkout.

So what if I'm just using the master branch of a publicly accessible repository (as is the case with GitHub)?

```groovy
stage('SCM') {
    git 'https://github.com/joostvdg/keep-watching'
}
```

Or with a different branch and credentials:

```groovy
stage('SCM') {
    git credentialsId: 'MyCredentialsId', url: 'https://github.com/joostvdg/keep-watching'
}
```

That's much better, but we can do even better.

### SCM shorthand

If you're starting this pipeline job via a SCM, you've already configured the SCM.

So assuming you've configured a pipeline job with 'Jenkinsfile from SCM' or an abstraction job - such as Multibranch-Pipeline, GitHub Organization or BitBucket Team/Project - you can do this.

```groovy
stage('SCM') {
    checkout scm
}
```

The ```checkout scm``` line will use the checkout command we've used in the first example together with the object **scm**.

This scm object, will contain the SCM configuration of the Job and will be reused for checking out.

!!! warning
    A pipeline job from SCM or abstraction, will only checkout your Jenkinsfile.
    You will always need to checkout the rest of your code if you want to build it.
    For that, just use ```checkout scm```                 

## Different Agent per Stage

As you could see on the top, we've set agent to none.

So for every stage we now need to tell it which agent to use - without it, the stage will fail.  

### Agent any

If you don't care what node it comes on, you specify any.

```groovy hl_lines="2"
stage('Checkout') {
    agent any
    steps {
        git 'https://github.com/joostvdg/keep-watching'
    }
}
```

### Agent via Label

If you want build on a node with a specific label - here **docker** - you do so with ```agent { label '<LABEL>' }```. 

```groovy hl_lines="2"
stage('Checkout') {
    agent { label 'docker' }
    steps {
        git 'https://github.com/joostvdg/keep-watching'
    }
}
```

### Docker Container as Agent

Many developers are using docker for their CI/CD builds. 
So being able to use docker containers as build agents is a requirement these days.

```groovy hl_lines="3 4 5 6"

stage('Maven Build') {
    agent {
        docker {
            image 'maven:3-alpine'
            label 'docker'
            args  '-v /home/joost/.m2:/root/.m2'
        }
    }
    steps {
        sh 'mvn -B clean package'
    }
}
```

### Cache Maven repo

When you're using a docker build container, it will be clean every time.

So if you want to avoid downloading the maven dependencies every build, you have to cache them.

One way to do this, is to map a volume into the container so the container will use that folder instead. 

```groovy hl_lines="6"

stage('Maven Build') {
    agent {
        docker {
            image 'maven:3-alpine'
            label 'docker'
            args  '-v /home/joost/.m2:/root/.m2'
        }
    }
    steps {
        sh 'mvn -B clean package'
    }
}
```

## Post stage/build

The declarative pipeline allows for Post actions, on both stage and complete build level.

For both types there are different post hooks you can use, such as success, failure.

```groovy hl_lines="12 13"
stage('Maven Build') {
    agent {
        docker {
            image 'maven:3-alpine'
            label 'docker'
            args  '-v /home/joost/.m2:/root/.m2'
        }
    }
    steps {
        sh 'mvn -B clean package'
    }
    post {
        success {
            junit 'target/surefire-reports/**/*.xml'
        }
    }
}
```

```groovy hl_lines="8 9 12 15 18 21"
stages {
    stage('Example') {
        steps {
            echo 'Hello World'
        }
    }
}
post {
    always {
        echo 'This will always run'
    }
    success {
        echo 'SUCCESS!'
    }
    failure {
        echo "We Failed"
    }
    unstable {
        echo "We're unstable"
    }
    changed {
        echo "Status Changed: [From: $currentBuild.previousBuild.result, To: $currentBuild.result]"
    }
}

```


## Entire example

```groovy
pipeline {
    agent none
    options {
        timeout(time: 10, unit: 'MINUTES')
        timestamps()
        buildDiscarder(logRotator(numToKeepStr: '5'))
    }
    stages {
        stage('Example') {
            steps {
                echo 'Hello World'
            }
        }
        stage('Checkout') {
            agent { label 'docker' }
            steps {
                git 'https://github.com/joostvdg/keep-watching'
            }
        }
        stage('Maven Build') {
            agent {
                docker {
                    image 'maven:3-alpine'
                    label 'docker'
                    args  '-v /home/joost/.m2:/root/.m2'
                }
            }
            steps {
                sh 'mvn -B clean package'
            }
            post {
                success {
                    junit 'target/surefire-reports/**/*.xml'
                }
            }
        }
        stage('Docker Build') {
            agent { label 'docker' }
            steps {
                sh 'docker build --tag=keep-watching-be .'
            }
        }
    }
    post {
        always {
            echo 'This will always run'
        }
        success {
            echo 'SUCCESS!'
        }
        failure {
            echo "We Failed"
        }
        unstable {
            echo "We're unstable"
        }
        changed {
            echo "Status Changed: [From: $currentBuild.previousBuild.result, To: $currentBuild.result]"
        }
    }
}
```