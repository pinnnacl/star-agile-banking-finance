terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
  }
}

# Configure the AWS provider
provider "aws" {
  region = "ap-south-1"
}

# Create a VPC
resource "aws_vpc" "proj-vpc" {
  cidr_block = "10.0.0.0/16"
}

# Create an Internet gateway
resource "aws_internet_gateway" "BNKproj-ig" {
  vpc_id = aws_vpc.proj-vpc.id
  tags = {
    Name = "gateway1"
  }
}

# Setting up the route table
resource "aws_route_table" "BNKproject-rt" {
  vpc_id = aws_vpc.proj-vpc.id
  route {
    # pointing to the internet
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.BNKproj-ig.id
  }
  route {
    ipv6_cidr_block = "::/0"
    gateway_id      = aws_internet_gateway.BNKproj-ig.id
  }

  tags = {
    Name = "rt1"
  }
}

# Setting up the subnet
resource "aws_subnet" "BNKproj-subnet" {
  vpc_id            = aws_vpc.proj-vpc.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "ap-south-1b"
  tags = {
    Name = "subnet"
  }
}

# Associating the subnet with the route table
resource "aws_route_table_association" "BNKproj-rt-sub-assoc" {
  subnet_id      = aws_subnet.BNKproj-subnet.id
  route_table_id = aws_route_table.BNKproject-rt.id
}

# Creating a security group
resource "aws_security_group" "BNKproj-sg" {
  name        = "proj-sg"
  description = "Allow inbound traffic"
  vpc_id      = aws_vpc.proj-vpc.id

  ingress {
    description = "Allow all traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS traffic"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTP traffic"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "proj-sg1"
  }
}

# Create a new network interface
resource "aws_network_interface" "BNKproj-ni" {
  subnet_id       = aws_subnet.BNKproj-subnet.id
  private_ips     = ["10.0.1.10"]
  security_groups = [aws_security_group.BNKproj-sg.id]
}

# Attaching an elastic IP to the network interface
resource "aws_eip" "BNKproj-eip" {
  vpc                      = true
  network_interface        = aws_network_interface.BNKproj-ni.id
  associate_with_private_ip = "10.0.1.10"
}

# Create an Ubuntu EC2 instance
resource "aws_instance" "BNK-UAT-Server" {
  ami               = "ami-0a0e5d9c7acc336f1"
  instance_type     = "t2.micro"
  availability_zone = "ap-south-1b"
  key_name          = "my"

  network_interface {
    device_index          = 0
    network_interface_id  = aws_network_interface.BNKproj-ni.id
  }

  user_data = <<-EOF
  #!/bin/bash
  sudo apt-get update -y
  sudo apt install docker.io -y
  sudo systemctl enable docker
  sudo docker run -itd -p 8085:8081 nandusathyan/app-name:latest
  sudo docker start $(docker ps -aq)
  EOF

  tags = {
    Name = "BNK-UAT-Server"
  }
}
