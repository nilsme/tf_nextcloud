variable "aws_region" {
  description = "AWS region"
  type = string
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
  description = "Ubuntu ami for nextcloud"
  type = string
  default = "ami-05f7491af5eef733a"
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

variable "bucket_name" {
  description = "Name of S3 bucket for storage"
  type = string
}

variable "aws_key" {
  description = "Key for access to S3"
  type = string
}

variable "aws_secret" {
  description = "Secret for access to S3"
  type = string
}
