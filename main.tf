# Configure AWS provider
provider "aws" {
  region = var.aws_region
}

# Network ------------------------------------------------------------------- #

# Create a VPC
resource "aws_vpc" "vpc" {
  cidr_block = "10.0.0.0/16"
  enable_dns_support = true
  enable_dns_hostnames = true
  tags = {
    Name = format("%s VPC", var.project)
    }
}

# Create a public subnet 1
resource "aws_subnet" "public" {
  vpc_id = aws_vpc.vpc.id
  cidr_block = "10.0.1.0/24"
  availability_zone = format("%sc", var.aws_region)
  tags = {
    Name = format("%s public subnet", var.project)
    }
}

# Create a public subnet 2
resource "aws_subnet" "public2" {
  vpc_id = aws_vpc.vpc.id
  cidr_block = "10.0.3.0/24"
  availability_zone = format("%sb", var.aws_region)
  tags = {
    Name = format("%s public subnet 2", var.project)
    }
}

# Create a private subnet
resource "aws_subnet" "private" {
  vpc_id = aws_vpc.vpc.id
  cidr_block = "10.0.2.0/24"
  availability_zone = format("%sc", var.aws_region)
  tags = {
    Name = format("%s private subnet", var.project)
    }
}

# Create a private subnet 2
resource "aws_subnet" "private2" {
  vpc_id = aws_vpc.vpc.id
  cidr_block = "10.0.4.0/24"
  availability_zone = format("%sb", var.aws_region)
  tags = {
    Name = format("%s private subnet 2", var.project)
    }
}

# Create internet gateway
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.vpc.id
}

# Create route table for public subnet
resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.vpc.id

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
resource "aws_route_table" "private_rt" {
  vpc_id = aws_vpc.vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
}

# Associate route table for private subnet
resource "aws_route_table_association" "private_route_assoc" {
  subnet_id = aws_subnet.private.id
  route_table_id = aws_route_table.private_rt.id
}


# Load balancer with ssl ---------------------------------------------------- #

# Create a new load balancer
resource "aws_lb" "nextcloud_elb" {
  name = format("%s-ELB", var.project)
  internal = false
  load_balancer_type = "application"
  subnets = [
    aws_subnet.public.id,
    aws_subnet.public2.id
    ]
  security_groups = [
    aws_security_group.sg_elb.id
    ]
  tags = {
    Name = format("%s ELB", var.project)
  }
}

# Create a target group for load balancer
resource "aws_lb_target_group" "nextcloud_tg" {
  name = format("%s-Target-Group", var.project)
  port = var.nextcloud_port
  protocol = "HTTP"
  vpc_id = aws_vpc.vpc.id
  
  health_check {
    path = "/"
    protocol = "HTTP"
    port = var.nextcloud_port
    matcher = "400"
  }

  tags = {
    Name = format("%s Target Group", var.project)
  }
}

# Attach instance to target group
resource "aws_lb_target_group_attachment" "nextcloud_tg_attach" {
  target_group_arn = aws_lb_target_group.nextcloud_tg.arn
  target_id        = aws_instance.ec2_nextcloud.id
  port             = var.nextcloud_port
}

# Create a listener for port 443
resource "aws_lb_listener" "webserver" {
  load_balancer_arn = aws_lb.nextcloud_elb.arn
  port = "443"
  protocol = "HTTPS"
  ssl_policy = "ELBSecurityPolicy-2016-08"
  certificate_arn = var.ssl_cert

  default_action {
    type = "forward"
    target_group_arn = aws_lb_target_group.nextcloud_tg.arn
  }
}

# Create a redirect for port 80
resource "aws_lb_listener" "webserver_http" {
  load_balancer_arn = aws_lb.nextcloud_elb.arn
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
resource "aws_route53_record" "a_record" {
  zone_id = var.route53_zone
  name = var.a_record
  type = "A"

  alias {
    name = aws_lb.nextcloud_elb.dns_name
    zone_id = aws_lb.nextcloud_elb.zone_id
    evaluate_target_health = false
  }
}


# Security groups ----------------------------------------------------------- #

resource "aws_security_group" "allow_ssh" {
  name = format("%s SG Allow SSH", var.project)
  vpc_id = aws_vpc.vpc.id

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

  tags = {
    Name = format("%s SG Allow SSH", var.project)
  }
}

resource "aws_security_group" "sg_elb" {
  name = format("%s SG Load Balancer", var.project)
  vpc_id = aws_vpc.vpc.id

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
     aws_subnet.public.cidr_block,
     aws_subnet.public2.cidr_block
      ]
  }

  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

    tags = {
    Name = format("%s SG Load Balancer", var.project)
  }
}

