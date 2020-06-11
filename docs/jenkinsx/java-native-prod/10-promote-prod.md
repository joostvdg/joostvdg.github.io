title: Jenkins X - Java Native Image Prod
description: Creating a Java Native Image application and run it as Production with Jenkins X - Promote To Production - 3/10
hero: Promote To Production - 10/10

# Promote To Production

## Code Snapshots

There's a branch for the status of the code after:

* adding Sentry for logging, in the [branch 09-sentry](https://github.com/joostvdg/quarkus-fruits/tree/09-sentry).
* adding Monitoring with Prometheus, in the branch [09-monitoring](https://github.com/joostvdg/quarkus-fruits/tree/09-monitoring)
* adding Jaeger with OpenTracing, in the branch [09-tracing](https://github.com/joostvdg/quarkus-fruits/tree/09-tracing)

## Configure Production Environment Repository

For each Jenkins X environment that your application is going to land in, such as `jx-staging` and `jx-production`, we have to enable Vault support.

We do this by making a change in the Environment's `jx-requirements.yml` file in the root of the repository of the environment. This file might not exist, if so, create it.

If you're not sure where the repository of your environment is, you can retrieve this information via the `jx` CLI.

```sh
jx get environments
```

To enable support for Vault, we add `secretStorage: vault` to the file. The file will look like this:

!!! example "jx-requirements.yml"

    ```yaml
    secretStorage: vault
    ```

### Add Application Values

Same as we did in the chapter `Database Connection Ad Secrets`, we add the application's values in the `env/values.yaml` file of the environment.

!!! example "env/values.yaml"

    ```yaml
    quarkus-fruits:
      secrets:
        sql_connection: vault:quarkus-fruits:INSTANCE_CONNECTION_NAME
        sql_sa: vault:quarkus-fruits:SA
        sql_password: vault:quarkus-fruits:GOOGLE_SQL_PASS
    ```

## Promote Application

First, retrieve the current version of your application.

```sh
jx get application
```

It should yield something like this:

```sh
APPLICATION    STAGING PODS URL
quarkus-fruits 1.0.51  1/1  https://quarkus-fruits-jx-staging.staging.example.com
```

We can now promote the latest working version in staging, `1.0.49` in my casse, to Production!

```sh
VERSION=1.0.51
```

```sh
jx promote --app quarkus-fruits --version ${VERSION} --env production -b
```


## Completed

Well, it is never finished now is it?

But this is as much as I want to write down, for now.
