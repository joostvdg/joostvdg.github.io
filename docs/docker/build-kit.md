title: Docker BuildKit
description: How To Build Docker Images Faster With Build-Kit

# Docker Build with Build-Kit

Instead of investing in improving docker image building via the Docker Client, Docker created a new API and client library.

This library called BuildKit, is completely independent. With Docker 18.09, it is included in the Docker Client allowing anyone to use it as easily as the traditional `docker image build`.

BuildKit is already used by some other tools, such as Buildah and IMG, and allows you to create custom DSL "Frontends". As long as the API of BuikdKit is adhered to, the resulting image will be OCI compliant.

## How To Use It

So further remarks below and how to use it.

* [BuildKit](https://github.com/moby/buildkit)
* In-Depth session [Supercharged Docker Build with BuildKit](https://europe-2018.dockercon.com/videos-hub)
* Usable from Docker `18.09`
* HighLights:
    * allows custom DSL for specifying image (BuildKit) to still be used with Docker client/daemon
    * build cache for your own files during build, think Go, Maven, Gradle...
    * much more optimized, builds less, quicker, with more cache in less time
    * support mounts (cache) such as secrets, during build phase

```bash
# Set env variable to enable
# Or configure docker's json config
export DOCKER_BUILDKIT=1
```

## Example

```dockerfile
# syntax=docker/dockerfile:experimental
#######################################
## 1. BUILD JAR WITH MAVEN
FROM maven:3.6-jdk-8 as BUILD
WORKDIR /usr/src
COPY . /usr/src
! RUN --mount=type=cache,target=/root/.m2/  mvn clean package -e
#######################################
## 2. BUILD NATIVE IMAGE WITH GRAAL
FROM oracle/graalvm-ce:1.0.0-rc9 as NATIVE_BUILD
WORKDIR /usr/src
COPY --from=BUILD /usr/src/ /usr/src
RUN ls -lath /usr/src/target/
COPY /docker-graal-build.sh /usr/src
RUN ./docker-graal-build.sh
RUN ls -lath
#######################################
## 3. BUILD DOCKER RUNTIME IMAGE
FROM alpine:3.8
CMD ["jpc-graal"]
COPY --from=NATIVE_BUILD /usr/src/jpc-graal /usr/local/bin/
RUN chmod +x /usr/local/bin/jpc-graal
#######################################