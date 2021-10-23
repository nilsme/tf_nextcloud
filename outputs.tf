output "load_balancer_dns" {
  value = format("https://%s", aws_lb.nextcloud_elb.dns_name)
}

output "nextcloud_url" {
  value = format("https://%s", var.a_record)
}
