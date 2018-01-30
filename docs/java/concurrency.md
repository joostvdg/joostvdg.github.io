# Java Concurrency

## Terminology

??? note "Correctness"
    Correctness means that a class *conforms to its specification*. 
    A good specification defines *invariants* constraining an object’s state 
    and *postconditions* describing the effects of its operations. [^6]
    
??? note "Thread Safe Class"
    a class is thread-safe when it continues to behave correctly when accessed
    from multiple threads

    No set of operations performed sequentially or concurrently on instances of a thread-safe class 
    can cause an instance to be in an invalid state. [^6]
      
??? note "Mutex"
    Every Java object can implicitly act as a lock for purposes of synchronization;
    these built-in locks are called **intrinsic locks** or **monitor locks**. 
    The lock is auto-matically acquired by the executing thread before entering a synchronized block
    and automatically released when control exits the synchronized block, whether
    by the normal control path or by throwing an exception out of the block.
    
    Intrinsic locks in Java act as **mutexes** (or **mutual exclusion locks**), which means
    that at most one thread may own the lock. When thread A attempts to acquire a
    lock held by thread B, A must wait, or block, until B releases it. If B never releases
    the lock, A waits forever. [^6]

??? note "Reentrant locks"
    When a thread requests a lock that is already held by another thread, the requesting thread blocks. 
    But because intrinsic locks are **reentrant**, if a thread tries to acquire a lock that it already holds, the request succeeds. 
    
    **Reentrancy** means that locks are acquired on a per-thread rather than per-invocation basis. 
    
    **Reentrancy** is implemented by associating with each lock an **acquisition count** and an owning **thread**. 
    When the count is zero, the lock is considered unheld. 
    
    When a thread acquires a previously unheld lock, the JVM records the owner and sets the acquisition count to one. 
    
    If that same thread acquires the lock again, the count is incremented, and when the owning thread exits the **synchronized block**, 
    the count is decremented. When the count reaches zero, the lock is released. [^6]

??? note "Liveness"
    In concurrent computing, liveness refers to a set of properties of concurrent systems, 
    that require a system to make progress despite the fact that its concurrently executing components ("processes") 
        may have to "take turns" in critical sections, parts of the program that cannot be simultaneously run by multiple processes.[^1] 
    
    Liveness guarantees are important properties in operating systems and distributed systems.[^2]
    
    A liveness property cannot be violated in a finite execution of a distributed system because the "good" event might only theoretically occur at some time after execution ends. 
    Eventual consistency is an example of a liveness property.[^3] 
    
    All properties can be expressed as the intersection of safety and liveness properties.[^4]

??? note "Volatile fields"
    When a field is declared **volatile**, the **compiler** and **runtime** are put on notice that this variable is shared 
    and that operations on it should not be reordered with other memory operations. 
    
    Volatile variables are not cached in registers or in caches where they are hidden from other processors, 
    so a read of a volatile variable always returns the **most recent write** by **any** thread. [^6]
    
    You can use volatile variables only when all the following criteria are met:

    * Writes to the variable do not depend on its current value, or you can ensure that only a single thread ever updates the value;
    * The variable does not participate in invariants with other state variables;
    * Locking is not required for any other reason while the variable is being accessed

??? note "Confinement"
    Confined objects must not escape their intended scope. 
    An object may be confined to a class instance (such as a private class member), a lexical scope (such
    as a local variable), or a thread (such as an object that is passed from method to
    method within a thread, but not supposed to be shared across threads). 
    
    Objects don’t escape on their own, of course—they need help from the developer,
     who assists by publishing the object beyond its intended scope. [^6]

??? note "Latch"
    Simply put, a CountDownLatch has a counter field, which you can decrement as we require. 
    We can then use it to block a calling thread until it’s been counted down to zero.
    
    If we were doing some parallel processing, we could instantiate the CountDownLatch with 
    the same value for the counter as a number of threads we want to work across. 
    
    Then, we could just call countdown() after each thread finishes, 
    guaranteeing that a dependent thread calling await() will block until the worker threads are finished.
    [^7]

??? note "Semaphore"
    In computer science, a semaphore is a variable or abstract data type used to control access to a common resource by multiple processes 
    in a concurrent system such as a multiprogramming operating system.
    
    A trivial semaphore is a plain variable that is changed (for example, incremented or decremented, or toggled) 
    depending on programmer-defined conditions. The variable is then used as a condition to control access to some system resource.
    
    A useful way to think of a semaphore as used in the real-world systems is as a record of how many units 
    of a particular resource are available, coupled with operations to adjust that record safely 
    (i.e. to avoid race conditions) as units are required or become free, and, if necessary, 
    wait until a unit of the resource becomes available. [^7]

