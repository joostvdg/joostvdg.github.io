title: Jenkins X - Java Native Image Prod
description: Creating a Java Native Image application and run it as Production with Jenkins X -Database Connection And Secrets - 5/9
hero:Database Connection And Secrets - 5/9

# Database Connection And Secrets

In most cases, connecting to a database from your application requires three pieces of information.

1. Database URL
1. Username
1. Password

Now, you can argue if the fourth would be the schema, or if that is included in #1. 

Eitherway, our application is currently missing this information.
If you remember, we've set our URL to `jdbc:mysql://127.0.0.1:3306/fruit`, and our username and password to `${GOOGLE_SQL_USER}` and `${GOOGLE_SQL_PASS}` respectively.

It is now time to configure this information.

## CloudSQL Proxy Container

But first, we have to do one more configuration for our CloudSQL Database.
If you do _not_ use the CloudSQL database, you can skip this step, but make sure to replace the JDBC URL appropriately.

Google takes its security serious, and thus doesn't allow you to access its CloudSQL databases from _everywhere_. Our Kubernetes cluster cannot directly access CloudSQL, but it can use a Proxy, provided we connect with a **Google Cloud Service Account** - not to be confused with a Kubernetes Service Account.

We deal with the secrets later, we first have to add this Proxy container configuration.
To add the container, we update the `deployment.yaml` in our `charts/Name-Of-Your-Application/templates` folder. Containers is a list, so we add the `cloudsql-proxy` container as an additional list item.

```yaml
- name: cloudsql-proxy
  image: gcr.io/cloudsql-docker/gce-proxy:1.16
  command: ["/cloud_sql_proxy",
            "-instances={{.Values.secrets.sql_connection}}=tcp:3306",
            "-credential_file=/secrets/cloudsql/credentials.json"]
```

If you look carefully, you can see we already reference a secret: `{{.Values.secrets.sql_connection}}`.
We come back to this later. For further clarification on how the containers section of our `deployment.yaml` should look like, expand the example below.

??? example "charts/Your-Application-Name/templates/deployment.yaml snippet"

    ```yaml hl_lines="3 4 5 6 7"
    spec:
      containers:
      - name: cloudsql-proxy
        image: gcr.io/cloudsql-docker/gce-proxy:1.16
        command: ["/cloud_sql_proxy",
                  "-instances={{.Values.secrets.sql_connection}}=tcp:3306",
                  "-credential_file=/secrets/cloudsql/credentials.json"]
      - name: {{ .Chart.Name }}
        envFrom:
          - secretRef:
              name: {{ template "fullname" . }}-sql-secret
          - secretRef:
              name: {{ template "fullname" . }}-sentry-dsn
        image: "{{ .Values.image.repository }}:{{ .Values.image.tag }}"
        imagePullPolicy: {{ .Values.image.pullPolicy }}
    ```

## Jenkins X and Secrets

If you have followed the pre-requisites, you have a Jenkins X installation with Hashicorp Vault. Where Jenkins X is configured to manage its secrets in Vault.

This allows Jenkins X to retrieve secrets from Vault for you, and inject them where you need them.
We will explore the different ways you can do so, in order to give our application enough information to connect to the MySQL database.

Jenkins X can deal with secrets in several ways, and we will use most of them going forward.

1. configure a Kubernetes secret in the Chart templates, not really Jenkins X, but remember you have this option as well
1. inject a secret as environment variable into the container from Vault, this is a _global secret_, in the sense that the Vault URI is always the same, for every environment
1. inject a secret via a `values.yaml` variable, you can - and should - change this depending on the environment, this is a _environment secret_ as our Jenkins X environment will do the replacement from Vault URI to value
1. use a container in our pipeline that has bot the Jenkins X binary (`jx`) and the Vault CLI, through which we can then interact with Vault's API

!!! caution
    When injecting variables directly as environment variable, they will show up in Kubernetes manifests.

    This might leak the secrets further than you intent. You can use this a shortcut to centralized configuration management - forgoing something such as Consul or Spring Cloud Config Server.

