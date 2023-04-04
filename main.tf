provider "aws" {
  region  = "us-east-1"
  access_key = "AKIAQMCKCVD4MBBF"
  secret_key = "gL8FDnRT7OQPlUbp/G1uQHM46yXwK0uDVafYS"

}

resource "aws_instance" "web" {
  ami           = "ami-007855ac798b5175e"
  instance_type = "t2.micro"
} 

#create vpc

resource "aws_vpc" "main" {
  cidr_block       = "10.0.0.0/16"

  tags = {
    Name = "main"
  }
}

#create IG

resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "main"
  }
}

# create custom route

resource "aws_route_table" "example" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }

  route {
    ipv6_cidr_block        = "::/0"
    gateway_id = aws_internet_gateway.gw.id
  }

  tags = {
    Name = "example"
  }
}

#create a subnet

resource "aws_subnet" "subnet-1" {
  vpc_id     = aws_vpc.main.id
  cidr_block = "10.0.1.0/24"
  availability_zone = "us-east-1a"

  tags = {
    Name = "Main"
  }
}

#Associate subnet with route

resource "aws_route_table_association" "a" {
  subnet_id      = aws_subnet.subnet-1.id
  route_table_id = aws_route_table.example.id
}

#SG allow port 22,80,443

resource "aws_security_group" "allow_tls" {
  name        = "allow_tls"
  description = "Allow TLS inbound traffic"
  vpc_id      = aws_vpc.main.id

  ingress {
    description      = "TLS from VPC"
    from_port        = 443
    to_port          = 443
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]

  }
   ingress {
    description      = "TLS from VPC"
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]

  }
   ingress {
    description      = "TLS from VPC"
    from_port        = 2
    to_port          = 2
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]

  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "allow_tls"
  }
}

# create network inteerfernce

resource "aws_network_interface" "test" {
  subnet_id       = aws_subnet.subnet-1.id
  private_ips     = ["10.0.1.50"]
  security_groups = [aws_security_group.allow_tls.id]

}

#elastic ip


resource "aws_eip" "one" {
  vpc                       = true
  network_interface         = aws_network_interface.test.id
  associate_with_private_ip = "10.0.1.50"
  depends_on = [aws_internet_gateway.gw]
}

resource "aws_instance" "web_server_instance" {
  ami = "ami-007855ac798b5175e"
  instance_type = "t2.micro"
  availability_zone = "us-east-1a"
  key_name = "server"

  network_interface {
    device_index = 0
    network_interface_id =  aws_network_interface.test.id
  }

  user_data = <<-EOF
                 #!/bin/bash
                 sudo apt update -y
                 sudo apt install apache2 -y
                 sudo systemctl start apache2
                 sudo bash -c 'echo your very first web server > /var/www/html/index.html'
                 EOF
  tags = {
    name = "web-server"
  }
}
