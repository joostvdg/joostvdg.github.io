title: joostvdg.github.com
description: J's Software Development Pages
hero: J's Ramblings

# Joost van der Griendt's Software Development Docs

This is a collection of knowledge that I have gathered over the years.
I find it helps me learn better if I write it down, and often use the docs at different customers as reference.

## Call me J

My full name is *Joost van der Griendt*, which unfortunately cannot be pronounced well in English.

In order to facilitate non-Dutch speakers, you can refer to me as J (Jay).

I've worked as a Java developer in the past, but currently I'm employed as a Solutions Architect for Platform Services at (VMware) [Tanzu Labs](https://tanzu.vmware.com/labs), previously I worked as a Consultant at [CloudBees](www.CloudBees.com).
My day-to-day work involves helping clients with CI/CD, Kubernetes and [Software Development Management](https://go.cloudbees.com/docs/lexicon/software-delivery-management.html). Or, in simple words, how to make it easy and less painful to get software to customers/clients that they want to pay for at scale.

In my spare time I keep my development skills active by developing in [Go](https://github.com/joostvdg?utf8=%E2%9C%93&tab=repositories&q=&type=&language=go) and [Java](https://github.com/joostvdg?utf8=%E2%9C%93&tab=repositories&q=&type=&language=java) mostly. But I'm also a big fan of automating the creation and management of CI/CD (self-service) platforms.

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
    * Jenkins X
    * CloudBees Products (my current employer as of 2018)
* `Containers` (Docker, Kubernetes, ...)
* `SWE`: Software Engineering in all its facets (building, maintaining, social aspects, psychology, etc.)

### Other Docs

* [Breakdown of a Spring Boot + ReactJS Application](https://joostvdg.github.io/keep-watching/)

### Continuous Integration

A good definition can be found here: http://www.martinfowler.com/articles/continuousIntegration.html

> Continuous Integration is a software development practice where members of a team integrate their work frequently, usually each person integrates at least daily - leading to multiple integrations per day. Each integration is verified by an automated build (including test) to detect integration errors as quickly as possible. Many teams find that this approach leads to significantly reduced integration problems and allows a team to develop cohesive software more rapidly."

### Continuous Delivery

Continuous Delivery/deployment is the next step in getting yr software changes at the desired server in order to let your clients take a look at it.
This article provides a good example of it: http://www.martinfowler.com/articles/continuousIntegration.html

> To do Continuous Integration you need multiple environments, one to run commit tests, one or more to run secondary tests. Since you are moving executables between these environments multiple times a day, you'll want to do this automatically. So it's important to have scripts that will allow you to deploy the application into any environment easily.
