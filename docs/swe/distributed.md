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

## Resources

* [Coursera course](https://www.coursera.org/learn/cloud-computing)
* [Article on synchronization in a distributed system](https://8thlight.com/blog/rylan-dirksen/2013/10/04/synchronization-in-a-distributed-system.html)