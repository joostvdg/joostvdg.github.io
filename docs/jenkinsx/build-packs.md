title: Extending Jenkins X Build Packs
description: How to extend Jenkins X Build Packs

# Build Packs

In this guide we will look at what a Jenkins X Build Pack is, what you can use it for and how you can extend it.

## What is a Build Pack

A build pack is a collection of resources that helps you build and deploy an application in Kubernetes with Jenkins X.

There's three ways you can use a build pack:

* when you create a new project (`jx create quickstart`)
* when you import an existing project (`jx import`)
* referencing it in a `jenkins-x.yaml` pipeline file

A build pack contains resources related to the pipeline, both a `Jenkinsfile` for static Jenkins and a `jenkins-x.yanl` for Jenkins X pipelines.

In addition, it contains everything else required to get an application of a specific technology and framework to build, versioned, containerized, and deployed with Helm. This means it contains a `Dockerfile` and a Helm Chart at least.

When importing, what you already have doesn't get replaced, so they're safe to apply to any existing applications.

As with any technology, you can never capture the whole world.
This means there are times when you need to extend the default Build Packs.

## Ways To Extend

Roughly speaking, there are three ways to extend the Build Packs functionality within Jenkins X.

* **Customize**: you can customize your Build Packs by replacing the local reference of Jenkins X to different repository
    * this makes especially sense for `jx create quickstart` and `jx import`, as these commands run locally
* **Extend Locally**: you can locally (in your own repository) extend the build pack by changing the generated files (such as `jenkins-x.yaml`)
* **Extend Globally**: for the Jenkins X pipeline (`jenkins-x.yaml`), you can also extend it _globally_ by chaining Build Pack references

!!! important
    The focus of this guide is on _extending globally_!

## Customize

To customize the Build Packs we have to do the following:

* fork the default Jenkins X Build Packs
* make your changes to this fork repository
* update your Jenkins X's local Build Pack reference to your fork

