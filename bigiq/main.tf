terraform {
  required_version = ">=0.9.6"
}

provider "aws" {
  region = "${var.aws_region}"
}

resource "aws_vpc" "terraform-vpc" {
  cidr_block           = "10.0.0.0/16"
  instance_tenancy     = "default"
  enable_dns_support   = "true"
  enable_dns_hostnames = "true"
  enable_classiclink   = "false"

  tags {
    Name = "terraform_${var.emailid}"
  }
}

resource "aws_subnet" "f5-management-a" {
  vpc_id                  = "${aws_vpc.terraform-vpc.id}"
  cidr_block              = "10.0.101.0/24"
  map_public_ip_on_launch = "false"
  availability_zone       = "${var.aws_region}a"

  tags {
    Name = "management"
  }
}

resource "aws_internet_gateway" "gw" {
  vpc_id = "${aws_vpc.terraform-vpc.id}"

  tags {
    Name = "internet-gateway"
  }
}

resource "aws_route_table" "rt1" {
  vpc_id = "${aws_vpc.terraform-vpc.id}"

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = "${aws_internet_gateway.gw.id}"
  }

  tags {
    Name = "Default"
  }
}

resource "aws_main_route_table_association" "association-subnet" {
  vpc_id         = "${aws_vpc.terraform-vpc.id}"
  route_table_id = "${aws_route_table.rt1.id}"
}

resource "aws_security_group" "f5_management" {
  name   = "f5_management"
  vpc_id = "${aws_vpc.terraform-vpc.id}"

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = "${var.restrictedSrcAddress}"
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = "${var.restrictedSrcAddress}"
  }

  ingress {
    from_port   = 8
    to_port     = 0
    protocol    = "icmp"
    cidr_blocks = "${var.restrictedSrcAddress}"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

data "template_file" "init" {
  template = "${file("init.tpl")}"
  vars {
    bigiq_regkey = "${var.bigiq_regkey}"
  }
}

resource "aws_instance" "bigiq" {
  count                       = 1
  ami                         = "${var.bigiq_ami}"
  instance_type               = "m4.large"
  subnet_id                   = "${aws_subnet.f5-management-a.id}"
  vpc_security_group_ids      = ["${aws_security_group.f5_management.id}"]
  key_name                    = "${var.aws_keypair}"
  associate_public_ip_address = true
  user_data = "${data.template_file.init.rendered}"
  disable_api_termination     = false
  tags {
    Name = "DO_NO_DELETE_f5-bigiq-terraform"
    Role = "BigIqLicenseManager"
  }
/*
  connection {
    type = "ssh"
    user = "admin"
    private_key = "${file("~/marfil-f5-terraform/${var.aws_keypair}.pem")}"
    timeout = "8m"
  }

  provisioner "remote-exec" {
    inline = [
        "install /sys license registration-key ${var.bigiq_regkey}"
      ]
  }
*/
}
resource "aws_eip" "bigiq-eip" {
  instance = "${aws_instance.bigiq.id}"
  vpc      = true
}
