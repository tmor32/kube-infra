provider "aws" {
  region = "us-east-2"
}

# Latest Amazon Linux 2 AMI
data "aws_ami" "amazon_linux_2" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# VPC
resource "aws_vpc" "k8s_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "k8s-vpc"
  }
}

# Subnets
resource "aws_subnet" "k8s_subnet_a" {
  vpc_id                  = aws_vpc.k8s_vpc.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "us-east-2a"
  map_public_ip_on_launch = true

  tags = {
    Name = "k8s-subnet-a"
  }
}

resource "aws_subnet" "k8s_subnet_b" {
  vpc_id                  = aws_vpc.k8s_vpc.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = "us-east-2b"
  map_public_ip_on_launch = true

  tags = {
    Name = "k8s-subnet-b"
  }
}

# Internet Gateway
resource "aws_internet_gateway" "k8s_igw" {
  vpc_id = aws_vpc.k8s_vpc.id
}

# Security Group
resource "aws_security_group" "k8s_sg" {
  name        = "k8s-sg"
  description = "Allow all traffic"
  vpc_id      = aws_vpc.k8s_vpc.id

  ingress {
    from_port   = 0
    to_port     = 65535
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 65535
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# IAM Role for Worker Nodes
resource "aws_iam_role" "k8s_worker_role" {
  name = "k8s-worker-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action    = "sts:AssumeRole",
        Principal = { Service = "ec2.amazonaws.com" },
        Effect    = "Allow",
        Sid       = ""
      }
    ]
  })
}

# IAM Policy Attachments
resource "aws_iam_role_policy_attachment" "worker_node_policy" {
  role       = aws_iam_role.k8s_worker_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}

resource "aws_iam_role_policy_attachment" "cluster_policy" {
  role       = aws_iam_role.k8s_worker_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

resource "aws_iam_role_policy_attachment" "vpc_policy" {
  role       = aws_iam_role.k8s_worker_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonVPCFullAccess"
}

# IAM Instance Profile
resource "aws_iam_instance_profile" "k8s_worker_profile" {
  name = "k8s-worker-profile"
  role = aws_iam_role.k8s_worker_role.name
}

# Launch Template with Spot Instances
resource "aws_launch_template" "k8s_spot_template" {
  name_prefix   = "k8s-spot-"
  image_id      = data.aws_ami.amazon_linux_2.id
  instance_type = "t3a.micro"

  key_name = var.key_name

  iam_instance_profile {
    name = aws_iam_instance_profile.k8s_worker_profile.name
  }

  instance_market_options {
    market_type = "spot"

    spot_options {
      max_price            = "0.0125"
      spot_instance_type   = "one-time"
    }
  }

  network_interfaces {
    associate_public_ip_address = true
    security_groups             = [aws_security_group.k8s_sg.id]
  }

  tag_specifications {
    resource_type = "instance"

    tags = {
      Name = "k8s-spot-worker"
    }
  }
}

# Auto Scaling Group for Spot Workers
resource "aws_autoscaling_group" "k8s_asg" {
  desired_capacity    = 2
  max_size            = 3
  min_size            = 1
  vpc_zone_identifier = [
    aws_subnet.k8s_subnet_a.id,
    aws_subnet.k8s_subnet_b.id,
  ]

  launch_template {
    id      = aws_launch_template.k8s_spot_template.id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = "k8s-spot-worker"
    propagate_at_launch = true
  }

  health_check_type         = "EC2"
  health_check_grace_period = 300

  lifecycle {
    create_before_destroy = true
  }
}
