---
tags:
  - IDP
  - Platform Engineering
  - Backstage
  - Plugin
---

title: Create Backstage Backend Plugin
description: Create Backstage Backend Plugin

# Create Backstage Backend Plugin

Let's start with creating Backstage Backend Plugin.

I'm going to write how I created my plugin.
This is based on the official guide and a Medium blog post (series).
So, this is not something I invented and there likely isn't anything new here.

The idea here is that I write down my experience to serve as my long term memory.

The prior art are these two resources:

* [Backstage Docs - Create a Backend plugin](https://backstage.io/docs/plugins/backend-plugin/)
* [John Tucker (Medium) - Backstage Plugins by Example - Part 2](https://john-tucker.medium.com/backstage-plugins-by-example-part-2-6ead20cb4c8d)

## Steps

The steps we'll take, are the following:

1. Initialize a new backend plugin with Yarn
1. Embed the plugin in our Backstage copy
1. Verify the plugin works within Backstage
1. Build and publish it as a standalone NPMJS package

## Init Backend Plugin

To get started, get to your Backstage code copy.
Make sure you're at the root of the code base.


!!! Example
    The root directly should be like this:

    ```sh
    tree -L 1
    ```

    ```sh
    .
    ├── README.md
    ├── app-config.local.yaml
    ├── app-config.production.yaml
    ├── app-config.yaml
    ├── backstage.json
    ├── catalog-info.yaml
    ├── dist-types
    ├── environment.sh
    ├── examples
    ├── lerna.json
    ├── node_modules
    ├── package.json
    ├── packages
    ├── playwright.config.ts
    ├── plugins
    ├── tsconfig.json
    └── yarn.lock
    ```

!!! Warning inline end "Name of plugin"

    The creation command adds `-backend` automatically.

To create the plugin, we run the `yarn new` command:

```sh
yarn new --select backend-plugin
```

This generates your plugin, which is now located in the folder `./plugins/<nameOfPlugin>`.

The initial response should be something like this:

```sh
Creating backend plugin @internal/plugin-hello-backend

 Checking Prerequisites:
  availability  plugins/hello-backend ✔
  creating      temp dir ✔

 Executing Template:
  copying       .eslintrc.js ✔
  templating    README.md.hbs ✔
  templating    package.json.hbs ✔
  copying       setupTests.ts ✔
  copying       index.ts ✔
  templating    run.ts.hbs ✔
  copying       router.test.ts ✔
  copying       router.ts ✔
  templating    standaloneServer.ts.hbs ✔

 Installing:
  moving        plugins/hello-backend ✔
  backend       adding dependency ✔
  executing     yarn install // this will be "working for some time"
  executing     yarn lint --fix ✔

🎉  Successfully created backend-plugin
```

I've named my plugin Hello, but feel free to choose a different name:

```sh
export PLUGIN_NAME=hello
```

Enter to your plugin directory:

```sh
cd plugins/${PLUGIN_NAME}-backend
```

And then run the self-run command as follows:

```sh
LEGACY_BACKEND_START=true yarn start
```

A successful launch emits the following:

```sh
Build succeeded
2024-01-10T17:06:52.173Z backstage info Listening on :7007
```

This will bootup a Node backend server with your plugin.
To verify your plugin works, run the following:

=== "Httpie"
    ```sh
    http :7007/${PLUGIN_NAME}/health
    ```

=== "Curl"
    ```sh
    curl http://localhost:7007/${PLUGIN_NAME}/health | jq
    ```

The response should be a 200 OK with a bit of JSON:

```json
{
    "status": "ok"
}
```

## Verify in Backstage

Oke, so the plugin works in and by itself.

That is not very useful, so let's import it into Backstage.

!!! Important "Set Package Namespace"
    
    Before we continue, we should update the Package _namespace_ in `package.json`.

    By default, it is `"name": "@internal/...",`.

    When we publish it to NPMJS.org we need to set this to our username or organization.
    
    We use this full name (namespace + package name) to import our plugin to Backstage.
    So update it now to your username or organization, to avoid problems later.

    In my case, the first three lines of `package.json` now look like this:

    ```json
    {
        "name": "@kearos/plugin-hello",
        "version": "0.2.0",
        ...
    }
    ```

To make this next command easier to use, export your NPMJS name(space):

```sh
export NPMJS_NAME=
```

Go back to the root directory of Backstage (should be `cd ../../`).

And then run this:

=== "Yarn 1.x"
    ```sh
    yarn add --cwd packages/backend "@${NPMJS_NAME}/plugin-${PLUGIN_NAME}-backend@^0.1.0" 
    ```

=== "Yarn 4.x"
    ```sh
    yarn workspace backend add "@${NPMJS_NAME}/plugin-${PLUGIN_NAME}-backend@^0.1.0"
    ```

We need to make two more code changes before we can run Backstage and see our plugin live.

First, create a plugin file at `./packages/backend/src/pugins/<name_of_plugin>.ts`:

!!! Example "hello.ts"

    ```typescript title="./packages/backend/src/pugins/hello.ts"
    import { createRouter } from '@kearos/plugin-hello-backend';
    import { Router } from 'express';
    import { PluginEnvironment } from '../types';

    export default async function createPlugin(
        env: PluginEnvironment,
        ): Promise<Router> {
    
        return await createRouter({
            logger: env.logger,
        });
    }
    ```

Start the Backstage backend:

```sh
yarn start-backend
```

And then call our plugin API again:

=== "Httpie"
    ```sh
    http :7007/api/${PLUGIN_NAME}/health
    ```

=== "Curl"
    ```sh
    curl localhost:7007/api/${PLUGIN_NAME}/health | jq
    ```

!!! Warning
    Notice the addition of `/api` there.

Which should return the same response:

```json
{
  "status": "ok"
}
```

This is it for our Backend plugin code.

While we could implement some logic and create an additional end point, 
for the purpose of having a backend and client plugin working together, this is enough.

## Build and Publish to NPMSJS

Before we can wrap it up entirely, we need to publish our backend plugin.

To do so, we need to compile the TypeScript and build a NPM package we can publish.

### Build Package

To compile the type script, we go to the root of the Backstage project, and run the following:

```sh
yarn install && yarn tsc
```

If there are any errors, which there shouldn't, resolve them before continuing.

We can then build the package.
First, go back to the plugin folder:

```sh
cd plugins/${PLUGIN_NAME}-backend
```

Then run the build:

```sh
yarn build
```

Once this is done, your plugin should be build and contain a `dist` folder:

```sh
tree
```

Which gives this result:

```sh
.
├── README.md
├── dist
│   ├── index.cjs.js
│   ├── index.cjs.js.map
│   └── index.d.ts
├── node_modules
├── package.json
└── src
    ├── index.ts
    ├── run.ts
    ├── service
    │   ├── router.test.ts
    │   ├── router.ts
    │   └── standaloneServer.ts
    └── setupTests.ts
```

### Publish Package

Ensure you have an NPMJS.org account and your NPM CLI is logged in:

```sh
npm login
```

Then, from the root of your plugin, run the NPM Publish command:

```sh
npm publish --access public
```

Which should ask you to login to your NPM account:

```sh
npm notice
npm notice 📦  @kearos/plugin-hello-backend@0.2.1
npm notice === Tarball Contents ===
npm notice 638B  README.md
npm notice 888B  dist/index.cjs.js
npm notice 1.2kB dist/index.cjs.js.map
npm notice 235B  dist/index.d.ts
npm notice 1.1kB package.json
npm notice === Tarball Details ===
npm notice name:          @kearos/plugin-hello-backend
npm notice version:       0.2.1
npm notice filename:      kearos-plugin-hello-backend-0.2.1.tgz
npm notice package size:  1.8 kB
npm notice unpacked size: 4.1 kB
npm notice shasum:        e7f58.............................bbd05e
npm notice integrity:     sha512-uhBJRSVioTMTd[...]xJ6Ti9WH+qluA==
npm notice total files:   5
npm notice
npm notice Publishing to https://registry.npmjs.org/ with tag latest and public access
Authenticate your account at:
https://www.npmjs.com/auth/cli/ebdff4ea-a53d-4575-9786-65a8984815de
Press ENTER to open in the browser..
```

Once you do, it should return with the following:

```sh
+ @kearos/plugin-hello-backend@0.2.1
```

We've completed our work on the backend plugin.