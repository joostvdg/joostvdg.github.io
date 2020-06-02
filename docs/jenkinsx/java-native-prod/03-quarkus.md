title: Jenkins X - Java Native Image Prod
description: Creating a Java Native Image application and run it as Production with Jenkins X - Quarkus - 3/10
hero: Quarkus - 3/10

# Create Quarkus Application

There are several ways you can create a Quarkus application.

You can create one by going to [code.quarkus.io](https://code.quarkus.io/), fill in your details and select your dependencies - this is an API call, so automatable. You can start with an maven archetype and add Quarkus details, or you can start from one of the [Quarkus Quickstarts](https://github.com/quarkusio/quarkus-quickstarts).

In this guide, we start with a Quarkus Quickstart (Spring Data JPA to be exact) and modify this to suit our needs.

## Fork, Clone, or Copy

We're going to start from Quarkus' `spring-data-jpa-quickstart`, I leave it up to you how you get the code in your own repository. You can fork it, clone it and copy it or whatever floats your boat.

You can find the quickstart [here](https://github.com/quarkusio/quarkus-quickstarts/tree/master/spring-data-jpa-quickstart), and for reference, the Quarkus Guide that comes with it, [here](https://quarkus.io/guides/spring-data-jpa).

### GitHub CLI

GitHub has a nice CLI that can help us here. There was [hub](https://hub.github.com/) before, but now there's [gh](https://cli.github.com/) which is better for the most common use cases.

=== "Clone Quarkus Quickstarts"
    ```sh
    git clone https://github.com/quarkusio/quarkus-quickstarts.git
    ```
=== "Create New GitHub Repo"
    ```sh
    gh repo create joostvdg/quarkus-fruits  -d "Quarkus Fruits Demo" --public
    cd ./quarkus-fruits/
    ```
=== "Copy Quickstart to Repo"
    ```sh
    cp -R ../quarkus-quickstarts/spring-data-jpa-quickstart/ .
    ```

## Update Project Configuration

### Change compiler source to Java 11

!!! example "pom.xml"

  Replace the 1.8 with `11`.
  ```xml
  <maven.compiler.source>1.8</maven.compiler.source>
  <maven.compiler.target>1.8</maven.compiler.target>
  ```

  ```xml
  <maven.compiler.source>11</maven.compiler.source>
  <maven.compiler.target>11</maven.compiler.target>
  ```

### Update Artifact Metadata

This is optional, but I prefer not having my application be known as `org.acme:spring-data-jpa-quickstart`.
So we update the fields `groupId` and `artifactId` in the pom.xml.

!!! example "pom.xml"

    ```xml
    <groupId>com.github.joostvdg.demo.jx</groupId>
    <artifactId>quarkus-fruits</artifactId>
    ```

### Rename Package

In the same vein, I'm renaming the packages in `src/main/java` and `src/test/java` to reflect the artifact's new group and artifact id's.

### Update Dependencies

We're going to modify the application, so lets dive into the `pom.xml` and make our changes.

First, we will use MySQL as our RDBMS so we drop the `quarkus-jdbc-postgresql` dependency.

Next, we add our other spring dependencies and the `quarkus-jdbc-mysql` for MySQL.

!!! example "pom.xml"

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

### Remove Docker plugin configuration

The Quarkus Quickstart comes with a maven build plugin configuration for the Docker plugin.
It is used to leverage Docker to start a Postgresql database for testing.

One, we won't be able to rely on Docker when building with Jenkins X - a general Kubernetes best practice - and we're not using Postgresql.

So remove the plugin `docker-maven-plugin` from the `<build> <plugins>` section of the pom.xml.

!!! example "pom.xml"

    ```xml
    <plugin>
        <!-- Automatically start PostgreSQL for integration testing - requires Docker -->
        <groupId>io.fabric8</groupId>
        <artifactId>docker-maven-plugin</artifactId>
        <version>${docker-plugin.version}</version>
        ...
    </plugun>
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
        public void delete(@PathVariable(value = "id") long id) {
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

1. delete the `FruitResourceIT` test class, we will solve this later in a different way
1. add the H2 test dependency
1. create a `application.properties` file for tests, in `src/test/resources`
1. annotate our test class with `@QuarkusTestResource(H2DatabaseTestResource.class)`, so Quarkus spins up the H2 database

### Add Dependency

!!! example "pom.xml"

    ```xml
    <dependency>
      <groupId>io.quarkus</groupId>
      <artifactId>quarkus-test-h2</artifactId>
      <scope>test</scope>
    </dependency>
    ```

### Create Test Properties file

Create a new directory under `src/test` called `resources`.
In this directory, create a new file called `application.properties`, with the contents below.

!!! example "src/test/resources/application.properties"

    ```properties
    quarkus.datasource.url=jdbc:h2:tcp://localhost/mem:fruits;MODE=MYSQL;DB_CLOSE_DELAY=-1
    quarkus.datasource.driver=org.h2.Driver
    quarkus.hibernate-orm.database.generation = drop-and-create
    quarkus.hibernate-orm.log.sql=true
    ```

### Update FruitResourceTest annotations

To use the H2 database for our tests, we add the `@QuarkusTestResource` to our `FruitResourceTest` test class.

!!! example "src/test/java/../FruitResourceTest.java"
    
    ```java hl_lines="1"
    @QuarkusTestResource(H2DatabaseTestResource.class)
    @QuarkusTest
    class FruitResourceTest {
        ...
    }
    ```

## Replace jsonb with jackson

Spring depends on `Jackson` for marshalling JSON to and from Java Objects.
It makes sense to make our application depend on the same libary to reduce potential conflicts.

Remove the `quarkus-resteasy-jsonb` dependency:

!!! example "pom.xml"

    ```xml
    <dependency>
        <groupId>io.quarkus</groupId>
        <artifactId>quarkus-resteasy-jsonb</artifactId>
    </dependency>
    ```

And add  `quarkus-resteasy-jackson`.

!!! example "pom.xml"

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

## Test That It Works

```sh
./mvnw clean test
```

The build should be successful and return as follows:

```sh
[INFO] Tests run: 2, Failures: 0, Errors: 0, Skipped: 0, Time elapsed: 9.634 s - in com.github.joostvdg.demo.jx.quarkusfruits.FruitResourceTest
2020-05-31 16:20:09,388 INFO  [io.quarkus] (main) Quarkus stopped in 0.057s
[INFO] H2 database was shut down; server status: Not started
[INFO]
[INFO] Results:
[INFO]
[INFO] Tests run: 2, Failures: 0, Errors: 0, Skipped: 0
[INFO]
[INFO] ------------------------------------------------------------------------
[INFO] BUILD SUCCESS
[INFO] ------------------------------------------------------------------------
[INFO] Total time:  16.491 s
[INFO] Finished at: 2020-05-31T16:20:09+02:00
[INFO] ------------------------------------------------------------------------
```

In case the test is not successful, and you're unsure how to resolve it, do not dispair!

I have saved the end result of this chapter in a branch in my version of the repository.

You can find the repository [here](https://github.com/joostvdg/quarkus-fruits), and the results of this chapter here: [03 Quarkus](https://github.com/joostvdg/quarkus-fruits/tree/03-quarkus).

## Next Steps

Running `mvn clean test` should result in a succesful build, with two tests testing most of our application.

This means we're ready to go to the next step, importing the application into Jenkins X!