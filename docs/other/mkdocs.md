# MKDocs

This website is build using the following:

* [MKDocs](http://www.mkdocs.org/) a python tool for building static websites from [MarkDown](https://en.wikipedia.org/wiki/Markdown) files
* [MK Material](https://squidfunk.github.io/mkdocs-material/) expansion/theme of MK Docs that makes it a responsive website with Google's Material theme

## Add information to the docs

MKDocs can be a bit daunting to use, especially when extended with ```MKDocs Material``` and [PyMdown Extensions](https://facelessuser.github.io/pymdown-extensions/).

There are two parts to the site: 1) the markdown files, they're in ```docs/``` and 2) the site listing (mkdocs.yml) and automation scripts, these can be found in ```docs-scripts/```.

### Extends current page

To extend a current page, simply write the MarkDown as you're used to.

For the specific extensions offered by PyMX and Material, checkout the following pages:

* [MKDocs Material Getting Started Guide](https://squidfunk.github.io/mkdocs-material/getting-started/)
* [MKDocs Extensions](https://squidfunk.github.io/mkdocs-material/extensions/admonition/)
* [PyMdown Extensions Usage Guide](https://squidfunk.github.io/mkdocs-material/extensions/pymdown/)

### Add a new page

In the ```docs-scripts/mkdocs.yml``` you will find the site structure under the yml item of ```pages```.

```yml
pages:
- Home: index.md
- Other Root Page: some-page.md
- Root with children:
  - ChildOne: root2/child1.md
  - ChildTwo: root2/child2.md
```

### Things to know

* All .md files that are listed in the ```pages``` will be translated to an HTML file and dubbed {OriginalFileName}.html
* Naming a file index.md will allow you to refer to it by path without the file name
    * we can refer to root2 simply by ```site/root2``` and can omit the index.
    ```yml
    - Root: index.md
    - Root2: root2/index.html
    ```

## Build the site locally

As it is a Python tool, you can easily build it with Python (2.7 is recommended).

The requirements are captured in a [pip](https://pip.pypa.io/en/stable/) install scripts: ```docs-scripts/install.sh``` where the dependencies are in [Pip's requirements.txt](https://pip.pypa.io/en/stable/user_guide/#requirements-files).

Once that is done, you can do the following:

```bash
mkdocs build --clean
```

Which will generate the site into ```docs-scripts/site``` where you can simply open the index.html with a browser - it is a static site.

For docker, you can use the ```*.sh``` scripts, or simply ```run.sh``` to kick of the entire build.

## Jenkins build

### Declarative format

```json
pipeline {
    agent none
    options {
        timeout(time: 10, unit: 'MINUTES')
        timestamps()
        buildDiscarder(logRotator(numToKeepStr: '5'))
    }
    stages {
        stage('Prepare'){
            agent { label 'docker' }
            steps {
                deleteDir()
            }
        }
        stage('Checkout'){
            agent { label 'docker' }
            steps {
                checkout scm
                script {
                    env.GIT_COMMIT_HASH = sh returnStdout: true, script: 'git rev-parse --verify HEAD'
                }
            }
        }
        stage('Build Docs') {
            agent {
                docker {
                    image "caladreas/mkdocs-docker-build-container"
                    label "docker"
                }
            }
            steps {
                sh 'cd docs-scripts && mkdocs build'
            }
        }
        stage('Prepare Docker Image'){
            agent { label 'docker' }
            environment {
                DOCKER_CRED = credentials('ldap')
            }
            steps {
                parallel (
                        TestDockerfile: {
                            script {
                                def lintResult = sh returnStdout: true, script: 'cd docs-scripts && docker run --rm -i lukasmartinelli/hadolint < Dockerfile'
                                if (lintResult.trim() == '') {
                                    println 'Lint finished with no errors'
                                } else {
                                    println 'Error found in Lint'
                                    println "${lintResult}"
                                    currentBuild.result = 'UNSTABLE'
                                }
                            }
                        }, // end test dockerfile
                        BuildImage: {
                            sh 'chmod +x docs-scripts/build.sh'
                            sh 'cd docs-scripts && ./build.sh'
                        },
                        login: {
                            sh "docker login -u ${DOCKER_CRED_USR} -p ${DOCKER_CRED_PSW} registry"
                        }
                )
            }
            post {
                success {
                    sh 'chmod +x push.sh'
                    sh './push.sh'
                }
            }
        }
    }
}
```