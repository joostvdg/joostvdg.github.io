# Gracefully Shutting Down Applications in Docker

I'm not sure about you, but I prefer that my neighbors leave our shared spaces clean and don't take up parking spaces when they don't need them.

Imagine you live in an apartment complex with the above-mentioned parking lot. Some tenants go away and never come back. If nothing is done to clean up after them - to reclaim their apartment and parking space - then after some time, more and more apartments are unavailable for no reason, and the parking lot fills with cars which belong to no one.

Some tenants did not get a parking lot and are getting frustrated that none are becoming available. When they moved in, they were told that when others leave they would be next in line. While they're waiting, they have to park outside the complex. Eventually, the entrance gets blocked and no one can enter or leave. The end result is a completely unlivable apartment block with trapped tenants.

If you agree with me that when a tenant leaves, he or she should clean the apartment and free the parking spot to make it ready for the next inhabitant; then please read on. We're going to dive into the equivalent of doing this with containers.

We will explore running our containers with Docker (run, compose, swarm) and Kubernetes.
Even if you use another way to run your containers, this article should provide you with enough insight to get you on your way.

## The case for graceful shutdown

We're in an age where many applications are running in Docker containers across a multitude of clusters and (potentially) different orchestrators. These bring with it other concerns to tackle, such as logging, monitoring, tracing and many more. One significant way we defend ourselves against the perils of distributed nature of these clusters is to make our applications more resilient.

NOTE: How are the perils from the last sentence related logging, monitoring, and tracing?

NOTE: The last sentence sounds as if distributed systems make applications less resilient so we need to increase their resiliency. If anything, it's the other way around. Running applications in distributed systems make them more resilient.

However, there is still no guarantee your application is always up and running. So another concern we should tackle is how it responds when it needs to shut down. Where we can differentiate between an unexpected shutdown - we crashed - or an expected shutdown.

NOTE: The first sentence is missleading. The subject is graceful shutdown and that's not directly related with the subject of how containers and schedulers guarantee applications uptime.

Shutting down can happen for a variety of reasons. In this post we'll dive into expected shutdown, such as through an orchestrator like Kubernetes.

Containers can be purposelly shut down for a variety of reasons, including but not limited too:

* your application's health check fails
* your application consumed more resources than allowed
* the application is scaling down
* and more

Not only does this increase the reliability of your application, but it also increases that of the cluster it lives in. As you can not always know in advance where your application runs, you might not even be the one putting it in a docker container, make sure your application knows how to quit!

NOTE: The previous paragraph sounds confusing.

Graceful shutdown is not unique to Docker, as it permeates Linux's best practices for quite some years before Docker's existence. However, applying them to Docker container adds extra dimensions.

NOTE: The previous paragraph sounds confusing.

NOTE: The subtitle is "The case for graceful shutdown" and yet you did not explain the case. For example, terminating pending requests before shutdown.

## Start Good So You Can End Well

When you sign up for an apartment, you probably have to sign a contract detailing your rights and obligations. The more you state explicitly, the easier it is to deal with bad behaving neighbors. The same is true for running processes; we should make sure that we set the rules, obligations, and expectations from the start.

As we say in Dutch: a good beginning is half the work. We will start with how you can run a process in a container with a process that shuts down gracefully.

There are many ways to start a process in a Docker container. I prefer to make things easy to understand and easy to know what to expect. So this article deals with processes started by commands in a Dockerfile.

NOTE: The second sentence sets expectations that you will make things easy, but the third sentence does not follow on that promise. It's as if they're not connected.

There are several ways to run a command in a Dockerfile.

NOTE: We do not run a command in a Dockerfile but in a container. Dockerfile specifies how will a command be executed.

These are as follows:

* **CMD**: runs a command when the container gets started
* **ENTRYPOINT**: provides the location (entrypoint) from where commands get run when the container starts

You need at least one ENTRYPOINT or CMD in a Dockerfile for it to be valid. They can be used in collaboration but they can do similar things.

