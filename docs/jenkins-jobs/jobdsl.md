# Jenkins Job DSL

Jenkins is a wonderful system for managing builds, and people love using its UI to configure jobs. Unfortunately, as the number of jobs grows, maintaining them becomes tedious, and the paradigm of using a UI falls apart. Additionally, the common pattern in this situation is to copy jobs to create new ones, these "children" have a habit of diverging from their original "template" and consequently it becomes difficult to maintain consistency between these jobs.

The Jenkins job-dsl-plugin attempts to solve this problem by allowing jobs to be defined with the absolute minimum necessary in a programmatic form, with the help of templates that are synced with the generated jobs. The goal is for your project to be able to define all the jobs they want to be related to their project, declaring their intent for the jobs, leaving the common stuff up to a template that were defined earlier or hidden behind the DSL.

## Pipeline with folder example
```groovy
import hudson.model.*
import jenkins.model.*

def dslExamplesFolder = 'DSL-Examples'
def gitLabCredentialsId = 'joost-flusso-gitlab-ssh'
def gitLabUrl = 'git@gitlab.flusso.nl'
def gitLabNamespace = 'keep'
def gitLabProject = 'keep-api'


if(!jenkins.model.Jenkins.instance.getItem(dslExamplesFolder)) {
    //folder doesn't exist because item doesn't exist in runtime
    //Therefore, create the folder.
    folder(dslExamplesFolder) {
        displayName('DSL Examples')
        description('Folder for job dsl examples')
    }
}

createMultibranchPipelineJob(gitLabCredentialsId, gitLabUrl, dslExamplesFolder, 'keep', 'keep-api')
createMultibranchPipelineJob(gitLabCredentialsId, gitLabUrl, dslExamplesFolder, 'keep', 'keep-backend-spring')
createMultibranchPipelineJob(gitLabCredentialsId, gitLabUrl, dslExamplesFolder, 'keep', 'keep-frontend')

def createMultibranchPipelineJob(def gitLabCredentialsId, def gitLabUrl, def folder, def gitNamespace, def project) {
    multibranchPipelineJob("${folder}/${project}-mb") {
        branchSources {
            git {
                remote("${gitLabUrl}:${gitNamespace}/${project}.git")
                credentialsId(gitLabCredentialsId)
            }
        }
        orphanedItemStrategy {
            discardOldItems {
                numToKeep(20)
            }
        }
    }
}
```

## Freestyle maven job
```groovy
def project = 'quidryan/aws-sdk-test'
def branchApi = new URL("https://api.github.com/repos/${project}/branches")
def branches = new groovy.json.JsonSlurper().parse(branchApi.newReader())
branches.each {
    def branchName = it.name
    def jobName = "${project}-${branchName}".replaceAll('/','-')
    job(jobName) {
        scm {
            git("git://github.com/${project}.git", branchName)
        }
        steps {
            maven("test -Dproject.name=${project}/${branchName}")
        }
    }
}
```

## Resources
* [Tutorial](https://github.com/jenkinsci/job-dsl-plugin/wiki/Tutorial---Using-the-Jenkins-Job-DSL)
* [Live Playground](http://job-dsl.herokuapp.com/)
* [Main DSL Commands](https://github.com/jenkinsci/job-dsl-plugin/wiki/Job-DSL-Commands)
* [API Viewer](https://jenkinsci.github.io/job-dsl-plugin/)

## Other References
* [Talks and Blogs](https://github.com/jenkinsci/job-dsl-plugin/wiki/Talks-and-Blog-Posts)
* [User Power Movies](https://github.com/jenkinsci/job-dsl-plugin/wiki/User-Power-Moves)
* [DZone article](https://dzone.com/articles/the-jenkins-job-dsl-plugin-in-practice)
* [Testing DSL Scripts](https://github.com/jenkinsci/job-dsl-plugin/wiki/Testing-DSL-Scripts)
