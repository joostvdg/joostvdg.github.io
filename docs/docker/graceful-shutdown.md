title: Docker Graceful Shutdown
description: Have To Achieve Graceful Shutdown In Docker Containers

# Gracefully Shutting Down Applications in Docker

I'm not sure about you, but I prefer it when my neighbors leave our shared spaces clean and don't take up parking spaces when they don't need them.

Imagine you live in an apartment complex with the above-mentioned parking lot. Some tenants go away and never come back. If nothing is done to clean up after them - to reclaim their apartment and parking space - then after some time, more and more apartments are unavailable for no reason, and the parking lot fills with cars which belong to no one.

Some tenants did not get a parking lot and are getting frustrated that none are becoming available. When they moved in, they were told that when others leave, they would be next in line. While they're waiting, they have to park outside the complex. Eventually, the entrance gets blocked and no one can enter or leave. The end result is a completely unlivable apartment block with trapped tenants - never to be seen or heard from again.

If you agree with me that when a tenant leaves, they should clean the apartment and free the parking spot to make it ready for the next inhabitant; then please read on. We're going to dive into the equivalent of doing this with containers.

We will explore running our containers with Docker (run, compose, swarm) and Kubernetes.
Even if you use another way to run your containers, this article should provide you with enough insight to get you on your way.

## The case for graceful shutdown

We're in an age where many applications are running in Docker containers across a multitude of clusters. These applications are then confronted with new concerns to tackle such as more moving parts, networking between these parts, remote storage and others. One significant way we defend ourselves against the perils of this distributed nature is to make our applications more robust - able to survive errors.

However, even then there is still no guarantee your application is always up and running. So another concern we should tackle is how it responds when it needs to shut down. Where we can differentiate between an unexpected shutdown - we crashed - or an expected shutdown. On top of that, failing instead of trying to recover when something bad happens also adheres to "fail fast" - as strongly advocated by Michael Nygard in ReleaseIt.

Shutting down can happen for a variety of reasons, in this post we dive into how to deal with an expected shutdown such as it being told to stop by an orchestrator such as Kubernetes.

Containers can be purposefully shut down for a variety of reasons, including but not limited too:

* your application's health check fails
* your application consumed more resources than allowed
* the application is scaling down

Just as cleaning up when leaving makes you a better tenant, having your application clean up connections, resources Moreover, the more tenants behaving in a good way increases the quality of living for all tenants. In our case, it improves the reliability and consistency of our cluster.

Graceful shutdown is not unique to Docker, as it has been part of Linux's best practices for quite some years before Docker's existence. However, applying them to Docker container adds extra dimensions.

## Start Good So You Can End Well

When you sign up for an apartment, you probably have to sign a contract detailing your rights and obligations. The more you state explicitly, the easier it is to deal with bad behaving neighbors. The same is true when running processes; we should make sure that we set the rules, obligations, and expectations from the start.

As we say in Dutch: a good beginning is half the work. We will start with how you can run a process in a container with a process that shuts down gracefully.

There are many ways to start a process in a container. In this article, we look at processes started by commands defined in a Dockerfile. There are two ways to specify this:

* **CMD**: runs a command when the container gets started
* **ENTRYPOINT**: provides the location (entrypoint) from where commands get run when the container starts

You need at least one ENTRYPOINT or CMD in a Dockerfile for it to be valid. They can be used in collaboration but they can do similar things.

