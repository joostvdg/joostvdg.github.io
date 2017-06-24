# Core Concepts

Below are some core concepts to understand before building pipelines in Jenkins.

* Step
* Master vs Nodes
* Workspace
* Stage
* Sandbox and Script Security
* Java vs. Groovy
* Env (object)
* Stash & archive
* Tools

## Terminology

The terminology used in this page is based upon the terms used by Cloudbees as related to Jenkins.

If in doubt, please consult the [Jenkins Glossary](https://jenkins.io/doc/book/glossary/). 

## Step

> A single task; fundamentally steps tell Jenkins what to do inside of a Pipeline or Project.

Consider the following piece of pipeline code:

```java hl_lines="4 5 7"
node {
    timestamps {
        stage ('My FIrst Stage') {
            if (isUnix()) {
                sh 'echo "this is Unix!"'
            } else {
                bat 'echo "this is windows"'
            }
        }
    }
}
```

The only execution that happens (almost) exclusively on the node (or build slave) are the **isUnix()**, **sh** and **bat** shell commands.

Those specific tasks are the steps in pipeline code.

## Master vs Nodes

There are many things to keep in mind about Pipelines in Jenkins. 
By far the most important are those related to the distinction between Masters and Nodes.

Aside from the points below, the key thing to keep in mind: Nodes (build slaves) are designed to executes task, Masters are not.

1. Except for the steps themselves, **all** of the Pipeline logic, the Groovy conditionals, loops, etc **execute on the master**. Whether simple or complex! Even **inside a node block**!

1. Steps may use executors to do work where appropriate, but each step has a small on-master overhead too.

1. Pipeline code is written as Groovy but the execution model is radically transformed at compile-time to Continuation Passing Style (CPS).

1. This transformation provides valuable safety and durability guarantees for Pipelines, but it comes with trade-offs:
    * Steps can invoke Java and execute fast and efficiently, but Groovy is much slower to run than normal.
    * Groovy logic requires far more memory, because an object-based syntax/block tree is kept in memory.

1. Pipelines persist the program and its state frequently to be able to survive failure of the master.

Source: [Sam van Oort](https://jenkins.io/blog/2017/02/01/pipeline-scalability-best-practice/), Cloudbees Engineer

#### Node

> A machine which is part of the Jenkins environment and capable of executing Pipelines or Projects. Both the Master and Agents are considered to be Nodes.

#### Master

> The central, coordinating process which stores configuration, loads plugins, and renders the various user interfaces for Jenkins.

### What to do?

So, if Pipeline code can cause big loads on Master, what should we do than?

* Try to limit the use of logic in your groovy code
* Avoid blocking or I/O calls unless explicitly done on a slave via a Step
* If you need heavy processing, and there isn't a Step, create either a 
    * [plugin](https://github.com/joostvdg/hello-world-jenkins-pipeline-plugin) 
    * [Shared Library](../global-shared-library/)
    * Or use a CLI tool via a platform independent language, such as Java or Go

## Workspace

> A disposable directory on the file system of a Node where work can be done by a Pipeline or Project. Workspaces are typically left in place after a Build or Pipeline run completes unless specific Workspace cleanup policies have been put in place on the Jenkins Master.

The key part of the glossary entry there is *disposable directory*. There are absolutely no guarantees about Workspaces in pipeline jobs.

That said, what you should take care of:

* always clean your workspace before you start, you don't know the state of the folder you get
* always clean your workspace after you finish, this way you're less likely to run into problems in subsequent builds
* a workspace is a temporary folder on a single node's filesystem: so every time you use ```node{}``` you have a new workspace
* after your build is finish or leaving the node otherwise, your workspace should be considered gone: need something from? stash or archive it!

## Stage

> Stage is a step for defining a conceptually distinct subset of the entire Pipeline, for example: "Build", "Test", and "Deploy", which is used by many plugins to visualize or present Jenkins Pipeline status/progress.

The stage "step" has a primary function and a secondary function.
Its primary function is to define the visual boundaries between intermediary goals of the pipeline.
 
For example, you can define SCM, Build, QA, Deploy as stages to tell you where the build currently is or where it failed.
 
The secondary function is to provided a scope for variables.
Just like most programming languages, code *blocks* are a more than just syntactic sugar, they also limit the scope of variables.

```java hl_lines="8"
node {
    stage('SCM') {
        def myVar = 'abc'
        checkout scm
    }
    stage('Build') {
        sh 'mvn clean install'
        echo myVar # will fail because the variable doesn't exist here
    }
}
```

#### Stages in classic view
![ClassicViewStages](../images/stages-classic.png)

#### Stages in Blue Ocean view
![ClassicViewStages](../images/stages-blue-ocean.png)

## Sandbox and Script Security

## Java vs. Groovy

## Env (object)

## Stash & archive

## Tools
