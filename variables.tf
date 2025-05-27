variable "aws_region" {
  description = "AWS region"
  type = string
}

variable "project" {
  description = "Name of the project to be used for generic components"
  type = string
  default = "Nextcloud"
}

variable "nextcloud_port" {
  description = "Port for nextcloud webserver"
  type = number
  default = 8080
}

variable "route53_zone" {
  description = "ID for Route53 hosted zone"
  type = string
}

variable "a_record" {
  description = "DNS A record"
  type = string
}

variable "ssl_cert" {
  description = "arn for ssl certificate"
  type = string
}

variable "ami" {
  description = "Ubuntu Server 24.04 LTS ami for nextcloud"
  type = string
  default = "ami-07eef52105e8a2059"
}

variable "public_key" {
  description = "Public key for ssh access to vm"
  type = string
  default = "~/.ssh/id_rsa.pub"
}

variable "admin_user" {
  description = "Admin user for nextcloud"
  type = string
}

variable "admin_pass" {
  description = "Password for admin user"
  type = string
}

variable "default_user" {
  description = "Name for default user"
  type = string
}

variable "default_user_pass" {
  description = "Password for default user"
  type = string
}

variable "default_quota" {
  description = "Default quota in GB for default user"
  type = number
  default = 20
}

variable "bucket_name" {
  description = "Name of S3 bucket for storage"
  type = string
}

variable "s3_user" {
  description = "User for S3 access"
  type = string
  default = "nextcloud-s3-user"
}

variable "mariadb_port" {
  description = "Port for MariaDB"
  type = number
  default = 3306
}

variable "mariadb_user" {
  description = "Master DB user for MariaDB"
  type = string
}

variable "mariadb_pass" {
  description = "Password for master DB user for MariaDB"
  type = string
}