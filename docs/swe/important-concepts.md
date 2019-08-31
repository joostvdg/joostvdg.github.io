title: Software Engineering Concepts
description: A Summary Of Important Software Engineering Concepts

# Software Engineering Concepts

## Resource management

When there are finite resources in your system, manage them explicitly.

Be that memory, CPU, amount of connections to a database or incoming http connections.

### Back Pressure

!!! note "Back pressure"
    When one component is struggling to keep-up, the system as a whole needs to respond in a sensible way. 
    
    It is unacceptable for the component under stress to fail catastrophically or to drop messages in an uncontrolled fashion. 
    
    Since it can’t cope and it can’t fail it should communicate the fact that it is under stress to upstream components 
    and so get them to reduce the load. This back-pressure is an important feedback mechanism that allows systems to 
    gracefully respond to load rather than collapse under it. The back-pressure may cascade all the way up to the user, 
    at which point responsiveness may degrade, but this mechanism will ensure that the system is resilient under load, 
    and will provide information that may allow the system itself to apply other resources to help distribute the load, see Elasticity.
    [^1]

Further reading:

* [DZone article](https://dzone.com/articles/applying-back-pressure-when)
* [Spotify Engineering](https://www.slideshare.net/protocol7/spotify-services-scc-2013)

### Memoization

!!! note "Memoization"
    In computing, memoization or memoisation is an optimization technique used primarily to speed up computer programs 
    by storing the results of expensive function calls and returning the cached result when the same inputs occur again. 
    
    Memoization has also been used in other contexts (and for purposes other than speed gains), 
    such as in simple mutually recursive descent parsing.

## Important Theories

* [Theory of constraints](https://en.wikipedia.org/wiki/Theory_of_constraints)
* [Law of demeter](https://en.wikipedia.org/wiki/Law_of_Demeter)
* [Conway's law](https://en.wikipedia.org/wiki/Conway%27s_law)
* [Little's law](https://en.wikipedia.org/wiki/Little%27s_law)
* [Commoditization](https://en.wikipedia.org/wiki/Commoditization)
* [Amdahl's Law](https://en.wikipedia.org/wiki/Amdahl%27s_law)

## Web Technologies

### HTTP Caching

* https://medium.freecodecamp.org/http-caching-in-depth-part-1-a853c6af99db

[^1]: [Reactive Manifesto](https://www.reactivemanifesto.org/glossary#Back-Pressure)
[^2]: [Wikipedia article on Memoization](https://en.wikipedia.org/wiki/Memoization)
