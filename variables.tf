variable "aws_region" {
  description = "The AWS region to create things in."
  default     = "ap-southeast-1"
}

variable "tag_Owner" {
  description = "Owner of cluster"
}

variable "az_count" {
  description = "Number of AZs to cover in a given AWS region"
  default     = "2"
}

variable "key_name" {
  description = "Name of AWS key pair"
}

variable "cidr_block" {
  description = "cluster VPC subnet"
  default = "10.10.0.0/16"
}

variable "cluster_name" {
  description = "cluster name"
  default = "production"
}

# see: https://aws.amazon.com/amazon-linux-ami/instance-type-matrix/
variable "instance_type" {
  default     = "t2.small"
  description = "AWS instance type, must support HVM"
}

variable "asg_min" {
  description = "Min numbers of servers in ASG"
  default     = "1"
}

variable "asg_max" {
  description = "Max numbers of servers in ASG"
  default     = "2"
}

variable "asg_desired" {
  description = "Desired numbers of servers in ASG"
  default     = "1"
}

variable "admin_cidr_ingress" {
  description = "CIDR to allow tcp/22 ingress to EC2 instance"
}
