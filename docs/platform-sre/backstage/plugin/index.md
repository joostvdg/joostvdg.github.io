---
tags:
  - IDP
  - Platform Engineering
  - Backstage
  - Plugin
---

title: Create Backstage Plugin
description: Create Backstage Frontend + Backend Plugin

# Create Backstage Plugin

Let's create a Backstage plugin!

Well, to be honest, this is quite trivial and there are greate guides out there.

So why am I writing this, yet again?

Because through writing it down I remember and understand it better.

Either way, my work is based upon, and inspired by:

* [Backstage Docs - Create a pluginb](https://backstage.io/docs/plugins/create-a-plugin/)
* [John Tucker (Medium) - Backstage Plugins by Example - Part 1](https://john-tucker.medium.com/backstage-plugins-by-example-part-1-a4737e21d256)

## Goal

The goal is to add the ability to say something about a Software Catalog entry.

We do this by having a Frontend component in the Catalog Item page (as a Tab) and a Backend component it can query.

And, ideally, this plugin is then also usable by [Tanzu Developer Portal](https://docs.vmware.com/en/VMware-Tanzu-Application-Platform/1.7/tap/tap-gui-about.html) via its Wrapper APIs.

## Steps

So, let's go over what we'll do:

1. Ensure we have all the pre-requisites in place (e.g., Backstage codebase, NodeJS, and so on)
1. Create a Backend plugin
    1. add it to Backstage
    1. build & publish it to NPMJS.org
1. Create a Frontend plugin
    1. add it to Backstage
    1. build & publish it to NPMJS.org

## Pre-requisites

Before we start, make sure you have the following ready/installed:

1. An account on [NPMJS.org](http://npmjs.org), we'll publish the plugins here
1. Get a copy of Backstage, so we can test our plugin(s)
    1. Do a Git checkout/clone of [github.com/backstage/backstage](https://github.com/backstage/backstage) or create a Fork
1. Install [Node Version Managager (NVM)](https://github.com/nvm-sh/nvm), not required though strongly recommended
1. Install [NodeJS](https://nodejs.org/en), either download it from the source, or use **NVM** to install it for you (_recommended)
    1. Backstage generally supports NodeJS 16 and 18, while latest is 20?
    1. To install via NVM, run `nvm use 18`
1. Install [NPM](https://docs.npmjs.com/downloading-and-installing-node-js-and-npm), even though Backstage uses [Yarn](https://yarnpkg.com/), we still rely on NPM for some tasks (such as Publishing)
1. Install [Yarn](https://yarnpkg.com/getting-started/install), more on this below
1. Install [TypeScript](https://www.typescriptlang.org/download), more on this below

### Yarn Installation

Oke, this has become super confusing.
So it helps to clarify a few things.

Yarn is an alternative NodeJS package manager/builder, as compared to NPM.

The "classical" Yarn, version 1 and 2, are installed standalone.

Beyond those versions, Yarn is installed via NodeJS.
But, not via NodeJS directly, but via [Corepack](https://yarnpkg.com/corepack).

I do believe you can keep using the classic Yar (e.g., 1.x) if you don't really care.

If you do care about having the latest versions, the process is as follows:

* Ensure you have the latest version of NodeJS (that is compatible with Backstage)
* Enable Corepack (might have to install it first, see below)
* Switch Yarn to the `stable` version

```sh
npm install -g corepack
corepack enable
yarn set version stable
yarn install
```

This should get you the latest stable version of Yarn.

### TypeScript Installation

The Backstage plugins are built via TypeScript.

While you can do every step along the way without TypeScript being involved, at the end of the line, your plugin won't work without it.

So, ensure you have TypeScript available, so commands like `yarn tsc` work:

```sh
npm install typescript -g
```
