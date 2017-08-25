# Maven Groovy DSL Example


```groovy
node {
    timestamps {
        timeout(time: 15, unit: 'MINUTES') {
            deleteDir()
            stage 'SCM'
            //git branch: 'master', credentialsId: 'flusso-gitlab', url: 'https://gitlab.flusso.nl/keep/keep-backend-spring.git'
            checkout scm

            env.JAVA_HOME="${tool 'JDK 8 Latest'}"
            env.PATH="${env.JAVA_HOME}/bin:${env.PATH}"
            sh 'java -version'

            try {
                def gradleHome = tool name: 'Gradle Latest', type: 'hudson.plugins.gradle.GradleInstallation'
                stage 'Build'

                sh "${gradleHome}/bin/gradle clean build javadoc"
                step([$class: 'CheckStylePublisher', canComputeNew: false, defaultEncoding: '', healthy: '', pattern: 'build/reports/checkstyle/main.xml', unHealthy: ''])
                step([$class: 'JUnitResultArchiver', testResults: 'build/test-results/*.xml'])
                step([$class: 'JavadocArchiver', javadocDir: 'build/docs/javadoc'])

                stage 'SonarQube'
                sh "${gradleHome}/bin/gradle sonarqube -Dsonar.host.url=http://sonarqube5-instance:9000"

                stash 'workspace'
            }  catch (err) {
                archive 'build/**/*.html'
                echo "Caught: ${err}"
                currentBuild.result = 'FAILURE'
            }
        }
    }
}

node ('docker') {
    timestamps {
        timeout(time: 15, unit: 'MINUTES') {
            deleteDir()
            unstash 'workspace'

            stage 'Build Docker image'
            sh './build.sh'
            def image = docker.image('keep-backend-spring-img')

            stage 'Push Docker image'
            try {
                sh 'docker tag keep-backend-spring-img nexus.docker:18443/flusso/keep-backend-spring-img:latest'
                sh 'docker push nexus.docker:18443/flusso/keep-backend-spring-img:latest'
            }  catch (err) {
                archive 'build/**/*.html'
                echo "Caught: ${err}"
                currentBuild.result = 'FAILURE'
            }

        }
    }
}


```
