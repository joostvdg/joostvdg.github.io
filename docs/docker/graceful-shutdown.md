# Docker & Graceful shutdown

## The case for graceful shutdown

> We can speak about the graceful shutdown of our application, when all of the resources it used and all of the traffic and/or data processing what it handled are closed and released properly.
  It means that no database connection remains open and no ongoing request fails because we stop our application. [^1]

I thank [Péter Márton](https://blog.risingstack.com/graceful-shutdown-node-js-kubernetes/) for the quote and giving a nice case for the graceful shutdown and docker.
Where his blog post goes into how to do this with/for Kubernetes, I will do this for Docker's Swarm (mode) orchestrator.

So, the case for graceful shutdown.
As the quote shows, what we mean with it, is that an application shuts down gracefully if it cleans up all its mess.

All things considered, I think most people would agree that cleaning up your mess - resources, connections or saying goodbye is preferred above just disappearing. 

Shutting down nicely and leaving nothing behind will reduce the amount of potential (hard to debug) errors.
It also allows other applications or services to reliably know when you are there and when you're not there.
Not every application will have such dependencies (to it), but in today's cluster environments with many moving parts you'll never know.

So I would recommend to always do a graceful shutdown if you're able.
In the light of Docker, that might be a bit different than you're use to.

## Exec (form) vs Shell (form)

There are several ways to run a command in a ```Dockerfile```.

These are are:

* **RUN**: runs a command during the docker build phase
* **CMD**: runs a command when the container gets started
* **ENTRYPOINT**: provides the location from where commands get run when the container starts

!!! note
    You need at least one ENTRYPOINT or CMD in a Dockerfile for it to be valid.
    They can be used in collaboration but they can do similar things.

Al these commands can be put in both a shell form and a exec form [^2]. For more information on these commands you should check out [John Zaccone's blog on Entrypoint vs CMD](http://www.johnzaccone.io/entrypoint-vs-cmd-back-to-basics/).

In summary, the shell form will run the command as a shell command and spawn a process via ```/bin/sh -c```.

Whereas the exec form will execute a child process that is still attached to PID1 [^4].

This means that if you run the examples below, you will notice that you cannot ```ctrl+c``` out of the shell form, but you **can** out of the exec form.

Exec form is the recommended form to use and is a requirement for graceful shutdown.
Below you'll find some further reading on the CMD and ENTRYPOINT commands [^5][^6].

### Shell form example

```dockerfile
FROM alpine  
ENTRYPOINT ping www.google.com  # "shell" format  
``` 
[^3]

### Exec form example

```dockerfile
FROM alpine  
ENTRYPOINT ["ping", "www.google.com"]  # "exec" format  
```
[^3]

## PID1

Now you run your commands nicely as PID1 and make sure it is your process that receives the [SIGNALS](http://man7.org/linux/man-pages/man7/signal.7.html).

Then all is good for a while, but at one point you will run into the problems of either having [zombie child processes](https://blog.phusion.nl/2015/01/20/docker-and-the-pid-1-zombie-reaping-problem) or [processes that aren't designed for running as PID1](https://www.fpcomplete.com/blog/2016/10/docker-demons-pid1-orphans-zombies-signals).

This means you will have to do something about this, and luckily there's already some people who have done this for you.

There's [tini](https://github.com/krallin/tini): a tiny initialization system designed for Docker.

If used with the *exec* form it will run as PID1 and will manage your process and its child processes for you.

For what it adds exactly and why it was introduced, you can rever to [this excellent explanation from its creator](https://github.com/krallin/tini/issues/8).

In fact, tini was so successful, that [docker included it in docker](https://github.com/krallin/tini/issues/81)!

While it works for ```docker run``` and [docker compose](https://docs.docker.com/compose/compose-file/compose-file-v2/#init) it doesn't yet work for Docker Swarm stacks.

### Example docker run with init

```bash hl_lines="4"
docker run \ 
    --rm \
    -ti \
    --init\
    --name dui-test\
     dui
```

### Example Dockerfile with tini

```dockerfile
FROM debian:stable-slim
ENV TINI_VERSION v0.16.1
ADD https://github.com/krallin/tini/releases/download/${TINI_VERSION}/tini /tini
RUN chmod +x /tini
ENTRYPOINT ["/tini", "-vv","-g", "--", "/usr/bin/dui"]
COPY --from=build /usr/bin/dui-image/ /usr/bin/dui
```
Tini will be the entrypoint, executing our own user program (/usr/bin/dui).

This can also be achieved as follows:

```dockerfile
ENTRYPOINT ["/tini", "-vv","-g", "--"]
CMD["/usr/bin/dui"]
```

* **-vv**: debug log level 2 (-v =1, -vv=2, -vvv=3)
* **-g**: kill the entire group of processes when signal is received
* **--**: end of tini and start of your command 

## Signals

Now that we can correctly respond to signals we need to take care of which signals to listen to.

> There are essentially two commands: `docker stop` and `docker kill` that can be used to stop it. Behind the scenes, `docker stop` stops a running container by sending it SIGINT signal, let the main process process it, and after a grace period uses SIGKILL to terminate the application. [^7]

You can test it with the following image, which uses Java's shutdown hook to shutdown gracefully: this only happens when it is stopped.
Run the command below and press ```ctrl+c```, and you will see that the application shuts down gracefully.

```bash
docker run --rm -ti --name test caladreas/buming
```
Make sure you have two terminal windows open. In terminal one, run this command:

```bash
docker run -d --name test caladreas/buming
docker logs -f test
```

In terminal two, run this command:

```bash
docker rm -f test
```

And now you will not see the graceful shutdown log, as the JVM was killed without being allowed to call shutdown hooks.

Docker allows you to specify which signal it should send via ```--stop-signal``` in the run command or ```stop_signal: ``` in a compose file.

```yaml
version: "3.5"

services:
  yi:
    image: dui
    build: .
    stop_signal: SIGINT
```

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

## References

[^1]: [Péter Márton(@slashdotpeter) Gracefule Shutdown NodeJS Kubernetes](https://blog.risingstack.com/graceful-shutdown-node-js-kubernetes/)
[^2]: [Docker docs on building](https://docs.docker.com/engine/reference/builder/)
[^3]: [John Zaccone on Entrypoint vs CMD](http://www.johnzaccone.io/entrypoint-vs-cmd-back-to-basics/)
[^4]: [Linux Exec command](https://www.lifewire.com/exec-linux-command-unix-command-4097150)
[^5]: [Stackoverflow thread on CMD vs Entrypoint](https://stackoverflow.com/questions/21553353/what-is-the-difference-between-cmd-and-entrypoint-in-a-dockerfile)
[^6]: [Codeship blog on CMD and Entrypoint details](https://blog.codeship.com/understanding-dockers-cmd-and-entrypoint-instructions/)
[^7]: [Grigorii Chudnov blog on Trapping Docker Signals](https://medium.com/@gchudnov/trapping-signals-in-docker-containers-7a57fdda7d86)
[^8]: [Andy Wilkinson (from pivotal) explaining Spring Boot shutdown hook for Tomcat](https://github.com/spring-projects/spring-boot/issues/4657#issuecomment-161354811)
[^9]: [Docker Swarm issue with multicast](https://github.com/docker/swarm/issues/1691)
[^10]: [Docker network library issue with multicast](https://github.com/docker/libnetwork/issues/552)