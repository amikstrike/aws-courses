provider "aws" {
  region = "us-west-2"
}

resource "aws_security_group" "oivchenko_w3_sg" {
  description = "SSH, HTTP/HTTPS access"
  name = "oivchenko_w3_sg"

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

resource "aws_iam_role" "MyAccessRole" {
  name = "MyAccessRole"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

resource "aws_iam_role_policy" "MultipleAccessPolicy" {
  name = "MultipleAccessPolicy"
  role = aws_iam_role.MyAccessRole.id

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "s3:*"
      ],
      "Effect": "Allow",
      "Resource": "*"
    },
    {
      "Action": [
        "rds:*"
      ],
      "Effect": "Allow",
      "Resource": "*"
    },
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

resource "aws_iam_instance_profile" "myIAMInstanceProfile" {
  name = "myIAMInstanceProfile"
  role = aws_iam_role.MyAccessRole.name
}

resource "aws_security_group" "DBSecurityGroup" {
  name        = "DBSecurityGroup"
  description = "Enable ec2 to db access"
  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.oivchenko_w3_sg.id]
  }
}

resource "aws_db_instance" "rds" {
  instance_class = "db.t2.micro"
  allocated_storage = 20
  engine = "postgres"
  engine_version = "11.6"
  username = "postgres"
  password = "password"
  vpc_security_group_ids = [aws_security_group.DBSecurityGroup.id]
  skip_final_snapshot = true
}

resource "aws_dynamodb_table" "dynamodb_table" {
  hash_key       = "Body"
  range_key      = "Title"
  name           = "Message"
  read_capacity  = 5
  write_capacity = 5
  attribute {
    name = "Body"
    type = "S"
  }
  attribute {
    name = "Title"
    type = "S"
  }
}

resource "aws_instance" "Ec2Instance" {
  ami = "ami-01f08ef3e76b957e5"
  instance_type = "t2.micro"
  key_name = "awssshkey"
  iam_instance_profile = aws_iam_instance_profile.myIAMInstanceProfile.name
  vpc_security_group_ids = [aws_security_group.oivchenko_w3_sg.id]
  user_data = <<EOF
#!/bin/bash
sudo yum update -y
aws s3 cp s3://oivchenko-s3-w3 ~ --recursive 
EOF
}
