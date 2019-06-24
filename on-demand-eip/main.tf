# Configure the Amazon AWS Provider
provider "aws" {
  access_key = "${var.aws_access_key}"
  secret_key = "${var.aws_secret_key}"
  region     = "${var.region}"
}

variable "instance_count" {
  default     = "1"
  description = "Number of instances to create"
}

variable "aws_access_key" {
  default     = "xxx"
  description = "Amazon AWS Access Key"
}

variable "aws_secret_key" {
  default     = "xxx"
  description = "Amazon AWS Secret Key"
}

variable "r53_hosted_zone" {
  default = "my-domain.com."
}

variable "vpc_id" {

}
variable "prefix" {
  default     = "yourname"
  description = "Cluster Prefix - All resources created by Terraform have this prefix prepended to them"
}

variable "region" {
  default     = "us-west-2"
  description = "Amazon AWS Region for deployment"
}
variable "availability_zones" {
type = "list"
}
variable "subnet_ids" {type = "list"}
variable "type" {
  default     = "t2.medium"
  description = "Amazon AWS Instance Type"
}

variable "instance_disk_size" {
  default = "35"
}
variable "ssh_key_name" {
  default     = ""
  description = "Amazon AWS Key Pair Name"
}

variable "ssh_key_path" {
  default     = ""
  description = "Path to the private key named by ssh_key_name"
}

data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-bionic-18.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# Create a new load balancer
resource "aws_elb" "elb" {
  name               = "${var.prefix}-terrarancher-elb"
  subnets             = "${var.subnet_ids}"

  listener {
    instance_port     = 443
    instance_protocol = "tcp"
    lb_port           = 443
    lb_protocol       = "tcp"
  }

  listener {
    instance_port     = 80
    instance_protocol = "tcp"
    lb_port           = 80
    lb_protocol       = "tcp"
  }

  health_check {
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 3
    target              = "TCP:443"
    interval            = 30
  }

  instances                   = ["${aws_instance.terrarancher.*.id}"]
  cross_zone_load_balancing   = true
  idle_timeout                = 400
  connection_draining         = true
  connection_draining_timeout = 400
  security_groups = ["${aws_security_group.rancher_mgmt_sg.id}"]
  tags {
    Name = "${var.prefix}-terrarancher-elb"
  }
}

resource "aws_security_group" "rancher_mgmt_sg" {
  name = "${var.prefix}-mgmt-terrarancher"
  vpc_id = "${var.vpc_id}"

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 6443
    to_port     = 6443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "rancher_internal_sg" {
  name = "${var.prefix}-internal-terrarancher"
  vpc_id = "${var.vpc_id}"

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    self = true
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    self = true
  }

  ingress {
    from_port   = 2379
    to_port     = 2380
    protocol    = "tcp"
    self = true
  }

  ingress {
    from_port   = 9009
    to_port     = 9009
    protocol    = "tcp"
    self = true
  }

  ingress {
    from_port   = 8472
    to_port     = 8472
    protocol    = "udp"
    self = true
  }

  ingress {
    from_port   = 10250
    to_port     = 10256
    protocol    = "tcp"
    self = true
  }

  ingress {
    from_port   = 30000
    to_port     = 32767
    protocol    = "tcp"
    self = true
  }
}

data "template_cloudinit_config" "terrarancher_cloudinit" {
  part {
    content_type = "text/x-shellscript"
    content      = "${file("18.09.sh")}"
  }
  part {
    content_type = "text/x-shellscript"
    content      = "#!/bin/sh\nusermod -aG docker ubuntu"
  }
  part {
    content_type = "text/x-shellscript"
    content      = "${file("setup_overlay2.sh")}"
  }
}

resource "aws_instance" "terrarancher" {
  count           = "${var.instance_count}"
  availability_zone = "${element(var.availability_zones, count.index)}"
  ami             = "${data.aws_ami.ubuntu.image_id}"
  instance_type   = "${var.type}"
  key_name        = "${var.ssh_key_name}"
  vpc_security_group_ids = ["${aws_security_group.rancher_internal_sg.id}", "${aws_security_group.rancher_mgmt_sg.id}"]
  subnet_id = "${element(var.subnet_ids, count.index)}"
  user_data = "${data.template_cloudinit_config.terrarancher_cloudinit.rendered}"
  root_block_device {
    volume_size = "${var.instance_disk_size}"
  }
  tags {
    Name = "${var.prefix}-ondemand-${count.index}"
  }
}

resource "aws_eip" "terrarancher-eip" {
  count = "${var.instance_count}"
  vpc = true
  instance = "${aws_instance.terrarancher.*.id[count.index]}"
  tags {
    Name = "${var.prefix}-ondemand-eip-${count.index}"
  }
}

terraform {
  backend "local" {
  }
}

terraform {
  backend "s3" {
  }
}

data "aws_route53_zone" "r53_zone" {
  name         = "${var.r53_hosted_zone}"
}

resource "aws_route53_record" "r53_record" {
  zone_id = "${data.aws_route53_zone.r53_zone.zone_id}"
  name    = "${var.prefix}.${data.aws_route53_zone.r53_zone.name}"
  type    = "A"

  alias {
    name                   = "${aws_elb.elb.dns_name}"
    zone_id                = "${aws_elb.elb.zone_id}"
    evaluate_target_health = false
  }
}

data "template_file" "segment" {
  count = "${var.instance_count}"
  template = "- address: ${aws_eip.terrarancher-eip.*.public_ip[count.index]}\n  internal_address: ${aws_eip.terrarancher-eip.*.private_ip[count.index]}\n  user: ubuntu\n  role: [controlplane,etcd,worker]\n  docker_socket: /var/run/docker.sock\n  ssh_key_path: ${var.ssh_key_path}"
}

output "clusteryml" {
  value = "nodes:\n${join("\n", data.template_file.segment.*.rendered)}"
}

output "rancherhost" {
  value = "${aws_route53_record.r53_record.name}"
}
