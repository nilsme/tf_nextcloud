# Configure AWS provider
provider "aws" {
  region = var.aws_region
}

# Network ------------------------------------------------------------------- #

# Create a VPC
resource "aws_vpc" "vpc_nextcloud" {
  cidr_block = "10.0.0.0/16"
  enable_dns_support = true
  enable_dns_hostnames = true
  tags = {
    Name = "Nextcloud VPC"
    Nextcloud = "vpc"
    }
}

# Create a public subnet 1
resource "aws_subnet" "public" {
  vpc_id = aws_vpc.vpc_nextcloud.id
  cidr_block = "10.0.1.0/24"
  availability_zone = format("%sc", var.aws_region)
  tags = {
    Name = "Nextcloud public subnet"
    Nextcloud = "public subnet"
    }
}

# Create a public subnet 2
resource "aws_subnet" "public2" {
  vpc_id = aws_vpc.vpc_nextcloud.id
  cidr_block = "10.0.3.0/24"
  availability_zone = format("%sb", var.aws_region)
  tags = {
    Name = "Nextcloud public subnet 2"
    Nextcloud = "public subnet 2"
    }
}

# Create a private subnet
resource "aws_subnet" "private" {
  vpc_id = aws_vpc.vpc_nextcloud.id
  cidr_block = "10.0.2.0/24"
  availability_zone = format("%sc", var.aws_region)
  tags = {
    Name = "Nextcloud private subnet"
    Nextcloud = "private subnet"
    }
}

# Create a private subnet 2
resource "aws_subnet" "private2" {
  vpc_id = aws_vpc.vpc_nextcloud.id
  cidr_block = "10.0.4.0/24"
  availability_zone = format("%sb", var.aws_region)
  tags = {
    Name = "Nextcloud private subnet 2"
    Nextcloud = "private subnet 2"
    }
}

# Create internet gateway
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.vpc_nextcloud.id
}

# Create route table for public subnet
resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.vpc_nextcloud.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
}

# Associate route table for public subnet
resource "aws_route_table_association" "public_route_assoc" {
  subnet_id = aws_subnet.public.id
  route_table_id = aws_route_table.public_rt.id
}

# Create route table for private subnet
resource "aws_route_table" "private-rt" {
  vpc_id = aws_vpc.vpc_nextcloud.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
}

# Associate route table for private subnet
resource "aws_route_table_association" "private-route-assoc" {
  subnet_id = aws_subnet.private.id
  route_table_id = aws_route_table.private-rt.id
}


# Load balancer with ssl ---------------------------------------------------- #

# Create a new load balancer
resource "aws_lb" "nextcloud-elb" {
  name = "nextcloud-elb"
  internal = false
  load_balancer_type = "application"
  subnets = [
    aws_subnet.public.id,
    aws_subnet.public2.id
    ]
  security_groups = [
    aws_security_group.nextcloud-sg-elb.id
    ]
  tags = {
    Name = "nextcloud elb"
  }
}

# Create a target group for load balancer
resource "aws_lb_target_group" "nextcloud-tg" {
  name = "nextcloud-tg"
  port = var.nextcloud_port
  protocol = "HTTP"
  vpc_id = aws_vpc.vpc_nextcloud.id
  
  health_check {
    path = "/"
    protocol = "HTTP"
    port = var.nextcloud_port
    matcher = "400"
  }

  tags = {
    Name = "nextcloud tg"
  }
}

# Attach instance to target group
resource "aws_lb_target_group_attachment" "nextcloud-tg-attach" {
  target_group_arn = aws_lb_target_group.nextcloud-tg.arn
  target_id        = aws_instance.ec2_nextcloud.id
  port             = var.nextcloud_port
}

# Create a listener for port 443
resource "aws_lb_listener" "webserver" {
  load_balancer_arn = aws_lb.nextcloud-elb.arn
  port = "443"
  protocol = "HTTPS"
  ssl_policy = "ELBSecurityPolicy-2016-08"
  certificate_arn = var.ssl_cert

  default_action {
    type = "forward"
    target_group_arn = aws_lb_target_group.nextcloud-tg.arn
  }
}

