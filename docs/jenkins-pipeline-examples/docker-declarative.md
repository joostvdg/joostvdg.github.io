# Docker Declarative Examples

```groovy
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
                parallel (
                    Clean: {
                        deleteDir()
                    },
                    NotifySlack: {
                        slackSend channel: 'cicd', color: '#FFFF00', message: "STARTED: Job '${env.JOB_NAME} [${env.BUILD_NUMBER}]' (${env.BUILD_URL})"
                    }
                )
            }
        }
        stage('Checkout'){
            agent { label 'docker' }
            steps {
                git credentialsId: '355df378-e726-4abd-90fa-e723c5c21ad5', url: 'git@gitlab.flusso.nl:CICD/ci-cd-docs.git'
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
                sh 'mkdocs build'
            }
        }
        stage('Prepare Docker Image'){
            agent { label 'docker' }
            steps {
                parallel (
                    TestDockerfile: {
                        script {
                            def lintResult = sh returnStdout: true, script: 'docker run --rm -i lukasmartinelli/hadolint < Dockerfile'
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
                        sh 'chmod +x build.sh'
                        sh './build.sh'
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
        stage('Update Docker Container') {
            agent { label 'docker' }
            steps {
                sh 'chmod +x container-update.sh'
                sh "./container-update.sh ${env.BUILD_URL} ${env.GIT_COMMIT_HASH}"
            }
        }
    }
    post {
        success {
            slackSend channel: 'cicd', color: '#00FF00', message: "SUCCESSFUL: Job '${env.JOB_NAME} [${env.BUILD_NUMBER}]' (${env.BUILD_URL})"
        }
        failure {
            slackSend channel: 'cicd', color: '#FF0000', message: "FAILED: Job '${env.JOB_NAME} [${env.BUILD_NUMBER}]' (${env.BUILD_URL})"
        }
    }
}
```