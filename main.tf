terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

resource "aws_vpc" "mtc1_vpc" {
  cidr_block           = "10.123.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "dev"
  }
}

resource "aws_subnet" "mtc1_public_subnet" {
  vpc_id                  = aws_vpc.mtc1_vpc.id
  cidr_block              = "10.123.1.0/24"
  map_public_ip_on_launch = true
  availability_zone       = "us-east-1a"

  tags = {
    Name = "dev-public"
  }
}

resource "aws_internet_gateway" "mtc1_internet_gateway" {
  vpc_id = aws_vpc.mtc1_vpc.id

  tags = {
    Name = "dev-igw"
  }
}

resource "aws_route_table" "mtc1_public_rt" {
  vpc_id = aws_vpc.mtc1_vpc.id

  tags = {
    Name = "dev_public_rt"
  }
}

resource "aws_route" "default_route" {
  route_table_id         = aws_route_table.mtc1_public_rt.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.mtc1_internet_gateway.id
}

resource "aws_route_table_association" "mtc1_public_assoc" {
  subnet_id      = aws_subnet.mtc1_public_subnet.id
  route_table_id = aws_route_table.mtc1_public_rt.id
}

resource "aws_security_group" "mtc1_sg" {
  name        = "dev_sg"
  description = "dev security group"
  vpc_id      = aws_vpc.mtc1_vpc.id

  ingress {
    description = "TLS from VPC"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]

  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_key_pair" "mtc1_auth" {
  key_name   = "mtc1key"
  public_key = file("~/.ssh/mtc1key.pub")
}

resource "aws_instance" "dev_node" {
  ami                    = data.aws_ami.server_ami.id
  instance_type          = "t2.micro"
  key_name               = aws_key_pair.mtc1_auth.id
  vpc_security_group_ids = [aws_security_group.mtc1_sg.id]
  subnet_id              = aws_subnet.mtc1_public_subnet.id
  user_data              = file("userdata.tpl")

  root_block_device {
    volume_size = 10
  }

  tags = {
    Name = "dev-node"
  }

  provisioner "local-exec" {
    command = templatefile("${var.host_os}-ssh-config.tpl", {
      hostname     = self.public_ip,
      user         = "ubuntu",
      identityfile = "~/.ssh/mtc1key"
    })
    interpreter = var.host_os == "linux" ? ["bash", "-c"] : ["Powershell", "-command"]
  }
}

  