??? note "Java Thread pools"
    There are several different types of Thread pools available.

    * **FixedThreadPool**: A fixed-size thread pool creates threads as tasks are submitted, 
        up to the maximum pool size, and then attempts to keep the pool
        size constant (adding new threads if a thread dies due to an unexpected Exception ).
    
    * **CachedThreadPool**: A cached thread pool has more flexibility to reap idle threads when the current size of the pool 
    exceeds the demand for processing, and to add new threads when demand increases, but places no bounds on the size of the pool.
    
    * **SingleThreadExecutor**: A single-threaded executor creates a single worker thread to process tasks, 
        replacing it if it dies unexpectedly. 
        Tasks are guaranteed to be processed sequentially according to the order imposed by the task queue (FIFO, LIFO, priority order). 4
    
    * **ScheduledThreadPool**: A fixed-size thread pool that supports delayed and periodic task execution, similar to Timer.
    [^6]

??? note "Interrupt"
    Thread provides the **interrupt** method for interrupting a thread and for querying whether a thread has been interrupted. 
    Each thread has a boolean property that represents its interrupted status; interrupting a thread sets this status.
    Interruption is a **cooperative** mechanism. 
    
    One thread cannot force another to stop what it is doing and do something else; 
    when thread A interrupts thread B, A is merely requesting that B stop what it is doing 
    when it gets to a convenient stopping point—if it feels like it.
    
    When your code calls a method that throws InterruptedException , then your
    method is a blocking method too, and must have a plan for responding to inter-
    ruption. 
    
    For library code, there are basically two choices:
    
    * **Propagate the InterruptedException**: This is often the most sensible policy if you can get away with it: 
        just propagate the InterruptedException to your caller. 
        This could involve not catching InterruptedException , or catching it and throwing it again after performing some brief activity-specific cleanup.
        
    * **Restore the interrupt**: Sometimes you cannot throw InterruptedException , for instance when your code is part of a Runnable . 
        In these situations, you must catch InterruptedException and restore the interrupted status by calling interrupt on the current thread,
         so that code higher up the call stack can see that an interrupt was issued.
    [^6]
    
## Patterns

### Queue & Deque

!!! note "Queue & Deque"
    A Deque is a double-ended queue that allows efficient insertion and removal from both the head and the tail. 
    Implementations include ArrayDeque and LinkedBlockingDeque .
    
    Just as blocking queues lend themselves to the producer-consumer pattern,
    deques lend themselves to a related pattern called work stealing. 
    
    A producer-consumer design has one shared work queue for all consumers; 
    in a work stealing design, every consumer has its own deque. 
    
    If a consumer exhausts the work in its own deque, it can steal work from the tail of someone else’s deque. 
    
    Work stealing can be more scalable than a traditional producer-consumer design 
    because workers don’t contend for a shared work queue; most of the time they access only their own deque, reducing contention. 
    
    When a worker has to access another’s queue, it does so from the tail rather than the head, further reducing contention.
    [^6]

### Monitor pattern

#### Resources

