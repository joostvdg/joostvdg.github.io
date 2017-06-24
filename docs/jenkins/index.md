# Jenkins

[Cloudbees Study Guide](https://www.cloudbees.com/jenkins/jenkins-certification)

## Base configuration

abc

## Tuning

Please read the following articles from Cloudbees:

* [Prepare-Jenkins-for-support](https://support.cloudbees.com/hc/en-us/articles/222446987-Prepare-Jenkins-for-support)
* [tuning-jenkins-gc-responsiveness-and-stability](https://www.cloudbees.com/blog/joining-big-leagues-tuning-jenkins-gc-responsiveness-and-stability)
* [After-moving-a-job-symlinks-for-folders-became-actual-folders](https://support.cloudbees.com/hc/en-us/articles/216227047-After-moving-a-job-symlinks-for-folders-became-actual-folders)
* [How-to-disable-the-weather-column-to-resolve-instance-slowness](https://support.cloudbees.com/hc/en-us/articles/216973327-How-to-disable-the-weather-column-to-resolve-instance-slowness)
* [Accessing-graphs-on-a-Build-History-page-can-cause-Jenkins-to-become-unresponsive](https://support.cloudbees.com/hc/en-us/articles/203981120-Accessing-graphs-on-a-Build-History-page-can-cause-Jenkins-to-become-unresponsive)
* [AutoBrowser-Feature-Can-Cause-Performance-Issues](https://support.cloudbees.com/hc/en-us/articles/232312088-AutoBrowser-Feature-Can-Cause-Performance-Issues)
* [Disk-Space-Issue-after-upgrading-Branch-API-plugin](https://support.cloudbees.com/hc/en-us/articles/229648087-Disk-Space-Issue-after-upgrading-Branch-API-plugin)
* [JVM-Memory-settings-best-practice](https://go.cloudbees.com/docs/support-kb-articles/CloudBees-Jenkins-Enterprise/JVM-Memory-settings-best-practice.html)

## Pipeline as code

>The default interaction model with Jenkins, historically, has been very web UI driven, requiring users to manually create jobs, then manually fill in the details through a web browser. This requires additional effort to create and manage jobs to test and build multiple projects, it also keeps the configuration of a job to build/test/deploy separate from the actual code being built/tested/deployed. This prevents users from applying their existing CI/CD best practices to the job configurations themselves.

> With the introduction of the Pipeline plugin, users now can implement a project’s entire build/test/deploy pipeline in a Jenkinsfile and store that alongside their code, treating their pipeline as another piece of code checked into source control.

We will dive into several things that come into play when writing Jenkins pipelines.

* Kind of Pipeline jobs
* Info about Pipeline DSL (a groovy DSL)
* Reuse pipeline DSL scripts
* Things to keep in mind
* Do's and Don't

### Resources

* [Pipeline Steps](https://jenkins.io/doc/pipeline/steps/)
* [Pipeline Solution](https://jenkins.io/solutions/pipeline/)
* [Pipeline as Code](https://jenkins.io/doc/pipeline/)
* [Dzone RefCard](https://dzone.com/refcardz/continuous-delivery-with-jenkins-workflow)

### Type of pipeline jobs

* Pipeline (inline)
* Pipeline (from SCM)
* [Multi-Branch Pipeline](https://wiki.jenkins-ci.org/display/JENKINS/Multi-Branch+Project+Plugin)
* [GitHub Organization](https://wiki.jenkins-ci.org/display/JENKINS/Multi-Branch+Project+Plugin)
* [BitBucket Team/Project](https://wiki.jenkins-ci.org/display/JENKINS/Bitbucket+Branch+Source+Plugin)

!!! danger
    When using the [stash function](https://jenkins.io/doc/pipeline/steps/workflow-basic-steps/#code-stash-code-stash-some-files-to-be-used-later-in-the-build) keep in mind that the copying goes from where you are now to the master.
    When you unstash, it will copy the files from the master to where you are building.

    When your pipeline runs on a node and you stash and then unstash, it will copy the files from the node to the master and then back to the node.
    This can have a severe penalty on the performance of your pipeline when you are copying over a network.

## API

Jenkins has an extensive [API](https://www.devopslibrary.com/lessons/ccjpe-api) allowing you to retrieve a lot of information from the server.


### Plugin

For this way you of course have to know how to write a plugin.
There are some usefull resources to get started:
* https://github.com/joostvdg/hello-world-jenkins-pipeline-plugin
* https://wiki.jenkins-ci.org/display/JENKINS/Plugin+tutorial
* https://jenkins.io/blog/2016/05/25/update-plugin-for-pipeline/

## Do's and Don't

Aside from the [Do's and Don'ts](https://www.cloudbees.com/blog/top-10-best-practices-jenkins-pipeline-plugin) from Cloudbees, there are some we want to share.

This changes the requirement for the component identifier property, as a job may only match a single group and a job listing in a group can only match a single. Thus the easiest way to make sure everything will stay unique (template names probably don’t), is to make the component identifier property unique per file - let it use the name of the project.
