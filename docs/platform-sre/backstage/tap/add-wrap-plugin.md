---
tags:
  - IDP
  - TAP
  - Platform Engineering
  - Tanzu
  - Backstage
---

title: Add Backstage Plugins to TDP
description: Add custom Backstage plugins to Tanzu Developer Portal

# Add Backstage Plugins to TDP

Before we can run our Tanzu Developer Portal with other Backstage plugins, for example our own, we need to take some steps.

!!! Warning "TAP Required"

    It may be obvious, but I add this warning just in case.

    This guide requires a TAP installation where you have the Tanzu Developer Portal and the tools related to Build profile.

    So either you have a Full Profile installation, or an install with both a View and a Build profile.

The steps:

1. Create a Cartographer Supply Chain (optional, but recommended)
1. Create our custom build configuration
1. Build our custom TDP image via the Supply Chain
1. Update our TAP installation to use our custom TDP image

!!! Warning "TAP 1.7.x"

    This guide is written for TAP 1.7.x.

    It is possible some things related to the TDP Configurator or the Cartographer Supply Chain change, breaking these examples.

For the most part, this guide follows the TAP official documentation of [Build your customized Tanzu Developer Portal](https://docs.vmware.com/en/VMware-Tanzu-Application-Platform/1.7/tap/tap-gui-configurator-building.html).

## Create Cartographer Supply Chain

We create a **ClusterSupplyChain** as documented.

While it is possible to build the custom TDP image via a OOTB supply chain, it is likely your other configuration options are incompatible with the Configurator build.

First, we need to retrieve the existing Configurator image to use a starting point in our Supply Chain.

We do this by running the following command:

```sh 
export TDP_IMAGE_LOCATION=$(imgpkg describe -b $(kubectl get -n tap-install $(kubectl get package -n tap-install \
  --field-selector spec.refName=tpb.tanzu.vmware.com -o name) -o \
  jsonpath="{.spec.template.spec.fetch[0].imgpkgBundle.image}") -o yaml --tty=true | grep -A 1 \
  "kbld.carvel.dev/id: harbor-repo.vmware.com/esback/configurator" | grep "image: " | sed 's/image: //g')
```

The code is collapsed by default for readability, click the arrow to expand it and copy the contents into a filed named `tdp-sc.yaml`.

Replace the following values:

* **TDP-IMAGE-LOCATION**: the content of the `TDP_IMAGE_LOCATION` variable (or the output of the command)
* **REGISTRY-HOSTNAME**: the hostname of the container registry to push the image too
* **IMAGE-REPOSITORY**: the repository path of that container registry to push the image too

??? Example "TDP Supply Chain"

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

Apply the Supply Chain to the cluster:

```sh
kubectl apply -f tdp-sc.yaml
```

And verify the Cluster Supply Chain exists and is valid:

```sh
kubectl get clustersupplychain
```

Which should yield something like the following:

```sh
NAME                         READY   REASON   AGE
scanning-image-scan-to-url   True    Ready    47d
source-test-scan-to-url      True    Ready    47d
tdp-configurator             True    Ready    40d
```

## Create our custom build configuration

The TDP Configurator configuration contains a list of the Wrapper plugins, in order, and separated into Frontend and Backend plugins.

For example, to include my Hello plugin:

!!! Example "TDP Configuration"

    ```yaml title="tdp-config.yaml"
    app:
      plugins:
        - name: '@kearos/hello-wrapper'
          version: '0.3.0'

    backend:
      plugins:
        - name: '@kearos/hello-wrapper-backend'
          version: '0.3.0'
    ```

To transport the configuration YAML into a Suply Chain run, we encode this value as Base64:

```sh
base64 -i tdp-config.yaml
```

Which we then add to the **Workload** definition.

!!! Example "TDP Workload Template"

    Make sure to replace the placeholder values:

    * **DEVELOPER-NAMESPACE**: the namespace which is configured to run TAP Supply Chain workloads
    * **ENCODED-TDP-CONFIG-VALUE**: the Bas64 encoded `tdp-config.yaml`

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

??? Example "TDP Config Example"

    ```yaml title="tdp-workload.yaml"
    apiVersion: carto.run/v1alpha1
    kind: Workload
    metadata:
      name: tdp-configurator-1-sc
      namespace: dev
      labels:
        apps.tanzu.vmware.com/workload-type: tdp
        app.kubernetes.io/part-of: tdp-configurator-1-custom
    spec:
      build:
        env:
          - name: TPB_CONFIG_STRING
            value: YXBwOgogIHBsdWdpbnM6CiAgICAtIG5hbWU6ICdAa2Vhcm9zL2hlbGxvLXdyYXBwZXInCiAgICAgIHZlcnNpb246ICcwLjMuMCcKCmJhY2tlbmQ6CiAgcGx1Z2luczoKICAgIC0gbmFtZTogJ0BrZWFyb3MvaGVsbG8td3JhcHBlci1iYWNrZW5kJwogICAgICB2ZXJzaW9uOiAnMC4zLjAnCg==
    ```

Apply this workload to the cluster and namepace where you can run TAP Supply Chain workloads:

```sh
tanzu apps workload create -f tdp-workload.yaml
```

Once you create the Workload this way, you receive the customary hints of commands to run to inspect the progress if the Supply Chain run.

You should also see the Supply Chain in your TAP GUI's (TDP) Supply Chain page.

## Update TAP to use custom TDP Image

This follows along the same way as [the official docs](https://docs.vmware.com/en/VMware-Tanzu-Application-Platform/1.7/tap/tap-gui-configurator-running.html).

From both the log, the GUI, and the resources in the cluster you can retrieve the resulting container image URI, which we need for the next step.

Or you can run this command:

```sh
export WORKLOAD_NAME=tdp-configurator-1-sc
export WORKLOAD_NS=dev
```

```sh
export IMAGE=$(kubectl get images.kpack.io -n $WORKLOAD_NS ${WORKLOAD_NAME} -ojsonpath="{.status.latestImage}")
echo "IMAGE=${IMAGE}"
```

We're two steps away from having our custom TDP image running:

1. Create a YTT Overlay Secret
1. Update the TAP install values to apply this overlay to the `tap-gui` package

For the first, the overlay secret we create depends on the dependencies we use with TAP's Tanzu Build Service.

!!! Info
    If you've not configured anything specific for TBS inside TAP, then you are using the `lite dependencies`

Which ever content you use, you need to replace the following:

* **IMAGE-REFERENCE**: with the content of the `IMAGE` variable we set earlier

=== "Lite TBS dependencies"

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

=== "Full TBS Dependencies"

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
                    exec /layers/tanzu-buildpacks_node-engine/node/bin/node portal/dist/packages/backend  \
                    --config=portal/app-config.yaml \
                    --config=portal/runtime-config.yaml \
                    --config=/etc/app-config/app-config.yaml    
    ```

Once you create the file and replace the `IMAGE-REFERENCE` placeholder, we can apply it to the cluster.

```sh
kubectl apply -f tdp-overlay-secret.yaml
```

Then the last step, update the TAP install values of the profile that includes your `tap-gui` package install (e.g., View or Full profile).

```yaml title="tap-install-values.yaml" hl_lines="5 6 7 8"
profile: full
tap_gui:
  ...

package_overlays:
- name: tap-gui
  secrets:
  - name: tdp-app-image-overlay-secret
```
