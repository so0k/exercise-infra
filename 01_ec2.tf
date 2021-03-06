# Specify the provider and access details
provider "aws" {
  region = "${var.aws_region}"
}

## EC2

### Network

data "aws_availability_zones" "available" {}

resource "aws_vpc" "main" {
  cidr_block = "${var.cidr_block}"

  tags {
    Name = "ecs"
    Cluster = "${var.cluster_name}"
    Owner = "${var.tag_Owner}"
    builtWith = "terraform"
  }
}

resource "aws_subnet" "main" {
  count             = "${var.az_count}"
  cidr_block        = "${cidrsubnet(aws_vpc.main.cidr_block, 8, count.index)}"
  availability_zone = "${data.aws_availability_zones.available.names[count.index]}"
  vpc_id            = "${aws_vpc.main.id}"

  tags {
    Name = "ecs ${data.aws_availability_zones.available.names[count.index]}"
    Cluster = "${var.cluster_name}"
    Owner = "${var.tag_Owner}"
    builtWith = "terraform"
  }
}

resource "aws_internet_gateway" "gw" {
  vpc_id = "${aws_vpc.main.id}"

  tags {
    Name = "ecs ${data.aws_availability_zones.available.names[count.index]}"
    Cluster = "${var.cluster_name}"
    Owner = "${var.tag_Owner}"
    builtWith = "terraform"
  }
}

resource "aws_route_table" "r" {
  vpc_id = "${aws_vpc.main.id}"

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = "${aws_internet_gateway.gw.id}"
  }

  tags {
    Cluster = "${var.cluster_name}"
    Owner = "${var.tag_Owner}"
    builtWith = "terraform"
  }
}

resource "aws_route_table_association" "a" {
  count          = "${var.az_count}"
  subnet_id      = "${element(aws_subnet.main.*.id, count.index)}"
  route_table_id = "${aws_route_table.r.id}"
}

### Compute

resource "aws_autoscaling_group" "app" {
  name                 = "ecs-${var.cluster_name}-asg"
  vpc_zone_identifier  = ["${aws_subnet.main.*.id}"]
  min_size             = "${var.asg_min}"
  max_size             = "${var.asg_max}"
  desired_capacity     = "${var.asg_desired}"
  launch_configuration = "${aws_launch_configuration.app.name}"

  lifecycle {
    create_before_destroy = true
  }

  tag {
    key = "builtWith"
    value = "terraform"
    propagate_at_launch = false
  }
  tag {
    key = "Cluster"
    value = "${var.cluster_name}"
    propagate_at_launch = true
  }
  tag {
    key = "Owner"
    value = "${var.tag_Owner}"
    propagate_at_launch = true
  }
}

data "template_file" "cloud_config" {
  template = "${file("${path.module}/templates/cloud-config.yml")}"

  vars {
    aws_region         = "${var.aws_region}"
    ecs_cluster_name   = "${aws_ecs_cluster.main.name}"
    ecs_log_level      = "info"
    ecs_agent_version  = "latest"
    ecs_log_group_name = "${aws_cloudwatch_log_group.ecs.name}"
    nfs_host           = "${var.nfs_host}"
  }
}

