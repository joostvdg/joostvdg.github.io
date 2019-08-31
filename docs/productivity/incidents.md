title: Software Development Incident Managent
description: How To Manage Incidents With Software Development

# Incidents

* incidents
* five why's
* blameless postmortems
    * identify causes (not culprits)
    * assume good will
    * take your time
* dangers of automation
* observability
* human bias
* human factors
* percententize work
    * how much percent of work should be what?m
    * figure out how to track, make it easy/automated
    * identify real vs. desired, figure out how to get (closer) to desired
* "Just Culture" (as in, justice, it is just)
* bad apple theory = debunked
    * bad apple theory = remove the small percentage of bad apples and the problem goes away

## Notes

* most incidents happen near updates/upgrades/deployments
    * make deployments a non-event
    * small increments, high frequency, automated, tested
* it is not systems, it not humans, but humans within systems
    * human will make mistakes
    * processes are (almost) always part of the problem
    * automation needs to include sanity checks (ranges of sane values)

## References

Below is a significant collection of references to resources that tackle the different parts of incident management.
They can explain it better than I ever can, so use them to better your own understanding just as I have.

### Books

* [Foundations of Safety Science](https://www.amazon.com/Foundations-Safety-Science-Understanding-Accidents-dp-1138481785/dp/1138481785/ref=mt_paperback?_encoding=UTF8&me=&qid=1556078063)
* [Code Complete](https://www.amazon.com/Code-Complete-Practical-Handbook-Construction/dp/0735619670)

### Talks

* [Ironies Of Automation](https://www.youtube.com/watch?v=U3ubcoNzx9k)
* [Google SRE: Postmortems and Retrospectives](https://www.youtube.com/watch?v=UBe7U2b3tsA)
* [John Allspaw: Blameless Post Mortems](https://www.youtube.com/watch?v=4nRahQddtJ0)

### Papers

* [Patient Safety and the "Just Culture" - Marx D](https://psnet.ahrq.gov/resources/resource/1582)
* [How do systems manage their adaptive capacity to successfully handle disruptions - M Branlat & D Woods](https://www.researchgate.net/publication/286581322_How_do_systems_manage_their_adaptive_capacity_to_successfully_handle_disruptions_A_resilience_engineering_perspective)
* [Ironies Of Automation - Lisanne Bainbridge](https://www.ise.ncsu.edu/wp-content/uploads/2017/02/Bainbridge_1983_Automatica.pdf)
* [Managing The Development Of Large Software Systems - Winston Royce](http://www-scf.usc.edu/~csci201/lectures/Lecture11/royce1970.pdf)

### Articles

* [John Allspaw: a mature role for automation](https://www.kitchensoap.com/2012/09/21/a-mature-role-for-automation-part-i/)
* [John Allspaw: Resillience Engineering: Part I](https://www.kitchensoap.com/2011/04/07/resilience-engineering-part-i/)
* [John Allspaw: getting the messy details is critical](https://medium.com/code-for-america/john-allspaw-getting-the-messy-details-is-critical-59e641aa0a77)
* [John Allspaw: Ask Me Anything](https://community.atlassian.com/t5/Jira-Ops-questions/I-m-John-Allspaw-Ask-Me-Anything-about-incident-analysis-and/qaq-p/957084)
* [John Allspaw: Blameless PostMortems And A Just Culture](https://codeascraft.com/2012/05/22/blameless-postmortems/)
* [Etsy's Postmortem Proces](https://www.fastcompany.com/3064726/what-etsy-does-when-things-go-wrong-a-7-step-guide)
* [Etsy's Winning Secret: Don't Play The Blame Game](https://www.businessinsider.com/etsy-chad-dickerson-blameless-post-mortem-2012-5)
* [Blameless Portmortems at Etsy](https://www.infoq.com/articles/postmortems-etsy/)
* [Google SRE - Postmortem Culture: Learning from Failure](https://landing.google.com/sre/sre-book/chapters/postmortem-culture/)
* [HoneyComb.io - Incident Review](https://www.honeycomb.io/blog/incident-review-you-cant-deploy-binaries-that-dont-exist/)
* [GitHub Outage Incident Analysis](https://github.blog/2018-10-30-oct21-post-incident-analysis/)
* [Google Postmortem](https://status.cloud.google.com/incident/compute/16007)
* [AWS Postmortem (S3 outage)](https://aws.amazon.com/message/41926/)
* [GitHub Page Listing Public Post Mortems](https://github.com/danluu/post-mortems)
* [Charity Majors: I Test In Prod](https://increment.com/testing/i-test-in-production/)
* [The Network Is Reliable: an informal survey of real-world communications failures](https://queue.acm.org/detail.cfm?id=2655736)
* [Charity Majors: Shipping Software Should Not Be Scary](https://charity.wtf/2018/08/19/shipping-software-should-not-be-scary/)
* [Circle CI: A brief history of devops part I: waterfall](https://circleci.com/blog/a-brief-history-of-devops-part-i-waterfall/)
* [Circle CI: A brief history of devops part II: agile development](https://circleci.com/blog/a-brief-history-of-devops-part-ii-agile-development/)
* [Circle CI: A brief history of devops part III: automated testing and continuous integration](https://circleci.com/blog/a-brief-history-of-devops-part-iii-automated-testing-and-continuous-integration/)
* [Circle CI: A brief history of devops part IV: continuous delivery and deployment](https://circleci.com/blog/a-brief-history-of-devops-part-iv-continuous-delivery-and-continuous-deployment/)