* [concurrency-patterns-monitor-object](http://www.tomaszezula.com/2014/08/30/concurrency-patterns-monitor-object/)
* [Wikipedia article on monitor pattern](https://en.wikipedia.org/wiki/Monitor_(synchronization))
* [e-zest blog on monitor pattern java](http://blog.e-zest.com/java-monitor-pattern/)

## Examples

### Confinement

> PersonSet (below) illustrates how confinement and locking can work
  together to make a class thread-safe even when its component state variables are not. 
  The state of PersonSet is managed by a HashSet , which is not thread-safe.
  
  But because mySet is private and not allowed to escape, the HashSet is confined to the PersonSet. 
  
  The only code paths that can access mySet are addPerson and containsPerson , and each of these acquires the lock on the PersonSet. 
  
  All its state is guarded by its intrinsic lock, making PersonSet thread-safe. [^6]

```java
public class PersonSet {
    @GuardedBy("this")
    private final Set<Person> mySet = new HashSet<Person>();
    
    public synchronized void addPerson(Person p) {
        mySet.add(p);
    }
    
    public synchronized boolean containsPerson(Person p) {
        return mySet.contains(p);
    }
}
```

### HTTP Call Counter

#### Unsafe Counter

```java
public class UnsafeCounter {
    private long count = 0;

    public long getCount() {
        return count;
    }

    public void service() {
        // do some work
        try {
            int pseudoRandom = new Random().nextInt(20);
            Thread.sleep(pseudoRandom * 100);
            ++count;
        } catch (InterruptedException e) {
            e.printStackTrace();
        }
    }
}

```

#### Safe Counter

```java
public class SafeCounter {

    private final AtomicLong count = new AtomicLong(0);

    public long getCount() {
        return count.get();
    }

    public void service() {
        try {
            int pseudoRandom = new Random().nextInt(20);
            Thread.sleep(pseudoRandom * 100);
            count.incrementAndGet();
        } catch (InterruptedException e) {
            e.printStackTrace();
        }
    }
}
```

#### Caller

```java
public class Server {
    public void start(int port) throws Exception {
        HttpServer server = HttpServer.create(new InetSocketAddress(port), 0);
        UnsafeCounter unsafeCounter = new UnsafeCounter();
        SafeCounter safeCounter = new SafeCounter();
        server.createContext("/test", new MyTestHandler(unsafeCounter, safeCounter));
        server.createContext("/", new MyHandler(unsafeCounter, safeCounter));
        Executor executor = Executors.newFixedThreadPool(5);
        server.setExecutor(executor); // creates a default executor
        server.start();
    }
    
    static class MyTestHandler implements HttpHandler {
        private UnsafeCounter unsafeCounter;
        private SafeCounter safeCounter;
    
        public MyTestHandler(UnsafeCounter unsafeCounter, SafeCounter safeCounter) {
            this.unsafeCounter = unsafeCounter;
            this.safeCounter = safeCounter;
        }
    
        @Override
        public void handle(HttpExchange t) throws IOException {
            safeCounter.service();
            unsafeCounter.service();
            System.out.println("Got a request on /test, counts so far:"+ unsafeCounter.getCount() + "::" + safeCounter.getCount());
            String response = "This is the response";
            t.sendResponseHeaders(200, response.length());
            try (OutputStream os = t.getResponseBody()) {
                os.write(response.getBytes());
            }
        }
    }
}
```

#### Outcome

```bash
Starting server on port 8080
Server started
Got a request on /, counts so far:2::1
Got a request on /, counts so far:6::2
Got a request on /, counts so far:6::3
Got a request on /, counts so far:6::4
Got a request on /, counts so far:6::5
Got a request on /, counts so far:6::6
```


[^1]:
    Lamport, L. (1977). "Proving the Correctness of Multiprocess Programs". IEEE Transactions on Software Engineering (2): 125–143. doi:[10.1109/TSE.1977.229904](https://doi.org/10.1109%2FTSE.1977.229904).

[^2]: 
    Luís Rodrigues, Christian Cachin; Rachid Guerraoui (2010). Introduction to reliable and secure distributed programming (2. ed.). Berlin: Springer Berlin. pp. 22–24. [ISBN](https://en.wikipedia.org/wiki/International_Standard_Book_Number) [978-3-642-15259-7](https://en.wikipedia.org/wiki/Special:BookSources/978-3-642-15259-7).

[^3]:
    Bailis, P.; Ghodsi, A. (2013). "Eventual Consistency Today: Limitations, Extensions, and Beyond". Queue. 11 (3): 20. doi:[10.1145/2460276.2462076](https://doi.org/10.1145%2F2460276.2462076).

[^4]:
    Alpern, B.; Schneider, F. B. (1987). "Recognizing safety and liveness". Distributed Computing. 2 (3): 117. doi:[10.1007/BF01782772](https://doi.org/10.1007%2FBF01782772).

[^5]: [Liveness article Wikipedia](https://en.wikipedia.org/wiki/Liveness) 

[^6]: Java Concurrency in Practice / Brian Goetz, with Tim Peierls. . . [et al.] [Concurrency in Practice](https://www.amazon.com/Java-Concurrency-Practice-Brian-Goetz/dp/0321349601)

[^7]: [Baeldung tutorial on CountDownLatch](http://www.baeldung.com/java-countdown-latch)

[^8]: [Wikipedia article on Semaphore](https://en.wikipedia.org/wiki/Semaphore_(programming))