You can put these commands in both a shell form and an exec form. For more information on these commands, you should check out [Docker's docs on Entrypoint vs. CMD](https://docs.docker.com/engine/reference/builder/#exec-form-entrypoint-example).

NOTE: If you start explaining something (e.g., shell for and exec form) provide at least some basic info. Otherwise, remove the first part and leave only the link (e.g., for more info...).

### Docker Shell form example

We start with the shell form and see if it can do what we want; begin in such a way, we can stop it nicely.

NOTE: Explain (1 sentence is enough) what is the shell form. Since you assumed that readers don't know what is CMD and what is ENTRYPOINT, you must assume that they do not know what is shell form. In other words, you need to be clear who is the target audience and cannot assume first that they do not know stuff and then that they do know things that build on that stuff.

Please create Dockerfile with the content that follows.

```dockerfile
FROM ubuntu:18.04
ENTRYPOINT top -b
```

Then build an image and run a container.

```bash
docker image build --tag shell-form .

docker run --name shell-form --rm shell-form
```

The latter command yields the following output.

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

NOTE: Elaborate why is that so.

To kill this container, open a second terminal and execute the following command.

```bash
docker rm -f shell-form
```

Shell form doesn't do what we need. Starting a process with shell form will only lead us to the disaster of parking lots filling up unless there's a someone actively cleaning up.

NOTE: I'm not sure I understand why does shell form lead to a disaster?

NOTE: If this is a blog post, you went to far into different ways to execute commands inside containers and there's still not sign of graceful (or non-graceful) shutdown. On the other hand, you're rushing through the shell form. If I don't know what it is, I would probably not understand it after this section. On the other hand, if I do know what it is, I'm bored and will probably give up on my expectation to read about graceful shutdown. I'd recommend to write two articles. One about different ways to run commands in Docker containers and the other about graceful shotdown. The latter can contain the link to the former.

NOTE: Have to go now, so I'll stop the review at this point.

### Docker exec form example

This leads us to the exec form. Hopefully, this gets us somewhere.

The exec form is written as an array of parameters: `ENTRYPOINT ["top", "-b"]`

To continue in the same line of examples, we will create a Dockerfile, build and run it.

```dockerfile
FROM ubuntu:18.04
ENTRYPOINT ["top", "-b"]
```

Then build and run it.

```bash
docker image build --tag exec-form .
docker run --name exec-form --rm exec-form
```

This yields the following output.

```bash
top - 18:12:30 up 1 day,  6:53,  0 users,  load average: 0.00, 0.00, 0.00
Tasks:   1 total,   1 running,   0 sleeping,   0 stopped,   0 zombie
%Cpu(s):  0.4 us,  0.3 sy,  0.0 ni, 99.2 id,  0.1 wa,  0.0 hi,  0.0 si,  0.0 st
KiB Mem :  2046932 total,   535896 free,   307196 used,  1203840 buff/cache
KiB Swap:  1048572 total,  1042292 free,     6280 used.  1574880 avail Mem

  PID USER      PR  NI    VIRT    RES    SHR S  %CPU %MEM     TIME+ COMMAND
    1 root      20   0   36480   2940   2584 R   0.0  0.1   0:00.03 top
```

Now we got something we can work with. If something would tell this Container to stop, it will tell our only running process so it is sure to reach the correct one!

### Gotchas

Knowing we can use the exec form for our goal - gracefully shutting down our container - we can move on to the next part of our efforts. For the sake of imparting you with some hard learned lessons, we will explore two gotchas. They're optional, so you can also choose to skip to *Make Sure Your Process Listens*.

#### Docker exec form with parameters

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

#### The special case of Alpine

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

This yields the following output.

```bash
Mem: 1509068K used, 537864K free, 640K shrd, 126756K buff, 1012436K cached
CPU:   0% usr   0% sys   0% nic 100% idle   0% io   0% irq   0% sirq
Load average: 0.00 0.00 0.00 2/404 5
  PID  PPID USER     STAT   VSZ %VSZ CPU %CPU COMMAND
    1     0 root     R     1516   0%   0   0% top -b
```

Aside from **top**'s output looking a bit different, there is only one command.

Alpine Linux helps us avoid the problem of shell form altogether!

## Make Sure Your Process Listens

It is excellent if your tenants are all signed up, know their rights and obligations.
But you can't contact them when something happens, how will they ever know when to act?

Translating that into our process. It starts and can be told to shut down, but does it process listen?
Can it interpret the message it gets from Docker or Kubernetes? And if it does, can it relay the message correctly to its Child Processes?
In order for your process to gracefully shutdown, it should know when to do so. As such, it should listen not only for itself but also on behalf of its children - yours never do anything wrong though!

Some processes do, but many aren't designed to [listen](https://www.fpcomplete.com/blog/2016/10/docker-demons-pid1-orphans-zombies-signals) or tell [their Children](https://blog.phusion.nl/2015/01/20/docker-and-the-pid-1-zombie-reaping-problem). They expect someone else to listen for them and tell them and their children - process managers.

In order to listen to these **signals**, we can call in the help of others. We will look at two options.

* we let Docker manage the process and its children
* we use a process manager

### Let Docker manage it for us

If you're not using Docker to run or manage your containers, you should skip to *Depend on a process manager*.

Docker has a build in feature, that it uses a lightweight process manager to help you.

So if you're running your images with Docker itself, either directly or via Compose or Swarm, you're fine. You can use the init flag in your run command or your compose file.

Please, note that the below examples require a certain minimum version of Docker.

* run - 1.13+
* [compose (v 2.2)](https://docs.docker.com/compose/compose-file/compose-file-v2/#image) - 1.13.0+
* [swarm (v 3.7)](https://docs.docker.com/compose/compose-file/#init) - 18.06.0+

#### With Docker Run

```bash
docker run --rm -ti --init caladreas/dui
```

#### With Docker Compose

```yaml
version: '2.2'
services:
    web:
        image: caladreas/java-docker-signal-demo:no-tini
        init: true
```

#### With Docker Swarm

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

## How To Be Told What You Want To Hear

You've made it this far; your tenets are reachable so you can inform them if they need to act. However, there's another problem lurking around the corner. Do they speak your language?

Our process now starts knowing it can be talked to, it has someone who takes care of listening for it and its children. Now we need to make sure it can understand what it hears, it should be able to handle the incoming signals. We have two main ways of doing this.

* **Handle signals as they come**: we should make sure our process deal with the signals as they come
* **State the signals we want**: we can also tell up front, which signals we want to hear and put the burden of translation on our callers

For more details on the subject of Signals and Docker, please read this excellent blog from [Grigorii Chudnov](https://medium.com/@gchudnov/trapping-signals-in-docker-containers-7a57fdda7d86).

### Handle signals as they come

Handling process signals depend on your application, programming language or framework.


### State the signals we want

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

## How To Be Told When You Want To Hear It

Our process now will now start knowing it will hear what it wants to hear. But we now have to make sure we hear it when we need to hear it. An intervention is excellent when you can still be saved, but it is a bit useless if you're already dead.

### Docker

You can either configure your health check in your [Dockerfile](https://docs.docker.com/engine/reference/builder/#healthcheck) or
 configure it in your [docker-compose.yml](https://docs.docker.com/compose/compose-file/#healthcheck) for either compose or swarm.

Considering only Docker can use the health check in your Dockerfile, 
 it is strongly recommended to have health checks in your application and document how they can be used.

### Kubernetes

In Kubernetes we have the concept of [Container Probes](https://kubernetes.io/docs/concepts/workloads/pods/pod-lifecycle/#container-probes).
This allows you to configure whether your container is ready (readinessProbe) to be used and if it is still working as expected (livenessProbe).
