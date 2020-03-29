provider "aws" {
  profile = "default"
  region = "us-west-2"
}

resource "aws_security_group" "InstanceSecurityGroup" {
  name        = "InstanceSecurityGroup"
  description = "Allow TLS inbound traffic"
  vpc_id      = "vpc-894e29f1"

  ingress {
    description = "allow_ssh"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "80 from VPC"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "22 from VPC"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 64000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_iam_instance_profile" "RootInstanceProfile" {
  name = "RootInstanceProfile"
  role = "ec2tos3fullaccess"
}

resource "aws_launch_configuration" "LaunchConfig" {
  name_prefix   = "LaunchConfig"
  image_id      = "ami-0ce21b51cb31a48b8"
  instance_type = "t2.micro"
  security_groups = ["${aws_security_group.InstanceSecurityGroup.id}"]
  key_name = "awssshkey"
  iam_instance_profile = "${aws_iam_instance_profile.RootInstanceProfile.id}"
  user_data = <<-EOF
    #! /bin/bash
    sudo yum update -y
    sudo yum install java-1.8.0-openjdk
    sudo aws s3 cp s3://oivchenkos3b2/test.txt /home/ec2-user/test.txt
	EOF
}

resource "aws_autoscaling_group" "asg2" {
  name                      = "foobar3-terraform-test"
  max_size                  = 2
  min_size                  = 2
  health_check_grace_period = 120
  health_check_type         = "ELB"
  desired_capacity          = 2
  force_delete              = true
  launch_configuration      = "${aws_launch_configuration.LaunchConfig.name}"
  vpc_zone_identifier       = ["subnet-8b09cad6", "subnet-b39464cb", "subnet-a98391e2", "subnet-8fe398a4"]
}