To fork the repository, you can go here [https://github.com/jenkins-x-buildpacks/jenkins-x-kubernetes](https://github.com/jenkins-x-buildpacks/jenkins-x-kubernetes).

The changes you might want to make I cannot predict, so you're on your own there.

To create a similar Build Pack, you can copy a whole folder, and only change the things that need to be different.

And, last but not least, to tell Jenkins X to use a different Build Pack repositort, use the command below:

!!! tip
    In order to make this a bit easier to use, I've assumed the following: 
    
    * you do a direct fork, and do not rename the repository
    * you fork it on GitHub

    Set the `GH_USER` variable and then the next few commands should be easier to use.

    ```bash
    GH_USER=
    ```

```bash
jx edit buildpack \
    -u https://github.com/$GH_USER/jenkins-x-kubernetes \
    -r master \
    -b
```

Once you've use it to create a new quickstart or import an existing application, you should be able to see your Build Repository checked out by Jenkins X locally.

```bash
ls -1 ~/.jx/draft/packs/github.com/$GH_USER/jenkins-x-kubernetes/packs
```

For a whole tutorial, you can look at [Viktor Farcic's blog](https://technologyconversations.com/2019/02/27/creating-custom-jenkins-x-build-packs/) technologyconversations.com.

## Extend Locally

To extend locally, we simply have to alter anything in your application's repository.

We can be a bit more helpful, there are ways to extend the Jenkins X pipeline locally, not by writing your own, but by the special `override`syntax in your `jenkins-x.yaml` file.

This would look like this:

```bash
pipelineConfig:
  pipelines:
    overrides:
```

Go to the [Jenkins X Pipelines](/jenkinsx/jx-pipelines/) page for further details.

## Extend Globally

Extending the Build Pack globally has a very limited scope, it is only for the Jenkins X pipeline.

However, as the pipeline is one of the - if not _the_ - most important parts of Jenkins X. So I'd argue that it is very powerful despite its limited scope.

So what we're going to do is the following:

* create a new repository
* set up the required structure in the repository
* create a pipeline extension
* configure an existing Jenkins X application to leverage our Build Pack

!!! info
    Why would you want to _globally extend_ the Build Packs?
    Because this allows you to store your extensions to the Jenkins X default pipelines in a way every application can reuse them, or even extend those.

    It allows you to define standard steps that every pipeline in your organization needs to execute, once and only once.

### Create Build Pack Repository

The minimal amount we need, is a folder called `packs`, inside which we need a few more things.

* an `imports.yaml` importing any and all Build Pack repositories we want to use
    * for example, the default `kubernetes` and `classic` packs from the Jenkins X Authors themselves
* a folder, the name of your Build Pack, containing a `pipeline.yaml`

The structure will then look like this.

```
.
├── README.md
└── packs
    ├── imports.yaml
    └── maven-joost
        └── pipeline.yaml
```

!!! example "packs/imports.yaml"

    Here we import the default Build Pack repositories, so our new pipelines can extends them using the [Pipeline Extensions](https://docs.cloudbees.com/docs/cloudbees-jenkins-x-distribution/latest/pipelines/#_extending_pipelines) syntax.

    ```yaml
    modules:
    - name: classic
      gitUrl: https://github.com/jenkins-x-buildpacks/jenkins-x-classic.git
      gitRef: master
    - name: kubernetes
      gitUrl: https://github.com/jenkins-x-buildpacks/jenkins-x-kubernetes.git
      gitRef: master
    ```

### Create Pipeline Extension

In order to extend the existing pipelines coming from other Build Packs, we have to set the `extends` configuration in the Build Pack's `pipeline.yaml`. 
This file would reside in `packs/<name-of-your-pack>/pipeline.yaml`.

In this case, we want to extend the `kubernetes` Build Pack repository's `maven-java11` syntax.
We do this by filling `import` field with the name field from the repository listed in the `packs/imports.yaml` file.

We then select a Build Pack's pipeline file by pointing to a `pipeline.yaml` file from the relative path of `packs/`.

Lets say we want to use a different docker container as build agent, we would end up with this.

!!! example "packs/maven-joost/pipeline.yaml"

    ```yaml
    extends:
        import: kubernetes
        file: maven-java11/pipeline.yaml
    agent:
        label: jenkins-maven-java11
        image: maven-java11
        container: maven
    ```

#### Extending The Pipeline Further

If you want to further extend the pipeline, you can leverage the Jenkins X Pipeline syntax.

For example, say you want to make sure your Pull Request builds run a SonarQube scan.
You can add the step `sonar-scan-pr` to the `pullRequest` Pipeline, under the stage `build` as below.

!!! example "packs/maven-joost/pipeline.yaml"

    ```yaml
    pipelines:
        pullRequest:
            build:
                steps:
                - name: sonar-scan-pr
                    command: sonar-scanner
                    image: newtmitch/sonar-scanner:3.0
                    dir: /workspace/source/
                    args:
                    - -Dsonar.projectName=...
                    - -Dsonar.projectKey=...
                    - -Dsonar.organization=...
                    - -Dsonar.sources=./src/main/java/
                    - -Dsonar.language=java
                    - -Dsonar.java.binaries=./target/classes
                    - -Dsonar.host.url=https://sonarcloud.io
                    - -Dsonar.login=${SONARCLOUD_TOKEN}
    ```

Go to the [Jenkins X Pipelines](/jenkinsx/jx-pipelines/) page for further details.

### Use New Build Pack

Once you have defined the pipeline in your Build Pack, you then specify the Build Pack you want to use in your application in the `jenkins-x.yaml` file.

!!! important
    This section refers to your application's, not the Build Back's repository.

You need to specify three parameters in order for Jenkins X to pick up your Build Pack and build up the [effective pipeline](https://jenkins-x.io/commands/jx_step_syntax_effective/) from your Build Pack hierarchy.

* **buildPack**: the name of your Build Pack, e.g. the folder name in your Build Pack repository's `packs` folder that contains the `pipeline.yaml`
* **buildPackGitRef**: the Git ref, e.g. tag, commit or branch name
* **buildPackGitURL**: the http(s) git URL

!!! example "jenkins-x.yaml"

    ```
    buildPack: maven-joost
    buildPackGitRef: master
    buildPackGitURL: https://github.com/joostvdg/jx-buildpacks.git
    ```