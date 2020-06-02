title: Jenkins X - Java Native Image Prod
description: Creating a Java Native Image application and run it as Production with Jenkins X - Previews & Integration Tests - 8/10
hero: Previews & Integration Tests - 8/10

# Previews & Integration Tests

As mentioned in [Pipeline Improvements](/jenkinsx/java-native-prod/07-pipeline-improvements/) (previous page), here we will dive into - amongst other things - running integration tests with PostMan.

The first part of the title is ***Previews***. The name comes from the Jenkins X feature called _Preview Environments_. We will explore how we can leverage Preview Environments for running Integration Tests.

> Jenkins X allows users to test and validate changes to code in a specialized fourth tier called a **preview environment**, which is a temporary tier where quick testing, feedback and limited availability demos for a wider user base can be done before changes are merged to master for production deployment. This gives developers the ability to receive faster feedback for their changes. - [CloudBees Jenkins X Distribution Guide](https://docs.cloudbees.com/docs/cloudbees-jenkins-x-distribution/latest/developer-guide/preview-environments)

The plan for this part of the guide, is to run a PostMan test suite everytime we create or update a PullRequest (PR) on its related Preview Environment.

## PostMan Test Suit

[Postman](https://learning.postman.com/docs/postman/launching-postman/introduction/) is a good and commonly used [rest] API testing tool.
It has a CLI alternative, which also ships as a [Docker image](https://hub.docker.com/r/postman/newman), called [Newman](https://github.com/postmanlabs/newman).

We can use this to test our running Preview application.

First, we create a [collection](https://learning.postman.com/docs/postman/collections/intro-to-collections/) of [tests](https://learning.postman.com/docs/postman/scripts/test-scripts/) with Postman, which we can then [export](https://learning.postman.com/docs/postman/collections/importing-and-exporting-data/#exporting-postman-data) as a json file.

### PostMan Test Suite JSON

??? example "postman-suite-01.json"

    We specify to variables in this script, `baseUrl`, which we set in the Jenkins X Pipeline Step, and `MANDARIN_ID`.
    `MANDARIN_ID` is set in one of the tests, when we add a new entry to the database.

    This way, we can ensure we also cleanup the database, so that an update to the PR has the original data set to work with.

    ```json
    {
      "variables": [],
      "info": {
        "name": "postman-suite-01",
        "_postman_id": "2c62b599-f952-d49c-3b36-5fb1b7a77472",
        "description": "",
        "schema": "https://schema.getpostman.com/json/collection/v2.0.0/collection.json"
      },
      "item": [
        {
          "name": "find-all-fruits",
          "event": [
            {
              "listen": "test",
              "script": {
                "type": "text/javascript",
                "exec": [
                  "tests[\"Successful GET request\"] = responseCode.code === 200;",
                  "",
                  "tests[\"Response time is less than 400ms\"] = responseTime < 400;",
                  "",
                  "var jsonData = JSON.parse(responseBody);",
                  "tests[\"JSON Data Test-1\"] = jsonData[0].name === \"Cherry\";",
                  "tests[\"JSON Data Test-2\"] = jsonData[1].name === \"Apple\";",
                  "tests[\"JSON Data Test-3\"] = jsonData[2].name === \"Banana\";",
                  "tests[\"JSON Data Test-4\"] = jsonData[3].color === \"Green\";",
                  "tests[\"JSON Data Test-5\"] = jsonData[4].color === \"Red\";",
                  ""
                ]
              }
            }
          ],
          "request": {
            "url": "{{baseUrl}}/fruits",
            "method": "GET",
            "header": [],
            "body": {},
            "description": "Test fina all fruits"
          },
          "response": []
        },
        {
          "name": "post-new-fruit",
          "event": [
            {
              "listen": "test",
              "script": {
                "type": "text/javascript",
                "exec": [
                  "tests[\"Successful GET request\"] = responseCode.code === 200;",
                  "",
                  "tests[\"Response time is less than 400ms\"] = responseTime < 400;",
                  "var jsonData = JSON.parse(responseBody);",
                  "postman.setGlobalVariable(\"MANDARIN_ID\", jsonData.id);"
                ]
              }
            }
          ],
          "request": {
            "url": "{{baseUrl}}/fruits/name/Mandarin/color/Orange",
            "method": "POST",
            "header": [],
            "body": {},
            "description": ""
          },
          "response": []
        },
        {
          "name": "post-new-fruit-again",
          "event": [
            {
              "listen": "test",
              "script": {
                "type": "text/javascript",
                "exec": [
                  "tests[\"Successful GET request\"] = responseCode.code === 500;",
                  "",
                  "tests[\"Response time is less than 400ms\"] = responseTime < 400;",
                  "",
                  ""
                ]
              }
            }
          ],
          "request": {
            "url": "{{baseUrl}}/fruits/name/Mandarin/color/Orange",
            "method": "POST",
            "header": [],
            "body": {},
            "description": ""
          },
          "response": []
        },
        {
          "name": "{{baseUrl}}/fruits/{{MANDARIN_ID}}",
          "event": [
            {
              "listen": "test",
              "script": {
                "type": "text/javascript",
                "exec": [
                  "tests[\"Successful GET request\"] = responseCode.code === 204;",
                  "",
                  "tests[\"Response time is less than 400ms\"] = responseTime < 400;"
                ]
              }
            }
          ],
          "request": {
            "url": "{{baseUrl}}/fruits/{{MANDARIN_ID}}",
            "method": "DELETE",
            "header": [],
            "body": {},
            "description": ""
          },
          "response": []
        }
      ]
    }
    ```  

## Preview Environments

> When a preview environment is up and running Jenkins X will submit a comment to a Pull Request with a link to a temporary build of the project so that development members or invited end users can demo the preview. 
> Using preview environments any pull request can have a preview version built and deployed, including libraries that feed into a downstream deployable application. This means development team members can perform code reviews, run unit or cross-functional behavior-driven development (BDD) tests, and grow consensus as to when a new feature can be deployed to production.
- [CloudBees Jenkins X Distribution Guide](https://docs.cloudbees.com/docs/cloudbees-jenkins-x-distribution/latest/developer-guide/preview-environments)

For more information on Preview Environments, you can read the Jenkins X [Guide on Preview Environments](https://jenkins-x.io/docs/build-test-preview/preview/), or the [Guide on the Promotion mechanism](https://jenkins-x.io/docs/build-test-preview/promotion/) within Jenkins X.

* create preview environment
* update preview pipeline
* add mysql database as preview dependency - so we test in a throwaway database
* update application.properties file
* tweak Helm Chart configuration

### Create Preview Environment

I included this paragraph for completeness. The only thing you have to do to create a Preview Environment, is to let Jenkins X create one for you. You do this by creating a ***Pull Request***, on an application that is managed by Jenkins X. 

If you're not sure how to create a Pull Request, [GitHub has a nice guide on this](https://help.github.com/en/github/collaborating-with-issues-and-pull-requests/creating-a-pull-request).

### Update Preview Pipeline

We can then call this JSON file an a new Jenkins X Pipeline step.
We want to run that step against a running application, so we run it _after_ preview-promote step, which will finish with confirming the preview is live.

Which will something like this:

!!! example "jenkins-x.yml"

    ```yaml hl_lines="13"
    - name: jx-preview
      stage: promote
      pipeline: pullRequest
      step:
        name: postman-tests
        dir: /workspace/source
        image: postman/newman
        command: newman
        args:
          - run
          - postman-suite-01.json
          - --global-var
          - "baseUrl=http://quarkus-fruits.jx-joostvdg-quarkus-fruits-pr-${PULL_NUMBER}.example.com"
          - --verbose
      type: after
    ```

!!! important
    Make sure you replace the URL with the actual URL of your application.

    The baseURL highlighted in the above example, `http://quarkus-fruits.jx-joostvdg-quarkus-fruits-pr-${PULL_NUMBER}.example.com`, depends on your domain, application name and repository owner.

    Adjust the configuration accordingly!

As each PR will have a unique URL based on the PR number, we set the global variable - from Newman perspective - `baseUrl` to `$PULL_NUMBER`.
Which is a [Pipeline environment variable](https://jenkins-x.io/docs/guides/using-jx/pipelines/envvars/) provided by the Jenkins X Pipeline.

### MySQL Database as Preview Dependency

You might have wondered until now, why there are two Helm Charts in the `charts/` folder.
One of the Charts, which we haven't used until now, is called `preview`. 

Guess what, it is used to generate the preview environment installation. 
It has a `requirements.yaml` file with its dependencies. As you can see, it always includes your main application via the `file://../` directive. This _must_ be the last entry.

We use a different database for our tests, and it should be a throw-away database.
The easiest way to do so, is to add `mysql` as a dependency to our Preview Chart.

This way, every preview environment has its own database, so our tests do not pollute other PR's or our permanent databases.

!!! example "charts/preview/requirements.yaml"

    ```yaml hl_lines="1 2 3"
    - name: mysql
      version: 1.6.3
      repository:  https://kubernetes-charts.storage.googleapis.com

      # !! "alias: preview" must be last entry in dependencies array !!
      # !! Place custom dependencies above !!
    - alias: preview
      name: quarkus-fruits
      repository: file://../quarkus-fruits
    ```

### Update Properties

We make sure `quarkus.datasource.jdbc.url` is now a variable, so we can set a different value in the Preview Environment.

!!! example "src/main/resources/application.properties"

    The highlighted lines are the changes. 

    ```properties hl_lines="8"
    quarkus.datasource.db-kind=mysql
    quarkus.datasource.jdbc.url=jdbc:mysql://127.0.0.1:3306/fruits
    quarkus.datasource.jdbc.max-size=8
    quarkus.datasource.jdbc.min-size=2

    quarkus.datasource.username=${GOOGLE_SQL_USER}
    quarkus.datasource.password=${GOOGLE_SQL_PASS}
    quarkus.datasource.jdbc.url=${GOOGLE_SQL_CONN}

    quarkus.flyway.migrate-at-start=true
    quarkus.flyway.baseline-on-migrate=true

    quarkus.hibernate-orm.database.generation=none
    quarkus.log.level=INFO
    quarkus.log.category."org.hibernate".level=INFO
    ```


### Update Helm Chart

We have to make a few related changes.

1. **Deployment**: so we only include the CloudSQL proxy container if we will talk to a CloudSQL Database
1. **Chart Values**: to set defaults for the CloudSQL proxy container configuration
1. **Preview Chart Values**: to configure the MySQL dependency

#### Deployment

!!! example "templates/deployment.yaml"
    

    ```yaml hl_lines="1 11"
    {{ if eq .Values.cloudsql.enabled "true" }}
    - name: cloudsql-proxy
      image: gcr.io/cloudsql-docker/gce-proxy:1.16
      command: ["/cloud_sql_proxy",
                "-instances={{.Values.secrets.sql_connection}}=tcp:3306",
                "-credential_file=/secrets/cloudsql/credentials.json"]
      volumeMounts:
        - name: cloudsql-instance-credentials
          mountPath: /secrets/cloudsql
          readOnly: true
    {{ end }}
    ```

#### Chart Values

In `charts/Name-of-Your-Application/values.yaml` we set default values for the CloudSQL configuration.
Namely the `GOOGLE_SQL_CONN` to connect to the CloudSQL proxy container, and `cloudsql.enabled=true` to ensure we run the CloudSQL proxy container.

!!! example "values.yaml"

    ```yaml
    cloudsql:
      enabled: "true"

    # define environment variables here as a map of key: value
    env:
      GOOGLE_SQL_USER: vault:quarkus-petclinic:GOOGLE_SQL_USER
      GOOGLE_SQL_CONN: jdbc:mysql://127.0.0.1:3306/fruits
    ```

#### Preview Chart Values

We add some basic configuration for our MySQL dependency.
Such as the passwords, storage, and database name.

Via the `preview` property, we configures our application's Helm Chart.
We ensure our Helm Chart is configured so our application will connect to the Preview Environment's MySQL database, and not to run a CloudSQL proxy container.

!!! example "charts/preview/values.yaml"

    ```yaml
    mysql:
      mysqlUser: fruitsadmin
      mysqlPassword: JFjec3c7MgFH6cZyKaVNaC2F
      mysqlRootPassword: 4dDDPE5nj3dVPxDYsPgCzu9B
      mysqlDatabase: fruits
      persistence:
        enabled: true
        size: 50Gi

    preview:
      cloudsql:
        enabled: "false"
      secrets:
        sql_password: "4dDDPE5nj3dVPxDYsPgCzu9B"
      env:
        GOOGLE_SQL_USER: root
        GOOGLE_SQL_CONN: jdbc:mysql://mysql:3306/fruits
    ```

### Ensure Sorted List Is Returned

The test I've written with PostMan is a bit silly. 
It evaluates each element of the returned list, expecting a fixed order.

As our code returns a List, we can sort it via a comparator.
With Java's Lambda support, this becomes a quite readable single line.

!!! example "FruitResource.java"

    ```java hl_lines="5"
    public List<Fruit> findAll() {
        var it = fruitRepository.findAll();
        List<Fruit> fruits = new ArrayList<Fruit>();
        it.forEach(fruits::add);
        fruits.sort(Comparator.comparing(Fruit::getId));
        return fruits;
    }
    ```

## Next Steps

Now that we have more tests and validations in our application, we focus our attention on how the application is running. Things like logging, metrics, and tracing.