resource "aws_security_group" "allow_elb" {
  name = format("%s SG Allow Load Balancer", var.project)
  vpc_id = aws_vpc.vpc.id

  ingress {
    from_port = var.nextcloud_port
    to_port = var.nextcloud_port
    protocol = "tcp"
    security_groups = [aws_security_group.sg_elb.id]
  }

  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = format("%s SG Allow Load Balancer", var.project)
  }
}

resource "aws_security_group" "rds" {
  name = format("%s SG RDS", var.project)
  vpc_id = aws_vpc.vpc.id

  ingress {
    from_port = var.mariadb_port
    to_port = var.mariadb_port
    protocol = "tcp"
    cidr_blocks = [
      aws_subnet.public.cidr_block,
      aws_subnet.public2.cidr_block
    ]
  }

  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

    tags = {
    Name = format("%s SG RDS", var.project)
  }
}

resource "aws_security_group" "allow_rds" {
  name = format("%s SG Allow RDS", var.project)
  vpc_id = aws_vpc.vpc.id

  ingress {
    from_port = var.mariadb_port
    to_port = var.mariadb_port
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

    tags = {
    Name = format("%s SG Allows RDS", var.project)
  }
}


# RDS database -------------------------------------------------------------- #

# Create subnet group for database
resource "aws_db_subnet_group" "private" {
  # name = "nextcloud-db-subnet-group"
  subnet_ids = [
    aws_subnet.private.id,
    aws_subnet.private2.id
  ]
  tags = {
    Name = format("%s DB subnet group", var.project)
  }
}

# Create a MariaDB for Nextcloud
resource "aws_db_instance" "db_nextcloud" {
  db_subnet_group_name = aws_db_subnet_group.private.name
  vpc_security_group_ids = [aws_security_group.rds.id]
  allocated_storage = 10
  storage_type = "gp2"
  engine = "MariaDB"
  instance_class = "db.t3.micro"
  name = "nextcloud"
  username = var.mariadb_user
  password = var.mariadb_pass
  port = var.mariadb_port
  publicly_accessible = false
  skip_final_snapshot = true
  deletion_protection = false

  tags = {
    Name = format("%s MariaDB", var.project)
  }
}


# EC2 instance -------------------------------------------------------------- #

# Create an EC2 instance for Nextcloud
resource "aws_instance" "ec2_nextcloud" {
  ami = var.ami
  instance_type = "t3.micro"
  subnet_id = aws_subnet.public.id
  associate_public_ip_address = true
  vpc_security_group_ids = [
    aws_security_group.allow_elb.id,
    aws_security_group.allow_rds.id
  ]
  user_data = templatefile("user_data.sh", {
    admin_user = var.admin_user
    admin_pass = var.admin_pass
    nextcloud_port = var.nextcloud_port
    a_record = var.a_record
    trusted_lb = aws_lb.nextcloud_elb.dns_name
    default_user = var.default_user
    default_user_pass = var.default_user_pass
    bucket_name = var.bucket_name
    aws_region = var.aws_region
    nextcloud_s3_user_id = aws_iam_access_key.s3_user.id
    nextcloud_s3_user_secret = aws_iam_access_key.s3_user.secret
    mariadb_host = aws_db_instance.db_nextcloud.address
    mariadb_port = var.mariadb_port
    mariadb_user = var.mariadb_user
    mariadb_pass = var.mariadb_pass
  })
  tags = {
    Name = format("%s EC2", var.project)
  }
  depends_on = [
    aws_db_instance.db_nextcloud,
    aws_s3_bucket.bucket_nextcloud,
    aws_iam_access_key.s3_user
  ]
}

# Enable encryption for all EBS volumes by default
resource "aws_ebs_encryption_by_default" "enabled" {
  enabled = true
}


# S3 for main storage ------------------------------------------------------- #

# Key for bucket encryption
resource "aws_kms_key" "key" {
  description  = "This key is used to encrypt bucket objects"
  deletion_window_in_days = 10
}

# Create a S3 bucket for main storage
resource "aws_s3_bucket" "bucket_nextcloud" {
  bucket = var.bucket_name
  force_destroy = true
  acl = "private"

  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        kms_master_key_id = aws_kms_key.key.arn
        sse_algorithm = "aws:kms"
      }
    }
  }

  tags = {
    Name = format("%s Bucket", var.project)
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
resource "aws_iam_user" "s3_user" {
  name = var.s3_user
  tags = {
    Name = format("%s S3 User", var.project)
  }
}
# Create access keys for IAM user
resource "aws_iam_access_key" "s3_user" {
  user = aws_iam_user.s3_user.name
}

# Attach policy for S3 and encryption keys
resource "aws_iam_user_policy" "s3_policy" {
  name = "nextcloud-s3-policy"
  user = var.s3_user
  policy = templatefile("policy.json", {
    bucket_name = var.bucket_name
  })
  depends_on = [
    aws_iam_user.s3_user
  ]
}
