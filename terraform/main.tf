
# ECR

resource "aws_ecr_repository" "resnet18" {
    name = "resnet18"
}

# VPC

resource "aws_vpc" "resnet18_vpc" {
    tags = {
        Name = "resnet18_vpc"
    }
    cidr_block = "10.0.0.0/16"
}

resource "aws_subnet" "public" {
  vpc_id = aws_vpc.resnet18_vpc.id
  cidr_block = cidrsubnet(aws_vpc.resnet18_vpc.cidr_block, 8, 1)
  map_public_ip_on_launch = true
    tags = {
        Name = "resnet18_public_subnet"
    }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.resnet18_vpc.id
  tags = {
    Name = "resnet18-igw"
  }
}


resource "aws_route_table" "public_route" {
  vpc_id = aws_vpc.resnet18_vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
}

resource "aws_route_table_association" "to-public" {
    subnet_id = aws_subnet.public.id
    route_table_id = aws_route_table.public_route.id
  
}

# security group

resource "aws_security_group" "resnet18_sg" {
  name = "resnet18_sg"
  vpc_id = aws_vpc.resnet18_vpc.id
  ingress {
    cidr_blocks = ["0.0.0.0/0"]
    from_port = 8080
    to_port = 8080
    protocol = "tcp"
  }
}



