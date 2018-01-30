# Java Streams

## Try-with-Resources 

> try with resources can be used with any object that implements the
  Closeable interface, which includes almost every object you need to
  dispose. So far, JavaMail Transport objects are the only exceptions
  I’ve encountered. Those still need to be disposed of explicitly.

```java
public class Main {
    public static void main(String[] args) {
        try (OutputStream out = new FileOutputStream("/tmp/data.txt")) {
            // work with the output stream...
        } catch (IOException ex) {
            System.err.println(ex.getMessage());
        }
    }
}
```