For more information on the details of these commands, read [Docker's docs on Entrypoint vs. CMD](https://docs.docker.com/engine/reference/builder/#exec-form-entrypoint-example).


### Docker Shell form example

We start with the shell form and see if it can do what we want; begin in such a way, we can stop it nicely.
Shell form means we define a shell command without any special format or keywords.

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

The above command yields the following output.

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
This happens because the *sh* process forked the *top* process, but the termination will only be send to PID 1 - in this case *sh*.
As *sh* will not stop the *top* process for us it will continue running and leave the container alive.

To kill this container, open a second terminal and execute the following command.

```bash
docker rm -f shell-form
```

Shell form doesn't do what we need. Starting a process with shell form will only lead us to the disaster of parking lots filling up unless there's a someone actively cleaning up.

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

## Examples

How to actually listen to the signals and determine which one to use will depend on your programming language.

There's three examples I have worked out, one for Go (lang) and two for Java: pojo and Spring Boot.


### Go

#### Dockerfile

```bash
# build stage
FROM golang:latest AS build-env
RUN go get -v github.com/docker/docker/client/...
RUN go get -v github.com/docker/docker/api/...
ADD src/ $GOPATH/flow-proxy-service-lister
WORKDIR $GOPATH/flow-proxy-service-lister
RUN go build -o main -tags netgo main.go

# final stage
FROM alpine
ENTRYPOINT ["/app/main"]
COPY --from=build-env /go/flow-proxy-service-lister/main /app/
RUN chmod +x /app/main
```

#### Go code for graceful shutdown

The following is a way for Go to shutdown a http server when receiving a termination signal.

```go
func main() {
    c := make(chan bool) // make channel for main <--> webserver communication
	go webserver.Start("7777", webserverData, c) // ignore the missing data

	stop := make(chan os.Signal, 1) // make a channel that listens to is signals
	signal.Notify(stop, syscall.SIGINT, syscall.SIGTERM) // we listen to some specific syscall signals

	for i := 1; ; i++ { // this is still infinite
		t := time.NewTicker(time.Second * 30) // set a timer for the polling
		select {
		case <-stop: // this means we got a os signal on our channel
			break // so we can stop
		case <-t.C:
			// our timer expired, refresh our data
			continue // and continue with the loop
		}
		break
	}
	fmt.Println("Shutting down webserver") // if we got here, we have to inform the webserver to close shop
	c <- true // we do this by sending a message on the channel
	if b := <-c; b { // when we get true back, that means the webserver is doing with a graceful shutdown
		fmt.Println("Webserver shut down") // webserver is done
	}
	fmt.Println("Shut down app") // we can close shop ourselves now
}
```

### Java plain (Docker Swarm)

This application is a Java 9 modular application, which can be found on github, [github.com/joostvdg](https://github.com/joostvdg/buming).

#### Dockerfile

```dockerfile
FROM openjdk:9-jdk AS build

RUN mkdir -p /usr/src/mods/jars
RUN mkdir -p /usr/src/mods/compiled

COPY . /usr/src
WORKDIR /usr/src

RUN javac -Xlint:unchecked -d /usr/src/mods/compiled --module-source-path /usr/src/src $(find src -name "*.java")
RUN jar --create --file /usr/src/mods/jars/joostvdg.dui.logging.jar --module-version 1.0 -C /usr/src/mods/compiled/joostvdg.dui.logging .
RUN jar --create --file /usr/src/mods/jars/joostvdg.dui.api.jar --module-version 1.0 -C /usr/src/mods/compiled/joostvdg.dui.api .
RUN jar --create --file /usr/src/mods/jars/joostvdg.dui.client.jar --module-version 1.0 -C /usr/src/mods/compiled/joostvdg.dui.client .
RUN jar --create --file /usr/src/mods/jars/joostvdg.dui.server.jar --module-version 1.0  -e com.github.joostvdg.dui.server.cli.DockerApp\
    -C /usr/src/mods/compiled/joostvdg.dui.server .

RUN rm -rf /usr/bin/dui-image
RUN jlink --module-path /usr/src/mods/jars/:/${JAVA_HOME}/jmods \
    --add-modules joostvdg.dui.api \
    --add-modules joostvdg.dui.logging \
    --add-modules joostvdg.dui.server \
    --add-modules joostvdg.dui.client \
    --launcher dui=joostvdg.dui.server \
    --output /usr/bin/dui-image

RUN ls -lath /usr/bin/dui-image
RUN ls -lath /usr/bin/dui-image
RUN /usr/bin/dui-image/bin/java --list-modules

FROM debian:stable-slim
LABEL authors="Joost van der Griendt <joostvdg@gmail.com>"
LABEL version="0.1.0"
LABEL description="Docker image for playing with java applications in a concurrent, parallel and distributed manor."
# Add Tini - it is already included: https://docs.docker.com/engine/reference/commandline/run/
ENV TINI_VERSION v0.16.1
ADD https://github.com/krallin/tini/releases/download/${TINI_VERSION}/tini /tini
RUN chmod +x /tini
ENTRYPOINT ["/tini", "-vv","-g", "--", "/usr/bin/dui/bin/dui"]
ENV DATE_CHANGED="20180120-1525"
COPY --from=build /usr/bin/dui-image/ /usr/bin/dui
RUN /usr/bin/dui/bin/java --list-modules
```

#### Handling code

The code first initializes the server which and when started, creates the [Shutdown Hook](https://docs.oracle.com/javase/7/docs/technotes/guides/lang/hook-design.html).

Java handles certain signals in specific ways, as can be found [in this table](https://docs.oracle.com/javase/8/docs/technotes/guides/troubleshoot/signals006.html#CIHBHCFE) for linux.
For more information, you can read the [docs from Oracle](https://docs.oracle.com/javase/8/docs/technotes/guides/troubleshoot/signals.html). 

```java
public class DockerApp {
    public static void main(String[] args) {
        ServiceLoader<Logger> loggers = ServiceLoader.load(Logger.class);
                Logger logger = loggers.findFirst().isPresent() ? loggers.findFirst().get() : null;
                if (logger == null) {
                    System.err.println("Did not find any loggers, quiting");
                    System.exit(1);
                }
                logger.start(LogLevel.INFO);
        
                int pseudoRandom = new Random().nextInt(ProtocolConstants.POTENTIAL_SERVER_NAMES.length -1);
                String serverName = ProtocolConstants.POTENTIAL_SERVER_NAMES[pseudoRandom];
                int listenPort = ProtocolConstants.EXTERNAL_COMMUNICATION_PORT_A;
                String multicastGroup = ProtocolConstants.MULTICAST_GROUP;
        
                DuiServer distributedServer = DuiServerFactory.newDistributedServer(listenPort,multicastGroup , serverName, logger);
        
                distributedServer.logMembership();
        
                ExecutorService executorService = Executors.newFixedThreadPool(1);
                executorService.submit(distributedServer::startServer);
        
                long threadId = Thread.currentThread().getId();
        
                Runtime.getRuntime().addShutdownHook(new Thread(() -> {
                    System.out.println("Shutdown hook called!");
                    logger.log(LogLevel.WARN, "App", "ShotdownHook", threadId, "Shutting down at request of Docker");
                    distributedServer.stopServer();
                    distributedServer.closeServer();
                    executorService.shutdown();
                    try {
                        Thread.sleep(100);
                        executorService.shutdownNow();
                        logger.stop();
                    } catch (InterruptedException e) {
                        e.printStackTrace();
                    }
                }));        
    }
}
```

### Java Plain (Kubernetes)

So far we've utilized the utilities from Docker itself in conjunction with it's native Docker Swarm orchestrator.

Unfortunately, when it comes to popularity [Kubernetes beats Swarm hands down](https://platform9.com/blog/kubernetes-docker-swarm-compared/).

So this isn't complete if it doesn't also do graceful shutdown in Kubernetes. 

#### In Dockerfile

Our original file had to be changed, as Debian's Slim image doesn't actually contain the kill package.
And we need a kill package, as we cannot instruct Kubernetes to issue a specific SIGNAL.
Instead, we can issue a [PreStop exec command](https://kubernetes.io/docs/concepts/containers/container-lifecycle-hooks/), which we can utilise to execute a [killall](https://packages.debian.org/wheezy/psmisc) java [-INT](https://www.tecmint.com/how-to-kill-a-process-in-linux/).

The command will be specified in the Kubernetes deployment definition below.

```dockerfile
FROM openjdk:9-jdk AS build

RUN mkdir -p /usr/src/mods/jars
RUN mkdir -p /usr/src/mods/compiled

COPY . /usr/src
WORKDIR /usr/src

RUN javac -Xlint:unchecked -d /usr/src/mods/compiled --module-source-path /usr/src/src $(find src -name "*.java")
RUN jar --create --file /usr/src/mods/jars/joostvdg.dui.logging.jar --module-version 1.0 -C /usr/src/mods/compiled/joostvdg.dui.logging .
RUN jar --create --file /usr/src/mods/jars/joostvdg.dui.api.jar --module-version 1.0 -C /usr/src/mods/compiled/joostvdg.dui.api .
RUN jar --create --file /usr/src/mods/jars/joostvdg.dui.client.jar --module-version 1.0 -C /usr/src/mods/compiled/joostvdg.dui.client .
RUN jar --create --file /usr/src/mods/jars/joostvdg.dui.server.jar --module-version 1.0  -e com.github.joostvdg.dui.server.cli.DockerApp\
    -C /usr/src/mods/compiled/joostvdg.dui.server .

RUN rm -rf /usr/bin/dui-image
RUN jlink --module-path /usr/src/mods/jars/:/${JAVA_HOME}/jmods \
    --add-modules joostvdg.dui.api \
    --add-modules joostvdg.dui.logging \
    --add-modules joostvdg.dui.server \
    --add-modules joostvdg.dui.client \
    --launcher dui=joostvdg.dui.server \
    --output /usr/bin/dui-image

RUN ls -lath /usr/bin/dui-image
RUN ls -lath /usr/bin/dui-image
RUN /usr/bin/dui-image/bin/java --list-modules

FROM debian:stable-slim
LABEL authors="Joost van der Griendt <joostvdg@gmail.com>"
LABEL version="0.1.0"
LABEL description="Docker image for playing with java applications in a concurrent, parallel and distributed manor."
# Add Tini - it is already included: https://docs.docker.com/engine/reference/commandline/run/
ENV TINI_VERSION v0.16.1
ADD https://github.com/krallin/tini/releases/download/${TINI_VERSION}/tini /tini
RUN chmod +x /tini
ENTRYPOINT ["/tini", "-vv","-g", "--", "/usr/bin/dui/bin/dui"]
ENV DATE_CHANGED="20180120-1525"
RUN apt-get update && apt-get install --no-install-recommends -y psmisc=22.* && rm -rf /var/lib/apt/lists/*
COPY --from=build /usr/bin/dui-image/ /usr/bin/dui
RUN /usr/bin/dui/bin/java --list-modules
```

#### Kubernetes Deployment

So here we have the image's K8s [Deployment]() descriptor.

Including the Pod's [lifecycle]() ```preStop``` with a exec style command. You should know by now [why we prefer that](http://www.johnzaccone.io/entrypoint-vs-cmd-back-to-basics/).

```yaml
apiVersion: extensions/v1beta1
kind: Deployment
metadata:
  name: dui-deployment
  namespace: default
  labels:
    k8s-app: dui
spec:
  replicas: 3
  template:
    metadata:
      labels:
        k8s-app: dui
    spec:
      containers:
        - name: master
          image: caladreas/buming
          ports:
            - name: http
              containerPort: 7777
          lifecycle:
            preStop:
              exec:
                command: ["killall", "java" , "-INT"]
      terminationGracePeriodSeconds: 60
```

### Java Spring Boot (1.x)

This example is for Spring Boot 1.x, in time we will have an example for 2.x.

This example is for the scenario of a Fat Jar with Tomcat as container [^8].

#### Execute example

```bash
docker-compose build
```

Execute the following command:

```bash
docker run --rm -ti --name test spring-boot-graceful
```

Exit the application/container via ```ctrl+c``` and you should see the application shutting down gracefully.

```bash
2018-01-30 13:35:46.327  INFO 7 --- [       Thread-3] ationConfigEmbeddedWebApplicationContext : Closing org.springframework.boot.context.embedded.AnnotationConfigEmbeddedWebApplicationContext@6e5e91e4: startup date [Tue Jan 30 13:35:42 GMT 2018]; root of context hierarchy
2018-01-30 13:35:46.405  INFO 7 --- [       Thread-3] BootGracefulApplication$GracefulShutdown : Tomcat was shutdown gracefully within the allotted time.
2018-01-30 13:35:46.408  INFO 7 --- [       Thread-3] o.s.j.e.a.AnnotationMBeanExporter        : Unregistering JMX-exposed beans on shutdown
``` 

#### Dockerfile

```dockerfile
FROM maven:3-jdk-8 AS build
ENV MAVEN_OPTS=-Dmaven.repo.local=/usr/share/maven/repository
ENV WORKDIR=/usr/src/graceful
RUN mkdir $WORKDIR
WORKDIR $WORKDIR
COPY pom.xml $WORKDIR
RUN mvn -B -e org.apache.maven.plugins:maven-dependency-plugin:3.0.2:go-offline
COPY . $WORKSPACE
RUN mvn -B -e clean verify

FROM anapsix/alpine-java:8_jdk_unlimited
LABEL authors="Joost van der Griendt <joostvdg@gmail.com>"
ENV TINI_VERSION v0.16.1
ADD https://github.com/krallin/tini/releases/download/${TINI_VERSION}/tini /tini
RUN chmod +x /tini
ENTRYPOINT ["/tini", "-vv","-g", "--"]
ENV DATE_CHANGED="20180120-1525"
COPY --from=build /usr/src/graceful/target/spring-boot-graceful.jar /app.jar
CMD ["java", "-Xms256M","-Xmx480M", "-Djava.security.egd=file:/dev/./urandom", "-jar", "/app.jar"]
```

#### Docker compose file

```yaml
version: "3.5"

services:
  web:
    image: spring-boot-graceful
    build: .
    stop_signal: SIGINT
```

#### Java handling code

```java
package com.github.joostvdg.demo.springbootgraceful;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;

import org.apache.catalina.connector.Connector;
import org.apache.tomcat.util.threads.ThreadPoolExecutor;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import org.springframework.boot.context.embedded.ConfigurableEmbeddedServletContainer;
import org.springframework.boot.context.embedded.EmbeddedServletContainerCustomizer;
import org.springframework.boot.context.embedded.tomcat.TomcatConnectorCustomizer;
import org.springframework.boot.context.embedded.tomcat.TomcatEmbeddedServletContainerFactory;
import org.springframework.context.ApplicationListener;
import org.springframework.context.annotation.Bean;
import org.springframework.context.event.ContextClosedEvent;

import java.util.concurrent.Executor;
import java.util.concurrent.TimeUnit;

@SpringBootApplication
public class SpringBootGracefulApplication {

	public static void main(String[] args) {
		SpringApplication.run(SpringBootGracefulApplication.class, args);
	}

    @Bean
    public GracefulShutdown gracefulShutdown() {
        return new GracefulShutdown();
    }

    @Bean
    public EmbeddedServletContainerCustomizer tomcatCustomizer() {
        return new EmbeddedServletContainerCustomizer() {

            @Override
            public void customize(ConfigurableEmbeddedServletContainer container) {
                if (container instanceof TomcatEmbeddedServletContainerFactory) {
                    ((TomcatEmbeddedServletContainerFactory) container)
                            .addConnectorCustomizers(gracefulShutdown());
                }

            }
        };
    }

    private static class GracefulShutdown implements TomcatConnectorCustomizer,
            ApplicationListener<ContextClosedEvent> {

        private static final Logger log = LoggerFactory.getLogger(GracefulShutdown.class);

        private volatile Connector connector;

        @Override
        public void customize(Connector connector) {
            this.connector = connector;
        }

        @Override
        public void onApplicationEvent(ContextClosedEvent event) {
            this.connector.pause();
            Executor executor = this.connector.getProtocolHandler().getExecutor();
            if (executor instanceof ThreadPoolExecutor) {
                try {
                    ThreadPoolExecutor threadPoolExecutor = (ThreadPoolExecutor) executor;
                    threadPoolExecutor.shutdown();
                    if (!threadPoolExecutor.awaitTermination(30, TimeUnit.SECONDS)) {
                        log.warn("Tomcat thread pool did not shut down gracefully within "
                                + "30 seconds. Proceeding with forceful shutdown");
                    } else {
                        log.info("Tomcat was shutdown gracefully within the allotted time.");
                    }
                }
                catch (InterruptedException ex) {
                    Thread.currentThread().interrupt();
                }
            }
        }

    }
}
```

## Example with Docker Swarm

For now there's only an example with [docker swarm](https://docs.docker.com/engine/swarm/), in time there will also be a [Kubernetes](https://kubernetes.io/) example.

Now that you can create Java applications packaged neatly in Docker images that support graceful shutdown, it would be nice to utilize.

A good scenario would be a microservices architecture where services can come and go, but are registered in a [service registry such as Eureka](https://spring.io/guides/gs/service-registration-and-discovery/).

Or a membership based protocol where members interact with each other and perhaps shard data.

In these cases, of course the interactions are designed to be fault tolerant and discover faulty nodes on their own.
But wouldn't it be better that if you knew you're going to quit, you inform the rest?

We can reuse the ```caladreas/buming``` image and make it a docker swarm stack and run the service on every node.
This way, we can easily see members coming and going and reduce the time to detect failure by notifying our peers of our impeding end.  

### Docker swarm cluster

Setting up a docker swarm cluster is easy, but has some requirements:

* virtual box 4.x+
* docker-machine 1.12+
* docker 17.06+

!!! warn
    Make sure this is the first and only virtualbox docker-machine VM being created/running, so that the ip range starts with 192.168.99.100

```bash
docker-machine create --driver virtualbox dui-1
docker-machine create --driver virtualbox dui-2
docker-machine create --driver virtualbox dui-3

eval "$(docker-machine env dui-1)"
IP=192.168.99.100
docker swarm init --advertise-addr $IP
TOKEN=$(docker swarm join-token -q worker)

eval "$(docker-machine env dui-2)"
docker swarm join --token ${TOKEN} ${IP}:2377

eval "$(docker-machine env dui-3)"
docker swarm join --token ${TOKEN} ${IP}:2377

eval "$(docker-machine env dui-1)"
docker node ls
```

### Docker swarm network and multicast

Unfortunately, docker swarm's swarm mode network [overlay](http://blog.nigelpoulton.com/demystifying-docker-overlay-networking/) does not support multicast [^9][^10].

Why is this a problem? Well, the application I use to test the graceful shutdown requires this, sorry.

Luckily there is a very easy solution for this, its by using [Weavenet](https://www.weave.works/blog/weave-net-2-released)'s docker network plugin.

Don't want to know about it or how you install it? Don't worry, just execute the script below.

```bash
#!/usr/bin/env bash
echo "=> Prepare dui-2"
eval "$(docker-machine env dui-2)"
docker plugin install weaveworks/net-plugin:2.1.3 --grant-all-permissions
docker plugin disable weaveworks/net-plugin:2.1.3
docker plugin set weaveworks/net-plugin:2.1.3 WEAVE_MULTICAST=1
docker plugin enable weaveworks/net-plugin:2.1.3

echo "=> Prepare dui-3"
eval "$(docker-machine env dui-3)"
docker plugin install weaveworks/net-plugin:2.1.3 --grant-all-permissions
docker plugin disable weaveworks/net-plugin:2.1.3
docker plugin set weaveworks/net-plugin:2.1.3 WEAVE_MULTICAST=1
docker plugin enable weaveworks/net-plugin:2.1.3

echo "=> Prepare dui-1"
eval "$(docker-machine env dui-1)"
docker plugin install weaveworks/net-plugin:2.1.3 --grant-all-permissions
docker plugin disable weaveworks/net-plugin:2.1.3
docker plugin set weaveworks/net-plugin:2.1.3 WEAVE_MULTICAST=1
docker plugin enable weaveworks/net-plugin:2.1.3
docker network create --driver=weaveworks/net-plugin:2.1.3 --opt works.weave.multicast=true --attachable dui
```

### Docker stack

Now to create a service that runs on every node it is the easiest to create a [docker stack](https://docs.docker.com/get-started/part5/).

#### Compose file (docker-stack.yml)

```yaml
version: "3.5"

services:
  dui:
    image: caladreas/buming
    build: .
    stop_signal: SIGINT
    networks:
      - dui
    deploy:
      mode: global
networks:
  dui:
    external: true
```

#### Create stack

```bash
docker stack deploy --compose-file docker-stack.yml buming
```

### Execute example

Now that we have a docker swarm cluster and a stack - which has a service running on every node - we can showcase the power of graceful shutdown in a cluster of dependent services.

Confirm the service is running correctly on every node, first lets check our nodes.

```bash
eval "$(docker-machine env dui-1)"
docker node ls
```
Which should look like this:

```bash
ID                            HOSTNAME            STATUS              AVAILABILITY        MANAGER STATUS
f21ilm4thxegn5xbentmss5ur *   dui-1               Ready               Active              Leader
y7475bo5uplt2b58d050b4wfd     dui-2               Ready               Active              
6ssxola6y1i6h9p8256pi7bfv     dui-3               Ready               Active                            
```

Then check the service.

```bash
docker service ps buming_dui
```

Which should look like this.

```bash
ID                  NAME                                   IMAGE               NODE                DESIRED STATE       CURRENT STATE            ERROR               PORTS
3mrpr0jg31x1        buming_dui.6ssxola6y1i6h9p8256pi7bfv   dui:latest          dui-3               Running             Running 17 seconds ago                       
pfubtiy4j7vo        buming_dui.f21ilm4thxegn5xbentmss5ur   dui:latest          dui-1               Running             Running 17 seconds ago                       
f4gjnmhoe3y4        buming_dui.y7475bo5uplt2b58d050b4wfd   dui:latest          dui-2               Running             Running 17 seconds ago                       
```

Now open a second terminal window.
In window one, follow the service logs:

```bash
eval "$(docker-machine env dui-1)"
docker service logs -f buming_dui
```

In window two, go to a different node and stop the container.

```bash
eval "$(docker-machine env dui-2)"
docker ps
docker stop buming_dui.y7475bo5uplt2b58d050b4wfd.pnoui2x6elrz0tvkjz51njz94
```

In this case, you will see the other nodes receiving a leave notice and then the node stopping.

```bash
buming_dui.0.ryd8szexxku3@dui-3    | [Server-John D. Carmack]			[WARN]	[14:19:02.604011]	[16]	[Main]				Received membership leave notice from MessageOrigin{host='83918f6ad817', ip='10.0.0.7', name='Ken Thompson'}
buming_dui.0.so5m14sz8ksh@dui-1    | [Server-Alan Kay]				    [WARN]	[14:19:02.602082]	[16]	[Main]				Received membership leave notice from MessageOrigin{host='83918f6ad817', ip='10.0.0.7', name='Ken Thompson'}
buming_dui.0.pnoui2x6elrz@dui-2    | Shutdown hook called!
buming_dui.0.pnoui2x6elrz@dui-2    | [App]						        [WARN]	[14:19:02.598759]	[1]	[ShotdownHook]		Shutting down at request of Docker
buming_dui.0.pnoui2x6elrz@dui-2    | [Server-Ken Thompson]			    [INFO]	[14:19:02.598858]	[12]	[Main]				 Stopping
buming_dui.0.pnoui2x6elrz@dui-2    | [Server-Ken Thompson]			    [INFO]	[14:19:02.601008]	[12]	[Main]				 Closing
```

## Further reading

* [Wikipedia page on reboots](https://en.wikipedia.org/wiki/Reboot_(computing))
* [Microsoft about graceful shutdown](https://msdn.microsoft.com/en-us/library/windows/desktop/ms738547(v=vs.85).aspx)
* [Gracefully stopping docker containers](https://www.ctl.io/developers/blog/post/gracefully-stopping-docker-containers/)
* [What to know about Java and shutdown hooks](https://dzone.com/articles/know-jvm-series-2-shutdown)
* https://www.weave.works/blog/docker-container-networking-multicast-fast/
* https://www.weave.works/docs/net/latest/install/plugin/plugin-how-it-works/
* https://www.weave.works/docs/net/latest/install/plugin/plugin-v2/
* https://www.auzias.net/en/docker-network-multihost/
* https://forums.docker.com/t/cannot-get-zookeeper-to-work-running-in-docker-using-swarm-mode/27109
* https://github.com/docker/libnetwork/issues/740
