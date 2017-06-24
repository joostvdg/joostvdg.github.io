# Jenkins Pipeline - Input

The Jenkins Pipeline has a plugin for dealing with external input.
Generally it is used to gather user input (values or approval), but it also has a REST API for this.

## General Info

The [Pipeline Input Step](https://wiki.jenkins-ci.org/display/JENKINS/Pipeline+Input+Step+Plugin) allows you to

The plugin allows you to capture input in a variety of ways, but there are some gotcha's.

* If you have a single parameter, it will be returned as a single value
* If you have multiple parameters, it will be returned as a map
* The choices for the Choice parameter should be a single line, where values are separated with /n
* Don't use input within a node {}, as this will block an executor slot
* ..


### Examples

#### Single Parameter

```groovy
def hello = input id: 'CustomId', message: 'Want to continue?', ok: 'Yes', parameters: [string(defaultValue: 'world', description: '', name: 'hello')]

node {
    println "echo $hello"
}
```

#### Multiple Parameters

```groovy
def userInput = input id: 'CustomId', message: 'Want to continue?', ok: 'Yes', parameters: [string(defaultValue: 'world', description: '', name: 'hello'), string(defaultValue: '', description: '', name: 'token')]

node {
    def hello = userInput['hello']
    def token = userInput['token']
    println "hello=$hello, token=$token"
}
```

#### Timeout on Input

```groovy
def userInput

timeout(time: 10, unit: 'SECONDS') {
    println 'Waiting for input'
    userInput = input id: 'CustomId', message: 'Want to continue?', ok: 'Yes', parameters: [string(defaultValue: 'world', description: '', name: 'hello'), string(defaultValue: '', description: '', name: 'token')]
}
```




## REST API

There's a rest API for sending the input to a waiting input step.
The format of the url: ${JenkinsURL}/${JobURL}/${Build#}/input/${InputID}/submit.

There are some things to keep in mind:

* If Jenkins has CSRF protection enabled, you need a Crumb (see below) for the requests
* Requests are send via POST
* For supplying values you need to have a JSON with the parameters with as *json* param
* You need to supply the *proceed* value: the value of the **ok** button, as *proceed* param
* You will have to fill in the *input id*, so it is best to configure a unique input id for the input steps you want to connect to from outside

### Examples

```json
{"parameter":
    [
        {"name": "hello", "value": "joost"},
        {"name": "token", "value": "not a token"}
    ]
}
```


```bash
# single parameter
curl --user $USER:$PASS -X POST -H "Jenkins-Crumb:b220147dbdf3cfebbeba4c29048c2e33" -d json='{"parameter": {"name": "hello", "value": "joost"}}' -d proceed='Yes' 'https://ci.flusso.nl/jenkins/job/Joost/job/Pipeline-Example/5/input/CustomId/submit'

```
```bash
# Multiple Parameters
curl --user $USER:$PASS -X POST -H "Jenkins-Crumb:b220147dbdf3cfebbeba4c29048c2e33" -d json='{"parameter": [{"name": "hello", "value": "joost"},{"name": "token", "value": "not a token"}]}' -d proceed='Yes' 'https://ci.flusso.nl/jenkins/job/Joost/job/Pipeline-Example/5/input/CustomId/submit'

```

### Crumb (secured Jenkins)

If Jenkins is secured against CSRF (via Global Security: Prevent Cross Site Request Forgery exploits), any API call requires a Crumb.
You can read more about it [here](https://wiki.jenkins-ci.org/display/JENKINS/CSRF+Protection).

To get a valid crumb you have to send a crumb request as authenticated user.

* JSON: https://ci.flusso.nl/jenkins/crumbIssuer/api/json
* XML (parsed): https://ci.flusso.nl/jenkins/crumbIssuer/api/xml?xpath=concat(//crumbRequestField,%22:%22,//crumb)
