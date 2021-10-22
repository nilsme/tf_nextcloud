# README

> Nextcloud deployment on AWS with terraform.

## Requirements

- terraform CLI (download: <https://www.terraform.io/downloads.html>)
- Route 53 hosted zone (available domain)

## Set variables

Create a file `terraform.tfvars` and include the following values as strings.

```terraform.tfvars
route53_zone = ""
a_record = ""
ssl_cert = ""
bucket_name = ""
admin_user = ""
admin_pass = ""
default_user = ""
default_user_pass = ""
```

> Password needs to be at least 10 characters long and special
> characters must be escaped.

## Terraform init

```Shell script
terraform init
```

## Terraform plan

```Shell script
terraform plan
```

## Terraform apply

```Shell script
terraform apply
```

## Terraform destroy

```Shell script
terraform destroy
```
