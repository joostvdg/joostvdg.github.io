# IDE Integration for Jenkins Pipeline DSL

## Supported IDE's

Currently only Jetbrain's Intelli J's IDEA is [supported](https://github.com/jenkinsci/job-dsl-plugin/wiki/IDE-Support).

This via a Groovy DSL file (.gdsl).


## Configure Intelli J IDEA

Go to a Jenkins Pipeline job and open the Pipeline Syntax page.

On the page in the left hand menu, you will see a link to download a Jenkins Master specific Groovy DSL file.
Download this and save it into your project's workspace.

![Jenkins Config](../images/jenkins-retrieve-gdsl.png)

It will have to be part of your classpath, the easiest way to do this is to add the file as pipeline.gdsl in a/the src folder.

For more information, you can read [Steffen Gerbert](https://st-g.de/2016/08/jenkins-pipeline-autocompletion-in-intellij)'s blog.

### Remarks from Kohsuke Kawaguchi

More effort in this space will be taken by Cloudbees.
But the priority is low compared to other initiatives.

## Integration of Pipeline Library

If you're using the Global Shared Libraries for sharing generic pipeline building blocks, it would be nice to have this awareness in your editor as well.

One of the ways to do this, is to checkout the source code of this library and make sure it is compiled.
In your editor (assuming Intelli J IDEA) you can then add the compiled classes as dependency (type: classes).
This way, at least every class defined in your library is usable as a normal dependency would be. 

## Final configuration Intelli J IDEA

![Intelli J IDEA Config](../images/intelli-j-pipeline-setup.png)