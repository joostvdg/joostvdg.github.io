---
tags:
  - IDP
  - TAP
  - Platform Engineering
  - Tanzu
  - Backstage
---

title: Create TDP Wrappers for Backstage Plugins
description: Use TDP APIs to wrap Backstage Plugins for use in TDP

# Create TDP Wrappers for Backstage Plugins

To make it possible to add either your own or any of the existing Backstage plugins, the TAP team created additional APIs inside Backstage.

This allows us to "wrap" a vanilla Backstage plugin and include it into the TDP via the [Tanzu Developer Portal Configurator](https://docs.vmware.com/en/VMware-Tanzu-Application-Platform/1.7/tap/tap-gui-configurator-building.html).

This has been explored by community superstar [VRabbi](https://vrabbi.cloud/post/tanzu-developer-portal-configurator-deep-dive/), who has created a [public repository](https://github.com/vrabbi-tap/tdp-plugin-wrappers) with many Backstage community plugins already wrapped and ready to use.

I created my own Hello World Backstage plugins, a Frontend and a Backend plugin.

Roughly the process was as follows:

1. Explore the Wrapper plugins already created by VRabbi
1. Fork VRabbi's repository
1. Create a Wrapper plugin for both the Backend and Frontend in my Fork
1. Verify they still work via VRabbi's repository setup
1. Publish them to NPMSJS.org
1. [Include them in the TDP via the Configurator](/platform-sre/backstage/tap/add-wrap-plugin/)

!!! Important
    While writing this, the Tanzu team added a similar guide to the official TAP documentation.

    You might want to follow the [Create a Tanzu Developer Portal plug-in](https://docs.vmware.com/en/VMware-Tanzu-Application-Platform/1.7/tap/tap-gui-configurator-create-plug-in-wrapper.html) guide instead.

## Fork vrabbi-tap/tdp-plugin-wrappers

Not only did VRabbi create excellent examples of the Wrapper plugins and the TDP configuration, his repository also lets you test the wrapped plugins!

The easiest way to get started, is to fork his GitHub [vrabbi-tap/tdp-plugin-wrappers](https://github.com/vrabbi-tap/tdp-plugin-wrappers) repository.

Check out your fork locally, open a terminal in this repository, and open the folder in your favorite IDE or editor.

## Create Backend Wrapper

For the Backend Wrapper, we'll take the following steps:

1. Create the plugin folder
1. Populate the folder with content, inspired/copied from the existing Wrapper Backend plugins
1. Compile and Build the plugin
1. Publish the plugin

The naming convention for the wrapper plugins is `<name>-wrapper` and if its a backend, the `-backend` comes at the end.

In my case, the plugin is `hello`, so this folder is `hello-wrapper-backend`.

While we can create a plugin via Yarn or the Backstage CLI, there's very little we'll keep.
I opted for copy-pasting the files from some of the other wrappers instead.

We end up with four files:

* **package.json**: it is still an NPM package, so we need a `package.json` for our dependencies, metadata, and scripts.
* **.eslintrc.js**: for linting
* **src/index.ts**: main plugin file, and a way to export any other module and types
* **src/HelloBackendPlugin.tsx**: the wrapper itself, wiring the plugin into the TDP APIs

!!! Example "package.json"

    The only differences are in the name/version of the metadata, and the dependencies.

    In my case, I'm depending on my own `plugin-hello-backend`, via `"@kearos/plugin-hello-backend": "^0.2.0",`.

    ```json title="package.json"
    {
      "name": "@kearos/hello-wrapper-backend",
      "version": "0.3.0",
      "main": "src/index.ts",
      "types": "src/index.ts",
      "license": "Apache-2.0",
      "publishConfig": {
          "access": "public",
          "main": "dist/index.cjs.js",
          "types": "dist/index.d.ts"
      },
      "backstage": {
          "role": "backend-plugin"
      },
      "scripts": {
          "start": "backstage-cli package start",
          "build": "backstage-cli package build",
          "lint": "backstage-cli package lint",
          "test": "backstage-cli package test",
          "clean": "backstage-cli package clean",
          "prepack": "backstage-cli package prepack",
          "postpack": "backstage-cli package postpack"
      },
      "dependencies": {
          "@kearos/plugin-hello-backend": "^0.2.0",
          "@types/express": "^4.17.17",
          "@vmware-tanzu/core-backend": "1.0.0",
          "express": "^4.18.2",
          "express-promise-router": "^4.1.0"
      },
      "devDependencies": {
          "@backstage/cli": "^0.22.6",
          "eslint": "^8.16.0",
          "typescript": "~4.6.4"
      },
      "files": [
          "dist"
      ]
    }
    ```

!!! Warning

    Make sure you name your plugin correctly.

    The `@../` is the scope, and should be either your username or your organization.

!!! Example "eslint file"

    ```javascript title=".eslintrc.js"
    module.exports = require('@backstage/cli/config/eslint-factory')(__dirname);
    ```

!!! Example "index.ts"

    The purpose of this file is to export the modules and types in our wrapper.

    ```typescript title="src/index.ts"
    export { HelloBackendPlugin as plugin } from './HelloBackendPlugin';
    ```

!!! Example "Plugin.tsx"

    The main content of the wrapper plugin.

    We import the Router from Express(js) and the function to create our plugin's router from our backend plugin.

    Then we import the APIs from the TDP plugin, to wrap ours.

    We then export our plugin as an implementation of the wrapper API.

    ```typescript title="src/HelloBackendPlugin.tsx"
    import { createRouter } from '@kearos/plugin-hello-backend';
    import {
      BackendPluginInterface,
      BackendPluginSurface,
      PluginEnvironment,
    } from '@vmware-tanzu/core-backend';
    import { Router } from 'express';

    const createPlugin = () => {
      return async (env: PluginEnvironment): Promise<Router> => {
          return await createRouter({
            logger: env.logger,
          });
      };
    };

    export const HelloBackendPlugin: BackendPluginInterface = () => 
      surfaces =>
        surfaces.applyTo(BackendPluginSurface, backendPluginSurface => {
          backendPluginSurface.addPlugin({
            name: 'hello',
            pluginFn: createPlugin(),
          });
        }); 
    ```

Once this is done, we need to confirm we didn't make any obvious mistake.
So we install and compile the typescript from the plugin's directory:

```sh
yarn install && yarn tsc
```

!!! Important
    The Backstage project requires Node 16 or 18.

    If you have another version, ensure you have [nvm](https://github.com/nvm-sh/nvm) installed, and then run:

    ```sh
    nvm use 18
    ```

if there are no errors, we can proceed to build and publish the plugin.

```sh
yarn build
```

Doing a `tree` on the directory to show the state after building.
To avoid going through all the nesting `node_modules` has, we limit to two levels:

```sh
tree -L 2
```

The directory should now look as follows:

```sh
.
├── dist
│   ├── index.cjs.js
│   ├── index.cjs.js.map
│   └── index.d.ts
├── node_modules
│   └── typescript
├── package.json
└── src
    ├── HelloBackendPlugin.tsx
    └── index.ts
```

We can now publish the plugin:

```sh
npm publish --access public 
```

## Create Frontend Wrapper

For the Frontend Wrapper, we'll take the following steps:

1. Create the plugin folder
1. Populate the folder with content, inspired/copied from the existing Wrapper plugins
1. Compile and Build the plugin
1. Publish the plugin

The naming convention for the wrapper plugins is `<name>-wrapper` and if its a backend, the `-backend` comes at the end.

In my case, the plugin is `hello`, so this folder is `hello-wrapper`.

While we can create a plugin via Yarn or the Backstage CLI, there's very little we'll keep.
I opted for copy-pasting the files from some of the other wrappers instead.

We end up with four files:

* **package.json**: it is still an NPM package, so we need a `package.json` for our dependencies, metadata, and scripts.
* **.eslintrc.js**: for linting
* **src/index.ts**: main plugin file, and a way to export any other module and types
* **src/HelloBackendPlugin.tsx**: the wrapper itself, wiring the plugin into the TDP APIs

!!! Example "package.json"

    The only differences are in the name/version of the metadata, and the dependencies.

    In my case, I'm depending on my own `plugin-hello`, via `"@kearos/plugin-hello": "^0.2.0",`.

    ```json title="package.json"
    {
      "name": "@kearos/hello-wrapper",
      "version": "0.3.0",
      "main": "src/index.ts",
      "types": "src/index.ts",
      "license": "Apache-2.0",
      "publishConfig": {
          "access": "public",
          "main": "dist/index.esm.js",
          "types": "dist/index.d.ts"
      },
      "backstage": {
          "role": "frontend-plugin"
      },
      "sideEffects": false,
      "scripts": {
          "start": "backstage-cli package start",
          "build": "backstage-cli package build",
          "lint": "backstage-cli package lint",
          "test": "backstage-cli package test",
          "clean": "backstage-cli package clean",
          "prepack": "backstage-cli package prepack",
          "postpack": "backstage-cli package postpack"
      },
      "dependencies": {
          "@backstage/core-components": "^0.13.2",
          "@backstage/core-plugin-api": "^1.5.2",
          "@backstage/plugin-catalog": "1.11.2",
          "@kearos/plugin-hello": "0.2.0",
          "@vmware-tanzu/core-common": "1.0.0",
          "@vmware-tanzu/core-frontend": "1.0.0"
      },
      "peerDependencies": {
          "react": "^17.0.2",
          "react-dom": "^17.0.2",
          "react-router": "6.0.0-beta.0",
          "react-router-dom": "6.0.0-beta.0"
      },
      "devDependencies": {
          "@backstage/cli": "^0.25.0",
          "@backstage/core-app-api": "^1.11.2",
          "@backstage/dev-utils": "^1.0.25",
          "@backstage/test-utils": "^1.4.6",
          "@testing-library/jest-dom": "^5.10.1",
          "@testing-library/react": "^12.1.3",
          "@testing-library/user-event": "^14.0.0",
          "eslint": "^8.16.0",
          "msw": "^1.0.0",
          "typescript": "~4.6.4"
      },
      "files": [
          "dist"
      ]
    }

    ```

!!! Warning

    Make sure you name your plugin correctly.

    The `@../` is the scope, and should be either your username or your organization.

!!! Example "eslint file"

    ```javascript title=".eslintrc.js"
    module.exports = require('@backstage/cli/config/eslint-factory')(__dirname);
    ```

!!! Example "index.ts"

    The purpose of this file is to export the modules and types in our wrapper.

    ```typescript title="src/index.ts"
    export { HelloPlugin as plugin } from './HelloPlugin';
    ```

!!! Example "Plugin.tsx"

    The main content of the wrapper plugin.

    We import the APIs from the TDP plugin, to wrap ours.

    We then export our plugin as an implementation of the wrapper API, adding our pluging Compoment into the layout.

    ```typescript title="src/HelloBackendPlugin.tsx"
    import { EntityLayout } from '@backstage/plugin-catalog';

    import { AppPluginInterface, AppRouteSurface, EntityPageSurface } from '@vmware-tanzu/core-frontend';
    import { SurfaceStoreInterface } from '@vmware-tanzu/core-common';
    import React from 'react';
    import { Grid } from '@material-ui/core';

    import { EntityHelloContent } from '@kearos/plugin-hello'

    export const HelloPlugin: AppPluginInterface =
      () => (context: SurfaceStoreInterface) => {
        context.applyWithDependency(
          AppRouteSurface,
          EntityPageSurface,
          (_appRouteSurface, entityPageSurface) => {
            entityPageSurface.servicePage.addTab(
              <EntityLayout.Route path="/hello" title="Hello">
                    <Grid container spacing={3} alignItems="stretch">
                      <Grid item md={12}>
                        <EntityHelloContent />
                      </Grid>
                    </Grid>
              </EntityLayout.Route>,
            );
          },
        );
      };
    ```

Once this is done, we need to confirm we didn't make any obvious mistake.
So we install and compile the typescript from the plugin's directory:

```sh
yarn install && yarn tsc
```

!!! Important
    The Backstage project requires Node 16 or 18.

    If you have another version, ensure you have [nvm](https://github.com/nvm-sh/nvm) installed, and then run:

    ```sh
    nvm use 18
    ```

if there are no errors, we can proceed to build and publish the plugin.

```sh
yarn build
```

Doing a `tree` on the directory to show the state after building.
To avoid going through all the nesting `node_modules` has, we limit to two levels:

```sh
tree -L 2
```

The directory should now look as follows:

```sh
.
├── dist
│   ├── index.d.ts
│   ├── index.esm.js
│   └── index.esm.js.map
├── node_modules
│   ├── @azure
│   ├── @backstage
│   ├── @react-hookz
│   ├── @rollup
│   ├── @types
│   ├── @typescript-eslint
│   ├── bfj
│   ├── cross-fetch
│   ├── eslint-plugin-unused-imports
│   ├── linkify-react
│   ├── linkifyjs
│   ├── magic-string
│   └── typescript
├── package.json
└── src
    ├── HelloPlugin.tsx
    └── index.ts
```

We can now publish the plugin:

```sh
npm publish --access public 
```