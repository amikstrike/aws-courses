variable "SSHKeyName" {
  description = "The EC2 Key Pair to allow SSH access to the instances"
  default     = "awssshkey"
}

provider "aws" {
  profile = "default"
  region = "us-west-2"
}

output "elb_dns_name" {
  value = aws_elb.elb.dns_name
}

resource "aws_security_group" "allow_ssh_and_http" {
  name = "AllowSSHAndHTTP"
  description = "Allow SSH/HTTP access"
  vpc_id = aws_vpc.vpc.id

  egress {
    protocol = "-1"
    to_port = 0
    from_port = 0
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    protocol = "tcp"
    to_port = 22
    from_port = 22
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    protocol = "tcp"
    to_port = 80
    from_port = 80
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    protocol = "tcp"
    to_port = 443
    from_port = 443
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "allow_ssh_and_http_internal" {
  name = "AllowSSHAndHTTPInternal"
  description = "Allow SSH/HTTP internal access"
  vpc_id = aws_vpc.vpc.id

  egress {
    protocol = "-1"
    to_port = 0
    from_port = 0
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    protocol = "tcp"
    to_port = 22
    from_port = 22
    cidr_blocks = [aws_subnet.public_subnet.cidr_block]
  }

  ingress {
    protocol = "tcp"
    to_port = 80
    from_port = 80
    cidr_blocks = [aws_subnet.public_subnet.cidr_block]
  }
}

resource "aws_security_group" "allow_http" {
  name = "AllowHTTP"
  description = "Allow HTTP access"
  vpc_id = aws_vpc.vpc.id

  egress {
    protocol = "-1"
    to_port = 0
    from_port = 0
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    protocol = "tcp"
    to_port = 80
    from_port = 80
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "rds_ingress" {
  name = "AllowRDSAccess"
  description = "Allow RDS TCP access"
  vpc_id = aws_vpc.vpc.id

  egress {
    protocol = "-1"
    to_port = 0
    from_port = 0
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    protocol = "tcp"
    to_port = 5432
    from_port = 5432
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_sqs_queue" "queue" {
  name = "edu-lohika-training-aws-sqs-queue"
}

resource "aws_sns_topic" "sns_topic" {
  name = "edu-lohika-training-aws-sns-topic"
}

resource "aws_vpc" "vpc" {
  cidr_block = "10.0.0.0/16"
}

resource "aws_subnet" "public_subnet" {
  vpc_id = aws_vpc.vpc.id
  cidr_block = "10.0.1.0/24"
  availability_zone = "us-west-2a"
}

resource "aws_subnet" "private_subnet" {
  vpc_id = aws_vpc.vpc.id
  cidr_block = "10.0.2.0/24"
  availability_zone = "us-west-2b"
}

resource "aws_internet_gateway" "internet_gateway" {
  vpc_id = aws_vpc.vpc.id
}

resource "aws_route_table" "public_route_table" {
  vpc_id = aws_vpc.vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.internet_gateway.id
  }
}

resource "aws_route_table_association" "public_subnet_route" {
  subnet_id = aws_subnet.public_subnet.id
  route_table_id = aws_route_table.public_route_table.id
}

resource "aws_route_table" "private_route_table" {
  vpc_id = aws_vpc.vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    instance_id = aws_instance.bastion.id
  }
}

resource "aws_route_table_association" "private_subnet_route" {
  subnet_id = aws_subnet.private_subnet.id
  route_table_id = aws_route_table.private_route_table.id
}

resource "aws_db_subnet_group" "private" {
  name = "subnet_group"
  subnet_ids = [
    aws_subnet.public_subnet.id,
    aws_subnet.private_subnet.id
  ]
}

resource "aws_dynamodb_table" "dynamodb_table" {
  name = "edu-lohika-training-aws-dynamodb"
  hash_key = "UserName"
  read_capacity  = 5
  write_capacity = 5

  attribute {
    name = "UserName"
    type = "S"
  }
}

resource "aws_db_instance" "rds" {
  instance_class = "db.t2.micro"
  allocated_storage = 20
  engine = "postgres"
  engine_version = "11.6"
  name = "EduLohikaTrainingAwsRds"
  username = "rootuser"
  password = "rootuser"
  vpc_security_group_ids = [aws_security_group.rds_ingress.id]
  db_subnet_group_name = aws_db_subnet_group.private.name
  skip_final_snapshot = true
}

resource "aws_iam_instance_profile" "for_public" {
  name = "PublicInstanceProfile"
  role = aws_iam_role.for_public.name
}

resource "aws_iam_instance_profile" "for_private" {
  name = "PrivateInstanceProfile"
  role = aws_iam_role.for_private.name
}

resource "aws_launch_configuration" "lc" {
  image_id = "ami-0ce21b51cb31a48b8"
  instance_type = "t2.micro"
  security_groups = [aws_security_group.allow_ssh_and_http_internal.id]
  iam_instance_profile = aws_iam_instance_profile.for_public.name
  key_name = var.SSHKeyName
  associate_public_ip_address = true
  user_data = <<-EOF
  #!/bin/bash -xe
  sudo yum -y update
  sudo yum -y install java-1.8.0-openjdk
  aws s3 cp s3://w6-oivchenko-s3/calc-0.0.1-SNAPSHOT.jar /home/ec2-user/calc-0.0.1-SNAPSHOT.jar
  sudo nohup java -jar /home/ec2-user/calc-0.0.1-SNAPSHOT.jar &
  EOF
}

resource "aws_autoscaling_group" "ag" {
  max_size = 2
  min_size = 2
  vpc_zone_identifier = [aws_subnet.public_subnet.id]
  launch_configuration = aws_launch_configuration.lc.name
  load_balancers = [aws_elb.elb.name]
}

resource "aws_instance" "private_ec2" {
  ami = "ami-0ce21b51cb31a48b8"
  instance_type = "t2.micro"
  key_name = var.SSHKeyName
  subnet_id = aws_subnet.private_subnet.id
  security_groups = [aws_security_group.allow_ssh_and_http_internal.id]
  iam_instance_profile = aws_iam_instance_profile.for_private.name
  user_data = <<-EOF
  #!/bin/bash -xe
  sudo yum -y update
  sudo yum -y install java-1.8.0-openjdk
  aws s3 cp s3://w6-oivchenko-s3/persist3-0.0.1-SNAPSHOT.jar /home/ec2-user/persist3-0.0.1-SNAPSHOT.jar
  export RDS_HOST=${aws_db_instance.rds.endpoint}
  nohup java -jar /home/ec2-user/persist3-0.0.1-SNAPSHOT.jar &
  EOF
  tags = {
    Name = "Private"
  }
}

resource "aws_instance" "bastion" {
  ami = "ami-0032ea5ae08aa27a2"
  instance_type = "t2.micro"
  subnet_id = aws_subnet.public_subnet.id
  security_groups = [aws_security_group.allow_ssh_and_http.id]
  key_name = var.SSHKeyName
  source_dest_check = false
  associate_public_ip_address = true
  tags = {
    Name = "Bastion"
  }
}

resource "aws_elb" "elb" {
  subnets = [aws_subnet.public_subnet.id]
  security_groups = [aws_security_group.allow_http.id]

  listener {
    instance_port = 80
    instance_protocol = "HTTP"
    lb_port = 80
    lb_protocol = "HTTP"
  }

  health_check {
    interval = 30
    timeout = 15
    target = "HTTP:80/health"
    healthy_threshold = 2
    unhealthy_threshold = 2
  }
}

resource "aws_iam_role" "for_public" {
  name = "ForPublic"

  assume_role_policy = <<-EOF
  {
    "Version": "2012-10-17",
    "Statement": [
      {
        "Action": "sts:AssumeRole",
        "Principal": {
          "Service": "ec2.amazonaws.com"
        },
        "Effect": "Allow"
      }
    ]
  }
  EOF
}

resource "aws_iam_role" "for_private" {
  name = "ForPrivate"

  assume_role_policy = <<-EOF
  {
    "Version": "2012-10-17",
    "Statement": [
      {
        "Action": "sts:AssumeRole",
        "Principal": {
          "Service": "ec2.amazonaws.com"
        },
        "Effect": "Allow"
      }
    ]
  }
  EOF
}

resource "aws_iam_policy" "s3" {
  name = "AmazonS3ReadOnlyAccess"

  policy = <<-EOF
  {
    "Version": "2012-10-17",
    "Statement": [
      {
        "Action": [
          "s3:Get*",
          "s3:List*"
        ],
        "Effect": "Allow",
        "Resource": "*"
      }
    ]
  }
  EOF
}

resource "aws_iam_policy" "dynamodb" {
  name = "AmazonDynamoDBAccess"

  policy = <<-EOF
  {
    "Version": "2012-10-17",
    "Statement": [
      {
        "Action": [
          "dynamodb:*"
        ],
        "Effect": "Allow",
        "Resource": "*"
      }
    ]
  }
  EOF
}

resource "aws_iam_policy" "sqs" {
  name = "AmazonSQSFullAccess"

  policy = <<-EOF
  {
    "Version": "2012-10-17",
    "Statement": [
      {
        "Action": [
          "sqs:*"
        ],
        "Effect": "Allow",
        "Resource": "*"
      }
    ]
  }
  EOF
}

resource "aws_iam_policy" "sns" {
  name = "AmazonSNSFullAccess"

  policy = <<-EOF
  {
    "Version": "2012-10-17",
    "Statement": [
      {
        "Action": [
          "sns:*"
        ],
        "Effect": "Allow",
        "Resource": "*"
      }
    ]
  }
  EOF
}

resource "aws_iam_role_policy_attachment" "for_public_s3" {
  role = aws_iam_role.for_public.name
  policy_arn = aws_iam_policy.s3.arn
}

resource "aws_iam_role_policy_attachment" "for_public_dynamodb" {
  role = aws_iam_role.for_public.name
  policy_arn = aws_iam_policy.dynamodb.arn
}

resource "aws_iam_role_policy_attachment" "for_public_sqs" {
  role = aws_iam_role.for_public.name
  policy_arn = aws_iam_policy.sqs.arn
}

resource "aws_iam_role_policy_attachment" "for_public_sns" {
  role = aws_iam_role.for_public.name
  policy_arn = aws_iam_policy.sns.arn
}

resource "aws_iam_role_policy_attachment" "for_private_s3" {
  role = aws_iam_role.for_private.name
  policy_arn = aws_iam_policy.s3.arn
}

resource "aws_iam_role_policy_attachment" "for_private_sqs" {
  role = aws_iam_role.for_private.name
  policy_arn = aws_iam_policy.sqs.arn
}

resource "aws_iam_role_policy_attachment" "for_private_sns" {
  role = aws_iam_role.for_private.name
  policy_arn = aws_iam_policy.sns.arn
}