# aws ec2 describe-images --owners 595879546273 \
# --filters "Name=description,Values=CoreOS stable*,Name=architecture,Values=x86_64,Name=virtualization-type,Values=hvm"
# first one: jq .Images[0]
data "aws_ami" "stable_coreos" {
  most_recent = true

  filter {
    name   = "description"
    values = ["CoreOS stable *"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["595879546273"] # CoreOS
}

resource "aws_launch_configuration" "app" {
  name_prefix   = "ecs-${var.cluster_name}-"
  security_groups = [
    "${aws_security_group.instance_sg.id}",
  ]

  key_name                    = "${var.key_name}"
  image_id                    = "${data.aws_ami.stable_coreos.id}"
  instance_type               = "${var.instance_type}"
  iam_instance_profile        = "${aws_iam_instance_profile.app.name}"
  user_data                   = "${data.template_file.cloud_config.rendered}"
  associate_public_ip_address = true

  lifecycle {
    create_before_destroy = true
  }
}

### Security

resource "aws_security_group" "lb_sg" {
  description = "controls access to the application ELB"

  vpc_id = "${aws_vpc.main.id}"
  name   = "ecs-${var.cluster_name}-lbsg"

  ingress {
    protocol    = "tcp"
    from_port   = 80
    to_port     = 80
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port = 0
    to_port   = 0
    protocol  = "-1"

    cidr_blocks = [
      "0.0.0.0/0",
    ]
  }

  tags {
    Cluster = "${var.cluster_name}"
    Owner = "${var.tag_Owner}"
    builtWith = "terraform"
  }
}

resource "aws_security_group" "instance_sg" {
  description = "controls direct access to application instances"
  vpc_id      = "${aws_vpc.main.id}"
  name        = "ecs-${var.cluster_name}-instsg"

  ingress {
    protocol  = "tcp"
    from_port = 22
    to_port   = 22

    cidr_blocks = [
      "${var.admin_cidr_ingress}",
    ]
  }

  ingress {
    protocol  = "tcp"
    from_port = 5000
    to_port   = 5000

    security_groups = [
      "${aws_security_group.lb_sg.id}",
    ]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags {
    Cluster = "${var.cluster_name}"
    Owner = "${var.tag_Owner}"
    builtWith = "terraform"
  }
}

## ECS

resource "aws_ecs_cluster" "main" {
  name = "${var.cluster_name}"
}

data "template_file" "task_definition" {
  template = "${file("${path.module}/templates/task-definition.json")}"

  vars {
    image_url        = "so0k/aws-uploads-sample:latest"
    container_name   = "uploads"
    log_group_region = "${var.aws_region}"
    log_group_name   = "${aws_cloudwatch_log_group.app.name}"
    upload_key       = "${aws_iam_access_key.uploads_user.id}"
    upload_secret    = "${aws_iam_access_key.uploads_user.secret}"
    upload_bucket    = "${var.uploads_bucket}"
    upload_region    = "${var.aws_region}"
  }
}

resource "aws_ecs_task_definition" "uploads" {
  family                = "uploads_td"
  container_definitions = "${data.template_file.task_definition.rendered}"
}

resource "aws_ecs_service" "uploads" {
  name            = "ecs-uploads"
  cluster         = "${aws_ecs_cluster.main.id}"
  task_definition = "${aws_ecs_task_definition.uploads.arn}"
  desired_count   = 1
  iam_role        = "${aws_iam_role.ecs_service.name}"

  load_balancer {
    target_group_arn = "${aws_alb_target_group.app.id}"
    container_name   = "uploads"
    container_port   = "5000"
  }

  depends_on = [
    "aws_iam_role_policy.ecs_service",
    "aws_alb_listener.front_end",
  ]
}


## ALB

resource "aws_alb_target_group" "app" {
  name     = "ecs-uploads"
  port     = 80
  protocol = "HTTP"
  vpc_id   = "${aws_vpc.main.id}"

  health_check {
    path   = "/upload/"
  }
}

resource "aws_alb" "main" {
  name            = "ecs-${var.cluster_name}-main"
  subnets         = ["${aws_subnet.main.*.id}"]
  security_groups = ["${aws_security_group.lb_sg.id}"]
}

resource "aws_alb_listener" "front_end" {
  load_balancer_arn = "${aws_alb.main.id}"
  port              = "80"
  protocol          = "HTTP"

  default_action {
    target_group_arn = "${aws_alb_target_group.app.id}"
    type             = "forward"
  }
}

## CloudWatch Logs

resource "aws_cloudwatch_log_group" "ecs" {
  name = "ecs-${var.cluster_name}-group/ecs-agent"
}

resource "aws_cloudwatch_log_group" "app" {
  name = "ecs-${var.cluster_name}-group/app-uploads"
}

