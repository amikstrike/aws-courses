provider "aws" {
  region  = "us-west-2"
}

resource "aws_vpc" "myVPC" {
  cidr_block = "10.0.0.0/16"
  tags = {
    Name = "myVPC"
  }
}

resource "aws_security_group" "mySecurityGroupPublic" {
  description = "SSH, HTTP/HTTPS access"
  name = "mySecurityGroupPublic"
  vpc_id = aws_vpc.myVPC.id

  ingress {
    from_port = 22
    protocol = "tcp"
    to_port = 22
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port = 80
    protocol = "tcp"
    to_port = 80
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port = 443
    protocol = "tcp"
    to_port = 443
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port = 0
    protocol = "-1"
    to_port = 0
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "mySecurityGroupPrivate" {
  name   = "mySecurityGroupPrivate"
  vpc_id = aws_vpc.myVPC.id
  ingress {
    from_port   = 22
    protocol    = "tcp"
    to_port     = 22
    cidr_blocks = [aws_subnet.subnet_public.cidr_block]
  }
  ingress {
    from_port   = 8
    protocol    = "icmp"
    to_port     = 0
    cidr_blocks = [aws_subnet.subnet_public.cidr_block]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_internet_gateway" "myInternetGateway" {
  vpc_id = aws_vpc.myVPC.id
  tags = {
    Name = "myInternetGateway"
  }
}

resource "aws_subnet" "subnet_private" {
  cidr_block        = "10.0.1.0/24"
  vpc_id            = aws_vpc.myVPC.id
  availability_zone = "us-west-2a"
  tags = {
    Name = "Private"
  }
}

resource "aws_subnet" "subnet_public" {
  cidr_block        = "10.0.2.0/24"
  vpc_id            = aws_vpc.myVPC.id
  availability_zone = "us-west-2b"
  tags = {
    Name = "Public"
  }
}

resource "aws_route_table" "rt_public" {
  vpc_id = aws_vpc.myVPC.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.myInternetGateway.id
  }

  tags = {
    Name = "Public"
  }
}

resource "aws_route_table" "rt_private" {
  vpc_id = aws_vpc.myVPC.id

  route {
    cidr_block     = "0.0.0.0/0"
    instance_id = aws_instance.NATInstance.id
  }

  tags = {
    Name = "Private"
  }
}

resource "aws_route_table_association" "association_public" {
  route_table_id = aws_route_table.rt_public.id
  subnet_id      = aws_subnet.subnet_public.id
}

resource "aws_route_table_association" "association_private" {
  route_table_id = aws_route_table.rt_private.id
  subnet_id      = aws_subnet.subnet_private.id
}

resource "aws_instance" "EC2InstancePublic" {
  ami                         = "ami-0d1cd67c26f5fca19"
  instance_type               = "t2.micro"
  key_name                    = "awssshkey"
  vpc_security_group_ids      = [aws_security_group.mySecurityGroupPublic.id]
  subnet_id                   = aws_subnet.subnet_public.id
  associate_public_ip_address = true
  user_data                   = <<EOF
#!/bin/bash
apt update && apt install -y apache2
echo "<html><h1>This is WebServer from public subnet</h1></html>" > /var/www/html/index.html
EOF
}

resource "aws_instance" "EC2InstancePrivate" {
  ami                    = "ami-0d1cd67c26f5fca19"
  instance_type          = "t2.micro"
  key_name               = "awssshkey"
  vpc_security_group_ids = [aws_security_group.mySecurityGroupPrivate.id]
  subnet_id              = aws_subnet.subnet_private.id
  user_data              = <<EOF
#!/bin/bash
apt update && apt install -y apache2
echo "<html><h1>This is WebServer from private subnet</h1></html>" > /var/www/html/index.html
EOF
}

resource "aws_instance" "NATInstance" {
  ami                         = "ami-0032ea5ae08aa27a2"
  instance_type               = "t2.micro"
  key_name                    = "awssshkey"
  vpc_security_group_ids      = [aws_security_group.mySecurityGroupPublic.id]
  subnet_id                   = aws_subnet.subnet_public.id
  associate_public_ip_address = true
  source_dest_check           = false
}

resource "aws_lb_target_group" "aws_training_lb_tg" {
  name     = "aws-training-lb-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.myVPC.id
}

resource "aws_lb" "aws_training_lb" {
  name               = "aws-training-lb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.mySecurityGroupPublic.id]
  subnets            = [aws_subnet.subnet_public.id, aws_subnet.subnet_private.id]
  tags = {
    Name = "aws_training_lb"
  }
}

resource "aws_lb_listener" "lb_listener" {
  load_balancer_arn = aws_lb.aws_training_lb.arn
  port              = 80
  protocol          = "HTTP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.aws_training_lb_tg.arn
  }
}

resource "aws_lb_target_group_attachment" "attachment1" {
  target_group_arn = aws_lb_target_group.aws_training_lb_tg.arn
  target_id        = aws_instance.EC2InstancePublic.id
  port             = 80
}

resource "aws_lb_target_group_attachment" "attachment2" {
  target_group_arn = aws_lb_target_group.aws_training_lb_tg.arn
  target_id        = aws_instance.EC2InstancePrivate.id
  port             = 80
}
