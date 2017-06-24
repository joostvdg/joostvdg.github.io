# Jenkins Pipelines

!!! warning
    This style of pipeline definition is deprecated.
    When possible, please use the declarative version.

> Jenkins Pipeline is a suite of plugins which supports implementing and integrating continuous delivery pipelines into Jenkins. Pipeline provides an extensible set of tools for modeling simple-to-complex delivery pipelines "as code" via the Pipeline DSL.

There are two ways to create pipelines in Jenkins.
Either via the [Groovy DSL](https://github.com/jenkinsci/pipeline-plugin/blob/master/TUTORIAL.md) or via the [Declarative pipeline](https://jenkins.io/blog/2017/02/03/declarative-pipeline-ga/).

For more information about the declarative pipeline, read the [next page](../declarative-pipeline/).

## Hello World Example

```groovy
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

## Resources

* [Getting started](https://jenkins.io/doc/pipeline/tour/hello-world/)
* [Best practices](https://www.cloudbees.com/blog/top-10-best-practices-jenkins-pipeline-plugin)
* [Best practices for scaling](https://jenkins.io/blog/2017/02/01/pipeline-scalability-best-practice/)
* [Possible Steps](https://jenkins.io/doc/pipeline/steps/)