When using the option to read the secret into a `values.yaml` variable, you can use this variable in a template. This means you can create a Kubernetes Secret manifest in your templates folder, and have Jenkins X populate its value from Vault.

## Create Secrets

Lets configure the secrets in our application. we start by setting up variables and placeholders in the `values.yaml` of our Chart. After which we configure the secret in our Helm templates and enter them in Vault.

!!! important
    To access Vault, you can use the [Vault CLI](https://www.vaultproject.io/docs/commands), see how to [install here](https://www.vaultproject.io/docs/install), or via its UI.

    Either way, to get the Vault configuration of your Jenkins X cluster, use the [get vault-config](https://jenkins-x.io/commands/jx_get_vault-config/) command:

    ```sh
    jx get vault-config
    ```

    It prints out the URL and the connection token.

    Every secret we create, is assumed to be in the `/secrets` KV vault. Jenkins X makes the same assumption, and omits this in the Vault secret URI.

### Configure Values.yaml

Depending on the secret, we either want it to be the same everywhere or unique per environment. 
That partly depends on your, do you have a different database for every environment that isn't Production? 

In my case, the user of my database is always the same, so I enject it as a environment variable.
We do this, by adding `key: value` pairs to the `env:` property.

The other information pieces are both more sensitive and environment specific.
So we create a new property called `secrets`, and fill in empty (placeholder) values:

* **sql_password**: the password for our database
* **sql_connection**: the connection information the CloudSQL Proxy container will use
* **sqlsa**: the Google Cloud Service Account (JSON) key for validating the database connection request

!!! example "values.yaml"

    ```yaml
    # Secrets that get loaded via the (jx) environment from Vault
    secrets:
      sql_password: ""
      sql_connection: ""
      sqlsa: ""
      
    # define environment variables here as a map of key: value
    env:
      GOOGLE_SQL_USER: vault:quarkus-fruits:GOOGLE_SQL_USER
    ```

### Configure Jenkins X Environments

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

### Google CloudSQL Connection URL

Access Vault and create a new Secret under `secrets/Name-Of-Your-Application`. In these examples, we use `quarkus-fruits` as our application name.

Each secret in Vault is a set of Key/Value pairs.

For the CloudSQL Connection URL, we use `INSTANCE_CONNECTION_NAME`, as this is how CloudSQL names this information.

#### Update Staging Environment

Once you create the secret and the `INSTANCE_CONNECTION_NAME` key with its secret value - which should be the instance connection name from your CloudSQL database - we can add this information to our Jenkins X environment(s), such as Staging. Again, here we assume the application's name is `quarkus-fruits`.

!!! example "env/values.yaml"

    ```yaml
    quarkus-fruits:
      secrets:
        sql_connection: vault:quarkus-fruits:INSTANCE_CONNECTION_NAME
    ```

For this secret, this is all we need to do. As our CloudSQL Proxy Container directly uses this value in the `deployment.yaml`.

### Google CloudSQL Service Account Key

If everything is allright, you have created this service account earlier. If not, please revisit [How To Connect To The Database paragraph from the CloudSQL page](/jenkinsx/java-native-prod/02-cloud-sql/#how-to-connect-to-the-database).

Due to the secret being a JSON file, it is best to Base64 encode the contents before adding it as a secret value in Vault.

In Linux of MacOS, this should be sufficient:

```sh
cat credentials.json | base64
```

As key, we use `SA`.

#### Update Staging Environment

!!! example "env/values.yaml"

  ```yaml
  quarkus-fruits:
    secrets:
      sql_connection: vault:quarkus-fruits:INSTANCE_CONNECTION_NAME
      sql_sa: vault:quarkus-fruits:SA
  ```

#### Create Secret Manifest

This is very sensitive information, so we follow the best practice of moutning the secret.
To do so, we have to create it as a secret in Kubernetes. 
We create a new Kubernetes Secert manifest in the `charts/Your-Application-Name/templates` folder with the name `sql-sa-secret.yaml` so that Jenkins X will create this for us.

!!! example "templates/sql-sa-secret.yaml" 

    ```yaml
    apiVersion: v1
    kind: Secret
    metadata:
      name: {{ template "fullname" . }}-sql-sa
    type: Opaque
    data:
      credentials.json: {{ .Values.secrets.sql_sa }}
    ```

#### Update Deployment


!!! example "templates/deployment.yaml"

    We have to make two changes. We have to create a *volume* and a *volumeMount* to ensure the `cloudsql-proxy` has access to the Service Account Key.

    ```yaml hl_lines="6 7 8 9"
    - name: cloudsql-proxy
      image: gcr.io/cloudsql-docker/gce-proxy:1.16
      command: ["/cloud_sql_proxy",
                "-instances={{.Values.secrets.sql_connection}}=tcp:3306",
                "-credential_file=/secrets/cloudsql/credentials.json"]
      volumeMounts:
        - name: cloudsql-instance-credentials
          mountPath: /secrets/cloudsql
          readOnly: true
    ```

    ```yaml
    volumes:
      - name: cloudsql-instance-credentials
        secret:
          secretName: {{ template "fullname" . }}-sql-sa
    ```

### Google CloudSQL Password

Add the CloudSQL password to your secret in Vault (in my case, `secrets/quarkus-fruits`) and use the Key `GOOGLE_SQL_PASS`.

#### Update Staging Environment

!!! example "env/values.yaml"

  ```yaml
  quarkus-fruits:
    secrets:
      sql_connection: vault:quarkus-fruits:INSTANCE_CONNECTION_NAME
      sql_sa: vault:quarkus-fruits:SA
      sql_password: vault:quarkus-fruits:GOOGLE_SQL_PASS
  ```

#### Create Secret Manifest

We again make a Kubernetes Secret Manifest, this time by the name of `sql-secret.yaml`.
Please not, that as we did not Base64 encode our password, we have to do this in our manifest.
But no worries, Helm templating can do this for us, via ` | b64enc`.

!!! example "templates/sql-secret.yaml" 

    ```yaml
    apiVersion: v1
    kind: Secret
    metadata:
      name: {{ template "fullname" . }}-sql-secret
    data:
      GOOGLE_SQL_PASS: {{ .Values.secrets.sql_password | b64enc }}
    ```

#### Update Deployment

Instead of mounting the secret, we inject it as a environment variable.
Unlike the the username, which was added as a environment variable directly, we let Kubernetes take care of the injection via `envFrom`. This ensures the secret does not show up in the manifest (when you do a `kubectl get pod -o yaml` for example), and saves us the hassle of reading the property from a file.

!!! example "templates/deployment.yaml"

    ```yaml hl_lines="2 3 4"
    - name: {{ .Chart.Name }}
      envFrom:
        - secretRef:
            name: {{ template "fullname" . }}-sql-secret
      image: "{{ .Values.image.repository }}:{{ .Values.image.tag }}"
      imagePullPolicy: {{ .Values.image.pullPolicy }}
    ```

### Google CloudSQL Username

Add the CloudSQL username to your secret in Vault (in my case, `secrets/quarkus-fruits`) and use the Key `GOOGLE_SQL_USER`.

For the username, this is all we have to do, as we directly inject this variable as an environment variable.

??? example "values.yaml"

    ```yaml
    env:
      GOOGLE_SQL_USER: vault:quarkus-fruits:GOOGLE_SQL_USER
    ```

### Summary of Changes Made To Application

* created two new templates in the folder `charts/Name-Of-Your-Application/templates`
    * `sql-secret.yaml`
    * `sql-sa-secret.yaml`
* updated the `charts/Name-Of-Your-Application/templates/deployment.yaml`
    * add second container, for the CloudSQL Proxy
    * add volume and volumeMount to CloudSQL Proxy container
    * add environment injection from secret for password
* updated `charts/Name-Of-Your-Application/values.yaml` with placeholders for the secrets

??? example "templates/deployment.yaml"

    Your deployment should now look like this:

    ```yaml
    {{- if .Values.knativeDeploy }}
    {{- else }}
    apiVersion: apps/v1
    kind: Deployment
    metadata:
      name: {{ template "fullname" . }}
      labels:
        draft: {{ default "draft-app" .Values.draft }}
        chart: "{{ .Chart.Name }}-{{ .Chart.Version | replace "+" "_" }}"
    spec:
      selector:
        matchLabels:
          app: {{ template "fullname" . }}
    {{- if .Values.hpa.enabled }}
    {{- else }}
      replicas: {{ .Values.replicaCount }}
      {{- end }}
      template:
        metadata:
          labels:
            draft: {{ default "draft-app" .Values.draft }}
            app: {{ template "fullname" . }}
          annotations:
            prometheus.io/port: "8080"
            prometheus.io/scrape: "true"
    {{- if .Values.podAnnotations }}
    {{ toYaml .Values.podAnnotations | indent 8 }} #Only for pods
    {{- end }}
        spec:
          containers:
          - name: cloudsql-proxy
            image: gcr.io/cloudsql-docker/gce-proxy:1.16
            command: ["/cloud_sql_proxy",
                      "-instances={{.Values.secrets.sql_connection}}=tcp:3306",
                      "-credential_file=/secrets/cloudsql/credentials.json"]
            volumeMounts:
              - name: cloudsql-instance-credentials
                mountPath: /secrets/cloudsql
                readOnly: true
          - name: {{ .Chart.Name }}
            envFrom:
              - secretRef:
                  name: {{ template "fullname" . }}-sql-secret
            image: "{{ .Values.image.repository }}:{{ .Values.image.tag }}"
            imagePullPolicy: {{ .Values.image.pullPolicy }}
            env:
    {{- range $pkey, $pval := .Values.env }}
            - name: {{ $pkey }}
              value: {{ $pval }}
    {{- end }}
            ports:
            - containerPort: {{ .Values.service.internalPort }}
            livenessProbe:
              httpGet:
                path: {{ .Values.probePath }}
                port: {{ .Values.service.internalPort }}
              initialDelaySeconds: {{ .Values.livenessProbe.initialDelaySeconds }}
              periodSeconds: {{ .Values.livenessProbe.periodSeconds }}
              successThreshold: {{ .Values.livenessProbe.successThreshold }}
              timeoutSeconds: {{ .Values.livenessProbe.timeoutSeconds }}
            readinessProbe:
              httpGet:
                path: {{ .Values.probePath }}
                port: {{ .Values.service.internalPort }}
              periodSeconds: {{ .Values.readinessProbe.periodSeconds }}
              successThreshold: {{ .Values.readinessProbe.successThreshold }}
              timeoutSeconds: {{ .Values.readinessProbe.timeoutSeconds }}
            resources:
    {{ toYaml .Values.resources | indent 12 }}
            terminationGracePeriodSeconds: {{ .Values.terminationGracePeriodSeconds }}
    {{- end }}
          volumes:
            - name: cloudsql-instance-credentials
              secret:
                secretName: {{ template "fullname" . }}-sql-sa
    ```

### Summary of Changes Made To Staging Environment

* created a new file, called `jx-requirements.yml` at the root
* updated the `env/values.yaml` with values for our application

??? example "jx-requirements.yml"

    ```yaml
    secretStorage: vault
    ```

??? example "env/values.yaml"

    ```yaml
    quarkus-fruits:
    secrets:
      sql_connection: vault:quarkus-fruits:INSTANCE_CONNECTION_NAME
      sql_sa: vault:quarkus-fruits:SA
      sql_password: vault:quarkus-fruits:GOOGLE_SQL_PASS
    ```