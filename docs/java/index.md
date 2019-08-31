# Java

## Patterns/Anti-patterns

### Constants

Use a class that cannot be instantiated for the use of constants.

Using an interface is [an anti-pattern](https://dzone.com/articles/constants-in-java-the-anti-pattern-1) because of what an interface implies.

```java
/**
 * It should also be final, else we can extend this and create a constructor allowing us to instantiate it anyway.
 */
public final class Constants {
    private Constants() {} // we should not instantiate this class

    public static final String HELLO = "WORLD";
    public static final int AMOUNT_OF_CONSTANTS = 2;
}
```

## Other usefull things

* [Random integer](https://www.mkyong.com/java/java-generate-random-integers-in-a-range/)