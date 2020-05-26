title: Jenkins X - Java Native Image Prod
description: Creating a Java Native Image application and run it as Production with Jenkins X - Cloud SQL - 2/9
hero: Cloud SQL - 2/9

# Google Cloud SQL

As with any public cloud, Google Cloud has classic Relation Database Management System offering.
In GCP this is called CloudSQL, and supports several flavors such a MySQL and Postgres.

We will explore the different ways you can create a CloudSQL database, so it should work for everyone.

## Requirements

For this guide we need a MySQL Database.

Personally, I don't like managing databases.
I know enough to use them, and I while I know that I can get one in Kubernetes with ease, I still rather not manage it over time. With storage, upgrades, backups & restore and so on. Which are definitely concerns you need to take care off, with a Database in Production.

So, while it is not a hard requirement I strongly encourage you to use a managed database.
And when in Google Cloud, the initial step is Cloud SQL.

Staying true to the classics - at least for me - I want it to be like MySQL.
No real reason, if you want Postgres or something else, go ahead. Most of this guide will be exactly the same.

## UI

If you do not want to automate the database creation, or you at least want to have a UI while exploring the options, Google offers a [clean UI with a guide](https://cloud.google.com/sql/docs/mysql/quickstart) to get you started. Or even more handson, a [Create a Managed MySQL Database with Cloud SQL Lab](https://codelabs.developers.google.com/codelabs/cloud-create-cloud-sql-db/index.html#0)!

The guide is very intuitive, so I'll leave you to it.
If you prefer a CLI or Terraform, read on!

## Gcloud CLI

`gcloud` Is Google Cloud's CLI for interacting with Google Cloud API's.

If you don't have it installed yet, [read the installation guide](https://cloud.google.com/sdk/install), and after, the [initialization guide](https://cloud.google.com/sdk/docs/initializing) for setting up access.

Ensure you have a working `gcloud` with a default project configured. Use `gcloud config list`, to verify this is the case. From there, creating the MySQL database we need is straightforward.

We're going to execute to steps:

1. enable the API
1. we create the Database Instace, [read here for more info on this command](https://cloud.google.com/sdk/gcloud/reference/sql/instances/create)
1. we create the Database in the Instance, so please do remember the name! [read here for more info on that command](https://cloud.google.com/sdk/gcloud/reference/sql/databases/create)

### Enable Cloud SQL API

```sh
gcloud services enable sqladmin.googleapis.com
```

### Create Database Instance

```sh
gcloud sql instances create quarkus-fruits \
      --database-version=MYSQL_5_7 --tier=db-n1-standard-1 \
      --region=europe-west4 --root-password=password123
```

!!! warning
    Do change the root-password!

### Create Database

```sh
gcloud sql databases create quarkus-fruits --instance quarkus-fruits
```

## Terraform

I'm a big fan of Configuration-as-Code, and [Terraform](https://www.terraform.io/) is the absolute poster child of this concept. This is not a guide on Terraform, so we do dive further into the best practices. I do suggest you read about [Terraform Backends](https://www.terraform.io/docs/backends/index.html).

We won't use one in this guide - for brevity - but do read it and think about using it.

In general, we use three files with Terraform:

1. **maint.tf**: the main file with Module definitions and, if possible, the bulk of the configuration
2. **variables.tf**: input variables, so we can more easily re-use or share our files
3. **outputs.tf**: in the event you have output from the created resources, we have no outputs, so no file

### Process

First we initialize our configuration. This ensures Terraform has the right modules available to talk to this particular cloud API.

```sh
terraform init
```

Then we let Terraform plan what needs to be done. Terraform is declarative, meaning, we state our end-result Terraform will make it happen. Terraform plan, lets Terraform tell us how it wants to do so.

We let Terraform output the plan to disk, so we can apply the plan, rather than letting Terraform figure it out again.

```sh
terraform plan --out plan.out
```

If the plan is valid and looks correct, we can apply it. Now terraform will create our resources.

```sh
terraform apply "plan.out"
```

### Terraform Files

!!! example "main.tf"

		```terraform
		terraform {
				required_version = "~> 0.12"
		}

		# https://www.terraform.io/docs/providers/google/index.html
		provider "google" {
				version   = "~> 2.18.1"
				project   = var.project
				region    = var.region
				zone      = var.zone
		}

		resource "google_sql_database_instance" "master" {
				name             = var.database_instance_name
				database_version = "MYSQL_5_7"
				region           = var.region

				settings {
						# Second-generation instance tiers are based on the machine
						# type. See argument reference below.
						tier = var.database_instance_tier
				}
		}

		resource "google_sql_database" "database" {
				name     = var.database_name
				instance = google_sql_database_instance.master.name
		}
		```

!!! example "variables.tf"

		```terraform
		variable "project" { 
				description = "GCP Project ID"
		}

		variable "region" {
				default ="europe-west4"
				description = "GCP Region"
		}

		variable "zone" {
				default = "europe-west4-a"
				description = "GCP Zone, should be within the Region"
		}

		variable "database_instance_name" {
				description = "The name of the database instance"
				default     = "quarkus-fruits"
		}
		variable "database_instance_tier" {
				default = "db-n1-standard-1"
		}

		variable "database_name" {
				description = "The name of the database"
				default     = "quarkus-fruits"
		}
		```

## How To Connect To The Database

> To access a Cloud SQL instance from an application running in Google Kubernetes Engine, you can use either the Cloud SQL Proxy (with public or private IP), or connect directly using a private IP address.
> The Cloud SQL Proxy is the recommended way to connect to Cloud SQL, even when using private IP. This is because the proxy provides strong encryption and authentication using IAM, which can help keep your database secure. [MySQL Connect From Kubernetes Guide](https://cloud.google.com/sql/docs/mysql/connect-kubernetes-engine?hl=en_US)

Our appliction runs in Kubernetes, so the above guide is perfect for us. It is recommened to use the `Cloud SQL Proxy` and I tend to listen to such advise. So in this guide, we're going to use the proxy.

We won't configure the proxy until later in the guide, but lets make sure we have the pre-requisites in place.

We need:

1. a Google Cloud Service Account with access to Cloud SQL
2. a JSON key for this Service Account, which the proxy can use as credentials

### Create Service Account

To create the Service Account, you can either the [UI](https://cloud.google.com/iam/docs/creating-managing-service-accounts#creating_a_service_account) or the `gcloud` CLI.

Step one, create the Service Account:

```sh
gcloud iam service-accounts create my-sa-123 \
    --description="sa-description" \
    --display-name="sa-display-name"
```

Step two, give it the required permissions for Cloud SQL.

```sh
gcloud projects add-iam-policy-binding my-project-123 \
  --member serviceAccount:my-sa-123@my-project-123.iam.gserviceaccount.com \
  --role roles/cloudsql.admin
```

!!! important
    Do make sure you change the values such as `my-sa-123` and `my-project-123` to your values.

### Generate JSON Key

To create the Service Account ***key*** you can either use the UI, or the `gcloud` CLI.

```sh
gcloud iam service-accounts keys create ~key.json \
  --iam-account <YOUR-SA-NAME>>@project-id.iam.gserviceaccount.com
```

And make sure you save the key.json, we will use it later.