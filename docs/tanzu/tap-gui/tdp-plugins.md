---
tags:
  - TAP
  - Tanzu
  - Backstage
  - Developer Portal
---

title: TAP GUI - Developer Portal Plugins
description: Tanzu Application Platform GUI - Add Additional Plugins

# TAP GUI - Developer Portal Plugins

The TAP GUI, now renamed to Tanzu Developer Portal or TDP for short, is _the_ GUI of TAP.

Based on the popular OSS project Backstage, it is intended to serve as the central information hub for all things software development.

As such, you want to integrate as many of the other tools related to your software development process in this GUI, where applicable of course.

Tanzu Application Platform starting with TAP 1.7.0 supports the process of baking your own image with a custom set of additional plugins.

Community hero [VRabbi](https://vrabbi.cloud/post/tanzu-developer-portal-configurator-deep-dive/) has done the first exploration of this feature[^1].

This guide is based on his work and the official [TAP docs](https://docs.vmware.com/en/VMware-Tanzu-Application-Platform/1.7/tap/tap-gui-configurator-about.html) on the component enabling this: Tanzu Developer Portal Configurator[^2].

## Customization Process

While there are various ways to get the job, the recommended approach is as follows:

1. Create a TDP configuration file, listing the desired plugins
1. Create a custom Supply Chain to build the custom TAP GUI image (included in the TAP docs)
1. Create a Workload CR for the custom build
1. Create a TAP GUI overlay, to replace the default image with yours
1. Configure TAP install values to support your selected plugins
1. Apply any other cluster configuration required by your plugins (e.g., additional RBAC permissions)

The steps are well documented:

1. [Prepare Configurator Configuration file](https://docs.vmware.com/en/VMware-Tanzu-Application-Platform/1.7/tap/tap-gui-configurator-building.html#prepare-your-configurator-configuration-file-1)
1. [Identify your Configurator Image](https://docs.vmware.com/en/VMware-Tanzu-Application-Platform/1.7/tap/tap-gui-configurator-building.html#identify-your-configurator-image-2)
1. [Build customized Portal image](https://docs.vmware.com/en/VMware-Tanzu-Application-Platform/1.7/tap/tap-gui-configurator-building.html#build-your-customized-portal-3)
1. [Identify Customized Image](https://docs.vmware.com/en/VMware-Tanzu-Application-Platform/1.7/tap/tap-gui-configurator-running.html)
1. [Prepare Custom Overlay](https://docs.vmware.com/en/VMware-Tanzu-Application-Platform/1.7/tap/tap-gui-configurator-running.html#prepare-to-overlay-your-customized-image-onto-the-currently-running-instance-1)

We'll quickly go through some example steps of my working example.

### Create Config File

Below I'm using some plugin wrappers created by VRabbi.

There are also several such ports created by the Tanzu team, [available on the NPMJS registry](https://www.npmjs.com/search?q=vmware-tanzu), which you can add in the same way[^6].

```yaml title="tdp-config.yaml"
app:
  plugins:
    - name: '@vrabbi/dev-toolbox-wrapper'
      version: '0.1.0'
    - name: "@vrabbi/tekton-wrapper"
      version: "0.1.2"
    - name: '@vrabbi/tech-insights-wrapper'
      version: '0.1.1'
    - name: '@vrabbi/backstage-devtools-wrapper'
      version: '0.2.1'

backend:
  plugins:
    - name: '@vrabbi/tech-insights-wrapper-backend'
      version: '0.1.1'
    - name: '@vrabbi/backstage-devtools-wrapper-backend'
      version: '0.1.0'
```

We add this configuration file as a **base64** encoded string to our **Workload** CR later.

So let's encode it now, and store it for later use:

```sh
base64 -i tdp-config.yaml
```

Which for me yields:

```sh
YXBwOgogIHBsdWdpbnM6CiAgICAtIG5hbWU6ICdAdnJhYmJpL2Rldi10b29sYm94LXdyYXBwZXInCiAgICAgIHZlcnNpb246ICcwLjEuMCcKICAgIC0gbmFtZTogIkB2cmFiYmkvdGVrdG9uLXdyYXBwZXIiCiAgICAgIHZlcnNpb246ICIwLjEuMiIKICAgIC0gbmFtZTogJ0B2cmFiYmkvdGVjaC1pbnNpZ2h0cy13cmFwcGVyJwogICAgICB2ZXJzaW9uOiAnMC4xLjEnCiAgICAtIG5hbWU6ICdAdnJhYmJpL2JhY2tzdGFnZS1kZXZ0b29scy13cmFwcGVyJwogICAgICB2ZXJzaW9uOiAnMC4yLjEnCgoKYmFja2VuZDoKICBwbHVnaW5zOgogICAgLSBuYW1lOiAnQHZyYWJiaS90ZWNoLWluc2lnaHRzLXdyYXBwZXItYmFja2VuZCcKICAgICAgdmVyc2lvbjogJzAuMS4xJwogICAgLSBuYW1lOiAnQHZyYWJiaS9iYWNrc3RhZ2UtZGV2dG9vbHMtd3JhcHBlci1iYWNrZW5kJwogICAgICB2ZXJzaW9uOiAnMC4xLjAnCg==
```

### Identify Configurator Image

>To build a customized Tanzu Developer Portal, you must identify the Configurator image to pass through the supply chain. Depending on your choices during installation, this is on either registry.tanzu.vmware.com or the local image registry (imgpkg) that you moved the installation packages to.

Essential, in order to build our custom portalimage, we must refer to the existing base image that is currently used.

When I run the documented command:

```sh
imgpkg describe -b $(kubectl get -n tap-install $(kubectl get package -n tap-install \
--field-selector spec.refName=tpb.tanzu.vmware.com -o name) -o \
jsonpath="{.spec.template.spec.fetch[0].imgpkgBundle.image}") -o yaml --tty=true | grep -A 1 \
"kbld.carvel.dev/id: harbor-repo.vmware.com/esback/configurator" | grep "image: " | sed 's/\simage: //g'
```

I get this as a result, pointing to an image in my local Harbor:

```sh
image: harbor.tap.h2o-2-19271.h2o.vmware.com/tap/tap-packages@sha256:29f978561d7d931c9a118c167eae905ce41990131013339aaff10c291ac6c42b
```

Which we store as `TDP_IMAGE_LOCATION`, so we know where to swap it in later:

```sh
export TDP_IMAGE_LOCATION=harbor.tap.h2o-2-19271.h2o.vmware.com/tap/tap-packages@sha256:29f978561d7d931c9a118c167eae905ce41990131013339aaff10c291ac6c42b
```

### Create Custom Supply Chain

As [documented](https://docs.vmware.com/en/VMware-Tanzu-Application-Platform/1.7/tap/tap-gui-configurator-building.html#build-your-customized-portal-3) we use the Custom Supply Chain, that way we don't have to adjust and possible wreck, any existing Supply Chain.

??? Example "TAP GUI Supply Chain Template"

    There are some placeholders in here we must fill with actual values:

    * **TDP-IMAGE-LOCATION** with the contents of the `TDP_IMAGE_LOCATION` we stored earlier
    * **REGISTRY-HOSTNAME** with the hostname of your Image Repository
    * **IMAGE-REPOSITORY** with the repository path of where in your Image Repository you want to store this

    In my cases, that became:

    ```yaml
    - default: registry.tanzu.vmware.com/tanzu-application-platform/tap-packages@sha256:001d3879720c2dc131ec95db6c6a34ff3c2f912d9d8b7ffacb8da08a844b740f
      name: tdp_configurator_bundle
    ```

    ```yaml
    - name: registry
      default:
        ca_cert_data: |-
          -----BEGIN CERTIFICATE-----
          MIID7jCCAtagAwIBAgIURv5DzXSDklERFu4gL2sQBNeRg+owDQYJKoZIhvcNAQEL
          ...
          vhs=
          -----END CERTIFICATE-----
        repository: tap-apps
        server: harbor.tap.h2o-2-19271.h2o.vmware.com
    ```


    ```yaml title="tdp-sc.yaml"
    apiVersion: carto.run/v1alpha1
    kind: ClusterSupplyChain
    metadata:
    name: tdp-configurator
    spec:
    resources:
    - name: source-provider
        params:
        - default: default
        name: serviceAccount
        - default: TDP-IMAGE-LOCATION
        name: tdp_configurator_bundle
        templateRef:
        kind: ClusterSourceTemplate
        name: tdp-source-template
    - name: image-provider
        params:
        - default: default
        name: serviceAccount
        - name: registry
        default:
            ca_cert_data: ""
            repository: IMAGE-REPOSITORY
            server: REGISTRY-HOSTNAME
        - default: default
        name: clusterBuilder
        sources:
        - name: source
        resource: source-provider
        templateRef:
        kind: ClusterImageTemplate
        name: tdp-kpack-template

    selectorMatchExpressions:
    - key: apps.tanzu.vmware.com/workload-type
        operator: In
        values:
        - tdp
    ---
    apiVersion: carto.run/v1alpha1
    kind: ClusterImageTemplate
    metadata:
    name: tdp-kpack-template
    spec:
    healthRule:
        multiMatch:
        healthy:
            matchConditions:
            - status: "True"
            type: BuilderReady
            - status: "True"
            type: Ready
        unhealthy:
            matchConditions:
            - status: "False"
            type: BuilderReady
            - status: "False"
            type: Ready
    imagePath: .status.latestImage
    lifecycle: mutable
    params:
    - default: default
        name: serviceAccount
    - default: default
        name: clusterBuilder
    - name: registry
        default: {}
    ytt: |
        #@ load("@ytt:data", "data")
        #@ load("@ytt:regexp", "regexp")

        #@ def merge_labels(fixed_values):
        #@   labels = {}
        #@   if hasattr(data.values.workload.metadata, "labels"):
        #@     exclusions = ["kapp.k14s.io/app", "kapp.k14s.io/association"]
        #@     for k,v in dict(data.values.workload.metadata.labels).items():
        #@       if k not in exclusions:
        #@         labels[k] = v
        #@       end
        #@     end
        #@   end
        #@   labels.update(fixed_values)
        #@   return labels
        #@ end

        #@ def image():
        #@   return "/".join([
        #@    data.values.params.registry.server,
        #@    data.values.params.registry.repository,
        #@    "-".join([
        #@      data.values.workload.metadata.name,
        #@      data.values.workload.metadata.namespace,
        #@    ])
        #@   ])
        #@ end

        #@ bp_node_run_scripts = "set-tpb-config,portal:pack"
        #@ tpb_config = "/tmp/tpb-config.yaml"

        #@ for env in data.values.workload.spec.build.env:
        #@   if env.name == "TPB_CONFIG_STRING":
        #@     tpb_config_string = env.value
        #@   end
        #@   if env.name == "BP_NODE_RUN_SCRIPTS":
        #@     bp_node_run_scripts = env.value
        #@   end
        #@   if env.name == "TPB_CONFIG":
        #@     tpb_config = env.value
        #@   end
        #@ end

        apiVersion: kpack.io/v1alpha2
        kind: Image
        metadata:
        name: #@ data.values.workload.metadata.name
        labels: #@ merge_labels({ "app.kubernetes.io/component": "build" })
        spec:
        tag: #@ image()
        serviceAccountName: #@ data.values.params.serviceAccount
        builder:
            kind: ClusterBuilder
            name: #@ data.values.params.clusterBuilder
        source:
            blob:
            url: #@ data.values.source.url
            subPath: builder
        build:
            env:
            - name: BP_OCI_SOURCE
            value: #@ data.values.source.revision
            #@  if regexp.match("^([a-zA-Z0-9\/_-]+)(\@sha1:)?[0-9a-f]{40}$", data.values.source.revision):
            - name: BP_OCI_REVISION
            value: #@ data.values.source.revision
            #@ end
            - name: BP_NODE_RUN_SCRIPTS
            value: #@ bp_node_run_scripts
            - name: TPB_CONFIG
            value: #@ tpb_config
            - name: TPB_CONFIG_STRING
            value: #@ tpb_config_string

    ---
    apiVersion: carto.run/v1alpha1
    kind: ClusterSourceTemplate
    metadata:
    name: tdp-source-template
    spec:
    healthRule:
        singleConditionType: Ready
    lifecycle: mutable
    params:
    - default: default
        name: serviceAccount
    revisionPath: .status.artifact.revision
    urlPath: .status.artifact.url
    ytt: |
        #@ load("@ytt:data", "data")

        #@ def merge_labels(fixed_values):
        #@   labels = {}
        #@   if hasattr(data.values.workload.metadata, "labels"):
        #@     exclusions = ["kapp.k14s.io/app", "kapp.k14s.io/association"]
        #@     for k,v in dict(data.values.workload.metadata.labels).items():
        #@       if k not in exclusions:
        #@         labels[k] = v
        #@       end
        #@     end
        #@   end
        #@   labels.update(fixed_values)
        #@   return labels
        #@ end

        ---
        apiVersion: source.apps.tanzu.vmware.com/v1alpha1
        kind: ImageRepository
        metadata:
        name: #@ data.values.workload.metadata.name
        labels: #@ merge_labels({ "app.kubernetes.io/component": "source" })
        spec:
        serviceAccountName: #@ data.values.params.serviceAccount
        interval: 10m0s
        #@ if hasattr(data.values.workload.spec, "source") and hasattr(data.values.workload.spec.source, "image"):
        image: #@ data.values.workload.spec.source.image
        #@ else:
        image: #@ data.values.params.tdp_configurator_bundle
        #@ end
    ```

### Create Workload Definition

Below is the [documented template](https://docs.vmware.com/en/VMware-Tanzu-Application-Platform/1.7/tap/tap-gui-configurator-building.html#build-your-customized-portal-3):

```yaml title="tdp-workload.yaml"
apiVersion: carto.run/v1alpha1
kind: Workload
metadata:
  name: tdp-configurator-1-sc
  namespace: DEVELOPER-NAMESPACE
  labels:
    apps.tanzu.vmware.com/workload-type: tdp
    app.kubernetes.io/part-of: tdp-configurator-1-custom
spec:
  build:
    env:
      - name: TPB_CONFIG_STRING
        value: ENCODED-TDP-CONFIG-VALUE
```

And here is my used example:

```yaml title="tdp-workload.yaml"
apiVersion: carto.run/v1alpha1
kind: Workload
metadata:
  name: tdp-configurator-1-sc
  namespace: d1
  labels:
    apps.tanzu.vmware.com/workload-type: tdp
    app.kubernetes.io/part-of: tdp-configurator-1-custom
spec:
  build:
    env:
      - name: TPB_CONFIG_STRING
        value: YXBwOgogIHBsdWdpbnM6CiAgICAtIG5hbWU6ICdAdnJhYmJpL2Rldi10b29sYm94LXdyYXBwZXInCiAgICAgIHZlcnNpb246ICcwLjEuMCcKICAgIC0gbmFtZTogIkB2cmFiYmkvdGVrdG9uLXdyYXBwZXIiCiAgICAgIHZlcnNpb246ICIwLjEuMiIKICAgIC0gbmFtZTogJ0B2cmFiYmkvdGVjaC1pbnNpZ2h0cy13cmFwcGVyJwogICAgICB2ZXJzaW9uOiAnMC4xLjEnCiAgICAtIG5hbWU6ICdAdnJhYmJpL2JhY2tzdGFnZS1kZXZ0b29scy13cmFwcGVyJwogICAgICB2ZXJzaW9uOiAnMC4yLjEnCgoKYmFja2VuZDoKICBwbHVnaW5zOgogICAgLSBuYW1lOiAnQHZyYWJiaS90ZWNoLWluc2lnaHRzLXdyYXBwZXItYmFja2VuZCcKICAgICAgdmVyc2lvbjogJzAuMS4xJwogICAgLSBuYW1lOiAnQHZyYWJiaS9iYWNrc3RhZ2UtZGV2dG9vbHMtd3JhcHBlci1iYWNrZW5kJwogICAgICB2ZXJzaW9uOiAnMC4xLjAnCg==
```

Apply the workload and verify the image is build successfully.

```sh
kubectl apply -f tdp-workload.yaml
```

!!! Info
    The build can take a long time and sometimes appears to be stuck (e.g., the log does not progress).

    This is normal, so just be patient.

### Create Overlay Secret

First, we figure out the last successfully build image:

```sh
export WORKLOAD_NAME=tdp-configurator-1-sc
export DEVELOPER_NAMESPACE=d1
```

```sh
kubectl get images.kpack.io ${WORKLOAD_NAME} \
  -o jsonpath={.status.latestImage} \
  -n ${DEVELOPER_NAMESPACE}
```

Which for me yields this:

```sh
harbor.tap.h2o-2-19271.h2o.vmware.com/tap-apps/tdp-configurator-1-sc-d1@sha256:6210f42d239fba1b9ea7ffca89e0e77612184069d9e3e2b8a9cffe1e74299888%
```

This is to replace the placeholder value `IMAGE-REFERENCE`.

=== "Content for Lite TBS Depdenencies (default)"

    ```yaml title="tdp-overlay-secret.yaml"
    apiVersion: v1
    kind: Secret
    metadata:
      name: tdp-app-image-overlay-secret
      namespace: tap-install
    stringData:
      tdp-app-image-overlay.yaml: |
        #@ load("@ytt:overlay", "overlay")

        #! makes an assumption that tap-gui is deployed in the namespace: "tap-gui"
        #@overlay/match by=overlay.subset({"kind": "Deployment", "metadata": {"name": "server", "namespace": "tap-gui"}}), expects="1+"
        ---
        spec:
          template:
            spec:
              containers:
                #@overlay/match by=overlay.subset({"name": "backstage"}),expects="1+"
                #@overlay/match-child-defaults missing_ok=True
                - image: IMAGE-REFERENCE
                #@overlay/replace
                  args:
                  - -c
                  - |
                    export KUBERNETES_SERVICE_ACCOUNT_TOKEN="$(cat /var/run/secrets/kubernetes.io/serviceaccount/token)"
                    exec /layers/tanzu-buildpacks_node-engine-lite/node/bin/node portal/dist/packages/backend  \
                    --config=portal/app-config.yaml \
                    --config=portal/runtime-config.yaml \
                    --config=/etc/app-config/app-config.yaml
    ```

=== "Content for Full TBS Dependencies"

    ```yaml
    apiVersion: v1
    kind: Secret
    metadata:
      name: tdp-app-image-overlay-secret
      namespace: tap-install
    stringData:
      tdp-app-image-overlay.yaml: |
        #@ load("@ytt:overlay", "overlay")

        #! makes an assumption that tap-gui is deployed in the namespace: "tap-gui"
        #@overlay/match by=overlay.subset({"kind": "Deployment", "metadata": {"name": "server", "namespace": "tap-gui"}}), expects="1+"
        ---
        spec:
          template:
            spec:
              containers:
                #@overlay/match by=overlay.subset({"name": "backstage"}),expects="1+"
                #@overlay/match-child-defaults missing_ok=True
                - image: IMAGE-REFERENCE
                #@overlay/replace
                  args:
                  - -c
                  - |
                    export KUBERNETES_SERVICE_ACCOUNT_TOKEN="$(cat /var/run/secrets/kubernetes.io/serviceaccount/token)"
                    exec /layers/tanzu-buildpacks_node-engine/node/bin/node portal/dist/packages/backend  \
                    --config=portal/app-config.yaml \
                    --config=portal/runtime-config.yaml \
                    --config=/etc/app-config/app-config.yaml
    ```

Apply the secret to the TAP install namespace:

```sh
kubectl apply -f tdp-overlay-secret.yaml
```

And then apply the Overlay configuration to the TAP install values:

```yaml
package_overlays:
- name: tap-gui
  secrets:
  - name: tdp-app-image-overlay-secret
```

## Tekton Plugin

* https://www.npmjs.com/package/@vrabbi/tekton-wrapper
* https://vrabbi.cloud/post/tanzu-developer-portal-configurator-deep-dive/
* https://github.com/janus-idp/backstage-plugins/blob/main/plugins/tekton/README.md
* https://janus-idp.io/plugins/tekton/

Several customers have complained to me about the difficulty of determining the status of the Tekton components run by the TAP Supply Chains.

One way to make that easier to detect, is to add the Backstage [Tekton plugin](https://janus-idp.io/plugins/tekton/) to the Tanzu Developer Portal[^3].

Because the TAP GUI isn't exactly Backstage, we need to use a Wrapper plugin.
These Wrapper plugins can then leverage [the APIs](https://docs.vmware.com/en/VMware-Tanzu-Application-Platform/1.7/tap/tap-gui-configurator-api-docs.html) to integrate common Backstage plugins in the TDP[^4].

I thank [VRabbi](https://vrabbi.cloud/post/tanzu-developer-portal-configurator-deep-dive/) for his hard work in creating some of these wrapper plugins and distributing them publicly. We'll use his [Tekton Wrapper plugin](https://www.npmjs.com/package/@vrabbi/tekton-wrapper) for our efforts[^4].

So, what do we need to do to get this plugin to work?

1. Create a custom TDP Image with the Tekton plugin included
1. Create additional RBAC configuration for the TAP GUI ServiceAccount
1. Configure the Kubernetes plugin in the TAP GUI's `app_config` property in the TAP Install values
1. Add additional Annotations to the Software Catalog entry for the Components for which we want to enable the Tekton plugin

Regarding the first step, see our previous chapter in this guide.

### Additional RBAC Configuration

The plugin has an [example ClusterRole](https://raw.githubusercontent.com/janus-idp/backstage-plugins/main/plugins/tekton/manifests/clusterrole.yaml) for the permissions required[^5]:

??? Example "Tekton Plugin ClusterRole"

    ```yaml title="janus-idp-tekton-plugin-cluster-role.yaml"
    kind: ClusterRole
    apiVersion: rbac.authorization.k8s.io/v1
    metadata:
      name: janus-idp-tekton-plugin
    rules:
      # Base for Kubernetes plugin
      - apiGroups:
          - ''
        resources:
          - pods/log
          - pods
          - services
          - configmaps
          - limitranges
        verbs:
          - get
          - watch
          - list
      - apiGroups:
          - metrics.k8s.io
        resources:
          - pods
        verbs:
          - get
          - watch
          - list
      - apiGroups:
          - apps
        resources:
          - daemonsets
          - deployments
          - replicasets
          - statefulsets
        verbs:
          - get
          - watch
          - list
      - apiGroups:
          - autoscaling
        resources:
          - horizontalpodautoscalers
        verbs:
          - get
          - watch
          - list
      - apiGroups:
          - networking.k8s.io
        resources:
          - ingresses
        verbs:
          - get
          - watch
          - list
      - apiGroups:
          - batch
        resources:
          - jobs
          - cronjobs
        verbs:
          - get
          - watch
          - list
      # Additional permissions for the @janus-idp/backstage-plugin-tekton
      - apiGroups:
          - tekton.dev
        resources:
          - pipelineruns
          - taskruns
        verbs:
          - get
          - list
    ```

Apply it:

```sh
kubectl apply -f janus-idp-tekton-plugin-cluster-role.yaml
```

Which we can then apply the to TAP GUI ServiceAccount via the following `ClsuterRoleBinding`:

```yaml title="tap-gui-tekton-clusterrolebinding.yaml"
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: janus-idp-tekton-plugin-tap-gui
subjects:
- kind: ServiceAccount
  name: tap-gui
  namespace: tap-gui
roleRef:
  kind: ClusterRole
  name: janus-idp-tekton-plugin
  apiGroup: rbac.authorization.k8s.io
```

And apply that as well:

```sh
kubectl apply -f tap-gui-tekton-clusterrolebinding.yaml
```

### Configure TAP Install Values

The Tekton plugin relies on the [Kubernetes plugin](https://backstage.io/docs/features/kubernetes/configuration/) for retrieving resources from the cluster.

While the main Kubernetes plugin page shows the configuration per cluster, in my experience that broke the TAP GUI's default configuration.

So I recommend using the "global" Kubernetes configuration to add additional `customResources` to list.

!!! Importan
    Be sure to provide the `tap-gui` **ServiceAccount** the permissions to read these resources.

```yaml title="tap-install-values.yaml"
tap_gui:
  app_config:
    kubernetes:
      customResources:
        - group: 'tekton.dev'
          apiVersion: 'v1'
          plural: 'pipelineruns'
        - group: 'tekton.dev'
          apiVersion: 'v1'
          plural: 'taskruns'
        - group: 'serving.knative.dev'
          apiVersion: 'v1'
          plural: 'revisions'
        - group: 'serving.knative.dev'
          apiVersion: 'v1'
          plural: 'services'
        - group: 'carto.run'
          apiVersion: 'v1alpha1'
          plural: 'clustersupplychains'
        - group: 'carto.run'
          apiVersion: 'v1alpha1'
          plural: 'deliverables'
        - group: 'carto.run'
          apiVersion: 'v1alpha1'
          plural: 'workloads'
```

### Add Additional Annotations

Once everything is sorted on the TAP side of things, you'll notice there is no Tekton tab or menu item anywhere!

Fear not, it is likely because the default mode is _opt in_.

So Software Catalog items by default do not have a Tekton tab, which makes sense as not all items are related to components let alone those that have relevant Tekton pipelines!

The documentation on the Tekton plugin [catalog item configuration](https://janus-idp.io/plugins/tekton/#setting-up-the-tekton-plugin) isn't entirely clear, these are the annotations I had to add[^7]:

```yaml
janus-idp.io/tekton-enabled : 'true'
backstage.io/kubernetes-id: 'spring-boot-postgres'
backstage.io/kubernetes-namespace: 'dev'
janus-idp.io/tekton: 'spring-boot-postgres'
```

So my entire Software Catalog entry became:

```yaml
apiVersion: backstage.io/v1alpha1
kind: Component
metadata:
  name: spring-boot-postgres
  description: Tanzu Java Web App with Spring Boot 3, using a PostgreSQL database.
  tags:
    - app-accelerator
    - java
    - spring
    - web
    - tanzu
  annotations:
    'backstage.io/kubernetes-label-selector': 'app.kubernetes.io/part-of=spring-boot-postgres'
    'backstage.io/techdocs-ref': 'dir:.'
    janus-idp.io/tekton-enabled : 'true'
    backstage.io/kubernetes-id: 'spring-boot-postgres'
    backstage.io/kubernetes-namespace: 'dev'
    janus-idp.io/tekton: 'spring-boot-postgres'
spec:
  type: service
  lifecycle: experimental
  owner: teal
```

Once this is updated in the Software Catalog, you should see a new tab called `Tekton` within the Software Catalog view of the Component.

## References

[^1]: [VRabbi - Tanzu Developer Portal Configurator Deep Dive](https://vrabbi.cloud/post/tanzu-developer-portal-configurator-deep-dive/)
[^2]: [TAP 1.7 Docs - Tanzu Developer Portal Configurator](https://docs.vmware.com/en/VMware-Tanzu-Application-Platform/1.7/tap/tap-gui-configurator-about.html)
[^3]: [Backstage Tekton plugin](https://janus-idp.io/plugins/tekton/)
[^4]: [Tanzu Developer Portal - Backstage Plugin APIs](https://docs.vmware.com/en/VMware-Tanzu-Application-Platform/1.7/tap/tap-gui-configurator-api-docs.html)
[^5]: [Backstage Tekton plugin - ClusterRole example](https://raw.githubusercontent.com/janus-idp/backstage-plugins/main/plugins/tekton/manifests/clusterrole.yaml)
[^6]: [VMware Tanzu - Backstage Wrapper Plugins for Tanzu Developer Portal](https://www.npmjs.com/search?q=vmware-tanzu)
[^7]: [Backstage Tekton Plugin - configure the plugin and enable it per Software Catalog item](https://janus-idp.io/plugins/tekton/#setting-up-the-tekton-plugin)
