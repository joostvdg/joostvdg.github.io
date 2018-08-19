# Graceful shutdown

> We can speak about the graceful shutdown of our application, when all of the resources it used and all of the traffic and/or data processing what it handled are closed and released properly. It means that no database connection remains open and no ongoing request fails because we stop our application. - [Péter Márton](https://blog.risingstack.com/graceful-shutdown-node-js-kubernetes/)

As I could not have done it better myself, I've quoted Péter Márton.

I think we can say that cleaning up your mess and informing people of your impending departure is a good thing. Many programming languages and frameworks have hooks for listening to signals - which we explore later - allowing you to handle a shutdown, expected or not.

When we have resources open, such as files, database connections, background processes and others. It would be best for ourselves, but also for our environment to clean those up before exiting. This cleanup would constitute a graceful shutdown.

We're going to dive into this subject, exploring several complimentary topics that together should help improve your (Docker) application's ability to gracefully shutdown.

* The case for graceful shutdown
* How to run processes in Docker
* Process management
* Signals management

## The case for graceful shutdown

We're in an age where many applications are running in Docker containers across a multitude of clusters and (potentially) different orchestrators. These bring with it, other concerns to tackle, such as logging, monitoring, tracing and many more. One significant way we defend ourselves against the perils of distributed nature of these clusters is to make our applications more resilient.

However, there is still no guarantee your application is always up and running. So another concern we should tackle is how it responds when it does fail, including it being told to stop by the orchestrator. Now, this can happen for a variety of reasons, for example; your application's health check fails or your application consumed more resources than allowed.

Not only does this increase the reliability of your application, but it also increases the reliability of the cluster it lives in. As you can not always know in advance where your application is run, you might not even be the one putting it in a docker container, make sure your application knows how to quit!

## How to run processes in Docker

There are many ways to run a process in Docker. I prefer to make things easy to understand and easy to know what to expect. So this article deals with processes started by commands in a Dockerfile.

There are several ways to run a command in a Dockerfile.

These are:

* **RUN**: runs a command during the docker build phase
* **CMD**: runs a command when the container gets started
* **ENTRYPOINT**: provides the location from where commands get run when the container starts
You need at least one ENTRYPOINT or CMD in a Dockerfile for it to be valid. They can be used in collaboration but they can do similar things.

You can put these commands in both a shell form and an exec form. For more information on these commands, you should check out [Docker's docs on Entrypoint vs. CMD](https://docs.docker.com/engine/reference/builder/#exec-form-entrypoint-example).

In summary, the shell form runs the command as a shell command and spawn a process via /bin/sh -c.

Whereas the exec form executes a child process that is still attached to PID1.

We'll show you what that looks like, borrowing the Docker docs example referred to earlier.

### Docker Shell form example

Create the following Dockerfile:

```dockerfile
FROM ubuntu:18.04
ENTRYPOINT top -b
```

Then build and run it:

```bash
docker image build --tag shell-form .
docker run --name shell-form --rm shell-form
```

This should yield the following:

```bash
top - 16:34:56 up 1 day,  5:15,  0 users,  load average: 0.00, 0.00, 0.00
Tasks:   2 total,   1 running,   1 sleeping,   0 stopped,   0 zombie
%Cpu(s):  0.4 us,  0.3 sy,  0.0 ni, 99.2 id,  0.1 wa,  0.0 hi,  0.0 si,  0.0 st
KiB Mem :  2046932 total,   541984 free,   302668 used,  1202280 buff/cache
KiB Swap:  1048572 total,  1042292 free,     6280 used.  1579380 avail Mem

  PID USER      PR  NI    VIRT    RES    SHR S  %CPU %MEM     TIME+ COMMAND
    1 root      20   0    4624    760    696 S   0.0  0.0   0:00.05 sh
    6 root      20   0   36480   2928   2580 R   0.0  0.1   0:00.01 top
```

As you can see, two processes are running, **sh** and **top**. 
Meaning, that killing the process, with *ctrl+c* for example, terminates the **sh** process, but not **top**. 
To kill this container, open a second terminal and execute the following command.

```bash
docker rm -f shell-form
```

As you can imagine, this is usually not what you want. 
So as a general rule, you should never use the shell form. So on to the exec form we go!

### Docker exec form example

The exec form is written as an array of parameters: `ENTRYPOINT ["top", "-b"]`

To continue in the same line of examples, we will create a Dockerfile, build and run it.

```dockerfile
FROM ubuntu:18.04
ENTRYPOINT ["top", "-b"]
```

Then build and run it:

```bash
docker image build --tag exec-form .
docker run --name exec-form --rm exec-form
```

This should yield the following:

```bash
top - 18:12:30 up 1 day,  6:53,  0 users,  load average: 0.00, 0.00, 0.00
Tasks:   1 total,   1 running,   0 sleeping,   0 stopped,   0 zombie
%Cpu(s):  0.4 us,  0.3 sy,  0.0 ni, 99.2 id,  0.1 wa,  0.0 hi,  0.0 si,  0.0 st
KiB Mem :  2046932 total,   535896 free,   307196 used,  1203840 buff/cache
KiB Swap:  1048572 total,  1042292 free,     6280 used.  1574880 avail Mem

  PID USER      PR  NI    VIRT    RES    SHR S  %CPU %MEM     TIME+ COMMAND
    1 root      20   0   36480   2940   2584 R   0.0  0.1   0:00.03 top
```

### Docker exec form with parameters

A caveat with the exec form is that it doesn't interpolate parameters.

You can try the following:

```dockerfile
FROM ubuntu:18.04
ENV PARAM="-b"
ENTRYPOINT ["top", "${PARAM}"]
```

Then build and run it:

```bash
docker image build --tag exec-param .
docker run --name exec-form --rm exec-param
```

This should yield the following:

```bash
/bin/sh: 1: [top: not found
```

This is where Docker created a mix between the two styles. 
It allows you to create an *Entrypoint* with a shell command - performing interpolation - but executing it as an exec form. 
This can be done by prefixing the shell form, with, you guessed it, *exec*.

```dockerfile
FROM ubuntu:18.04
ENV PARAM="-b"
ENTRYPOINT exec "top" "${PARAM}"
```

Then build and run it:

```bash
docker image build --tag exec-param .
docker run --name exec-form --rm exec-param
```

This will return the exact same as if we would've run `ENTRYPOINT ["top", "-b"]`.

Now you can also override the param, by using the environment variable flag.

```bash
docker image build --tag exec-param .
docker run --name exec-form --rm -e PARAM="help" exec-param
```

Resulting in top's help string.

### The special case of Alpine

One of the main [best practices for Dockerfiles](https://docs.docker.com/develop/develop-images/dockerfile_best-practices/), is to make them as small as possible. 
The easiest way to do this is to start with a minimal image. 
This is where [Alpine Linux](https://hub.docker.com/_/alpine/) comes in. We will revisit out shell form example, but replace ubuntu with alpine.

Create the following Dockerfile.

```dockerfile
FROM alpine:3.8
ENTRYPOINT top -b
```

Then build and run it.

```bash
docker image build --tag exec-param .
docker run --name exec-form --rm -e PARAM="help" exec-param
```

It will result in the following output.

```bash
Mem: 1509068K used, 537864K free, 640K shrd, 126756K buff, 1012436K cached
CPU:   0% usr   0% sys   0% nic 100% idle   0% io   0% irq   0% sirq
Load average: 0.00 0.00 0.00 2/404 5
  PID  PPID USER     STAT   VSZ %VSZ CPU %CPU COMMAND
    1     0 root     R     1516   0%   0   0% top -b
```

Aside from **top**'s output looking a bit different, there is only one command.

Alpine Linux helps us avoid the problem of shell form altogether!

## Process management

Now that we know how to create a Dockerfile that helps us make sure we can run as PID1 so that we can make sure our process correctly responds to signals?

We'll get into signal handling next, but first, let us explore how we can manage our process. 
As you're used to by now, there are multiple solutions at our disposal.

We can broadly categorize them like this:

* Process manages itself and it's children, by itself
* We let Docker manage the process, and it's children
* We use a process manager to do the work for us

### Process manages itself

Great, if this is the case, it saves you some trouble of relying on dependencies. 
Unfortunately, not all processes are [designed for PID1](https://www.fpcomplete.com/blog/2016/10/docker-demons-pid1-orphans-zombies-signals), and some might be [prone to zombie processes regardless](https://blog.phusion.nl/2015/01/20/docker-and-the-pid-1-zombie-reaping-problem).

In those cases, you still have to invest some time and effort to get a solution in place.


### Docker manages PID1

Docker has a build in feature, that it uses a lightweight process manager to help you.

So if you're running your images with Docker itself, either directly or via Compose or Swarm, you're fine. You can use the init flag in your run command or your compose file.

Please, note that the below examples require a certain minimum version of Docker.

* run - 1.13+
* [compose (v 2.2)](https://docs.docker.com/compose/compose-file/compose-file-v2/#image) - 1.13.0+
* [swarm (v 3.7)](https://docs.docker.com/compose/compose-file/#init) - 18.06.0+

#### Docker Run

```bash
docker run --rm -ti --init caladreas/dui
```

#### Docker Compose

```yaml
version: '2.2'
services:
    web:
        image: caladreas/java-docker-signal-demo:no-tini
        init: true
```

#### Docker Swarm

```yaml
version: '3.7'
services:
    web:
        image: caladreas/java-docker-signal-demo:no-tini
        init: true
```

Relying on Docker does create a dependency on how your container runs. It only runs correctly in Docker-related technologies (run, compose, swarm) and only if the proper versions are available.

Creating either a different experience for users running your application somewhere else or not able to meet the version requirements. So maybe another solution is to bake a process manager into your image and guarantee its behavior.

### Depend on a process manager
One of our goals for Docker images is to keep them small. We should look for a lightweight process manager. It does not have too many a whole machine worth or processes, just one and perhaps some children.

Here we would like to introduce you to [Tini](https://github.com/krallin/tini), a lightweight process manager [designed for this purpose](https://github.com/krallin/tini/issues/8). 
It is a very successful and widely adopted process manager in the Docker world. So successful, that the before mentioned init flags from Docker are implemented by baking [Tini into Docker](https://github.com/krallin/tini/issues/81).

#### Debian example

For brevity, the build process is excluded, and for image size, we use Debian slim instead of default Debian.

```dockerfile
FROM debian:stable-slim
ENV TINI_VERSION v0.18.0
ADD https://github.com/krallin/tini/releases/download/${TINI_VERSION}/tini /tini
RUN chmod +x /tini
ENTRYPOINT ["/tini", "-vv","-g", "--", "/usr/bin/dui/bin/dui","-XX:+UseCGroupMemoryLimitForHeap", "-XX:+UnlockExperimentalVMOptions"]
COPY --from=build /usr/bin/dui-image/ /usr/bin/dui
```

#### Alpine example

Alpine Linux works wonders for Docker images, so to improve our lives, you can very easily install it if you want.

```dockerfile
FROM alpine
RUN apk add --no-cache tini
ENTRYPOINT ["/sbin/tini", "-vv","-g","-s", "--"]
CMD ["top -b"]
```

## Signals management

Now that we can capture signals and manage our process, we have to see how we can manage those signals. There are three parts to this:

* **Handle signals**: we should make sure our process can deal with the signals it receives
* **Receive the right signals**: we might have to alter the signals we receive from our orchestrators
* **Signals and Docker orchestrators**: we have to help our orchestrators to know when to deliver these signals.

For more details on the subject of Signals and Docker, please read this excellent blog from [Grigorii Chudnov](https://medium.com/@gchudnov/trapping-signals-in-docker-containers-7a57fdda7d86).

### Handle signals

Handling process signals depend on your application, programming language or framework.

For Java and Go(lang) we dive into this further, exploring some options we have here, including some of the most used frameworks.

### Receive the right signals

Sometimes your language or framework of choice, doesn't handle signals all that well. 
It might be very rigid in what it does with specific signals, removing your ability to do the right thing. 
Of course, not all languages or frameworks are designed with Docker container or Microservices in mind, are yet to catch up to this more dynamic environment.

Luckily Docker and Kubernetes allow you to specify what signal too sent to your process.

#### Docker run

```bash
docker run --rm -ti --init --stop-signal=SIGINT \
   caladreas/java-docker-signal-demo
```

#### Docker compose/swarm

Docker's compose file format allows you to specify a [stop signal](https://docs.docker.com/compose/compose-file/compose-file-v2/#stop_signal). 
This is the signal sent when the container is stopped in a normal fashion. Normal in this case, meaning `docker stop` or when docker itself determines it should stop the container.

If you forcefully remove the container, for example with `docker rm -f`  it will directly kill the process, so don't do that.

```yaml
version: '2.2'
services:
    web:
        image: caladreas/java-docker-signal-demo
        stop_signal: SIGINT
        stop_grace_period: 15s
```

If you run this with `docker-compose up` and then in a second terminal, stop the container, you will see something like this.

```bash
web_1  | HelloWorld!
web_1  | Shutdown hook called!
web_1  | We're told to stop early...
web_1  | java.lang.InterruptedException: sleep interrupted
web_1  | 	at java.base/java.lang.Thread.sleep(Native Method)
web_1  | 	at joostvdg.demo.signal@1.0/com.github.joostvdg.demo.signal.HelloWorld.printHelloWorld(Unknown Source)
web_1  | 	at java.base/java.util.concurrent.Executors$RunnableAdapter.call(Unknown Source)
web_1  | 	at java.base/java.util.concurrent.FutureTask.run(Unknown Source)
web_1  | 	at java.base/java.util.concurrent.ThreadPoolExecutor.runWorker(Unknown Source)
web_1  | 	at java.base/java.util.concurrent.ThreadPoolExecutor$Worker.run(Unknown Source)
web_1  | 	at java.base/java.lang.Thread.run(Unknown Source)
web_1  | [DEBUG tini (1)] Passing signal: 'Interrupt'
web_1  | [DEBUG tini (1)] Received SIGCHLD
web_1  | [DEBUG tini (1)] Reaped child with pid: '7'
web_1  | [INFO  tini (1)] Main child exited with signal (with signal 'Interrupt')
```

#### Kubernetes

In Kubernetes we can make use of [Container Lifecycle Hooks](https://kubernetes.io/docs/concepts/containers/container-lifecycle-hooks/) to manage how our container should be stopped. 
We could, for example, send a SIGINT (interrupt) to tell our application to stop.

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
    name: java-signal-demo
    namespace: default
    labels:
        app: java-signal-demo
spec:
    replicas: 1
    template:
        metadata:
            labels:
                app: java-signal-demo
        spec:
            containers:
            - name: main
              image: caladreas/java-docker-signal-demo
              lifecycle:
                  preStop:
                      exec:
                          command: ["killall", "java" , "-INT"]
            terminationGracePeriodSeconds: 60
```

When you create this as deployment.yml, create and delete it - `kubectl apply -f deployment.yml` / `kubectl delete -f deployment.yml` - you will see the same behavior.

 
### Signals and Docker orchestrators

Now that we can respond to signals and receive the correct signals, there's one last thing to take care off. 
We have to make sure our orchestrator of choice sends these signals for the right reasons. 
Quickly telling us, there's something wrong with our running process, and it should shut down, which of course, we'll do gracefully!

As the topic for health, readiness and liveness checks is a topic on its own, we'll keep it short. 
Giving some basic examples and pointing you to more work to further investigate how to use it to your advantage.

### Docker

You can either configure your health check in your [Dockerfile](https://docs.docker.com/engine/reference/builder/#healthcheck) or
 configure it in your [docker-compose.yml](https://docs.docker.com/compose/compose-file/#healthcheck) for either compose or swarm.

Considering only Docker can use the health check in your Dockerfile, 
 it is strongly recommended to have health checks in your application and document how they can be used.

### Kubernetes

In Kubernetes we have the concept of [Container Probes](https://kubernetes.io/docs/concepts/workloads/pods/pod-lifecycle/#container-probes). 
This allows you to configure whether your container is ready (readinessProbe) to be used and if it is still working as expected (livenessProbe).
