title: joostvdg.github.com
description: J's Software Development Pages
hero: J's Ramblings

# Joost van der Griendt's Software Development Docs

This is a collection of knowledge that I have gathered over the years.
I find it helps me learn better if I write it down, and often use the docs at different customers as reference.

## Call me J

My full name is *Joost van der Griendt*, which unfortunately cannot be pronounced well in English.

In order to facilitate non-Dutch speakers, you can refer to me as J (Jay).

I've worked in the software development industry since 2006, as Sofware Developer (Java backend/Fullstack), Build Engineer, DevOps Engineer, Solutions Architect, and Product Manager.
In the end, the only thing that matters is getting the right things done for the right reasons.

On this side, I write guides, work-in-progress solutions to problems I've encountered in my hobby projects and my work.

For more information about me, check out my [LinkedIn](https://www.linkedin.com/in/joostvdg/) profile.
I also write more tightly focused articles on my personal blog - [blog.joostvdg.net](https://blog.joostvdg.net/).

I'm a big fan of Open Source Software and when it makes sense, Free & Free software.
Which is also why this site is completely open, and open source as well.

!!! Info
    Curious how this site is build?
    [Read my explanation here](other/mkdocs/)

### Tracker

Your browser will tell you there's a tracker.
I'm curious to understand if people are reading my docs and if so, which pages.

Feel free to block the tracker (Google Analytics), most browsers are able to do so.

## Main Topics

* `CI/CD` (Continuous Integration / Continous Delivery)
    * Jenkins
    * Tekton
* `Containers` (Docker, Kubernetes, ...)
* `SWE`: Software Engineering in all its facets (building, maintaining, social aspects, psychology, etc.)
* GitOps/DevOps for my Homelab

### Other Material

* [blog.joostvdg.net](https://blog.joostvdg.net/)
* [Breakdown of a Spring Boot + ReactJS Application](https://joostvdg.github.io/keep-watching/)
* [Jenkins X Workshop](https://joostvdg.github.io/jenkinsx-workshop/)
* [Tanzu Application Platform Workshop](https://joostvdg.github.io/tap-workshops/)

### Continuous Integration

A good definition can be found here: http://www.martinfowler.com/articles/continuousIntegration.html

> Continuous Integration is a software development practice where members of a team integrate their work frequently, usually each person integrates at least daily - leading to multiple integrations per day. Each integration is verified by an automated build (including test) to detect integration errors as quickly as possible. Many teams find that this approach leads to significantly reduced integration problems and allows a team to develop cohesive software more rapidly."

### Continuous Delivery

Continuous Delivery/deployment is the next step in getting yr software changes at the desired server in order to let your clients take a look at it.
This article provides a good example of it: http://www.martinfowler.com/articles/continuousIntegration.html

> To do Continuous Integration you need multiple environments, one to run commit tests, one or more to run secondary tests. Since you are moving executables between these environments multiple times a day, you'll want to do this automatically. So it's important to have scripts that will allow you to deploy the application into any environment easily.
