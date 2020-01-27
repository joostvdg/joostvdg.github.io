# jx convert jenkinsfile

`jx convert jenkinsfile` is a plugin for [Jenkins X](https://jenkins-x.io) to assist in converting from the legacy
`Jenkinsfile`-based pipelines to the modern `jenkins-x.yml`-based pipelines. It will attempt to convert an existing
`Jenkinsfile` into the equivalent `jenkins-x.yml` in the same directory, letting the user know if there are parts
 of the existing `Jenkinsfile` which cannot be converted.

Directives in the `Jenkinsfile` which cannot be automatically converted will be noted in the  `jenkins-x.yml` with
comments showing the `Jenkinsfile` snippet, and steps which cannot be converted will be noted with comments and
replaced by `echo ... && exit 1` in the actual pipeline execution.

If the `Jenkinsfile` contains code outside of the `pipeline { ... }` block, or unknown Declarative directives, 
`jx convert jenkinsfile` will exit with an error.

## Installation

Download the `jx-convert-jenkinsfile` binary and place it in a directory in your `PATH`:

### Linux

```shell
curl -L https://github.com/jenkins-x/jx-convert-jenkinsfile/releases/download/$(curl --silent https://api.github.com/repos/jenkins-x/jx-convert-jenkinsfile/releases/latest | jq -r '.tag_name')/jx-convert-jenkinsfile-linux-amd64.tar.gz | tar xzv 
sudo mv jx-convert-jenkinsfile /usr/local/bin
```

### macOS

```shell
curl -L https://github.com/jenkins-x/jx-convert-jenkinsfile/releases/download/$(curl --silent https://api.github.com/repos/jenkins-x/jx-convert-jenkinsfile/releases/latest | jq -r '.tag_name')/jx-convert-jenkinsfile-darwin-amd64.tar.gz | tar xzv 
sudo mv jx-convert-jenkinsfile /usr/local/bin
```

You can now invoke the tool by running `jx convert jenkinsfile`.

## Usage

Run `jx convert jenkinsfile`, optionally specifying `--dir ...` to look for the `Jenkinsfile` in a different
directory than the current one. 
