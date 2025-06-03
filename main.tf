provider "aws" {
  region = "us-east-1"  # Change to your desired region
}

# Create a VPC
resource "aws_vpc" "k8s_vpc" {
  cidr_block = "10.0.0.0/16"
  enable_dns_support = true
  enable_dns_hostnames = true
  tags = {
    Name = "k8s-vpc"
  }
}

# Create Subnets
resource "aws_subnet" "k8s_subnet_a" {
  vpc_id                  = aws_vpc.k8s_vpc.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true
  tags = {
    Name = "k8s-subnet-a"
  }
}

resource "aws_subnet" "k8s_subnet_b" {
  vpc_id                  = aws_vpc.k8s_vpc.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = "us-east-1b"
  map_public_ip_on_launch = true
  tags = {
    Name = "k8s-subnet-b"
  }
}

# Create an Internet Gateway and Attach it to VPC
resource "aws_internet_gateway" "k8s_igw" {
  vpc_id = aws_vpc.k8s_vpc.id
}

# Security Group to allow necessary traffic
resource "aws_security_group" "k8s_sg" {
  name        = "k8s-sg"
  description = "Allow all inbound/outbound traffic for Kubernetes"
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

# Create IAM Role for EC2 Instances (Worker Nodes)
resource "aws_iam_role" "k8s_worker_role" {
  name               = "k8s-worker-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action    = "sts:AssumeRole"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
        Effect    = "Allow"
        Sid       = ""
      }
    ]
  })
}

# Attach Policies to the IAM Role
resource "aws_iam_role_policy_attachment" "k8s_worker_policy" {
  role       = aws_iam_role.k8s_worker_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}

resource "aws_iam_role_policy_attachment" "k8s_eks_cluster_policy" {
  role       = aws_iam_role.k8s_worker_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

resource "aws_iam_role_policy_attachment" "k8s_vpc_policy" {
  role       = aws_iam_role.k8s_worker_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonVPCFullAccess"
}

# Create EC2 Auto Scaling Group for Spot Instances
resource "aws_launch_configuration" "k8s_launch_config" {
  name          = "k8s-launch-config"
  image_id      = "ami-0c55b159cbfafe1f0" # Replace with the latest Amazon Linux 2 AMI for Kubernetes (find in AWS Console)
  instance_type = "t3a.micro"             # Change to your preferred EC2 type
  security_groups = [aws_security_group.k8s_sg.id]
  iam_instance_profile = aws_iam_role.k8s_worker_role.name

  lifecycle {
    create_before_destroy = true
  }
}

# Auto Scaling Group for Kubernetes Worker Nodes (Spot Instances)
resource "aws_autoscaling_group" "k8s_asg" {
  desired_capacity     = 2
  max_size             = 3
  min_size             = 1
  launch_configuration = aws_launch_configuration.k8s_launch_config.id
  vpc_zone_identifier  = [aws_subnet.k8s_subnet_a.id, aws_subnet.k8s_subnet_b.id]
  
  tag {
    key                 = "Name"
    value               = "k8s-worker-node"
    propagate_at_launch = true
  }

  health_check_type          = "EC2"
  health_check_grace_period = 300
}

# Spot Instance Configuration (Optional for better control over Spot Instance interruption)
resource "aws_spot_instance_request" "k8s_spot" {
  ami             = "ami-0c55b159cbfafe1f0" # Replace with the latest AMI ID
  instance_type   = "t3a.micro"
  spot_price      = "0.01" # Adjust based on your budget
  max_duration    = 3600
  security_groups = [aws_security_group.k8s_sg.name]

  tags = {
    Name = "SpotInstance"
  }
}
