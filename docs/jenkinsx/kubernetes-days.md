# Jenkins X - Kubernetes Days

## Prepare

```bash
asciinema rec first.cast
```

```bash
asciinema play -i 2 first.cast
```

* `-i` -> play back with max of 2 seconds of idleness
* `-s` -> play back with double speed

## Process

* Create cluster
* Create quickstart 
* Gitops
* Promotion
* Pr
* `jx boot`

## Commands


```bash
asciinema rec jx-k8s-days-00-logo.cast
```

```bash

  ______  __        ______    __    __   _______        .__   __.      ___   .___________. __  ____    ____  _______                     
 /      ||  |      /  __  \  |  |  |  | |       \       |  \ |  |     /   \  |           ||  | \   \  /   / |   ____|                    
|  ,----'|  |     |  |  |  | |  |  |  | |  .--.  |______|   \|  |    /  ^  \ `---|  |----`|  |  \   \/   /  |  |__                       
|  |     |  |     |  |  |  | |  |  |  | |  |  |  |______|  . `  |   /  /_\  \    |  |     |  |   \      /   |   __|                      
|  `----.|  `----.|  `--'  | |  `--'  | |  '--'  |      |  |\   |  /  _____  \   |  |     |  |    \    /    |  |____                     
 \______||_______| \______/   \______/  |_______/       |__| \__| /__/     \__\  |__|     |__|     \__/     |_______|                    
                                                                                                                                         
                                      ______  __       ___ ______  _______                                                               
                                     /      ||  |     /  //      ||       \                                                              
                                    |  ,----'|  |    /  /|  ,----'|  .--.  |                                                             
                                    |  |     |  |   /  / |  |     |  |  |  |                                                             
                                    |  `----.|  |  /  /  |  `----.|  '--'  |                                                             
                                     \______||__| /__/    \______||_______/                                                              
                                                                                                                                         
____    __    ____  __  .___________. __    __               __   _______ .__   __.  __  ___  __  .__   __.      _______.      ___   ___ 
\   \  /  \  /   / |  | |           ||  |  |  |             |  | |   ____||  \ |  | |  |/  / |  | |  \ |  |     /       |      \  \ /  / 
 \   \/    \/   /  |  | `---|  |----`|  |__|  |             |  | |  |__   |   \|  | |  '  /  |  | |   \|  |    |   (----`       \  V  /  
  \            /   |  |     |  |     |   __   |       .--.  |  | |   __|  |  . `  | |    <   |  | |  . `  |     \   \            >   <   
   \    /\    /    |  |     |  |     |  |  |  |       |  `--'  | |  |____ |  |\   | |  .  \  |  | |  |\   | .----)   |          /  .  \  
    \__/  \__/     |__|     |__|     |__|  |__|        \______/  |_______||__| \__| |__|\__\ |__| |__| \__| |_______/          /__/ \__\ 
                                                                                                                                         

```

```bash
asciinema play jx-k8s-days-00-logo.cast
```

### Create Cluster

```bash
export NAMESPACE=cd
export PROJECT=
```

```bash
asciinema rec jx-k8s-days-01-create.cast
```

```bash
jx create cluster gke -n jx-rocks -p $PROJECT -r us-east1 \
    -m n1-standard-4 --min-num-nodes 1 --max-num-nodes 2 \
    --default-admin-password=admin \
    --default-environment-prefix jx-rocks --git-provider-kind github \
    --namespace $NAMESPACE --prow --tekton
```

```bash
asciinema play -i 1 -s 4 jx-k8s-days-01-create.cast
```

### Create QuickStart Go

```bash
asciinema rec jx-k8s-days-02-quickstart.cast
```

```bash
export APP_NAME=jx-k8s-days-go-02
```

```bash
jx create quickstart --filter golang-http --project-name ${APP_NAME} --batch-mode
```

```bash
ls -l ${APP_NAME}
```

```bash
jx get activity -f ${APP_NAME} -w
```

```bash
jx get pipelines
```

```bash
jx get applications -e staging
```

```bash
http "http://${APP_NAME}.cd-staging.35.185.41.106.nip.io"
```

```bash
jx get build logs -f ${APP_NAME}  # Cancel with ctrl+c
```

```bash
cd ${APP_NAME}
vim main.go
```

```bash
jx get activity -f ${APP_NAME} -w
```

```bash
jx get applications -e staging
```

```bash
http "http://${APP_NAME}.cd-staging.35.185.41.106.nip.io"
```


```bash
asciinema play -i 2 -s 2 jx-k8s-days-02-quickstart.cast
```

## Import Project

