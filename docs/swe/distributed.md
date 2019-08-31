title: Distributed Computing Fundamentals
description: An Introduction To The Fundamentals Of Distributed Computing

# Distributed Computing

## Distributed Computing fundamentals

### Time and Event ordering

See: [Lamport timestamp](https://en.wikipedia.org/wiki/Lamport_timestamps)

## Distributed Applications

### Topics to take into account

* logging 
    * structured
    * pulled into central log service
    * Java: SLF4J + LogBack?
    * Go: logrus
* tracing 
    * sampling based
* metrics
    * prometheus
    * including alert definitions
* network connection stability
    * services discovery
    * loadbalancing
    * circuit brakers
    * backpressure
    * shallow queues
    * connection pools
    * dynamic/randomized backoff procedures
* network connection performance
    * 3-step handshake
    * binary over http
    * standard protocols
    * thin wrapper for UI: GraphQL
    * thick wrapper for UI: JSON over HTTP (restful)
    * Service to Service: gRPC / twirp

## Designing Distributed Systems - Brandon Burns

### Sidecar pattern

```bash
docker run -d <my-app-image>
```

> After you run that image, you will receive the identifier for that specific container. It will look something like: cccf82b85000... If you don’t have it, you can always look it up using the docker ps command, which will show all currently running containers. Assuming you have stashed that value in an environment variable named APP_ID, you can then run the topz container in the same PID namespace using:

```bash
docker run --pid=container:${APP_ID} \ -p 8080:8080 brendanburns/topz:db0fa58 /server --address=0.0.0.0:8080
```

## Resources

* [Coursera course](https://www.coursera.org/learn/cloud-computing)
* [Article on synchronization in a distributed system](https://8thlight.com/blog/rylan-dirksen/2013/10/04/synchronization-in-a-distributed-system.html)
* http://label-schema.org/
* https://engineering.linkedin.com/distributed-systems/log-what-every-software-engineer-should-know-about-real-time-datas-unifying
* https://blog.envoyproxy.io/introduction-to-modern-network-load-balancing-and-proxying-a57f6ff80236
* https://eng.lyft.com/announcing-envoy-c-l7-proxy-and-communication-bus-92520b6c8191
* https://blog.envoyproxy.io/service-mesh-data-plane-vs-control-plane-2774e720f7fc
* https://cse.buffalo.edu/~demirbas/publications/cloudConsensus.pdf
* http://www.read.seas.harvard.edu/~kohler/class/08w-dsi/chandra07paxos.pdf
* https://medium.com/source-code/understanding-the-memcached-source-code-slab-i-9199de613762
