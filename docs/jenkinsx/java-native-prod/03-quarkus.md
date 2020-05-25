title: Jenkins X - Java Native Image Prod
description: Creating a Java Native Image application and run it as Production with Jenkins X - Quarkus - 3/9
hero: Quarkus - 3/9

# Create Quarkus Application

There are several ways you can create a Quarkus application.

You can create one by going to [code.quarkus.io](https://code.quarkus.io/), fill in your details and select your dependencies - this is an API call, so automatable. You can start with an maven archetype and add Quarkus details, or you can start from one of the [Quarkus Quickstarts](https://github.com/quarkusio/quarkus-quickstarts).

In this guide, we start with a Quarkus Quickstart (Spring Data JPA to be exact) and modify this to suit our needs.

## Fork, Clone, or Copy

We're going to start from Quarkus' `spring-data-jpa-quickstart`, I leave it up to you how you get the code in your own repository. You can fork it, clone it and copy it or whatever floats your boat.

You can find the quickstart [here](https://github.com/quarkusio/quarkus-quickstarts/tree/master/spring-data-jpa-quickstart), and for reference, the Quarkus Guide that comes with it, [here](https://quarkus.io/guides/spring-data-jpa).

## Update Dependencies

We're going to modify the application, so lets dive into the `pom.xml` and make our changes.

First, we will use MySQL as our RDBMS so we drop the `quarkus-jdbc-postgresql` dependency.

Next, we add our other spring dependencies and the `quarkus-jdbc-mysql` for MySQL.

```xml
<dependency>
  <groupId>io.quarkus</groupId>
  <artifactId>quarkus-spring-web</artifactId>
</dependency>
<dependency>
  <groupId>io.quarkus</groupId>
  <artifactId>quarkus-spring-di</artifactId>
</dependency>
<dependency>
  <groupId>io.quarkus</groupId>
  <artifactId>quarkus-jdbc-mysql</artifactId>
</dependency>
```

## Transform Resource to Controller

Now that we're using Spring Web, we are going to change our Resource - FruitResource - to a Spring Web Controller.

Replace this annotation:

```java
@Path("/fruits")
```

With this.

```java
@RestController
@RequestMapping(value = "/fruits")
```

Replace all `@PathParams` with Spring's `@PathVariable`'s.
Mind you, these require the name of the variable as a parameter.

For example:

```java
@POST
@Path("/name/{name}/color/{color}")
@Produces("application/json")
public Fruit create(@PathParam String name, @PathParam String color) {}
```

Becomes:

```java
@PostMapping("/name/{name}/color/{color}")
public Fruit create(@PathVariable(value = "name") String name, @PathVariable(value = "color") String color) {
```

Then, replace the Http method annotations for the methods:

* `@GET` with  `@GetMapping` 
* `@DELETE` with `@DeleteMapping` 
* `@POST` with `@PostMapping` 
* `@PUT` with `@PutMapping`

!!! note
    Spring's annotation includes the path, so you can collapse the `@PATH` into the Http method annotation.

    For example:
    
    ```java
    @GET
    @Path("/color/{color}")
    @Produces("application/json")
    ```

    Becomes:

    ```java
    @GetMapping("/color/{color}")
    ```

??? example "FruitResource.java"

    ```java
    @RestController
    @RequestMapping(value = "/fruits")
    public class FruitResource {

        private final FruitRepository fruitRepository;

        public FruitResource(FruitRepository fruitRepository) {
            this.fruitRepository = fruitRepository;
        }

        @GetMapping("/")
        public List<Fruit> findAll() {
            ...
        }

        @DeleteMapping("{id}")
        public ResponseEntity<Long> delete(@PathVariable(value = "id") long id) {
            ...
        }

        @PostMapping("/name/{name}/color/{color}")
        public Fruit create(@PathVariable(value = "name") String name, @PathVariable(value = "color") String color) {
            ...
        }

        @PutMapping("/id/{id}/color/{color}")
        public Fruit changeColor(@PathVariable(value = "id") Long id, @PathVariable(value = "color") String color) {
            ...
        }

        @GetMapping("/color/{color}")
        public List<Fruit> findByColor(@PathVariable(value = "color") String color) {
            ...
        }
    }
    ```

## Update Application Properties

Let's update the applications properties, an initial configuration for MySQL.

For the username and password, we use environment variables wich we will address later - when we import the aplication into Jenkins X.

The JDBC URL looks a bit weird, but this has to do with [how Google Cloud SQL can be accessed via Kubernetes](https://cloud.google.com/sql/docs/mysql/connect-kubernetes-engine?hl=en_US). This is enough for now, we'll come back for more, don't worry.

```properties
quarkus.datasource.db-kind=mysql
quarkus.datasource.jdbc.url=jdbc:mysql://127.0.0.1:3306/fruits
quarkus.datasource.jdbc.max-size=8
quarkus.datasource.jdbc.min-size=2

quarkus.datasource.username=${GOOGLE_SQL_USER}
quarkus.datasource.password=${GOOGLE_SQL_PASS}
```

## Unit Testing

In order to build our application, we now need a MySQL database as we have unit tests, testing our FruitResource - as we should! Locally, we can address this by running MySQL as a Docker container. Unfortunately, when building applications in Jenkins X, we don't have access to Docker - you could, but in Kubernetes this is a big no-no. So, for now, we'll spin up an H2 database in MySQL mode to avoid the issue, [but we should probably come back to that later](https://phauer.com/2017/dont-use-in-memory-databases-tests-h2/).

This was in part inspired by [@hantsy's post on creating your first Quarkus application](https://medium.com/@hantsy/kickstart-your-first-quarkus-application-cde54f469973) on Medium, definitely worth a read in general.

In order to use the H2 database for our unit tests, we have to make three changes:

1. add the H2 test dependency
1. create a `application.properties` file for tests, in `src/test/resources`
1. annotate our test class with `@QuarkusTestResource(H2DatabaseTestResource.class)`, so Quarkus spins up the H2 database


```xml
<dependency>
  <groupId>io.quarkus</groupId>
  <artifactId>io.quarkus:quarkus-test-h2</artifactId>
  <scope>test</scope>
</dependency>
```

!!! example "src/test/java/../FruitResourceTest.java"
    
    ```java
    @QuarkusTestResource(H2DatabaseTestResource.class)
    @QuarkusTest
    class FruitResourceTest {
        ...
    }
    ```

!!! example "src/test/resoureces/application.properties"

    ```properties
    quarkus.datasource.url=jdbc:h2:tcp://localhost/mem:test
    quarkus.datasource.driver=org.h2.Driver
    quarkus.hibernate-orm.database.generation = drop-and-create
    quarkus.hibernate-orm.log.sql=true
    ```

## Replace jsonb with jackson

Spring depends on `Jackson` for marshalling JSON to and from Java Objects.
It makes sense to make our application depend on the same libary to reduce potential conflicts.

Remove the `quarkus-resteasy-jsonb` dependency:

```xml
<dependency>
    <groupId>io.quarkus</groupId>
    <artifactId>quarkus-resteasy-jsonb</artifactId>
</dependency>
```

And add  `quarkus-resteasy-jackson`.

```xml
<dependency>
  <groupId>io.quarkus</groupId>
  <artifactId>quarkus-resteasy-jackson</artifactId>
</dependency>
```

## Update FruitResource findAll

If you have tested our application, you might have noticed our `findAll()` method no longer works. This is because the `RestEasy Jackson` library doesn't properly marshall the Fruit's iterator. To solve this, we make and return a List instead.

!!! example "FruitResource.java"

    ```java
    public List<Fruit> findAll() {
        var it = fruitRepository.findAll();
        List<Fruit> fruits = new ArrayList<Fruit>();
        it.forEach(fruits::add);
        return fruits;
    }
    ```


## Next Steps

Running `mvn clean test` should result in a succesful build, with two tests testing most of our application.

This means we're ready to go to the next step, importing the application into Jenkins X!