```bash
 __  .___  ___. .______     ______   .______     .___________.    __________   ___  __       _______.___________..__   __.   _______ 
|  | |   \/   | |   _  \   /  __  \  |   _  \    |           |   |   ____\  \ /  / |  |     /       |           ||  \ |  |  /  _____|
|  | |  \  /  | |  |_)  | |  |  |  | |  |_)  |   `---|  |----`   |  |__   \  V  /  |  |    |   (----`---|  |----`|   \|  | |  |  __  
|  | |  |\/|  | |   ___/  |  |  |  | |      /        |  |        |   __|   >   <   |  |     \   \       |  |     |  . `  | |  | |_ | 
|  | |  |  |  | |  |      |  `--'  | |  |\  \----.   |  |        |  |____ /  .  \  |  | .----)   |      |  |     |  |\   | |  |__| | 
|__| |__|  |__| | _|       \______/  | _| `._____|   |__|        |_______/__/ \__\ |__| |_______/       |__|     |__| \__|  \______| 
                                                                                                                                     
     ___      .______   .______    __       __    ______     ___   .___________. __    ______   .__   __.                            
    /   \     |   _  \  |   _  \  |  |     |  |  /      |   /   \  |           ||  |  /  __  \  |  \ |  |                            
   /  ^  \    |  |_)  | |  |_)  | |  |     |  | |  ,----'  /  ^  \ `---|  |----`|  | |  |  |  | |   \|  |                            
  /  /_\  \   |   ___/  |   ___/  |  |     |  | |  |      /  /_\  \    |  |     |  | |  |  |  | |  . `  |                            
 /  _____  \  |  |      |  |      |  `----.|  | |  `----./  _____  \   |  |     |  | |  `--'  | |  |\   |                            
/__/     \__\ | _|      | _|      |_______||__|  \______/__/     \__\  |__|     |__|  \______/  |__| \__|                            
                                                                                                                                     

```

```bash
asciinema rec jx-k8s-days-03-import.cast
```

```bash
git clone https://github.com/joostvdg/go-demo-6.git
```

```bash
cd go-demo-6
git checkout orig
git merge -s ours master --no-edit
git checkout master
git merge orig
rm -rf charts
ls -lath
```

```bash
git push

jx import --batch-mode
```

```bash
jx get activities --filter go-demo-6 --watch
```

```bash
jx get applications
```

```bash
kubectl --namespace cd-staging logs -l app=jx-go-demo-6
```

```bash
echo "dependencies:
- name: mongodb
  alias: go-demo-6-db
  version: 5.3.0
  repository:  https://kubernetes-charts.storage.googleapis.com
  condition: db.enabled" > charts/go-demo-6/requirements.yaml
```

```bash
cat charts/go-demo-6/requirements.yaml
```

```bash
vim charts/go-demo-6/templates/deployment.yaml
```

```bash
        env:
        - name: DB
          value: {{ template "fullname" . }}-db
```

```bash
vim charts/go-demo-6/values.yaml
```

```bash
probePath: /demo/hello?health=true
```

```bash
git status
git add charts/
git commit -m "add db dependency"
git push
```

```bash
jx get activities --filter go-demo-6 --watch
```

```bash
jx get applications
```

```bash
http http://go-demo-6.cd-staging.35.185.41.106.nip.io/demo/hello
```

```bash
jx delete application
```

```bash
rm -rf go-demo-6
```

```bash
jx get applications
```

```bash
asciinema play -i 2 -s 2 jx-k8s-days-03-import.cast
```

## Preview Environments

```bash
APP_NAME=jx-k8s-days-go-01
```

```bash
asciinema rec jx-k8s-days-04-preview.cast
```

```bash
jx get applications
```

```bash
cd ${APP_NAME}
```

```bash
git checkout -b my-new-pr-3
```

```bash
vim main.go
```

```bash
git status
git add main.go
git commit -m "change message"
git push --set-upstream origin my-new-pr-3
```

```bash
jx create pullrequest \
    --title "My PR" \
    --body "This is the text that describes the PR" \
    --batch-mode
```

```bash
open pr link
```

```bash
jx get previews
```

```bash
http ..
```

```bash
add /lgtm to pr
merge pr
```

```http
jx get activity --filter jx-k8s-day-go-01 --watch
```

```bash
jx get applications
```

```bash
git checkout master
git pull
cd ..
```

```bash
jx get previews
jx gc previews
jx get previews
```

```bash
asciinema play -i 2 -s 2 jx-k8s-days-04-preview.cast
```

## Env

```bash
jx create environment
```

## Reel


```bash
for VARIABLE in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17
do
    asciinema play jx-k8s-days-00-logo.cast
	asciinema play -i 2 -s 3 jx-k8s-days-01-create.cast
	asciinema play -i 2 -s 1 jx-k8s-days-02-quickstart.cast
	asciinema play -i 2 -s 1 jx-k8s-days-03-import.cast
    asciinema play -i 2 -s 2 jx-k8s-days-04-preview.cast
done
```