# Create a redirect for port 80
resource "aws_lb_listener" "front_end_http" {
  load_balancer_arn = aws_lb.nextcloud-elb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type = "redirect"

    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

# Set DNS routing policy
resource "aws_route53_record" "cloud" {
  zone_id = var.route53_zone
  name = var.a_record
  type = "A"

  alias {
    name = aws_lb.nextcloud-elb.dns_name
    zone_id = aws_lb.nextcloud-elb.zone_id
    evaluate_target_health = false
  }
}


# Security groups ----------------------------------------------------------- #

resource "aws_security_group" "nextcloud-allow-ssh" {
  name = "nextcloud-allow-ssh"
  vpc_id = aws_vpc.vpc_nextcloud.id

  ingress {
    from_port = 22
    to_port = 22
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "nextcloud-sg-elb" {
  name = "nextcloud-sg-elb"
  vpc_id = aws_vpc.vpc_nextcloud.id

  ingress {
    from_port = 80
    to_port = 80
    protocol = "tcp"
    cidr_blocks = [ "0.0.0.0/0" ]
  }

  ingress {
    from_port = 443
    to_port = 443
    protocol = "tcp"
    cidr_blocks = [ "0.0.0.0/0" ]
  }

  ingress {
    from_port = var.nextcloud_port
    to_port = var.nextcloud_port
    protocol = "tcp"
    cidr_blocks = [
     aws_subnet.private.cidr_block,
     aws_subnet.private2.cidr_block
      ]
  }

  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "nextcloud-allow-elb" {
  name = "nextcloud-allow-elb"
  vpc_id = aws_vpc.vpc_nextcloud.id

  ingress {
    from_port = var.nextcloud_port
    to_port = var.nextcloud_port
    protocol = "tcp"
    security_groups = [aws_security_group.nextcloud-sg-elb.id]
  }

  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}


# EC2 instance -------------------------------------------------------------- #

# Create an EC2 instance for Nextcloud
resource "aws_instance" "ec2_nextcloud" {
  ami = var.ami
  instance_type = "t3.micro"
  subnet_id = aws_subnet.private.id
  associate_public_ip_address = true
  vpc_security_group_ids = [
    aws_security_group.nextcloud-allow-elb.id
  ]
  user_data = templatefile("user_data.sh", {
    admin_user = var.admin_user
    admin_pass = var.admin_pass
    nextcloud_port = var.nextcloud_port
    a_record = var.a_record
    default_user = var.default_user
    default_user_pass = var.default_user_pass
    bucket_name = var.bucket_name
    aws_region = var.aws_region
    nextcloud_s3_user_id = aws_iam_access_key.nextcloud_s3_user.id
    nextcloud_s3_user_secret = aws_iam_access_key.nextcloud_s3_user.secret
  })
  tags = {
    Name = "Nextcloud EC2"
    Nextcloud = "ec2"
    }
  depends_on = [
    aws_s3_bucket.bucket_nextcloud,
    aws_iam_access_key.nextcloud_s3_user
  ]
}

# Enable encryption for all EBS volumes by default
resource "aws_ebs_encryption_by_default" "enabled" {
  enabled = true
}


# S3 for main storage ------------------------------------------------------- #

# Key for bucket encryption
resource "aws_kms_key" "mykey" {
  description  = "This key is used to encrypt bucket objects"
  deletion_window_in_days = 10
}

# Create a S3 bucket for main storage
resource "aws_s3_bucket" "bucket_nextcloud" {
  bucket = var.bucket_name
  acl = "private"

  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        kms_master_key_id = aws_kms_key.mykey.arn
        sse_algorithm = "aws:kms"
      }
    }
  }

  tags = {
      Name = "Nextcloud bucket"
      Nextcloud = "main_storage"
  }
}

# Block all public access to S3 bucket
resource "aws_s3_bucket_public_access_block" "block_bucket" {
  bucket = aws_s3_bucket.bucket_nextcloud.id
  block_public_acls = true
  block_public_policy = true
  ignore_public_acls = true
  restrict_public_buckets = true
}


# User for S3 access -------------------------------------------------------- #

# Create IAM user
resource "aws_iam_user" "nextcloud_s3_user" {
  name = var.s3_user
}
# Create access keys for IAM user
resource "aws_iam_access_key" "nextcloud_s3_user" {
  user = aws_iam_user.nextcloud_s3_user.name
}

# Attach policy for S3 and encryption keys
resource "aws_iam_user_policy" "s3_policy" {
  name = "nextcloud-s3-policy"
  user = var.s3_user
  policy = templatefile("policy.json", {
    bucket_name = var.bucket_name
  })
  depends_on = [
    aws_iam_user.nextcloud_s3_user
  ]
}
