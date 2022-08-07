# Configure the AWS Provider
provider "aws" {
  region = "us-east-1"
  access_key = var.access-key
  secret_key = var.secret-key
}
# Create a VPC
resource "aws_vpc" "prod-vpc" {
  cidr_block = "10.0.0.0/16"
  tags={
    Name="production"
  }
}
#create internet gateway
resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.prod-vpc.id

  tags = {
    Name = "prod-gw"
  }
}
#create custom route table
resource "aws_route_table" "prod-route-table" {
  vpc_id = aws_vpc.prod-vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }

  route {
    ipv6_cidr_block        = "::/0"
    gateway_id             = aws_internet_gateway.gw.id
  }

  tags = {
    Name = "prod"
  }
}
#create a subnet
resource "aws_subnet" "subnet-1" {
  vpc_id = aws_vpc.prod-vpc.id
  cidr_block = "10.0.1.0/24"
  availability_zone = "us-east-1a"

  tags = {
    Name = "prod-subnet"
  }
}
#associate subnet with route table
resource "aws_route_table_association" "a" {
  subnet_id      = aws_subnet.subnet-1.id
  route_table_id = aws_route_table.prod-route-table.id
}
#create security group to allow port 22,80,443
resource "aws_security_group" "allow_web" {
  name        = "allow_web_traffic"
  description = "Allow Web inbound traffic"
  vpc_id      = aws_vpc.prod-vpc.id

  ingress {
    description      = "HTTPS from VPC"
    from_port        = 443
    to_port          = 443
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }
    ingress {
    description      = "HTTP from VPC"
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }
    ingress {
    description      = "SSH from VPC"
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  tags = {
    Name = "allow_web_traffic"
  }
}
#create an network interface with an ip in subnet created in step 4
resource "aws_network_interface" "web-server-nic" {
  subnet_id       = aws_subnet.subnet-1.id
  private_ips     = ["10.0.1.50"]
  security_groups = [aws_security_group.allow_web.id]

  # attachment {
  #   instance     = aws_instance.web-server.id
  #   device_index = 1
  # }
}
#assign an elastic IP to the network interface created in step 7
resource "aws_eip" "eip-1" {
  vpc                       = true
  network_interface         = aws_network_interface.web-server-nic.id
  associate_with_private_ip = "10.0.1.50"
  depends_on                = [aws_internet_gateway.gw]
  
}
#create ubuntu server and install/enable apache2
resource "aws_instance" "web-server" {
  ami = "ami-052efd3df9dad4825"
  key_name = "eks-key"
  instance_type = "t2.micro"
  availability_zone = "us-east-1a"
  network_interface {
    network_interface_id = aws_network_interface.web-server-nic.id
    device_index         = 0
  }
  tags={
    Name = "ubuntu-web-server"
  }
  user_data = <<-EOF
  #! /bin/bash
  sudo apt-get update
  sudo apt-get install -y apache2
  sudo systemctl start apache2
  sudo systemctl enable apache2
  echo "Deployed by Terraform" > /var/www/html/index.html
  EOF
}
output "server-private-ip"{
  value=aws_instance.web-server.private_ip
}
output "server-public-ip"{
  value=aws_eip.eip-1.public_ip
}
output "server-id"{
  value=aws_instance.web-server.id
}

variable "access-key"{
    description = "an access key of udacity3 profile"
    type = string
    #default = "value"
}
variable "secret-key"{
    description = "a secret key of udacity3 profile"
    type = string
    #default = "value"
}